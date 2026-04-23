import Domain
import CryptoKit
import Foundation

public enum WorkspaceServiceError: Error, Equatable, Sendable {
    case importPreviewNotReady
    case importPreviewSourceRowsUnavailable
    case importPreviewCouldNotNormalizeRow(line: Int)
    case transactionLedgerUnavailable
    case reviewQueueUnavailable
    case learnedRuleManagementUnavailable
    case monthlyTargetConflict(MonthlyTargetConflict)
    case archivedAccountImportUnavailable
    case accountManagementUnavailable
    case accountDeleteBlocked
    case targetManagementUnavailable
    case workspaceMaintenanceUnavailable
}

extension WorkspaceServiceError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .importPreviewNotReady:
            "The CSV preview must be valid before it can be imported."
        case .importPreviewSourceRowsUnavailable:
            "The CSV preview no longer has the source rows needed for import."
        case .importPreviewCouldNotNormalizeRow(let line):
            "CSV row \(line) could not be normalized for import."
        case .transactionLedgerUnavailable:
            "The transaction ledger is unavailable for this workspace."
        case .reviewQueueUnavailable:
            "The review queue is unavailable for this workspace."
        case .learnedRuleManagementUnavailable:
            "Learned rules are unavailable for this workspace."
        case .monthlyTargetConflict(let conflict):
            switch conflict {
            case .duplicateScope:
                "A monthly target already exists for that scope."
            case .categoryGroupOverlap:
                "A monthly target cannot overlap a category group and one of its member categories."
            }
        case .archivedAccountImportUnavailable:
            "Archived accounts can't accept new imports."
        case .accountManagementUnavailable:
            "Accounts are unavailable for this workspace."
        case .accountDeleteBlocked:
            "This account can't be deleted because it still has imported files or transactions."
        case .targetManagementUnavailable:
            "Monthly targets are unavailable for this workspace."
        case .workspaceMaintenanceUnavailable:
            "Workspace maintenance is unavailable for this workspace."
        }
    }
}

public enum StagedCSVImportOutcome: Equatable, Sendable {
    case staged
    case exactReimportNoOp
}

public struct StagedCSVImportResult: Equatable, Sendable {
    public var outcome: StagedCSVImportOutcome
    public var session: StagedImportSession?
    public var decisions: [ImportRowDecision]
    public var classifications: [ImportRowClassification]
    public var summary: StagedImportDecisionSummary

    public init(
        outcome: StagedCSVImportOutcome,
        session: StagedImportSession?,
        decisions: [ImportRowDecision],
        classifications: [ImportRowClassification] = [],
        summary: StagedImportDecisionSummary
    ) {
        self.outcome = outcome
        self.session = session
        self.decisions = decisions
        self.classifications = classifications
        self.summary = summary
    }
}

public struct ReviewCreatedLearnedRuleAction: Equatable, Sendable {
    public var ruleID: UUID
    public var merchantLabel: String
    public var destination: SettingsDestination

    public init(ruleID: UUID, merchantLabel: String, destination: SettingsDestination) {
        self.ruleID = ruleID
        self.merchantLabel = merchantLabel
        self.destination = destination
    }
}

public struct ReviewApprovalResult: Equatable, Sendable {
    public var decisionEvent: ReviewDecisionEvent
    public var createdLearnedRuleAction: ReviewCreatedLearnedRuleAction?

    public init(
        decisionEvent: ReviewDecisionEvent,
        createdLearnedRuleAction: ReviewCreatedLearnedRuleAction?
    ) {
        self.decisionEvent = decisionEvent
        self.createdLearnedRuleAction = createdLearnedRuleAction
    }
}

public struct WorkspaceService: Sendable {
    private let store: any WorkspaceStoring & StagedImportWriting & ImportDecisionReading
    private let merchantNormalizer: MerchantNormalizer
    private let classifier: ClassificationEngine

