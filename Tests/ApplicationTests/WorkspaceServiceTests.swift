import Application
import Domain
import Foundation
import Testing

private struct StubWorkspaceStore: WorkspaceStoring, StagedImportWriting, ImportDecisionReading, ReviewQueueReading, LearnedRuleReading {
    var summary: WorkspaceSummary
    var accounts: [Account]
    var pendingReviewItems: [PendingReviewItem] = []
    var learnedRuleSummaries: [LearnedRuleSummary] = []

    func fetchSummary() throws -> WorkspaceSummary {
        summary
    }

    func fetchAccounts() throws -> [Account] {
        accounts
    }

    func fetchManagementAccounts() throws -> [Account] {
        accounts
    }

    func fetchImportEligibleAccounts() throws -> [Account] {
        accounts.filter { !$0.isArchived }
    }

    func fetchLedgerFilterAccounts() throws -> [Account] {
        accounts
    }

    func fetchPermanentlyDeletableAccountIDs() throws -> Set<UUID> {
        Set(accounts.map(\.id))
    }

    func fetchCategories() throws -> [BudgetCategory] {
        []
    }

    func fetchCategoryGroups() throws -> [BudgetCategoryGroup] {
        []
    }

    func fetchPendingReviewItems() throws -> [PendingReviewItem] {
        pendingReviewItems
    }

    func fetchLearnedRuleSummaries() throws -> [LearnedRuleSummary] {
        learnedRuleSummaries
    }

    func fetchLearnedRuleSummary(id: UUID) throws -> LearnedRuleSummary? {
        learnedRuleSummaries.first { $0.id == id }
    }

    func fetchLearnedRuleDetail(id: UUID) throws -> ManagedLearnedRule? {
        guard let summary = learnedRuleSummaries.first(where: { $0.id == id }) else {
            return nil
        }
        return ManagedLearnedRule(
            id: summary.id,
            merchantPattern: summary.merchantPattern,
            categoryID: summary.categoryID,
            merchantName: summary.merchantName,
            matchKind: summary.matchKind,
            createdAt: summary.createdAt,
            lifecycle: summary.lifecycle
        )
    }

    func createAccount(named: String, kind: AccountKind, institutionName: String?) throws -> Account {
        Account(
            name: named,
            kind: kind,
            institutionName: institutionName
        )
    }

    func updateAccount(id: UUID, named: String, kind: AccountKind, institutionName: String?) throws -> Account {
        Account(id: id, name: named, kind: kind, institutionName: institutionName)
    }

    func archiveAccount(id: UUID, archivedAt: Date) throws -> Account {
        let existing = try #require(accounts.first { $0.id == id })
        return Account(
            id: existing.id,
            name: existing.name,
            kind: existing.kind,
            institutionName: existing.institutionName,
            createdAt: existing.createdAt,
            archivedAt: archivedAt
        )
    }

    func restoreAccount(id: UUID) throws -> Account {
        let existing = try #require(accounts.first { $0.id == id })
        return Account(
            id: existing.id,
            name: existing.name,
            kind: existing.kind,
            institutionName: existing.institutionName,
            createdAt: existing.createdAt
        )
    }

    func deleteAccountPermanently(id: UUID) throws {}

    func createStagedImportSession(_ draft: StagedImportSessionDraft) throws -> StagedImportSession {
        StagedImportSession(
            id: 1,
            sourceFile: StagedSourceFile(
                id: 1,
                accountID: draft.accountID,
                originalFilename: draft.originalFilename,
                contentHash: draft.contentHash,
                importedAt: draft.importedAt,
                rowCount: draft.rows.count
            ),
            mapping: draft.mapping,
            validRowCount: draft.validRowCount,
            invalidRowCount: draft.invalidRowCount,
            status: draft.status,
            rows: draft.rows.enumerated().map { index, row in
                StagedSourceRow(
                    id: Int64(index + 1),
                    sourceFileID: 1,
                    sourceLineNumber: row.sourceLineNumber,
                    rawPayload: row.rawPayload,
                    rowHash: row.rowHash,
                    validationStatus: row.validationStatus
                )
            }
        )
    }

    func fetchExistingSourceRowHashes(accountID: UUID, rowHashes: Set<String>) throws -> Set<String> {
        []
    }

    func fetchExistingSourceRowHashCounts(accountID: UUID, rowHashes: Set<String>) throws -> [String: Int] {
        [:]
    }

    func fetchLikelyDuplicateTransactions(
        accountID: UUID,
        candidates: [NormalizedImportCandidate]
    ) throws -> [LikelyDuplicateCandidate] {
        []
    }
}

private final class MutableWorkspaceStore: WorkspaceStoring, StagedImportWriting, ImportDecisionReading, ReviewQueueReading, ReviewQueueWriting, TransactionLedgerReading, ClassificationRuleReading, LearnedRuleManaging, LearnedRulePreviewReading, TargetManaging, ReportingReading, WorkspacePreferencesManaging, @unchecked Sendable {
    var summary: WorkspaceSummary
    var accounts: [Account]
    var categories: [BudgetCategory] = []
    var categoryGroups: [BudgetCategoryGroup] = []
    var pendingReviewItems: [PendingReviewItem] = []
    var transactionDetailsByID: [UUID: TransactionDetail] = [:]
    var learnedRuleSummaries: [LearnedRuleSummary] = []
    var stagedImportDrafts: [StagedImportSessionDraft] = []
    var likelyDuplicateCandidates: [LikelyDuplicateCandidate] = []
    var existingSourceRowHashes: Set<String> = []
    var classificationRules: [ClassificationRule] = []
    var createdTargets: [MonthlyTarget] = []
    var monthlyReport = MonthlyReport.empty
    var managedTargets: [ManagedMonthlyTarget] = []
    var preferences = WorkspacePreferences()
    var previewLearnedRuleImpactResult = LearnedRuleImpactPreview(
        matchedAcceptedTransactionCount: 0,
        matchedPendingReviewItemCount: 0
    )
    var createMonthlyTargetError: (any Error)?
    var updateMonthlyTargetError: (any Error)?
    var deleteMonthlyTargetError: (any Error)?
    var deleteAccountPermanentlyError: (any Error)?
    var nextCreatedLearnedRuleID = UUID(uuidString: "00000000-0000-0000-0000-000000000999")!
    var lastApprovedClassificationRequest: ApprovedClassificationRequest?
    var lastPreviewLearnedRuleRequest: PreviewLearnedRuleRequest?

    init(summary: WorkspaceSummary = .empty, accounts: [Account] = []) {
        self.summary = summary
        self.accounts = accounts
    }

    func fetchSummary() throws -> WorkspaceSummary {
        summary
    }

    func fetchAccounts() throws -> [Account] {
        try fetchManagementAccounts()
    }

    func fetchManagementAccounts() throws -> [Account] {
        accounts.sorted {
            if $0.isArchived == $1.isArchived {
                return $0.name < $1.name
            }
            return !$0.isArchived && $1.isArchived
        }
    }

    func fetchImportEligibleAccounts() throws -> [Account] {
        accounts
            .filter { !$0.isArchived }
            .sorted { $0.name < $1.name }
    }

    func fetchLedgerFilterAccounts() throws -> [Account] {
        accounts.sorted { $0.name < $1.name }
    }

    func fetchPermanentlyDeletableAccountIDs() throws -> Set<UUID> {
        Set(accounts.filter { !$0.isArchived }.map(\.id))
    }

    func fetchCategories() throws -> [BudgetCategory] {
        categories.sorted { $0.name < $1.name }
    }

    func fetchCategoryGroups() throws -> [BudgetCategoryGroup] {
        categoryGroups.sorted { $0.name < $1.name }
    }

    func fetchPendingReviewItems() throws -> [PendingReviewItem] {
        pendingReviewItems
    }

    func keepBothForLikelyDuplicateReviewItem(id: UUID, resolvedAt: Date) throws -> ReviewDecisionEvent {
        ReviewDecisionEvent(
            id: UUID(),
            reviewItemID: id,
            sourceRowID: 1,
            action: .keepBoth,
            details: "Kept both.",
            createdAt: resolvedAt
        )
    }

    func approveClassificationReviewItem(
        id: UUID,
        assignment: ClassificationAssignment,
        ruleLearning: ReviewRuleLearningOption?,
        resolvedAt: Date
    ) throws -> ReviewDecisionEvent {
        lastApprovedClassificationRequest = ApprovedClassificationRequest(
            id: id,
            assignment: assignment,
            ruleLearning: ruleLearning,
            resolvedAt: resolvedAt
        )

        if let ruleLearning {
            learnedRuleSummaries.append(
                LearnedRuleSummary(
                    id: nextCreatedLearnedRuleID,
                    merchantPattern: ruleLearning.pattern,
                    categoryID: assignment.categoryID,
                    merchantName: assignment.merchantName,
                    matchKind: ruleLearning.matchKind,
                    createdAt: resolvedAt,
                    lifecycle: .active
                )
            )
        }

        return ReviewDecisionEvent(
            id: UUID(),
            reviewItemID: id,
            sourceRowID: 1,
            action: .approveSuggestion,
            details: "Approved.",
            createdAt: resolvedAt
        )
    }

    func createAccount(named: String, kind: AccountKind, institutionName: String?) throws -> Account {
        let account = Account(
            name: named,
            kind: kind,
            institutionName: institutionName
        )
        accounts.append(account)
        summary.accountCount = accounts.filter { !$0.isArchived }.count
        return account
    }

    func updateAccount(id: UUID, named: String, kind: AccountKind, institutionName: String?) throws -> Account {
        let existingIndex = try #require(accounts.firstIndex { $0.id == id })
        accounts[existingIndex].name = named
        accounts[existingIndex].kind = kind
        accounts[existingIndex].institutionName = institutionName
        return accounts[existingIndex]
    }

    func archiveAccount(id: UUID, archivedAt: Date) throws -> Account {
        let existingIndex = try #require(accounts.firstIndex { $0.id == id })
        accounts[existingIndex].archivedAt = archivedAt
        summary.accountCount = accounts.filter { !$0.isArchived }.count
        return accounts[existingIndex]
    }

    func restoreAccount(id: UUID) throws -> Account {
        let existingIndex = try #require(accounts.firstIndex { $0.id == id })
        accounts[existingIndex].archivedAt = nil
        summary.accountCount = accounts.filter { !$0.isArchived }.count
        return accounts[existingIndex]
    }

    func deleteAccountPermanently(id: UUID) throws {
        if let deleteAccountPermanentlyError {
            throw deleteAccountPermanentlyError
        }
        accounts.removeAll { $0.id == id }
        summary.accountCount = accounts.filter { !$0.isArchived }.count
    }

    func createStagedImportSession(_ draft: StagedImportSessionDraft) throws -> StagedImportSession {
        stagedImportDrafts.append(draft)
        return StagedImportSession(
            id: Int64(stagedImportDrafts.count),
            sourceFile: StagedSourceFile(
                id: Int64(stagedImportDrafts.count),
                accountID: draft.accountID,
                originalFilename: draft.originalFilename,
                contentHash: draft.contentHash,
                importedAt: draft.importedAt,
                rowCount: draft.rows.count
            ),
            mapping: draft.mapping,
            validRowCount: draft.validRowCount,
            invalidRowCount: draft.invalidRowCount,
            status: draft.status,
            rows: draft.rows.enumerated().map { index, row in
                StagedSourceRow(
                    id: Int64(index + 1),
                    sourceFileID: Int64(stagedImportDrafts.count),
                    sourceLineNumber: row.sourceLineNumber,
                    rawPayload: row.rawPayload,
                    rowHash: row.rowHash,
                    validationStatus: row.validationStatus,
                    importDecision: row.importDecision
                )
            }
        )
    }

    func fetchExistingSourceRowHashes(accountID: UUID, rowHashes: Set<String>) throws -> Set<String> {
        existingSourceRowHashes.union(
            stagedImportDrafts
                .filter { $0.accountID == accountID }
                .flatMap(\.rows)
                .map(\.rowHash)
                .filter { rowHashes.contains($0) }
        )
    }

