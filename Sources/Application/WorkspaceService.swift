import Domain
import CryptoKit
import Foundation

public enum WorkspaceServiceError: Error, Equatable, Sendable {
    case importPreviewNotReady
    case importPreviewSourceRowsUnavailable
    case importPreviewCouldNotNormalizeRow(line: Int)
    case transactionLedgerUnavailable
    case reviewQueueUnavailable
    case targetWritingUnavailable
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
        case .targetWritingUnavailable:
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
        return WorkspaceSnapshot(
            summary: summary,
            accounts: try store.fetchAccounts(),
            categories: try store.fetchCategories(),
            categoryGroups: try store.fetchCategoryGroups(),
            pendingReviewItems: try reviewReader?.fetchPendingReviewItems() ?? [],
            transactions: try ledgerReader?.fetchTransactionLedger(filter: filter) ?? [],
            transactionImportOrigins: try ledgerReader?.fetchTransactionImportOrigins() ?? [],
            monthlyReport: monthlyReport,
            homeDashboard: HomeDashboardSnapshot.make(summary: summary, monthlyReport: monthlyReport)
        )
    }

    public func loadTransactionDetail(id: UUID) throws -> TransactionDetail? {
        try transactionLedgerReader().fetchTransactionDetail(id: id)
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

    public func approveClassificationReviewItem(
        id: UUID,
        assignment: ClassificationAssignment,
        createRule: Bool,
        resolvedAt: Date = Date()
    ) throws {
        guard let writer = store as? any ReviewQueueWriting else {
            throw WorkspaceServiceError.reviewQueueUnavailable
        }
        _ = try writer.approveClassificationReviewItem(
            id: id,
            assignment: assignment,
            createRule: createRule,
            resolvedAt: resolvedAt
        )
    }

    @discardableResult
    public func createMonthlyTarget(
        _ draft: MonthlyTargetDraft,
        createdAt: Date = Date()
    ) throws -> MonthlyTarget {
        guard let writer = store as? any TargetWriting else {
            throw WorkspaceServiceError.targetWritingUnavailable
        }
        return try writer.createMonthlyTarget(draft, createdAt: createdAt)
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
    public func seedSampleDataIfNeeded() throws -> Bool {
        let existingAccounts = try store.fetchAccounts()
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
            summary: .make(decisions: decisions)
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
            effectiveClassifier = try effectiveClassifier.settingSuggestionsEnabled(
                preferencesReader.fetchWorkspacePreferences().suggestionsEnabled
            )
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