    public init(
        store: any WorkspaceStoring & StagedImportWriting & ImportDecisionReading,
        merchantNormalizer: MerchantNormalizer = MerchantNormalizer(),
        classifier: ClassificationEngine = ClassificationEngine()
    ) {
        self.store = store
        self.merchantNormalizer = merchantNormalizer
        self.classifier = classifier
    }

    public func loadSnapshot(filter: TransactionLedgerFilter = .empty) throws -> WorkspaceSnapshot {
        let ledgerReader = store as? any TransactionLedgerReading
        let reportingReader = store as? any ReportingReading
        let reviewReader = store as? any ReviewQueueReading
        let summary = try store.fetchSummary()
        let monthlyReport = try reportingReader?.fetchMonthlyReport(referenceDate: .now) ?? .empty
        let managementAccounts = try store.fetchManagementAccounts()
        let importEligibleAccounts = try store.fetchImportEligibleAccounts()
        let ledgerFilterAccounts = try store.fetchLedgerFilterAccounts()
        let permanentlyDeletableAccountIDs = try store.fetchPermanentlyDeletableAccountIDs()
        return WorkspaceSnapshot(
            summary: summary,
            managementAccounts: managementAccounts,
            importEligibleAccounts: importEligibleAccounts,
            ledgerFilterAccounts: ledgerFilterAccounts,
            permanentlyDeletableAccountIDs: permanentlyDeletableAccountIDs,
            categories: try store.fetchCategories(),
            categoryGroups: try store.fetchCategoryGroups(),
            pendingReviewItems: try reviewReader?.fetchPendingReviewItems() ?? [],
            transactions: try ledgerReader?.fetchTransactionLedger(filter: filter) ?? [],
            transactionImportOrigins: try ledgerReader?.fetchTransactionImportOrigins() ?? [],
            monthlyReport: monthlyReport,
            homeDashboard: HomeDashboardSnapshot.make(summary: summary, monthlyReport: monthlyReport)
        )
    }

    public func loadLearnedRuleManagerSnapshot() throws -> LearnedRuleManagerSnapshot {
        guard let learnedRuleReader = store as? any LearnedRuleReading else {
            throw WorkspaceServiceError.learnedRuleManagementUnavailable
        }
        let learnedRules = try learnedRuleReader.fetchLearnedRuleSummaries()
        let learnedRows = learnedRules.map { ManagedLearnedRuleRow(summary: $0) }
        return LearnedRuleManagerSnapshot(
            learned: LearnedRuleManagerSectionSnapshot(
                mode: .learned,
                rows: learnedRows
            ),
            seeded: LearnedRuleManagerSectionSnapshot(
                mode: .seeded,
                rows: seededRuleSourceRows()
            )
        )
    }

    @discardableResult
    public func createLearnedRule(
        _ draft: LearnedRuleDraft,
        createdAt: Date = .now
    ) throws -> ManagedLearnedRule {
        guard let learnedRuleWriter = store as? any LearnedRuleWriting else {
            throw WorkspaceServiceError.learnedRuleManagementUnavailable
        }

        return try learnedRuleWriter.createLearnedRule(draft, createdAt: createdAt)
    }

    public func duplicateLearnedRuleAsDraft(id: UUID) throws -> LearnedRuleDraft? {
        guard let learnedRuleReader = learnedRuleReader() else {
            throw WorkspaceServiceError.learnedRuleManagementUnavailable
        }

        guard let detail = try learnedRuleReader.fetchLearnedRuleDetail(id: id) else {
            return nil
        }
        return LearnedRuleDraft(rule: detail)
    }

    @discardableResult
    public func disableLearnedRule(id: UUID, disabledAt: Date = .now) throws -> ManagedLearnedRule {
        guard let learnedRuleWriter = store as? any LearnedRuleWriting else {
            throw WorkspaceServiceError.learnedRuleManagementUnavailable
        }

        return try learnedRuleWriter.disableLearnedRule(id: id, disabledAt: disabledAt)
    }