    func fetchExistingSourceRowHashCounts(accountID: UUID, rowHashes: Set<String>) throws -> [String: Int] {
        let storedHashes = stagedImportDrafts
            .filter { $0.accountID == accountID }
            .flatMap(\.rows)
            .map(\.rowHash)
            .filter { rowHashes.contains($0) }
        let explicitHashes = existingSourceRowHashes.filter { rowHashes.contains($0) }
        return Dictionary((storedHashes + explicitHashes).map { ($0, 1) }, uniquingKeysWith: +)
    }

    func fetchLikelyDuplicateTransactions(
        accountID: UUID,
        candidates: [NormalizedImportCandidate]
    ) throws -> [LikelyDuplicateCandidate] {
        let candidateHashes = Set(candidates.map(\.rowHash))
        return likelyDuplicateCandidates.filter { candidateHashes.contains($0.rowHash) }
    }

    func fetchClassificationRules() throws -> [ClassificationRule] {
        classificationRules
    }

    func fetchTransactionLedger(filter: TransactionLedgerFilter) throws -> [TransactionLedgerRow] {
        transactionDetailsByID.values.map(\.row)
    }

    func fetchTransactionDetail(id: UUID) throws -> TransactionDetail? {
        transactionDetailsByID[id]
    }

    func fetchTransactionImportOrigins() throws -> [TransactionImportOrigin] {
        []
    }

    func fetchLearnedRuleSummaries() throws -> [LearnedRuleSummary] {
        learnedRuleSummaries
    }

    func fetchLearnedRuleSummary(id: UUID) throws -> LearnedRuleSummary? {
        learnedRuleSummaries.first { $0.id == id }
    }

    func fetchLearnedRuleDetail(id: UUID) throws -> ManagedLearnedRule? {
        guard let summary = learnedRuleSummaries.first(where: { $0.id == id }) else {
            return nil
        }
        return ManagedLearnedRule(
            id: summary.id,
            merchantPattern: summary.merchantPattern,
            categoryID: summary.categoryID,
            merchantName: summary.merchantName,
            matchKind: summary.matchKind,
            createdAt: summary.createdAt,
            lifecycle: summary.lifecycle
        )
    }

    func createLearnedRule(_ draft: LearnedRuleDraft, createdAt: Date) throws -> ManagedLearnedRule {
        let rule = ManagedLearnedRule(
            id: nextCreatedLearnedRuleID,
            merchantPattern: draft.normalizedMerchantPattern ?? draft.merchantPattern,
            categoryID: draft.categoryID,
            merchantName: draft.merchantName,
            matchKind: draft.matchKind,
            createdAt: createdAt,
            lifecycle: .active
        )
        learnedRuleSummaries.insert(
            LearnedRuleSummary(
                id: rule.id,
                merchantPattern: rule.merchantPattern,
                categoryID: rule.categoryID,
                merchantName: rule.merchantName,
                matchKind: rule.matchKind,
                createdAt: rule.createdAt,
                lifecycle: rule.lifecycle
            ),
            at: 0
        )
        return rule
    }

    func disableLearnedRule(id: UUID, disabledAt: Date) throws -> ManagedLearnedRule {
        let existingIndex = try #require(learnedRuleSummaries.firstIndex { $0.id == id })
        learnedRuleSummaries[existingIndex].lifecycle = .disabled(disabledAt: disabledAt)
        return try #require(try fetchLearnedRuleDetail(id: id))
    }

    func enableLearnedRule(id: UUID) throws -> ManagedLearnedRule {
        let existingIndex = try #require(learnedRuleSummaries.firstIndex { $0.id == id })
        learnedRuleSummaries[existingIndex].lifecycle = .active
        return try #require(try fetchLearnedRuleDetail(id: id))
    }

    func previewLearnedRuleImpact(
        merchantPattern: String,
        matchKind: ClassificationRuleMatchKind,
        excludingReviewItemID: UUID?
    ) throws -> LearnedRuleImpactPreview {
        lastPreviewLearnedRuleRequest = PreviewLearnedRuleRequest(
            merchantPattern: merchantPattern,
            matchKind: matchKind,
            excludingReviewItemID: excludingReviewItemID
        )
        return previewLearnedRuleImpactResult
    }

    func fetchWorkspacePreferences() throws -> WorkspacePreferences {
        preferences
    }

    func updateWorkspacePreferences(_ preferences: WorkspacePreferences) throws {
        self.preferences = preferences
    }

    func fetchManagedTargets(referenceDate: Date) throws -> [ManagedMonthlyTarget] {
        managedTargets
    }

    func createMonthlyTarget(_ draft: MonthlyTargetDraft, createdAt: Date) throws -> MonthlyTarget {
        if let createMonthlyTargetError {
            throw createMonthlyTargetError
        }
        let target = MonthlyTarget(id: UUID(), scope: draft.scope, monthlyLimit: draft.monthlyLimit, createdAt: createdAt)
        createdTargets.append(target)
        summary.targetCount = createdTargets.count
        managedTargets.append(
            ManagedMonthlyTarget(
                id: target.id,
                name: "Groceries",
                scope: target.scope,
                monthlyLimit: target.monthlyLimit,
                spent: Decimal(40),
                remaining: target.monthlyLimit - Decimal(40),
                paceDelta: Decimal(0),
                createdAt: createdAt
            )
        )
        monthlyReport.targets.append(
            TargetProgress(
                id: target.id,
                name: "Groceries",
                scope: target.scope,
                monthlyLimit: target.monthlyLimit,
                spent: Decimal(40),
                remaining: target.monthlyLimit - Decimal(40),
                paceDelta: Decimal(0)
            )
        )
        return target
    }

    func updateMonthlyTarget(id: UUID, _ draft: MonthlyTargetDraft) throws -> MonthlyTarget {
        if let updateMonthlyTargetError {
            throw updateMonthlyTargetError
        }

        let existingIndex = try #require(createdTargets.firstIndex { $0.id == id })
        let existingTarget = createdTargets[existingIndex]
        let updatedTarget = MonthlyTarget(
            id: id,
            scope: draft.scope,
            monthlyLimit: draft.monthlyLimit,
            createdAt: existingTarget.createdAt
        )
        createdTargets[existingIndex] = updatedTarget

        if let managedIndex = managedTargets.firstIndex(where: { $0.id == id }) {
            managedTargets[managedIndex] = ManagedMonthlyTarget(
                id: id,
                name: "Groceries",
                scope: draft.scope,
                monthlyLimit: draft.monthlyLimit,
                spent: Decimal(40),
                remaining: draft.monthlyLimit - Decimal(40),
                paceDelta: Decimal(0),
                createdAt: existingTarget.createdAt
            )
        }
        if let reportIndex = monthlyReport.targets.firstIndex(where: { $0.id == id }) {
            monthlyReport.targets[reportIndex] = TargetProgress(
                id: id,
                name: "Groceries",
                scope: draft.scope,
                monthlyLimit: draft.monthlyLimit,
                spent: Decimal(40),
                remaining: draft.monthlyLimit - Decimal(40),
                paceDelta: Decimal(0)
            )
        }

        return updatedTarget
    }

    func deleteMonthlyTarget(id: UUID) throws {
        if let deleteMonthlyTargetError {
            throw deleteMonthlyTargetError
        }
        guard createdTargets.contains(where: { $0.id == id }) else {
            throw MonthlyTargetManagementError.targetNotFound(id)
        }
        createdTargets.removeAll { $0.id == id }
        managedTargets.removeAll { $0.id == id }
        monthlyReport.targets.removeAll { $0.id == id }
        summary.targetCount = createdTargets.count
    }

    func fetchMonthlyReport(referenceDate: Date) throws -> MonthlyReport {
        monthlyReport
    }
}

private struct ApprovedClassificationRequest: Equatable {
    var id: UUID
    var assignment: ClassificationAssignment
    var ruleLearning: ReviewRuleLearningOption?
    var resolvedAt: Date
}

private struct PreviewLearnedRuleRequest: Equatable {
    var merchantPattern: String
    var matchKind: ClassificationRuleMatchKind
    var excludingReviewItemID: UUID?
}

private final class MaintenanceWorkspaceStore: WorkspaceStoring, StagedImportWriting, ImportDecisionReading, LearnedRuleReading, WorkspaceMaintenanceManaging, @unchecked Sendable {
    var summary: WorkspaceSummary = .empty
    var accounts: [Account] = []
    var backupCallCount = 0
    var restoreCallCount = 0
    var resetCallCount = 0
    var lastRestoreBackupURL: URL?
    var backup: WorkspaceBackup = WorkspaceBackup(
        fileURL: URL(fileURLWithPath: "/tmp/backup.sqlite"),
        createdAt: Date(timeIntervalSince1970: 1_775_171_200),
        sizeBytes: 4096
    )
    var restoreResult: WorkspaceRestoreResult = WorkspaceRestoreResult(
        restoredFromURL: URL(fileURLWithPath: "/tmp/canned-restore-result.sqlite"),
        safetyBackup: WorkspaceBackup(
            fileURL: URL(fileURLWithPath: "/tmp/safety-backup.sqlite"),
            createdAt: Date(timeIntervalSince1970: 1_775_171_260),
            sizeBytes: 2048
        ),
        restoredAt: Date(timeIntervalSince1970: 1_775_171_260)
    )
    var resetResult: WorkspaceResetResult = WorkspaceResetResult(
        preResetBackupURL: URL(fileURLWithPath: "/tmp/pre-reset-backup.sqlite")
    )

    func fetchSummary() throws -> WorkspaceSummary {
        summary
    }

    func fetchAccounts() throws -> [Account] {
        accounts
    }

    func fetchManagementAccounts() throws -> [Account] {
        accounts
    }

    func fetchImportEligibleAccounts() throws -> [Account] {
        accounts
    }

    func fetchLedgerFilterAccounts() throws -> [Account] {
        accounts
    }

    func fetchPermanentlyDeletableAccountIDs() throws -> Set<UUID> {
        Set(accounts.map(\.id))
    }

    func fetchCategories() throws -> [BudgetCategory] {
        []
    }

    func fetchCategoryGroups() throws -> [BudgetCategoryGroup] {
        []
    }

    func fetchWorkspaceMetadata() throws -> WorkspaceMetadata {
        WorkspaceMetadata(
            databaseURL: URL(fileURLWithPath: "/tmp/workspace.sqlite"),
            databaseExists: true,
            databaseSizeBytes: 1024,
            modifiedAt: Date(timeIntervalSince1970: 1_775_171_200)
        )
    }

    func createAccount(named: String, kind: AccountKind, institutionName: String?) throws -> Account {
        Account(name: named, kind: kind, institutionName: institutionName)
    }

    func updateAccount(id: UUID, named: String, kind: AccountKind, institutionName: String?) throws -> Account {
        Account(id: id, name: named, kind: kind, institutionName: institutionName)
    }

    func archiveAccount(id: UUID, archivedAt: Date) throws -> Account {
        Account(id: id, name: "Archived", kind: .checking, institutionName: nil, archivedAt: archivedAt)
    }

    func restoreAccount(id: UUID) throws -> Account {
        Account(id: id, name: "Restored", kind: .checking, institutionName: nil)
    }

    func deleteAccountPermanently(id: UUID) throws {}

    func createStagedImportSession(_ draft: StagedImportSessionDraft) throws -> StagedImportSession {
        StagedImportSession(
            id: 1,
            sourceFile: StagedSourceFile(
                id: 1,
                accountID: draft.accountID,
                originalFilename: draft.originalFilename,
                contentHash: draft.contentHash,
                importedAt: draft.importedAt,
                rowCount: draft.rows.count
            ),
            mapping: draft.mapping,
            validRowCount: draft.validRowCount,
            invalidRowCount: draft.invalidRowCount,
            status: draft.status,
            rows: draft.rows.enumerated().map { index, row in
                StagedSourceRow(
                    id: Int64(index + 1),
                    sourceFileID: 1,
                    sourceLineNumber: row.sourceLineNumber,
                    rawPayload: row.rawPayload,
                    rowHash: row.rowHash,
                    validationStatus: row.validationStatus
                )
            }
        )
    }