    @discardableResult
    public func enableLearnedRule(id: UUID) throws -> ManagedLearnedRule {
        guard let learnedRuleWriter = store as? any LearnedRuleWriting else {
            throw WorkspaceServiceError.learnedRuleManagementUnavailable
        }

        return try learnedRuleWriter.enableLearnedRule(id: id)
    }

    public func loadTransactionDetail(id: UUID) throws -> TransactionDetail? {
        guard var detail = try transactionLedgerReader().fetchTransactionDetail(id: id) else {
            return nil
        }
        detail.learnedRuleProvenance = try resolveLearnedRuleProvenance(for: detail)
        return detail
    }

    public func updateTransactionLedgerFields(id: UUID, draft: TransactionLedgerEditDraft) throws {
        guard let writer = store as? any TransactionLedgerWriting else {
            throw WorkspaceServiceError.transactionLedgerUnavailable
        }
        try writer.updateTransactionLedgerFields(id: id, draft: draft)
    }

    public func keepBothLikelyDuplicateReviewItem(id: UUID, resolvedAt: Date = Date()) throws {
        guard let writer = store as? any ReviewQueueWriting else {
            throw WorkspaceServiceError.reviewQueueUnavailable
        }
        _ = try writer.keepBothForLikelyDuplicateReviewItem(id: id, resolvedAt: resolvedAt)
    }

    @discardableResult
    public func approveClassificationReviewItem(
        id: UUID,
        assignment: ClassificationAssignment,
        ruleLearning: ReviewRuleLearningOption?,
        resolvedAt: Date = Date()
    ) throws -> ReviewApprovalResult {
        guard let writer = store as? any ReviewQueueWriting else {
            throw WorkspaceServiceError.reviewQueueUnavailable
        }
        let existingLearnedRuleIDs = try Set(
            learnedRuleReader()?.fetchLearnedRuleSummaries().map(\.id) ?? []
        )
        let decisionEvent = try writer.approveClassificationReviewItem(
            id: id,
            assignment: assignment,
            ruleLearning: ruleLearning,
            resolvedAt: resolvedAt
        )
        let createdLearnedRuleAction = try resolveCreatedLearnedRuleAction(
            ruleLearning: ruleLearning,
            existingLearnedRuleIDs: existingLearnedRuleIDs
        )
        return ReviewApprovalResult(
            decisionEvent: decisionEvent,
            createdLearnedRuleAction: createdLearnedRuleAction
        )
    }

    public func previewLearnedRuleImpact(
        reviewItemID: UUID,
        createRuleEnabled: Bool,
        merchantPattern: String,
        matchKind: ClassificationRuleMatchKind
    ) throws -> LearnedRuleImpactPreviewState {
        guard createRuleEnabled else {
            return .noEligiblePreview
        }
        guard let previewReader = store as? any LearnedRulePreviewReading else {
            return .unavailable
        }
        guard let sanitizedPattern = try previewMerchantPattern(
            reviewItemID: reviewItemID,
            merchantPattern: merchantPattern
        ) else {
            return .noEligiblePreview
        }

        let preview = try previewReader.previewLearnedRuleImpact(
            merchantPattern: sanitizedPattern,
            matchKind: matchKind,
            excludingReviewItemID: reviewItemID
        )
        return .ready(preview)
    }

    public func fetchManagedTargets(referenceDate: Date = Date()) throws -> [ManagedMonthlyTarget] {
        try targetManager().fetchManagedTargets(referenceDate: referenceDate)
    }

    @discardableResult
    public func createMonthlyTarget(
        _ draft: MonthlyTargetDraft,
        createdAt: Date = Date()
    ) throws -> MonthlyTarget {
        do {
            return try targetManager().createMonthlyTarget(draft, createdAt: createdAt)
        } catch MonthlyTargetManagementError.conflict(let conflict) {
            throw WorkspaceServiceError.monthlyTargetConflict(conflict)
        }
    }

    @discardableResult
    public func updateMonthlyTarget(id: UUID, _ draft: MonthlyTargetDraft) throws -> MonthlyTarget {
        do {
            return try targetManager().updateMonthlyTarget(id: id, draft)
        } catch MonthlyTargetManagementError.conflict(let conflict) {
            throw WorkspaceServiceError.monthlyTargetConflict(conflict)
        }
    }

    public func deleteMonthlyTarget(id: UUID) throws {
        do {
            try targetManager().deleteMonthlyTarget(id: id)
        } catch MonthlyTargetManagementError.conflict(let conflict) {
            throw WorkspaceServiceError.monthlyTargetConflict(conflict)
        }
    }

    public func loadWorkspaceMetadata() throws -> WorkspaceMetadata {
        try workspaceMaintenanceManager().fetchWorkspaceMetadata()
    }

    public func createWorkspaceBackup() throws -> WorkspaceBackup {
        try workspaceMaintenanceManager().createWorkspaceBackup()
    }

    public func restoreWorkspaceBackup(from backupURL: URL) throws -> WorkspaceRestoreResult {
        try workspaceMaintenanceManager().restoreWorkspaceBackup(from: backupURL)
    }

    public func resetWorkspace() throws -> WorkspaceResetResult {
        try workspaceMaintenanceManager().resetWorkspace()
    }

    public func loadWorkspacePreferences() throws -> WorkspacePreferences {
        try workspacePreferencesManager().fetchWorkspacePreferences()
    }

    public func updateWorkspacePreferences(_ preferences: WorkspacePreferences) throws {
        try workspacePreferencesManager().updateWorkspacePreferences(preferences)
    }

    @discardableResult
    public func createAccount(
        named: String,
        kind: AccountKind,
        institutionName: String?
    ) throws -> Account {
        try store.createAccount(
            named: named.trimmingCharacters(in: .whitespacesAndNewlines),
            kind: kind,
            institutionName: institutionName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        )
    }

    @discardableResult
    public func updateAccount(
        id: UUID,
        named: String,
        kind: AccountKind,
        institutionName: String?
    ) throws -> Account {
        try store.updateAccount(
            id: id,
            named: named.trimmingCharacters(in: .whitespacesAndNewlines),
            kind: kind,
            institutionName: institutionName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        )
    }

    @discardableResult
    public func archiveAccount(id: UUID, archivedAt: Date = .now) throws -> Account {
        try store.archiveAccount(id: id, archivedAt: archivedAt)
    }

    @discardableResult
    public func restoreAccount(id: UUID) throws -> Account {
        try store.restoreAccount(id: id)
    }

    public func deleteAccountPermanently(id: UUID) throws {
        do {
            try store.deleteAccountPermanently(id: id)
        } catch AccountManagementError.deleteBlockedByDependencies {
            throw WorkspaceServiceError.accountDeleteBlocked
        }
    }

    @discardableResult
    public func seedSampleDataIfNeeded() throws -> Bool {
        let existingAccounts = try store.fetchManagementAccounts()
        guard existingAccounts.isEmpty else {
            return false
        }

        _ = try createAccount(
            named: "Checking",
            kind: .checking,
            institutionName: "Local Bank"
        )
        _ = try createAccount(
            named: "Daily Card",
            kind: .creditCard,
            institutionName: "Sample Card"
        )
        return true
    }