    func fetchExistingSourceRowHashes(accountID: UUID, rowHashes: Set<String>) throws -> Set<String> {
        []
    }

    func fetchExistingSourceRowHashCounts(accountID: UUID, rowHashes: Set<String>) throws -> [String: Int] {
        [:]
    }

    func fetchLikelyDuplicateTransactions(
        accountID: UUID,
        candidates: [NormalizedImportCandidate]
    ) throws -> [LikelyDuplicateCandidate] {
        []
    }

    func fetchLearnedRuleSummaries() throws -> [LearnedRuleSummary] {
        []
    }

    func fetchLearnedRuleSummary(id: UUID) throws -> LearnedRuleSummary? {
        nil
    }

    func fetchLearnedRuleDetail(id: UUID) throws -> ManagedLearnedRule? {
        nil
    }

    func createWorkspaceBackup(in directory: URL?, now: Date) throws -> WorkspaceBackup {
        backupCallCount += 1
        return backup
    }

    func restoreWorkspaceBackup(
        from backupURL: URL,
        safetyBackupDirectory: URL?,
        now: Date
    ) throws -> WorkspaceRestoreResult {
        restoreCallCount += 1
        lastRestoreBackupURL = backupURL
        return restoreResult
    }

    func resetWorkspace() throws -> WorkspaceResetResult {
        resetCallCount += 1
        return resetResult
    }
}

@Test
func resetWorkspaceThrowsWhenMaintenanceIsUnavailable() throws {
    let service = WorkspaceService(store: StubWorkspaceStore(summary: .empty, accounts: []))

    #expect(throws: WorkspaceServiceError.workspaceMaintenanceUnavailable) {
        try service.resetWorkspace()
    }
}

@Test
func createWorkspaceBackupReturnsTypedOutcomeData() throws {
    let store = MaintenanceWorkspaceStore()
    let service = WorkspaceService(store: store)

    let backup = try service.createWorkspaceBackup()

    #expect(backup.fileURL == URL(fileURLWithPath: "/tmp/backup.sqlite"))
    #expect(backup.createdAt == Date(timeIntervalSince1970: 1_775_171_200))
    #expect(backup.sizeBytes == 4096)
    #expect(store.backupCallCount == 1)
    #expect(store.restoreCallCount == 0)
    #expect(store.resetCallCount == 0)
}

@Test
func restoreWorkspaceBackupReturnsTypedOutcomeData() throws {
    let store = MaintenanceWorkspaceStore()
    let service = WorkspaceService(store: store)
    let sourceURL = URL(fileURLWithPath: "/tmp/incoming-backup.sqlite")

    let result = try service.restoreWorkspaceBackup(from: sourceURL)

    #expect(store.lastRestoreBackupURL == sourceURL)
    #expect(result.restoredFromURL == URL(fileURLWithPath: "/tmp/canned-restore-result.sqlite"))
    #expect(result.safetyBackup?.fileURL == URL(fileURLWithPath: "/tmp/safety-backup.sqlite"))
    #expect(result.safetyBackup?.sizeBytes == 2048)
    #expect(store.backupCallCount == 0)
    #expect(store.restoreCallCount == 1)
    #expect(store.resetCallCount == 0)
}

private final class DefaultResetBridgeMaintenanceStore: WorkspaceStoring, StagedImportWriting, ImportDecisionReading, WorkspaceMaintenanceManaging, @unchecked Sendable {
    func fetchSummary() throws -> WorkspaceSummary {
        .empty
    }

    func fetchAccounts() throws -> [Account] {
        []
    }

    func fetchManagementAccounts() throws -> [Account] {
        []
    }

    func fetchImportEligibleAccounts() throws -> [Account] {
        []
    }

    func fetchLedgerFilterAccounts() throws -> [Account] {
        []
    }

    func fetchPermanentlyDeletableAccountIDs() throws -> Set<UUID> {
        []
    }

    func fetchCategories() throws -> [BudgetCategory] {
        []
    }

    func fetchCategoryGroups() throws -> [BudgetCategoryGroup] {
        []
    }

    func fetchWorkspaceMetadata() throws -> WorkspaceMetadata {
        WorkspaceMetadata(
            databaseURL: URL(fileURLWithPath: "/tmp/workspace.sqlite"),
            databaseExists: true,
            databaseSizeBytes: 0,
            modifiedAt: nil
        )
    }

    func createAccount(named: String, kind: AccountKind, institutionName: String?) throws -> Account {
        Account(name: named, kind: kind, institutionName: institutionName)
    }

    func updateAccount(id: UUID, named: String, kind: AccountKind, institutionName: String?) throws -> Account {
        Account(id: id, name: named, kind: kind, institutionName: institutionName)
    }

    func archiveAccount(id: UUID, archivedAt: Date) throws -> Account {
        Account(id: id, name: "Archived", kind: .checking, institutionName: nil, archivedAt: archivedAt)
    }

    func restoreAccount(id: UUID) throws -> Account {
        Account(id: id, name: "Restored", kind: .checking, institutionName: nil)
    }

    func deleteAccountPermanently(id: UUID) throws {}

    func createStagedImportSession(_ draft: StagedImportSessionDraft) throws -> StagedImportSession {
        StagedImportSession(
            id: 1,
            sourceFile: StagedSourceFile(
                id: 1,
                accountID: draft.accountID,
                originalFilename: draft.originalFilename,
                contentHash: draft.contentHash,
                importedAt: draft.importedAt,
                rowCount: draft.rows.count
            ),
            mapping: draft.mapping,
            validRowCount: draft.validRowCount,
            invalidRowCount: draft.invalidRowCount,
            status: draft.status,
            rows: draft.rows.enumerated().map { index, row in
                StagedSourceRow(
                    id: Int64(index + 1),
                    sourceFileID: 1,
                    sourceLineNumber: row.sourceLineNumber,
                    rawPayload: row.rawPayload,
                    rowHash: row.rowHash,
                    validationStatus: row.validationStatus
                )
            }
        )
    }

    func fetchExistingSourceRowHashes(accountID: UUID, rowHashes: Set<String>) throws -> Set<String> {
        []
    }

    func fetchExistingSourceRowHashCounts(accountID: UUID, rowHashes: Set<String>) throws -> [String: Int] {
        [:]
    }

    func fetchLikelyDuplicateTransactions(
        accountID: UUID,
        candidates: [NormalizedImportCandidate]
    ) throws -> [LikelyDuplicateCandidate] {
        []
    }

    func createWorkspaceBackup(in directory: URL?, now: Date) throws -> WorkspaceBackup {
        WorkspaceBackup(
            fileURL: URL(fileURLWithPath: "/tmp/bridge-backup.sqlite"),
            createdAt: now,
            sizeBytes: 1
        )
    }

    func restoreWorkspaceBackup(
        from backupURL: URL,
        safetyBackupDirectory: URL?,
        now: Date
    ) throws -> WorkspaceRestoreResult {
        WorkspaceRestoreResult(
            restoredFromURL: backupURL,
            safetyBackup: nil,
            restoredAt: now
        )
    }
}

@Test
func resetWorkspaceReturnsTypedOutcomeData() throws {
    let store = MaintenanceWorkspaceStore()
    let service = WorkspaceService(store: store)

    let result = try service.resetWorkspace()

    #expect(result.preResetBackupURL == URL(fileURLWithPath: "/tmp/pre-reset-backup.sqlite"))
    #expect(store.backupCallCount == 0)
    #expect(store.restoreCallCount == 0)
    #expect(store.resetCallCount == 1)
}

@Test
func resetWorkspaceSurfacesDefaultBridgeErrorWhenMaintenanceUsesProtocolDefault() throws {
    let service = WorkspaceService(store: DefaultResetBridgeMaintenanceStore())

    #expect(throws: WorkspaceMaintenanceError.resetNotImplementedYet) {
        try service.resetWorkspace()
    }
}

@Test
func loadSnapshotReturnsSummaryAndAccountsFromStore() throws {
    let reviewItem = PendingReviewItem(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000222")!,
        type: .lowConfidenceCategory,
        status: .pending,
        reason: "Needs a category.",
        createdAt: Date(timeIntervalSince1970: 1_775_000_000),
        sourceFile: PendingReviewSourceFile(
            accountID: UUID(uuidString: "00000000-0000-0000-0000-000000000123")!,
            originalFilename: "checking.csv"
        ),
        sourceRow: PendingReviewSourceRow(
            id: 1,
            sourceLineNumber: 2,
            rowHash: "row-hash",
            rawPayload: "[\"2026-04-01\",\"Coffee Shop\",\"-4.75\"]"
        ),
        duplicateTransactionID: nil
    )
    let store = StubWorkspaceStore(
        summary: WorkspaceSummary(
            accountCount: 1,
            transactionCount: 24,
            reviewCount: 3,
            targetCount: 2
        ),
        accounts: [
            Account(name: "Checking", kind: .checking, institutionName: "Local Bank"),
        ],
        pendingReviewItems: [reviewItem]
    )

    let service = WorkspaceService(store: store)
    let snapshot = try service.loadSnapshot()

    #expect(snapshot.summary.accountCount == 1)
    #expect(snapshot.summary.reviewCount == 3)
    #expect(snapshot.managementAccounts.map(\.name) == ["Checking"])
    #expect(snapshot.importEligibleAccounts.map(\.name) == ["Checking"])
    #expect(snapshot.ledgerFilterAccounts.map(\.name) == ["Checking"])
    #expect(snapshot.permanentlyDeletableAccountIDs == Set(store.accounts.map(\.id)))
    #expect(snapshot.pendingReviewItems == [reviewItem])
}

@Test
func loadSnapshotSeparatesArchivedAccountVisibility() throws {
    let archivedAt = Date(timeIntervalSince1970: 1_775_171_260)
    let activeAccount = Account(name: "Checking", kind: .checking, institutionName: "Local Bank")
    let archivedAccount = Account(
        name: "Travel Card",
        kind: .creditCard,
        institutionName: "Visa",
        archivedAt: archivedAt
    )
    let store = StubWorkspaceStore(
        summary: WorkspaceSummary(
            accountCount: 1,
            transactionCount: 0,
            reviewCount: 0,
            targetCount: 0
        ),
        accounts: [activeAccount, archivedAccount]
    )

    let snapshot = try WorkspaceService(store: store).loadSnapshot()

    #expect(snapshot.managementAccounts.map(\.name) == ["Checking", "Travel Card"])
    #expect(snapshot.importEligibleAccounts.map(\.name) == ["Checking"])
    #expect(snapshot.ledgerFilterAccounts.map(\.name) == ["Checking", "Travel Card"])
    #expect(snapshot.permanentlyDeletableAccountIDs == Set([activeAccount.id, archivedAccount.id]))
}

@Test
func createAccountReturnsCreatedAccountAndUpdatedSnapshot() throws {
    let store = MutableWorkspaceStore()
    let service = WorkspaceService(store: store)

    let created = try service.createAccount(
        named: "Travel Card",
        kind: .creditCard,
        institutionName: "Visa"
    )
    let snapshot = try service.loadSnapshot()

    #expect(created.name == "Travel Card")
    #expect(snapshot.summary.accountCount == 1)
    #expect(snapshot.managementAccounts.map(\.name) == ["Travel Card"])
    #expect(snapshot.importEligibleAccounts.map(\.name) == ["Travel Card"])
    #expect(snapshot.permanentlyDeletableAccountIDs == Set([created.id]))
}

@Test
func seedSampleDataCreatesStarterAccountsOnlyOnce() throws {
    let store = MutableWorkspaceStore()
    let service = WorkspaceService(store: store)

    try service.seedSampleDataIfNeeded()
    try service.seedSampleDataIfNeeded()

    let snapshot = try service.loadSnapshot()

    #expect(snapshot.summary.accountCount == 2)
    #expect(snapshot.managementAccounts.map(\.name) == ["Checking", "Daily Card"])
    #expect(snapshot.importEligibleAccounts.map(\.name) == ["Checking", "Daily Card"])
    #expect(snapshot.permanentlyDeletableAccountIDs.count == 2)
}

@Test
func archiveAndRestoreAccountUpdateVisibilityContracts() throws {
    let store = MutableWorkspaceStore()
    let service = WorkspaceService(store: store)
    let created = try service.createAccount(
        named: "Travel Card",
        kind: .creditCard,
        institutionName: "Visa"
    )

    _ = try service.archiveAccount(
        id: created.id,
        archivedAt: Date(timeIntervalSince1970: 1_775_171_260)
    )

    var snapshot = try service.loadSnapshot()
    #expect(snapshot.summary.accountCount == 0)
    #expect(snapshot.managementAccounts.map(\.name) == ["Travel Card"])
    #expect(snapshot.importEligibleAccounts.isEmpty)
    #expect(snapshot.ledgerFilterAccounts.map(\.name) == ["Travel Card"])
    #expect(snapshot.permanentlyDeletableAccountIDs.isEmpty)

    _ = try service.restoreAccount(id: created.id)

    snapshot = try service.loadSnapshot()
    #expect(snapshot.summary.accountCount == 1)
    #expect(snapshot.importEligibleAccounts.map(\.name) == ["Travel Card"])
    #expect(snapshot.permanentlyDeletableAccountIDs == Set([created.id]))
}

@Test
func deleteAccountPermanentlySurfacesDependencyGuard() throws {
    let store = MutableWorkspaceStore()
    store.deleteAccountPermanentlyError = AccountManagementError.deleteBlockedByDependencies(
        UUID(uuidString: "00000000-0000-0000-0000-000000000444")!
    )
    let service = WorkspaceService(store: store)

    #expect(throws: WorkspaceServiceError.accountDeleteBlocked) {
        try service.deleteAccountPermanently(id: UUID(uuidString: "00000000-0000-0000-0000-000000000444")!)
    }
}

@Test
func stageCSVImportRejectsArchivedAccountsEvenForStaleCallers() throws {
    let archivedAccountID = UUID(uuidString: "00000000-0000-0000-0000-000000000555")!
    let staleAccount = Account(
        id: archivedAccountID,
        name: "Travel Card",
        kind: .creditCard,
        institutionName: "Visa"
    )
    let archivedStoreAccount = Account(
        id: archivedAccountID,
        name: "Travel Card",
        kind: .creditCard,
        institutionName: "Visa",
        archivedAt: Date(timeIntervalSince1970: 1_775_171_260)
    )
    let store = MutableWorkspaceStore(accounts: [archivedStoreAccount])
    let service = WorkspaceService(store: store)
    let csv = """
    Date,Description,Amount
    2026-04-01,Coffee Shop,-4.75
    """

    #expect(throws: WorkspaceServiceError.archivedAccountImportUnavailable) {
        _ = try service.stageCSVImport(
            preview: try CSVImportPreviewService().makePreview(from: csv),
            account: staleAccount,
            originalFilename: "travel-card.csv",
            csvText: csv
        )
    }
    #expect(store.stagedImportDrafts.isEmpty)
}

@Test
func createMonthlyTargetReturnsTargetAndReloadsSnapshot() throws {
    let store = MutableWorkspaceStore()
    let categoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000111")!
    store.categories = [BudgetCategory(id: categoryID, name: "Groceries", kind: .expense)]
    let service = WorkspaceService(store: store)

    let target = try service.createMonthlyTarget(
        MonthlyTargetDraft(scope: .category(categoryID), monthlyLimit: Decimal(125)),
        createdAt: Date(timeIntervalSince1970: 1_775_171_260)
    )
    let snapshot = try service.loadSnapshot()

    #expect(target.scope == .category(categoryID))
    #expect(snapshot.summary.targetCount == 1)
    #expect(snapshot.monthlyReport.targets.map(\.id) == [target.id])
    #expect(snapshot.monthlyReport.targets.map(\.remaining) == [Decimal(85)])
}

@Test
func createMonthlyTargetSurfacesTypedConflictErrors() throws {
    let store = MutableWorkspaceStore()
    let categoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000911")!
    store.createMonthlyTargetError = MonthlyTargetManagementError.conflict(.duplicateScope(.category(categoryID)))
    let service = WorkspaceService(store: store)

    #expect(throws: WorkspaceServiceError.monthlyTargetConflict(.duplicateScope(.category(categoryID)))) {
        try service.createMonthlyTarget(
            MonthlyTargetDraft(scope: .category(categoryID), monthlyLimit: Decimal(125)),
            createdAt: Date(timeIntervalSince1970: 1_775_171_260)
        )
    }
}

@Test
func updateMonthlyTargetSurfacesTypedConflictErrors() throws {
    let store = MutableWorkspaceStore()
    let categoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000912")!
    let groupID = UUID(uuidString: "00000000-0000-0000-0000-000000000913")!
    store.updateMonthlyTargetError = MonthlyTargetManagementError.conflict(
        .categoryGroupOverlap(categoryID: categoryID, categoryGroupID: groupID)
    )
    let service = WorkspaceService(store: store)

    #expect(
        throws: WorkspaceServiceError.monthlyTargetConflict(
            .categoryGroupOverlap(categoryID: categoryID, categoryGroupID: groupID)
        )
    ) {
        try service.updateMonthlyTarget(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000914")!,
            MonthlyTargetDraft(scope: .categoryGroup(groupID), monthlyLimit: Decimal(250))
        )
    }
}

@Test
func fetchManagedTargetsReturnsManagedTargets() throws {
    let store = MutableWorkspaceStore()
    let categoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000915")!
    store.managedTargets = [
        ManagedMonthlyTarget(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000916")!,
            name: "Groceries",
            scope: .category(categoryID),
            monthlyLimit: Decimal(125),
            spent: Decimal(40),
            remaining: Decimal(85),
            paceDelta: Decimal(5),
            createdAt: Date(timeIntervalSince1970: 1_775_171_260)
        ),
    ]
    let service = WorkspaceService(store: store)

    let managedTargets = try service.fetchManagedTargets(referenceDate: Date(timeIntervalSince1970: 1_775_171_200))

    #expect(managedTargets == store.managedTargets)
}

@Test
func deleteMonthlyTargetRemovesTargetAndReloadsSnapshot() throws {
    let store = MutableWorkspaceStore()
    let categoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000917")!
    store.categories = [BudgetCategory(id: categoryID, name: "Groceries", kind: .expense)]
    let service = WorkspaceService(store: store)
    let target = try service.createMonthlyTarget(
        MonthlyTargetDraft(scope: .category(categoryID), monthlyLimit: Decimal(125)),
        createdAt: Date(timeIntervalSince1970: 1_775_171_260)
    )

    try service.deleteMonthlyTarget(id: target.id)
    let snapshot = try service.loadSnapshot()

    #expect(snapshot.summary.targetCount == 0)
    #expect(snapshot.monthlyReport.targets.isEmpty)
    #expect(try service.fetchManagedTargets(referenceDate: Date(timeIntervalSince1970: 1_775_171_200)).isEmpty)
}

@Test
func deleteMonthlyTargetPropagatesStaleIDError() throws {
    let store = MutableWorkspaceStore()
    let service = WorkspaceService(store: store)
    let missingID = UUID(uuidString: "00000000-0000-0000-0000-000000000918")!

    #expect(throws: MonthlyTargetManagementError.targetNotFound(missingID)) {
        try service.deleteMonthlyTarget(id: missingID)
    }
}

@Test
func stageCSVImportCreatesStagedSessionFromValidPreview() throws {
    let account = Account(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000123")!,
        name: "Checking",
        kind: .checking,
        institutionName: "Local Bank"
    )
    let store = MutableWorkspaceStore(accounts: [account])
    let service = WorkspaceService(store: store)
    let csv = """
    Date,Description,Amount
    2026-04-01,Coffee Shop,-4.75
    2026-04-02,Payroll,1250.00
    """
    let preview = try CSVImportPreviewService().makePreview(from: csv)
    let importedAt = Date(timeIntervalSince1970: 1_777_000_000)

    let result = try service.stageCSVImport(
        preview: preview,
        account: account,
        originalFilename: "checking-april.csv",
        csvText: csv,
        importedAt: importedAt
    )
    let session = try #require(result.session)

    let draft = try #require(store.stagedImportDrafts.first)
    #expect(result.outcome == .staged)
    #expect(result.summary.importedRowCount == 2)
    #expect(result.summary.skippedRowCount == 0)
    #expect(result.summary.flaggedDuplicateRowCount == 0)
    #expect(store.stagedImportDrafts.count == 1)
    #expect(session.status == .staged)
    #expect(draft.accountID == account.id)
    #expect(draft.originalFilename == "checking-april.csv")
    #expect(draft.importedAt == importedAt)
    #expect(draft.mapping == preview.mapping)
    #expect(draft.validRowCount == 2)
    #expect(draft.invalidRowCount == 0)
    #expect(draft.status == .staged)
    #expect(draft.rows.map(\.sourceLineNumber) == [2, 3])
    #expect(draft.rows.map(\.validationStatus) == [.valid, .valid])
    #expect(draft.rows.map(\.importDecision) == [
        .imported(reason: "New source row."),
        .imported(reason: "New source row."),
    ])
    #expect(draft.rows.map(\.rawPayload) == [
        #"["2026-04-01","Coffee Shop","-4.75"]"#,
        #"["2026-04-02","Payroll","1250.00"]"#,
    ])
    #expect(draft.contentHash.isEmpty == false)
    #expect(draft.rows.allSatisfy { !$0.rowHash.isEmpty })
}

@Test
func stageCSVImportReturnsClassificationResultsForImportedRows() throws {
    let account = Account(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000123")!,
        name: "Checking",
        kind: .checking,
        institutionName: "Local Bank"
    )
    let categoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000111")!
    let ruleID = UUID(uuidString: "00000000-0000-0000-0000-000000000222")!
    let store = MutableWorkspaceStore(accounts: [account])
    let classifier = ClassificationEngine(
        explicitRules: [
            ClassificationRule(
                id: ruleID,
                merchantPattern: "coffee shop",
                categoryID: categoryID,
                merchantName: "Coffee Shop"
            ),
        ]
    )
    let service = WorkspaceService(store: store, classifier: classifier)
    let csv = """
    Date,Description,Amount
    2026-04-01,SQ *Coffee Shop,-4.75
    """
    let preview = try CSVImportPreviewService().makePreview(from: csv)

    let result = try service.stageCSVImport(
        preview: preview,
        account: account,
        originalFilename: "checking-april.csv",
        csvText: csv
    )

    #expect(result.classifications == [
        ImportRowClassification(
            rowHash: try WorkspaceService.rowHash(for: preview.sourceRows[0]),
            sourceLineNumber: 2,
            decision: .autoAccepted(
                assignment: ClassificationAssignment(
                    categoryID: categoryID,
                    merchantName: "Coffee Shop"
                ),
                source: .rule,
                sourceReference: ruleID.uuidString,
                confidence: 1.0,
                reason: "Matched explicit merchant rule."
            )
        ),
    ])
}

@Test
func stageCSVImportUsesPersistedClassificationRulesToAvoidReview() throws {
    let account = Account(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000123")!,
        name: "Checking",
        kind: .checking,
        institutionName: "Local Bank"
    )
    let categoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000111")!
    let store = MutableWorkspaceStore(accounts: [account])
    store.classificationRules = [
        ClassificationRule(
            merchantPattern: "coffee shop",
            categoryID: categoryID,
            merchantName: "Coffee Shop"
        ),
    ]
    let service = WorkspaceService(store: store)
    let csv = """
    Date,Description,Amount
    2026-04-02,SQ *Coffee Shop,-5.25
    """
    let preview = try CSVImportPreviewService().makePreview(from: csv)

    let result = try service.stageCSVImport(
        preview: preview,
        account: account,
        originalFilename: "checking-april.csv",
        csvText: csv
    )

    #expect(result.classifications.count == 1)
    #expect(result.classifications[0].decision.isAutoAccepted)
    #expect(result.classifications[0].decision.source == .rule)
    #expect(try #require(store.stagedImportDrafts.first).rows.first?.classification?.isAutoAccepted == true)
}