    @discardableResult
    public func stageCSVImport(
        preview: CSVImportPreview,
        account: Account,
        originalFilename: String,
        csvText: String,
        importedAt: Date = .now
    ) throws -> StagedCSVImportResult {
        let importEligibleAccountIDs = try Set(store.fetchImportEligibleAccounts().map(\.id))
        guard importEligibleAccountIDs.contains(account.id) else {
            throw WorkspaceServiceError.archivedAccountImportUnavailable
        }

        guard preview.validation.isReadyForImport else {
            throw WorkspaceServiceError.importPreviewNotReady
        }
        guard preview.sourceRows.count == preview.validation.validRowCount else {
            throw WorkspaceServiceError.importPreviewSourceRowsUnavailable
        }

        let rowIdentities = try preview.sourceRows.map { row in
            try StagedImportRowIdentity(row: row, rawPayload: Self.rawPayload(for: row))
        }
        let rowHashes = Set(rowIdentities.map(\.rowHash))
        let existingRowHashCounts = try store.fetchExistingSourceRowHashCounts(
            accountID: account.id,
            rowHashes: rowHashes
        )
        let incomingRowHashCounts = Dictionary(rowIdentities.map { ($0.rowHash, 1) }, uniquingKeysWith: +)

        if !rowIdentities.isEmpty && incomingRowHashCounts.allSatisfy({ hash, count in
            (existingRowHashCounts[hash] ?? 0) >= count
        }) {
            let decisions = rowIdentities.map { _ in
                ImportRowDecision.skippedExactReimport(reason: "Source row already exists for this account.")
            }
            return StagedCSVImportResult(
                outcome: .exactReimportNoOp,
                session: nil,
                decisions: decisions,
                classifications: [],
                summary: .make(decisions: decisions)
            )
        }

        var remainingExistingRowHashCounts = existingRowHashCounts
        var normalizedRows: [NormalizedImportCandidateWithPayload] = []
        var skippedRows: [String: Int] = [:]
        for rowIdentity in rowIdentities {
            let existingCount = remainingExistingRowHashCounts[rowIdentity.rowHash] ?? 0
            if existingCount > 0 {
                remainingExistingRowHashCounts[rowIdentity.rowHash] = existingCount - 1
                skippedRows[rowIdentity.rowHash, default: 0] += 1
            } else {
                normalizedRows.append(try normalizedRow(for: rowIdentity, mapping: preview.mapping))
            }
        }

        let duplicateCandidates = try store.fetchLikelyDuplicateTransactions(
            accountID: account.id,
            candidates: normalizedRows.asCandidates
        )
        let duplicateByRowHash = Dictionary(duplicateCandidates.map { ($0.rowHash, $0) }, uniquingKeysWith: { first, _ in first })

        let importClassifier = try effectiveClassifier()
        let classifications = normalizedRows.map { normalizedRow in
            ImportRowClassification(
                rowHash: normalizedRow.rowHash,
                sourceLineNumber: normalizedRow.sourceLineNumber,
                decision: importClassifier.classify(
                    candidate: normalizedRow.candidate,
                    hasDuplicateConcern: duplicateByRowHash[normalizedRow.rowHash] != nil
                )
            )
        }
        let classificationByRowHash = Dictionary(
            zip(normalizedRows.map(\.rowHash), classifications),
            uniquingKeysWith: { first, _ in first }
        )
        let normalizedMerchantByRowHash = Dictionary(
            normalizedRows.map { ($0.rowHash, $0.normalizedMerchantName) },
            uniquingKeysWith: { first, _ in first }
        )
        let transactionDraftByRowHash = Dictionary(
            normalizedRows.map { normalizedRow in
                (
                    normalizedRow.rowHash,
                    StagedTransactionDraft(
                        transactionDate: normalizedRow.transactionDate,
                        rawDescription: normalizedRow.rawDescription,
                        normalizedMerchantName: normalizedRow.normalizedMerchantName,
                        amount: normalizedRow.amount
                    )
                )
            },
            uniquingKeysWith: { first, _ in first }
        )

        var remainingSkippedRows = skippedRows
        let rows = rowIdentities.map { rowIdentity in
            let decision: ImportRowDecision
            let skippedCount = remainingSkippedRows[rowIdentity.rowHash] ?? 0
            if skippedCount > 0 {
                remainingSkippedRows[rowIdentity.rowHash] = skippedCount - 1
                decision = .skippedExactReimport(reason: "Source row already exists for this account.")
            } else if let duplicate = duplicateByRowHash[rowIdentity.rowHash] {
                decision = .flaggedLikelyDuplicate(
                    existingTransactionID: duplicate.existingTransactionID,
                    reason: duplicate.reason
                )
            } else {
                decision = .imported(reason: "New source row.")
            }

            return StagedSourceRowDraft(
                sourceLineNumber: rowIdentity.sourceLineNumber,
                rawPayload: rowIdentity.rawPayload,
                rowHash: rowIdentity.rowHash,
                validationStatus: .valid,
                importDecision: decision,
                classification: classificationByRowHash[rowIdentity.rowHash]?.decision,
                normalizedMerchantName: normalizedMerchantByRowHash[rowIdentity.rowHash],
                transaction: transactionDraftByRowHash[rowIdentity.rowHash]
            )
        }
        let decisions = rows.map(\.importDecision)
        let pendingClassificationReviewRowCount = rows.filter { row in
            guard case .imported = row.importDecision,
                  let classification = row.classification,
                  case .reviewRequired = classification
            else {
                return false
            }
            return true
        }.count

        let session = try store.createStagedImportSession(
            StagedImportSessionDraft(
                accountID: account.id,
                originalFilename: originalFilename.trimmingCharacters(in: .whitespacesAndNewlines),
                contentHash: Self.sha256Hex(csvText),
                importedAt: importedAt,
                rows: rows,
                mapping: preview.mapping,
                validRowCount: preview.validation.validRowCount,
                invalidRowCount: preview.validation.invalidRowCount,
                status: .staged
            )
        )
        return StagedCSVImportResult(
            outcome: .staged,
            session: session,
            decisions: decisions,
            classifications: classifications,
            summary: .make(
                decisions: decisions,
                pendingClassificationReviewRowCount: pendingClassificationReviewRowCount
            )
        )
    }

    public static func rowHash(for row: CSVRow) throws -> String {
        try sha256Hex(rawPayload(for: row))
    }

    private func normalizedRow(
        for rowIdentity: StagedImportRowIdentity,
        mapping: CSVColumnMapping
    ) throws -> NormalizedImportCandidateWithPayload {
        guard
            let transactionDate = dateValue(in: rowIdentity.row, at: mapping.dateColumnIndex),
            let description = stringValue(in: rowIdentity.row, at: mapping.descriptionColumnIndex),
            let amount = amountValue(in: rowIdentity.row, mapping: mapping)
        else {
            throw WorkspaceServiceError.importPreviewCouldNotNormalizeRow(line: rowIdentity.sourceLineNumber)
        }

        return NormalizedImportCandidateWithPayload(
            rowHash: rowIdentity.rowHash,
            sourceLineNumber: rowIdentity.sourceLineNumber,
            transactionDate: transactionDate,
            rawDescription: description,
            normalizedMerchantName: merchantNormalizer.normalize(description),
            amount: amount,
            rawPayload: rowIdentity.rawPayload
        )
    }

    private func effectiveClassifier() throws -> ClassificationEngine {
        var effectiveClassifier = classifier
        if let preferencesReader = store as? any WorkspacePreferencesManaging {
            let preferences = try preferencesReader.fetchWorkspacePreferences()
            effectiveClassifier = effectiveClassifier
                .settingSuggestionsEnabled(preferences.suggestionsEnabled)
                .settingSeededHeuristicAutoAcceptEnabled(preferences.seededHeuristicAutoAcceptEnabled)
        }
        guard let ruleReader = store as? any ClassificationRuleReading else {
            return effectiveClassifier
        }

        return try effectiveClassifier.appendingExplicitRules(ruleReader.fetchClassificationRules())
    }

    private func transactionLedgerReader() throws -> any TransactionLedgerReading {
        guard let reader = store as? any TransactionLedgerReading else {
            throw WorkspaceServiceError.transactionLedgerUnavailable
        }
        return reader
    }