@Test
func stageCSVImportHonorsPersistedSuggestionPreference() throws {
    let account = Account(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000123")!,
        name: "Checking",
        kind: .checking,
        institutionName: "Local Bank"
    )
    let categoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000111")!
    let store = MutableWorkspaceStore(accounts: [account])
    store.preferences = WorkspacePreferences(suggestionsEnabled: false)
    let classifier = ClassificationEngine(
        suggestionProvider: FixedSuggestionProvider(
            suggestion: ClassificationSuggestion(
                assignment: ClassificationAssignment(categoryID: categoryID, merchantName: "Coffee Shop"),
                confidence: 0.80,
                sourceReference: "fixture"
            )
        )
    )
    let service = WorkspaceService(store: store, classifier: classifier)
    let csv = """
    Date,Description,Amount
    2026-04-02,SQ *Coffee Shop,-5.25
    """
    let preview = try CSVImportPreviewService().makePreview(from: csv)

    let result = try service.stageCSVImport(
        preview: preview,
        account: account,
        originalFilename: "checking-april.csv",
        csvText: csv
    )

    #expect(result.classifications.count == 1)
    #expect(result.classifications[0].decision.source == nil)
    #expect(result.classifications[0].decision.assignment == nil)
}

@Test
func stageCSVImportHonorsSeededHeuristicAutoAcceptPreference() throws {
    let account = Account(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000123")!,
        name: "Checking",
        kind: .checking,
        institutionName: "Local Bank"
    )
    let categoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000111")!
    let classifier = ClassificationEngine(
        heuristics: [
            ClassificationHeuristic(
                merchantPattern: "coffee",
                categoryID: categoryID,
                merchantName: "Coffee Shop"
            ),
        ]
    )
    let csv = """
    Date,Description,Amount
    2026-04-02,SQ *Coffee Shop,-5.25
    """
    let preview = try CSVImportPreviewService().makePreview(from: csv)
    let aggressiveStore = MutableWorkspaceStore(accounts: [account])
    aggressiveStore.preferences = WorkspacePreferences(
        suggestionsEnabled: true,
        seededHeuristicAutoAcceptEnabled: true
    )
    let aggressiveService = WorkspaceService(store: aggressiveStore, classifier: classifier)

    let aggressiveResult = try aggressiveService.stageCSVImport(
        preview: preview,
        account: account,
        originalFilename: "checking-april.csv",
        csvText: csv
    )

    let conservativeStore = MutableWorkspaceStore(accounts: [account])
    conservativeStore.preferences = WorkspacePreferences(
        suggestionsEnabled: true,
        seededHeuristicAutoAcceptEnabled: false
    )
    let conservativeService = WorkspaceService(store: conservativeStore, classifier: classifier)

    let reviewResult = try conservativeService.stageCSVImport(
        preview: preview,
        account: account,
        originalFilename: "checking-april-review.csv",
        csvText: csv
    )

    #expect(aggressiveResult.classifications.count == 1)
    #expect(aggressiveResult.classifications[0].decision.isAutoAccepted)
    #expect(aggressiveResult.classifications[0].decision.source == .heuristic)
    #expect(reviewResult.classifications.count == 1)
    #expect(reviewResult.classifications[0].decision.isAutoAccepted == false)
    #expect(reviewResult.classifications[0].decision.source == .heuristic)
}

@Test
func stageCSVImportCarriesCuratedReviewPrefillForLive99PLEDGFamily() throws {
    let account = Account(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000123")!,
        name: "Checking",
        kind: .checking,
        institutionName: "Local Bank"
    )
    let store = MutableWorkspaceStore(accounts: [account])
    let service = WorkspaceService(store: store, classifier: SeededClassification.liveClassifier())
    let csv = """
    Date,Description,Amount
    2026-04-02,99PLEDG*ONIR BAWEJA,-25.00
    """
    let preview = try CSVImportPreviewService().makePreview(from: csv)

    let result = try service.stageCSVImport(
        preview: preview,
        account: account,
        originalFilename: "checking-curated.csv",
        csvText: csv
    )

    #expect(result.classifications.count == 1)
    let classification = result.classifications[0]
    let expectedRowHash = try WorkspaceService.rowHash(for: preview.sourceRows[0])
    let expectedDecision = TransactionClassificationDecision.reviewRequired(
        prefill: ClassificationAssignment(
            categoryID: DefaultBudgetTaxonomy.CategoryID.donations,
            merchantName: "99PLEDG"
        ),
        source: .curatedPrefill,
        sourceReference: "starter.99pledg.family",
        confidence: nil,
        reason: "Curated starter match requires review before acceptance."
    )
    let stagedDraft = try #require(store.stagedImportDrafts.first)
    let stagedRow = try #require(stagedDraft.rows.first)

    #expect(classification.rowHash == expectedRowHash)
    #expect(classification.sourceLineNumber == 2)
    #expect(classification.decision.isAutoAccepted == false)
    #expect(classification.decision == expectedDecision)
    #expect(result.summary.importedRowCount == 1)
    #expect(result.summary.pendingClassificationReviewRowCount == 1)
    #expect(stagedDraft.rows.count == 1)
    #expect(stagedRow.importDecision == .imported(reason: "New source row."))
    #expect(stagedRow.classification == expectedDecision)
}

@Test
func stageCSVImportAppliesHeuristicPreferenceWithoutChangingCuratedReviewPrefillBehavior() throws {
    let account = Account(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000123")!,
        name: "Checking",
        kind: .checking,
        institutionName: "Local Bank"
    )
    let csv = """
    Date,Description,Amount
    2026-04-02,99PLEDG*ONIR BAWEJA,-25.00
    2026-04-03,SQ *Coffee Shop,-4.75
    """
    let preview = try CSVImportPreviewService().makePreview(from: csv)
    let aggressiveStore = MutableWorkspaceStore(accounts: [account])
    aggressiveStore.preferences = WorkspacePreferences(
        suggestionsEnabled: true,
        seededHeuristicAutoAcceptEnabled: true
    )
    let aggressiveService = WorkspaceService(
        store: aggressiveStore,
        classifier: SeededClassification.liveClassifier()
    )

    let aggressiveResult = try aggressiveService.stageCSVImport(
        preview: preview,
        account: account,
        originalFilename: "checking-curated-aggressive.csv",
        csvText: csv
    )

    let conservativeStore = MutableWorkspaceStore(accounts: [account])
    conservativeStore.preferences = WorkspacePreferences(
        suggestionsEnabled: true,
        seededHeuristicAutoAcceptEnabled: false
    )
    let conservativeService = WorkspaceService(
        store: conservativeStore,
        classifier: SeededClassification.liveClassifier()
    )

    let conservativeResult = try conservativeService.stageCSVImport(
        preview: preview,
        account: account,
        originalFilename: "checking-curated-conservative.csv",
        csvText: csv
    )

    let expectedDecision = TransactionClassificationDecision.reviewRequired(
        prefill: ClassificationAssignment(
            categoryID: DefaultBudgetTaxonomy.CategoryID.donations,
            merchantName: "99PLEDG"
        ),
        source: .curatedPrefill,
        sourceReference: "starter.99pledg.family",
        confidence: nil,
        reason: "Curated starter match requires review before acceptance."
    )
    let aggressiveHeuristicDecision = TransactionClassificationDecision.autoAccepted(
        assignment: ClassificationAssignment(
            categoryID: DefaultBudgetTaxonomy.CategoryID.coffeeShops,
            merchantName: nil
        ),
        source: .heuristic,
        sourceReference: nil,
        confidence: 0.65,
        reason: "Aggressive seeded heuristic matched."
    )
    let conservativeHeuristicDecision = TransactionClassificationDecision.reviewRequired(
        prefill: ClassificationAssignment(
            categoryID: DefaultBudgetTaxonomy.CategoryID.coffeeShops,
            merchantName: nil
        ),
        source: .heuristic,
        sourceReference: nil,
        confidence: 0.65,
        reason: "Deterministic heuristic requires review."
    )
    let aggressiveDraft = try #require(aggressiveStore.stagedImportDrafts.first)
    let conservativeDraft = try #require(conservativeStore.stagedImportDrafts.first)

    #expect(aggressiveResult.classifications.count == 2)
    #expect(aggressiveResult.summary.importedRowCount == 2)
    #expect(aggressiveResult.summary.pendingClassificationReviewRowCount == 1)
    #expect(aggressiveDraft.rows.count == 2)
    #expect(aggressiveDraft.rows.map(\.classification) == [
        expectedDecision,
        aggressiveHeuristicDecision,
    ])
    #expect(aggressiveDraft.rows.map(\.importDecision) == [
        .imported(reason: "New source row."),
        .imported(reason: "New source row."),
    ])
    #expect(aggressiveResult.classifications.map(\.decision) == [
        expectedDecision,
        aggressiveHeuristicDecision,
    ])

    #expect(conservativeResult.classifications.count == 2)
    #expect(conservativeResult.summary.importedRowCount == 2)
    #expect(conservativeResult.summary.pendingClassificationReviewRowCount == 2)
    #expect(conservativeDraft.rows.count == 2)
    #expect(conservativeDraft.rows.map(\.classification) == [
        expectedDecision,
        conservativeHeuristicDecision,
    ])
    #expect(conservativeDraft.rows.map(\.importDecision) == [
        .imported(reason: "New source row."),
        .imported(reason: "New source row."),
    ])
    #expect(conservativeResult.classifications.map(\.decision) == [
        expectedDecision,
        conservativeHeuristicDecision,
    ])
}

@Test
func stageCSVImportTreatsRenamedExactReimportAsNoOp() throws {
    let account = Account(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000123")!,
        name: "Checking",
        kind: .checking,
        institutionName: "Local Bank"
    )
    let store = MutableWorkspaceStore(accounts: [account])
    let service = WorkspaceService(store: store)
    let csv = """
    Date,Description,Amount
    2026-04-01,Coffee Shop,-4.75
    2026-04-02,Payroll,1250.00
    """
    let preview = try CSVImportPreviewService().makePreview(from: csv)

    let firstResult = try service.stageCSVImport(
        preview: preview,
        account: account,
        originalFilename: "checking-april.csv",
        csvText: csv
    )
    let renamedResult = try service.stageCSVImport(
        preview: preview,
        account: account,
        originalFilename: "renamed-export.csv",
        csvText: csv
    )

    #expect(firstResult.outcome == .staged)
    #expect(renamedResult.outcome == .exactReimportNoOp)
    #expect(renamedResult.session == nil)
    #expect(renamedResult.summary.importedRowCount == 0)
    #expect(renamedResult.summary.skippedRowCount == 2)
    #expect(renamedResult.decisions == [
        .skippedExactReimport(reason: "Source row already exists for this account."),
        .skippedExactReimport(reason: "Source row already exists for this account."),
    ])
    #expect(store.stagedImportDrafts.count == 1)
}

@Test
func stageCSVImportDoesNotTreatExtraRepeatedRowsAsExactReimportNoOp() throws {
    let account = Account(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000123")!,
        name: "Checking",
        kind: .checking,
        institutionName: "Local Bank"
    )
    let store = MutableWorkspaceStore(accounts: [account])
    let service = WorkspaceService(store: store)
    let firstCSV = """
    Date,Description,Amount
    2026-04-01,Coffee Shop,-4.75
    """
    let repeatedCSV = """
    Date,Description,Amount
    2026-04-01,Coffee Shop,-4.75
    2026-04-01,Coffee Shop,-4.75
    """

    _ = try service.stageCSVImport(
        preview: try CSVImportPreviewService().makePreview(from: firstCSV),
        account: account,
        originalFilename: "checking-april.csv",
        csvText: firstCSV
    )
    let repeatedResult = try service.stageCSVImport(
        preview: try CSVImportPreviewService().makePreview(from: repeatedCSV),
        account: account,
        originalFilename: "checking-april-repeated.csv",
        csvText: repeatedCSV
    )

    #expect(repeatedResult.outcome == .staged)
    #expect(repeatedResult.summary.importedRowCount == 1)
    #expect(repeatedResult.summary.skippedRowCount == 1)
    #expect(repeatedResult.session != nil)
    #expect(store.stagedImportDrafts.count == 2)
}