    private func targetManager() throws -> any TargetManaging {
        guard let manager = store as? any TargetManaging else {
            throw WorkspaceServiceError.targetManagementUnavailable
        }
        return manager
    }

    private func workspaceMaintenanceManager() throws -> any WorkspaceMaintenanceManaging {
        guard let manager = store as? any WorkspaceMaintenanceManaging else {
            throw WorkspaceServiceError.workspaceMaintenanceUnavailable
        }
        return manager
    }

    private func workspacePreferencesManager() throws -> any WorkspacePreferencesManaging {
        guard let manager = store as? any WorkspacePreferencesManaging else {
            throw WorkspaceServiceError.workspaceMaintenanceUnavailable
        }
        return manager
    }

    private func learnedRuleReader() -> (any LearnedRuleReading)? {
        store as? any LearnedRuleReading
    }

    private func previewMerchantPattern(
        reviewItemID: UUID,
        merchantPattern: String
    ) throws -> String? {
        let fallbackPattern = try (store as? any ReviewQueueReading)?
            .fetchPendingReviewItems()
            .first { $0.id == reviewItemID }?
            .classification?
            .normalizedMerchantName
        return LearnedRuleMatcher.normalizedPattern(
            merchantPattern,
            fallbackPattern: fallbackPattern
        )
    }

    private func resolveLearnedRuleProvenance(
        for detail: TransactionDetail
    ) throws -> TransactionLearnedRuleProvenance? {
        guard detail.decisionSource == .rule,
              let reference = detail.decisionSourceReference,
              let learnedRuleID = UUID(uuidString: reference),
              let summary = try learnedRuleReader()?.fetchLearnedRuleSummary(id: learnedRuleID) else {
            return nil
        }

        return TransactionLearnedRuleProvenance(
            id: summary.id,
            merchantPattern: summary.merchantPattern,
            categoryID: summary.categoryID,
            categoryName: try categoryName(for: summary.categoryID),
            merchantName: summary.merchantName,
            matchKind: summary.matchKind,
            lifecycle: summary.lifecycle
        )
    }

    private func resolveCreatedLearnedRuleAction(
        ruleLearning: ReviewRuleLearningOption?,
        existingLearnedRuleIDs: Set<UUID>
    ) throws -> ReviewCreatedLearnedRuleAction? {
        guard ruleLearning != nil,
              let learnedRuleReader = learnedRuleReader() else {
            return nil
        }

        let matchingSummary = try learnedRuleReader
            .fetchLearnedRuleSummaries()
            .filter { summary in
                existingLearnedRuleIDs.contains(summary.id) == false
            }
            .sorted { lhs, rhs in
                if lhs.createdAt == rhs.createdAt {
                    return lhs.id.uuidString < rhs.id.uuidString
                }
                return lhs.createdAt > rhs.createdAt
            }
            .first

        guard let matchingSummary else {
            return nil
        }

        let merchantLabel = matchingSummary.merchantName?.trimmingCharacters(in: .whitespacesAndNewlines)
        return ReviewCreatedLearnedRuleAction(
            ruleID: matchingSummary.id,
            merchantLabel: merchantLabel?.isEmpty == false
                ? merchantLabel ?? matchingSummary.merchantPattern
                : matchingSummary.merchantPattern,
            destination: .learnedRulesRoute(selectedLearnedRuleID: matchingSummary.id)
        )
    }

    private func categoryName(for categoryID: UUID?) throws -> String? {
        guard let categoryID else {
            return nil
        }
        return try store.fetchCategories().first { $0.id == categoryID }?.name
    }