@Test
func stageCSVImportCanNoOpExactReimportBeforeDateNormalization() throws {
    let account = Account(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000123")!,
        name: "Checking",
        kind: .checking,
        institutionName: "Local Bank"
    )
    let store = MutableWorkspaceStore(accounts: [account])
    let service = WorkspaceService(store: store)
    let preview = CSVImportPreview(
        headers: [
            CSVColumn(name: "Date", columnIndex: 0),
            CSVColumn(name: "Description", columnIndex: 1),
            CSVColumn(name: "Amount", columnIndex: 2),
        ],
        mapping: CSVColumnMapping(
            dateColumnIndex: 0,
            descriptionColumnIndex: 1,
            amount: .singleSignedAmount(columnIndex: 2)
        ),
        previewRows: [],
        validation: CSVImportValidationSummary(
            missingRequiredFields: [],
            validRowCount: 1,
            invalidRowCount: 0,
            rowIssues: []
        ),
        sourceRows: [
            CSVRow(
                sourceLineNumber: 2,
                cells: [
                    CSVCell(value: "April 1, 2026", columnIndex: 0),
                    CSVCell(value: "Coffee Shop", columnIndex: 1),
                    CSVCell(value: "-4.75", columnIndex: 2),
                ]
            ),
        ]
    )
    let rowHash = try WorkspaceService.rowHash(for: preview.sourceRows[0])
    store.existingSourceRowHashes = [rowHash]

    let result = try service.stageCSVImport(
        preview: preview,
        account: account,
        originalFilename: "renamed-export.csv",
        csvText: "Date,Description,Amount\nApril 1, 2026,Coffee Shop,-4.75"
    )

    #expect(result.outcome == .exactReimportNoOp)
    #expect(result.summary.skippedRowCount == 1)
    #expect(store.stagedImportDrafts.isEmpty)
}

@Test
func stageCSVImportFlagsLikelyDuplicatesForReviewInsteadOfSkipping() throws {
    let account = Account(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000123")!,
        name: "Checking",
        kind: .checking,
        institutionName: "Local Bank"
    )
    let store = MutableWorkspaceStore(accounts: [account])
    let service = WorkspaceService(store: store)
    let csv = """
    Date,Description,Amount
    2026-04-02,SQ *Coffee Shop,-4.75
    """
    let preview = try CSVImportPreviewService().makePreview(from: csv)
    let rowHash = try WorkspaceService.rowHash(for: preview.sourceRows[0])
    let existingTransactionID = UUID(uuidString: "00000000-0000-0000-0000-000000000999")!
    store.likelyDuplicateCandidates = [
        LikelyDuplicateCandidate(
            rowHash: rowHash,
            existingTransactionID: existingTransactionID,
            reason: "Same account, amount, normalized merchant, and nearby date."
        ),
    ]

    let result = try service.stageCSVImport(
        preview: preview,
        account: account,
        originalFilename: "checking-april.csv",
        csvText: csv
    )

    let draft = try #require(store.stagedImportDrafts.first)
    #expect(result.outcome == .staged)
    #expect(result.summary.importedRowCount == 0)
    #expect(result.summary.flaggedDuplicateRowCount == 1)
    #expect(result.decisions == [
        .flaggedLikelyDuplicate(
            existingTransactionID: existingTransactionID,
            reason: "Same account, amount, normalized merchant, and nearby date."
        ),
    ])
    #expect(draft.rows.map(\.importDecision) == result.decisions)
    #expect(draft.rows.map(\.validationStatus) == [.valid])
}

@Test
func stageCSVImportHandlesRepeatedRowsThatShareADuplicateCandidate() throws {
    let account = Account(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000123")!,
        name: "Checking",
        kind: .checking,
        institutionName: "Local Bank"
    )
    let store = MutableWorkspaceStore(accounts: [account])
    let service = WorkspaceService(store: store)
    let csv = """
    Date,Description,Amount
    2026-04-02,SQ *Coffee Shop,-4.75
    2026-04-02,SQ *Coffee Shop,-4.75
    """
    let preview = try CSVImportPreviewService().makePreview(from: csv)
    let rowHash = try WorkspaceService.rowHash(for: preview.sourceRows[0])
    let existingTransactionID = UUID(uuidString: "00000000-0000-0000-0000-000000000999")!
    store.likelyDuplicateCandidates = [
        LikelyDuplicateCandidate(
            rowHash: rowHash,
            existingTransactionID: existingTransactionID,
            reason: "Same account, amount, normalized merchant, and nearby date."
        ),
        LikelyDuplicateCandidate(
            rowHash: rowHash,
            existingTransactionID: existingTransactionID,
            reason: "Same account, amount, normalized merchant, and nearby date."
        ),
    ]

    let result = try service.stageCSVImport(
        preview: preview,
        account: account,
        originalFilename: "checking-april.csv",
        csvText: csv
    )

    #expect(result.summary.flaggedDuplicateRowCount == 2)
    #expect(result.decisions == [
        .flaggedLikelyDuplicate(
            existingTransactionID: existingTransactionID,
            reason: "Same account, amount, normalized merchant, and nearby date."
        ),
        .flaggedLikelyDuplicate(
            existingTransactionID: existingTransactionID,
            reason: "Same account, amount, normalized merchant, and nearby date."
        ),
    ])
}

@Test
func stageCSVImportSummarySeparatesPendingClassificationReviewFromLikelyDuplicates() throws {
    let account = Account(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000123")!,
        name: "Checking",
        kind: .checking,
        institutionName: "Local Bank"
    )
    let categoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000111")!
    let classifier = ClassificationEngine(
        heuristics: [
            ClassificationHeuristic(
                merchantPattern: "coffee",
                categoryID: categoryID,
                merchantName: "Coffee Shop"
            ),
        ]
    )
    let store = MutableWorkspaceStore(accounts: [account])
    store.preferences = WorkspacePreferences(
        suggestionsEnabled: true,
        seededHeuristicAutoAcceptEnabled: false
    )
    let service = WorkspaceService(store: store, classifier: classifier)
    let csv = """
    Date,Description,Amount
    2026-04-02,SQ *Coffee Shop,-4.75
    2026-04-03,Book Shop,-12.00
    """
    let preview = try CSVImportPreviewService().makePreview(from: csv)
    let duplicateRowHash = try WorkspaceService.rowHash(for: preview.sourceRows[1])
    let existingTransactionID = UUID(uuidString: "00000000-0000-0000-0000-000000000999")!
    store.likelyDuplicateCandidates = [
        LikelyDuplicateCandidate(
            rowHash: duplicateRowHash,
            existingTransactionID: existingTransactionID,
            reason: "Same account, amount, normalized merchant, and nearby date."
        ),
    ]

    let result = try service.stageCSVImport(
        preview: preview,
        account: account,
        originalFilename: "checking-april.csv",
        csvText: csv
    )

    #expect(result.summary.importedRowCount == 1)
    #expect(result.summary.skippedRowCount == 0)
    #expect(result.summary.pendingClassificationReviewRowCount == 1)
    #expect(result.summary.flaggedDuplicateRowCount == 1)
}

@Test
func stageCSVImportRejectsInvalidPreviewBeforeWriting() throws {
    let account = Account(name: "Checking", kind: .checking, institutionName: "Local Bank")
    let store = MutableWorkspaceStore(accounts: [account])
    let service = WorkspaceService(store: store)
    let csv = """
    Date,Description,Amount
    ,Missing Date,-4.75
    """
    let preview = try CSVImportPreviewService().makePreview(from: csv)

    #expect(throws: WorkspaceServiceError.importPreviewNotReady) {
        try service.stageCSVImport(
            preview: preview,
            account: account,
            originalFilename: "invalid.csv",
            csvText: csv
        )
    }
    #expect(store.stagedImportDrafts.isEmpty)
}

@Test
func stageCSVImportRejectsPreviewWithMissingSourceRowsBeforeWriting() throws {
    let account = Account(name: "Checking", kind: .checking, institutionName: "Local Bank")
    let store = MutableWorkspaceStore(accounts: [account])
    let service = WorkspaceService(store: store)
    let preview = CSVImportPreview(
        headers: [
            CSVColumn(name: "Date", columnIndex: 0),
            CSVColumn(name: "Description", columnIndex: 1),
            CSVColumn(name: "Amount", columnIndex: 2),
        ],
        mapping: CSVColumnMapping(
            dateColumnIndex: 0,
            descriptionColumnIndex: 1,
            amount: .singleSignedAmount(columnIndex: 2)
        ),
        previewRows: [
            CSVImportPreviewRow(
                sourceLineNumber: 2,
                cells: [
                    CSVCell(value: "2026-04-01", columnIndex: 0),
                    CSVCell(value: "Coffee Shop", columnIndex: 1),
                    CSVCell(value: "-4.75", columnIndex: 2),
                ],
                interpretedAmount: -4.75
            ),
        ],
        validation: CSVImportValidationSummary(
            missingRequiredFields: [],
            validRowCount: 1,
            invalidRowCount: 0,
            rowIssues: []
        )
    )

    #expect(throws: WorkspaceServiceError.importPreviewSourceRowsUnavailable) {
        try service.stageCSVImport(
            preview: preview,
            account: account,
            originalFilename: "missing-source-rows.csv",
            csvText: "Date,Description,Amount\n2026-04-01,Coffee Shop,-4.75"
        )
    }
    #expect(store.stagedImportDrafts.isEmpty)
}

@Test
func previewWithoutConfirmationDoesNotCreateStagedRecords() throws {
    let account = Account(name: "Checking", kind: .checking, institutionName: "Local Bank")
    let store = MutableWorkspaceStore(accounts: [account])
    let csv = """
    Date,Description,Amount
    2026-04-01,Coffee Shop,-4.75
    """

    _ = try CSVImportPreviewService().makePreview(from: csv)

    #expect(store.stagedImportDrafts.isEmpty)
}

private struct FixedSuggestionProvider: SuggestionProvider {
    var suggestion: ClassificationSuggestion?

    func suggestion(for candidate: NormalizedImportCandidate) -> ClassificationSuggestion? {
        suggestion
    }
}

@Test
func workspaceServiceReturnsDistinctLearnedAndSeededManagerSections() throws {
    let learnedRuleID = UUID(uuidString: "00000000-0000-0000-0000-000000000111")!
    let store = MutableWorkspaceStore()
    store.learnedRuleSummaries = [
        LearnedRuleSummary(
            id: learnedRuleID,
            merchantPattern: "local market",
            categoryID: UUID(uuidString: "00000000-0000-0000-0000-000000000211"),
            merchantName: "Local Market",
            matchKind: .contains,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            lifecycle: .active
        )
    ]

    let service = WorkspaceService(store: store, classifier: SeededClassification.liveClassifier())
    let snapshot = try service.loadLearnedRuleManagerSnapshot()

    #expect(snapshot.learned.mode == .learned)
    #expect(snapshot.seeded.mode == .seeded)
    #expect(snapshot.learned.rows.map(\.id) == [learnedRuleID])
    #expect(snapshot.seeded.rows.isEmpty == false)
}

@Test
func seededManagerRowsAreAssembledFromSeededClassification() throws {
    let service = WorkspaceService(
        store: MutableWorkspaceStore(),
        classifier: SeededClassification.liveClassifier()
    )

    let snapshot = try service.loadLearnedRuleManagerSnapshot()
    let expectedSeededCount = SeededClassification.deterministicRules.count + SeededClassification.curatedReviewPrefills.count

    #expect(snapshot.seeded.rows.count == expectedSeededCount)
    #expect(snapshot.seeded.rows.contains(where: { $0.sourceKind == .deterministicRule }) == true)
    #expect(snapshot.seeded.rows.contains(where: { $0.sourceKind == .curatedPrefill }) == true)
}

@Test
func seededHeuristicsDoNotAppearInTheManagerSnapshot() throws {
    let service = WorkspaceService(
        store: MutableWorkspaceStore(),
        classifier: SeededClassification.liveClassifier()
    )

    let snapshot = try service.loadLearnedRuleManagerSnapshot()
    let seededPatterns = Set(snapshot.seeded.rows.map(\.merchantPattern))
    let heuristicOnlyPatterns = Set(SeededClassification.heuristics.map(\.merchantPattern))
        .subtracting(Set(SeededClassification.deterministicRules.map(\.merchantPattern)))
        .subtracting(Set(SeededClassification.curatedReviewPrefills.map(\.merchantPattern)))

    #expect(heuristicOnlyPatterns.allSatisfy { seededPatterns.contains($0) == false })
}

@Test
func loadLearnedRuleManagerSnapshotFailsWithoutLearnedRuleReader() throws {
    let service = WorkspaceService(store: DefaultResetBridgeMaintenanceStore())

    #expect(throws: WorkspaceServiceError.learnedRuleManagementUnavailable) {
        try service.loadLearnedRuleManagerSnapshot()
    }
}

@Test
func loadTransactionDetailPreservesRawRuleReferenceWhenLearnedRuleCannotBeResolved() throws {
    let transactionID = UUID(uuidString: "00000000-0000-0000-0000-000000000511")!
    let unresolvedRuleID = UUID(uuidString: "00000000-0000-0000-0000-000000000512")!
    let store = MutableWorkspaceStore()
    store.transactionDetailsByID[transactionID] = makeTransactionDetail(
        id: transactionID,
        decisionSource: .rule,
        decisionSourceReference: unresolvedRuleID.uuidString
    )

    let detail = try #require(try WorkspaceService(store: store).loadTransactionDetail(id: transactionID))

    #expect(detail.ruleProvenance == nil)
    #expect(detail.decisionSourceReference == unresolvedRuleID.uuidString)
}

@Test
func loadTransactionDetailResolvesDisabledLearnedRuleHistoricalProvenance() throws {
    let transactionID = UUID(uuidString: "00000000-0000-0000-0000-000000000521")!
    let learnedRuleID = UUID(uuidString: "00000000-0000-0000-0000-000000000522")!
    let categoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000523")!
    let disabledAt = Date(timeIntervalSince1970: 1_776_355_200)
    let store = MutableWorkspaceStore()
    store.categories = [
        BudgetCategory(id: categoryID, name: "Groceries", kind: .expense)
    ]
    store.transactionDetailsByID[transactionID] = makeTransactionDetail(
        id: transactionID,
        decisionSource: .rule,
        decisionSourceReference: learnedRuleID.uuidString
    )
    store.learnedRuleSummaries = [
        LearnedRuleSummary(
            id: learnedRuleID,
            merchantPattern: "local market",
            categoryID: categoryID,
            merchantName: "Local Market",
            matchKind: .prefixNormalizedMerchant,
            createdAt: Date(timeIntervalSince1970: 1_776_268_800),
            lifecycle: .disabled(disabledAt: disabledAt)
        )
    ]

    let detail = try #require(try WorkspaceService(store: store).loadTransactionDetail(id: transactionID))
    let provenance = try #require(detail.ruleProvenance)

    guard case .learnedRule(let learnedRule) = provenance else {
        Issue.record("Expected learned rule provenance")
        return
    }

    #expect(learnedRule.id == learnedRuleID)
    #expect(learnedRule.merchantPattern == "local market")
    #expect(learnedRule.matchKind == .prefixNormalizedMerchant)
    #expect(learnedRule.categoryID == categoryID)
    #expect(learnedRule.categoryName == "Groceries")
    #expect(learnedRule.isDisabled == true)
    #expect(learnedRule.disabledAt == disabledAt)
}

@Test
func loadTransactionDetailResolvesDeterministicBuiltInRuleProvenance() throws {
    let transactionID = UUID(uuidString: "00000000-0000-0000-0000-000000000524")!
    let rule = try #require(
        SeededClassification.deterministicRules.first { $0.merchantPattern == "costco" }
    )
    let detailReference = rule.seededSourceID
    let store = MutableWorkspaceStore()
    store.categories = [
        BudgetCategory(id: rule.categoryID, name: "Groceries", kind: .expense)
    ]
    store.transactionDetailsByID[transactionID] = makeTransactionDetail(
        id: transactionID,
        decisionSource: .rule,
        decisionSourceReference: detailReference
    )

    let detail = try #require(try WorkspaceService(store: store).loadTransactionDetail(id: transactionID))
    let provenance = try #require(detail.ruleProvenance)

    guard case .seededSource(let seededSource) = provenance else {
        Issue.record("Expected seeded source provenance")
        return
    }

    #expect(seededSource.id == detailReference)
    #expect(seededSource.kind == .deterministicRule)
    #expect(seededSource.merchantPattern == "costco")
    #expect(seededSource.matchKind == .contains)
    #expect(seededSource.categoryID == rule.categoryID)
    #expect(seededSource.categoryName == "Groceries")
    #expect(seededSource.merchantName == "Costco")
}

@Test
func loadTransactionDetailResolvesCuratedReviewFirstBuiltInProvenance() throws {
    let transactionID = UUID(uuidString: "00000000-0000-0000-0000-000000000525")!
    let source = try #require(SeededClassification.curatedReviewPrefills.first)
    let store = MutableWorkspaceStore()
    store.categories = [
        BudgetCategory(id: source.assignment.categoryID, name: "Donations", kind: .expense)
    ]
    store.transactionDetailsByID[transactionID] = makeTransactionDetail(
        id: transactionID,
        decisionSource: .curatedPrefill,
        decisionSourceReference: source.id
    )

    let detail = try #require(try WorkspaceService(store: store).loadTransactionDetail(id: transactionID))
    let provenance = try #require(detail.ruleProvenance)

    guard case .seededSource(let seededSource) = provenance else {
        Issue.record("Expected seeded source provenance")
        return
    }

    #expect(seededSource.id == source.id)
    #expect(seededSource.kind == .curatedPrefill)
    #expect(seededSource.merchantPattern == source.merchantPattern)
    #expect(seededSource.matchKind == source.matchKind)
    #expect(seededSource.categoryID == source.assignment.categoryID)
    #expect(seededSource.categoryName == "Donations")
    #expect(seededSource.merchantName == source.assignment.merchantName)
}

@Test
func approveClassificationReviewItemReturnsDeepLinkActionForCreatedLearnedRule() throws {
    let learnedRuleID = UUID(uuidString: "00000000-0000-0000-0000-000000000531")!
    let categoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000532")!
    let reviewItemID = UUID(uuidString: "00000000-0000-0000-0000-000000000533")!
    let resolvedAt = Date(timeIntervalSince1970: 1_776_355_260)
    let store = MutableWorkspaceStore()
    store.nextCreatedLearnedRuleID = learnedRuleID
    let service = WorkspaceService(store: store)

    let result = try service.approveClassificationReviewItem(
        id: reviewItemID,
        assignment: ClassificationAssignment(
            categoryID: categoryID,
            merchantName: "Coffee Shop"
        ),
        ruleLearning: .exactNormalizedMerchant(pattern: "coffee shop"),
        resolvedAt: resolvedAt
    )
    let action = try #require(result.createdLearnedRuleAction)

    #expect(action.ruleID == learnedRuleID)
    #expect(action.merchantLabel == "Coffee Shop")
    #expect(action.destination == .learnedRulesRoute(selection: .learnedRule(learnedRuleID)))
}

@Test
func approveClassificationReviewItemPrefersTheNewlyCreatedRuleOverExistingMatchingRules() throws {
    let existingRuleID = UUID(uuidString: "00000000-0000-0000-0000-000000000536")!
    let createdRuleID = UUID(uuidString: "00000000-0000-0000-0000-000000000537")!
    let categoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000538")!
    let reviewItemID = UUID(uuidString: "00000000-0000-0000-0000-000000000539")!
    let resolvedAt = Date(timeIntervalSince1970: 1_776_355_260)
    let store = MutableWorkspaceStore()
    store.learnedRuleSummaries = [
        LearnedRuleSummary(
            id: existingRuleID,
            merchantPattern: "coffee shop",
            categoryID: categoryID,
            merchantName: "Coffee Shop",
            matchKind: .exactNormalizedMerchant,
            createdAt: resolvedAt,
            lifecycle: .active
        )
    ]
    store.nextCreatedLearnedRuleID = createdRuleID
    let service = WorkspaceService(store: store)

    let result = try service.approveClassificationReviewItem(
        id: reviewItemID,
        assignment: ClassificationAssignment(
            categoryID: categoryID,
            merchantName: "Coffee Shop"
        ),
        ruleLearning: .exactNormalizedMerchant(pattern: "coffee shop"),
        resolvedAt: resolvedAt
    )
    let action = try #require(result.createdLearnedRuleAction)

    #expect(action.ruleID == createdRuleID)
    #expect(action.destination == .learnedRulesRoute(selection: .learnedRule(createdRuleID)))
}

@Test
func approveClassificationReviewItemOmitsDeepLinkActionWhenRuleLearningIsDisabled() throws {
    let categoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000541")!
    let reviewItemID = UUID(uuidString: "00000000-0000-0000-0000-000000000542")!
    let store = MutableWorkspaceStore()
    let service = WorkspaceService(store: store)

    let result = try service.approveClassificationReviewItem(
        id: reviewItemID,
        assignment: ClassificationAssignment(
            categoryID: categoryID,
            merchantName: "Coffee Shop"
        ),
        ruleLearning: nil,
        resolvedAt: Date(timeIntervalSince1970: 1_776_355_320)
    )

    #expect(result.createdLearnedRuleAction == nil)
}

@Test
func learnedRuleDraftDefaultsToManualAuthoringValues() {
    let draft = LearnedRuleDraft()

    #expect(draft.merchantPattern == "")
    #expect(draft.categoryID == nil)
    #expect(draft.merchantName == nil)
    #expect(draft.matchKind == .exactNormalizedMerchant)
}

@Test
func learnedRuleDraftSheetForNewRuleStartsBlankAndAllowsOnlyBasicMatchKinds() {
    let sheet = LearnedRuleDraftSheet.newRule()

    #expect(sheet.mode == .newRule)
    #expect(sheet.title == "New Rule")
    #expect(sheet.confirmationTitle == "Save Rule")
    #expect(sheet.allowedMatchKinds == [
        .exactNormalizedMerchant,
        .prefixNormalizedMerchant,
    ])
    #expect(sheet.draft == LearnedRuleDraft())
    #expect(sheet.canSave == false)
}

@Test
func learnedRuleDraftSheetForDuplicateRuleCopiesEditableFieldsIntoANewDraft() {
    let sourceRuleID = UUID(uuidString: "00000000-0000-0000-0000-0000000005A1")!
    let categoryID = UUID(uuidString: "00000000-0000-0000-0000-0000000005A2")!
    let sheet = LearnedRuleDraftSheet.duplicateRule(
        sourceRuleID: sourceRuleID,
        draft: LearnedRuleDraft(
            merchantPattern: "coffee shop",
            categoryID: categoryID,
            merchantName: "Coffee Shop",
            matchKind: .prefixNormalizedMerchant
        )
    )

    #expect(sheet.mode == .duplicateRule(sourceRuleID: sourceRuleID))
    #expect(sheet.title == "Duplicate Rule")
    #expect(sheet.confirmationTitle == "Save Duplicate")
    #expect(
        sheet.draft == LearnedRuleDraft(
            merchantPattern: "coffee shop",
            categoryID: categoryID,
            merchantName: "Coffee Shop",
            matchKind: .prefixNormalizedMerchant
        )
    )
}