    private func seededRuleSourceRows() -> [SeededRuleSourceRow] {
        let deterministicRows = SeededClassification.deterministicRules.map { rule in
            SeededRuleSourceRow(
                id: rule.id.uuidString,
                merchantPattern: rule.merchantPattern,
                categoryID: rule.categoryID,
                merchantName: rule.merchantName,
                matchKind: rule.matchKind,
                sourceKind: .deterministicRule
            )
        }
        let curatedPrefillRows = SeededClassification.curatedReviewPrefills.map { prefill in
            SeededRuleSourceRow(
                id: prefill.id,
                merchantPattern: prefill.merchantPattern,
                categoryID: prefill.assignment.categoryID,
                merchantName: prefill.assignment.merchantName,
                matchKind: prefill.matchKind,
                sourceKind: .curatedPrefill
            )
        }

        return deterministicRows + curatedPrefillRows
    }

    private static func rawPayload(for row: CSVRow) throws -> String {
        let values = row.cells
            .sorted { $0.columnIndex < $1.columnIndex }
            .map(\.value)
        let data = try JSONEncoder().encode(values)
        return String(data: data, encoding: .utf8) ?? "[]"
    }

    fileprivate static func sha256Hex(_ text: String) -> String {
        SHA256.hash(data: Data(text.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private func amountValue(in row: CSVRow, mapping: CSVColumnMapping) -> Decimal? {
        guard let amount = mapping.amount else {
            return nil
        }

        switch amount {
        case .singleSignedAmount(let columnIndex):
            return decimalValue(in: row, at: columnIndex)
        case .debitCredit(let debitColumnIndex, let creditColumnIndex):
            if let debit = decimalValue(in: row, at: debitColumnIndex) {
                return -debit
            }
            return decimalValue(in: row, at: creditColumnIndex)
        }
    }

    private func dateValue(in row: CSVRow, at columnIndex: Int?) -> Date? {
        guard let value = stringValue(in: row, at: columnIndex) else {
            return nil
        }

        for formatter in Self.dateFormatters {
            if let date = formatter.date(from: value) {
                return date
            }
        }
        return nil
    }

    private func decimalValue(in row: CSVRow, at columnIndex: Int) -> Decimal? {
        guard let value = stringValue(in: row, at: columnIndex) else {
            return nil
        }
        return Decimal(string: value, locale: Locale(identifier: "en_US_POSIX"))
    }

    private func stringValue(in row: CSVRow, at columnIndex: Int?) -> String? {
        guard
            let columnIndex,
            let value = row.cells.first(where: { $0.columnIndex == columnIndex })?.value
        else {
            return nil
        }

        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }

    private static let dateFormatters: [DateFormatter] = [
        makeDateFormatter("yyyy-MM-dd"),
        makeDateFormatter("MM/dd/yyyy"),
        makeDateFormatter("M/d/yyyy"),
    ]

    private static func makeDateFormatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = format
        return formatter
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

private struct StagedImportRowIdentity: Equatable, Sendable {
    var row: CSVRow
    var sourceLineNumber: Int
    var rawPayload: String
    var rowHash: String

    init(row: CSVRow, rawPayload: String) {
        self.row = row
        self.sourceLineNumber = row.sourceLineNumber
        self.rawPayload = rawPayload
        self.rowHash = WorkspaceService.sha256Hex(rawPayload)
    }
}

private struct NormalizedImportCandidateWithPayload: Equatable, Sendable {
    var rowHash: String
    var sourceLineNumber: Int
    var transactionDate: Date
    var rawDescription: String
    var normalizedMerchantName: String
    var amount: Decimal
    var rawPayload: String
}

extension NormalizedImportCandidateWithPayload {
    var candidate: NormalizedImportCandidate {
        NormalizedImportCandidate(
            rowHash: rowHash,
            sourceLineNumber: sourceLineNumber,
            transactionDate: transactionDate,
            rawDescription: rawDescription,
            normalizedMerchantName: normalizedMerchantName,
            amount: amount
        )
    }
}

private extension Array where Element == NormalizedImportCandidateWithPayload {
    var asCandidates: [NormalizedImportCandidate] {
        map(\.candidate)
    }
}