@Test
func learnedRuleDraftSheetSaveValidationAllowsBasicAndAdvancedManualMatchKinds() {
    let categoryID = UUID(uuidString: "00000000-0000-0000-0000-0000000005A3")!
    let exactSheet = LearnedRuleDraftSheet.newRule(
        draft: LearnedRuleDraft(
            merchantPattern: "  Coffee Shop  ",
            categoryID: categoryID,
            merchantName: "Coffee Shop",
            matchKind: .exactNormalizedMerchant
        )
    )
    let prefixSheet = LearnedRuleDraftSheet.newRule(
        draft: LearnedRuleDraft(
            merchantPattern: "Coffee",
            categoryID: categoryID,
            merchantName: "Coffee",
            matchKind: .prefixNormalizedMerchant
        )
    )
    let containsSheet = LearnedRuleDraftSheet.newRule(
        draft: LearnedRuleDraft(
            merchantPattern: "Coffee",
            categoryID: categoryID,
            merchantName: "Coffee",
            matchKind: .contains
        )
    )

    #expect(exactSheet.canSave)
    #expect(prefixSheet.canSave)
    #expect(containsSheet.canSave)
}

@Test
func manualRuleAuthoringKeepsContainsBehindAdvancedDisclosureAndOutOfReview() throws {
    let learnedRulesSource = try sourceText(in: "Sources/AlderwiseApp/LearnedRulesManagerView.swift")
    let reviewSource = try sourceText(in: "Sources/AlderwiseApp/ReviewQueueView.swift")

    #expect(learnedRulesSource.contains("DisclosureGroup(\"Advanced\""))
    #expect(learnedRulesSource.contains("manualAuthoringWarningText"))
    #expect(reviewSource.contains("Text(\"Contains\")") == false)
}

@Test
func createLearnedRulePersistsManualDraftAndReturnsManagedRule() throws {
    let categoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000551")!
    let createdAt = Date(timeIntervalSince1970: 1_776_355_340)
    let store = MutableWorkspaceStore()
    let service = WorkspaceService(store: store)

    let createdRule = try service.createLearnedRule(
        LearnedRuleDraft(
            merchantPattern: "  COFFEE SHOP  ",
            categoryID: categoryID,
            merchantName: "Coffee Shop",
            matchKind: .contains
        ),
        createdAt: createdAt
    )

    #expect(createdRule.merchantPattern == "coffee shop")
    #expect(createdRule.categoryID == categoryID)
    #expect(createdRule.merchantName == "Coffee Shop")
    #expect(createdRule.matchKind == .contains)
    #expect(createdRule.createdAt == createdAt)
    #expect(createdRule.isDisabled == false)
    #expect(store.learnedRuleSummaries.map(\.merchantPattern) == ["coffee shop"])
}

@Test
func createLearnedRuleRejectsDraftsWithoutCategory() {
    let store = MutableWorkspaceStore()
    let service = WorkspaceService(store: store)

    #expect(throws: WorkspaceServiceError.learnedRuleCategoryRequired) {
        try service.createLearnedRule(
            LearnedRuleDraft(
                merchantPattern: "coffee shop",
                categoryID: nil,
                merchantName: "Coffee Shop",
                matchKind: .exactNormalizedMerchant
            )
        )
    }
}

@Test
func duplicateLearnedRuleAsDraftCopiesOnlyEditableFields() throws {
    let ruleID = UUID(uuidString: "00000000-0000-0000-0000-000000000552")!
    let categoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000553")!
    let store = MutableWorkspaceStore()
    store.learnedRuleSummaries = [
        LearnedRuleSummary(
            id: ruleID,
            merchantPattern: "coffee shop",
            categoryID: categoryID,
            merchantName: "Coffee Shop",
            matchKind: .prefixNormalizedMerchant,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            lifecycle: .disabled(disabledAt: Date(timeIntervalSince1970: 1_776_355_360))
        )
    ]
    let service = WorkspaceService(store: store)

    let draft = try #require(try service.duplicateLearnedRuleAsDraft(id: ruleID))

    #expect(
        draft == LearnedRuleDraft(
            merchantPattern: "coffee shop",
            categoryID: categoryID,
            merchantName: "Coffee Shop",
            matchKind: .prefixNormalizedMerchant
        )
    )
}

@Test
func previewLearnedRuleImpactReturnsReadyCountsWhenEligible() throws {
    let reviewItemID = UUID(uuidString: "00000000-0000-0000-0000-000000000561")!
    let store = MutableWorkspaceStore()
    store.pendingReviewItems = [
        PendingReviewItem(
            id: reviewItemID,
            type: .lowConfidenceCategory,
            status: .pending,
            reason: nil,
            createdAt: Date(timeIntervalSince1970: 1_776_355_360),
            sourceFile: PendingReviewSourceFile(
                accountID: UUID(uuidString: "00000000-0000-0000-0000-000000000562")!,
                originalFilename: "checking.csv"
            ),
            sourceRow: PendingReviewSourceRow(
                id: 1,
                sourceLineNumber: 2,
                rowHash: "row-1",
                rawPayload: #"["2026-04-03","Coffee Shop","-4.75"]"#
            ),
            duplicateTransactionID: nil,
            classification: PendingReviewClassification(
                normalizedMerchantName: "coffee shop",
                prefill: nil,
                source: nil,
                sourceReference: nil,
                confidence: nil
            )
        )
    ]
    store.previewLearnedRuleImpactResult = LearnedRuleImpactPreview(
        matchedAcceptedTransactionCount: 2,
        matchedPendingReviewItemCount: 1
    )
    let service = WorkspaceService(store: store)

    let preview = try service.previewLearnedRuleImpact(
        reviewItemID: reviewItemID,
        createRuleEnabled: true,
        merchantPattern: "coffee shop",
        matchKind: .exactNormalizedMerchant
    )

    #expect(preview == .ready(LearnedRuleImpactPreview(
        matchedAcceptedTransactionCount: 2,
        matchedPendingReviewItemCount: 1
    )))
    #expect(store.lastPreviewLearnedRuleRequest == PreviewLearnedRuleRequest(
        merchantPattern: "coffee shop",
        matchKind: .exactNormalizedMerchant,
        excludingReviewItemID: reviewItemID
    ))
}

@Test
func previewLearnedRuleImpactReusesExistingCountsForContainsRules() throws {
    let reviewItemID = UUID(uuidString: "00000000-0000-0000-0000-000000000568")!
    let store = MutableWorkspaceStore()
    store.pendingReviewItems = [
        PendingReviewItem(
            id: reviewItemID,
            type: .lowConfidenceCategory,
            status: .pending,
            reason: nil,
            createdAt: Date(timeIntervalSince1970: 1_776_355_460),
            sourceFile: PendingReviewSourceFile(
                accountID: UUID(uuidString: "00000000-0000-0000-0000-000000000569")!,
                originalFilename: "checking.csv"
            ),
            sourceRow: PendingReviewSourceRow(
                id: 1,
                sourceLineNumber: 2,
                rowHash: "row-contains",
                rawPayload: #"["2026-04-03","Daily Coffee","-4.75"]"#
            ),
            duplicateTransactionID: nil,
            classification: PendingReviewClassification(
                normalizedMerchantName: "daily coffee",
                prefill: nil,
                source: nil,
                sourceReference: nil,
                confidence: nil
            )
        )
    ]
    store.previewLearnedRuleImpactResult = LearnedRuleImpactPreview(
        matchedAcceptedTransactionCount: 6,
        matchedPendingReviewItemCount: 2
    )
    let service = WorkspaceService(store: store)

    let preview = try service.previewLearnedRuleImpact(
        reviewItemID: reviewItemID,
        createRuleEnabled: true,
        merchantPattern: "coffee",
        matchKind: .contains
    )

    #expect(preview == .ready(LearnedRuleImpactPreview(
        matchedAcceptedTransactionCount: 6,
        matchedPendingReviewItemCount: 2
    )))
    #expect(store.lastPreviewLearnedRuleRequest == PreviewLearnedRuleRequest(
        merchantPattern: "coffee",
        matchKind: .contains,
        excludingReviewItemID: reviewItemID
    ))
}

@Test
func previewLearnedRuleImpactReturnsNoEligiblePreviewWhenRuleCreationIsDisabled() throws {
    let reviewItemID = UUID(uuidString: "00000000-0000-0000-0000-000000000563")!
    let store = MutableWorkspaceStore()
    let service = WorkspaceService(store: store)

    let preview = try service.previewLearnedRuleImpact(
        reviewItemID: reviewItemID,
        createRuleEnabled: false,
        merchantPattern: "coffee shop",
        matchKind: .exactNormalizedMerchant
    )

    #expect(preview == .noEligiblePreview)
    #expect(store.lastPreviewLearnedRuleRequest == nil)
}

@Test
func previewLearnedRuleImpactReturnsNoEligiblePreviewWhenDraftCannotProduceValidPattern() throws {
    let reviewItemID = UUID(uuidString: "00000000-0000-0000-0000-000000000564")!
    let store = MutableWorkspaceStore()
    store.pendingReviewItems = [
        PendingReviewItem(
            id: reviewItemID,
            type: .lowConfidenceCategory,
            status: .pending,
            reason: nil,
            createdAt: Date(timeIntervalSince1970: 1_776_355_420),
            sourceFile: PendingReviewSourceFile(
                accountID: UUID(uuidString: "00000000-0000-0000-0000-000000000565")!,
                originalFilename: "checking.csv"
            ),
            sourceRow: PendingReviewSourceRow(
                id: 1,
                sourceLineNumber: 2,
                rowHash: "row-1",
                rawPayload: #"["2026-04-03","","-4.75"]"#
            ),
            duplicateTransactionID: nil,
            classification: PendingReviewClassification(
                normalizedMerchantName: "",
                prefill: nil,
                source: nil,
                sourceReference: nil,
                confidence: nil
            )
        )
    ]
    let service = WorkspaceService(store: store)

    let preview = try service.previewLearnedRuleImpact(
        reviewItemID: reviewItemID,
        createRuleEnabled: true,
        merchantPattern: "   ",
        matchKind: .exactNormalizedMerchant
    )

    #expect(preview == .noEligiblePreview)
    #expect(store.lastPreviewLearnedRuleRequest == nil)
}

@Test
func previewLearnedRuleImpactReturnsUnavailableWithoutPreviewReader() throws {
    let service = WorkspaceService(store: DefaultResetBridgeMaintenanceStore())

    let preview = try service.previewLearnedRuleImpact(
        reviewItemID: UUID(uuidString: "00000000-0000-0000-0000-000000000566")!,
        createRuleEnabled: true,
        merchantPattern: "coffee shop",
        matchKind: .exactNormalizedMerchant
    )

    #expect(preview == .unavailable)
}

private func makeTransactionDetail(
    id: UUID,
    decisionSource: ClassificationDecisionSource?,
    decisionSourceReference: String?
) -> TransactionDetail {
    TransactionDetail(
        row: TransactionLedgerRow(
            id: id,
            accountID: UUID(uuidString: "00000000-0000-0000-0000-000000000551")!,
            accountName: "Checking",
            categoryID: nil,
            categoryName: nil,
            rawDescription: "Coffee Shop",
            merchantName: "Coffee Shop",
            amount: Decimal(-4.75),
            transactionDate: Date(timeIntervalSince1970: 1_776_268_800),
            postedDate: nil,
            direction: .expense,
            reviewStatus: .accepted,
            importOrigin: nil
        ),
        notes: nil,
        decisionSource: decisionSource,
        decisionSourceReference: decisionSourceReference,
        confidence: 1,
        duplicateStatus: "unique"
    )
}

private func sourceText(in relativePath: String) throws -> String {
    let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let sourceURL = repoRoot.appendingPathComponent(relativePath)
    return try String(contentsOf: sourceURL, encoding: .utf8)
}
