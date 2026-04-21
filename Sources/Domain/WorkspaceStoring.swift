import Foundation

public protocol WorkspaceReading: Sendable {
    func fetchSummary() throws -> WorkspaceSummary
    func fetchAccounts() throws -> [Account]
    func fetchCategories() throws -> [BudgetCategory]
    func fetchCategoryGroups() throws -> [BudgetCategoryGroup]
}

public protocol AccountWriting: Sendable {
    func createAccount(named: String, kind: AccountKind, institutionName: String?) throws -> Account
}

public protocol StagedImportWriting: Sendable {
    func createStagedImportSession(_ draft: StagedImportSessionDraft) throws -> StagedImportSession
}

public protocol StagedImportReading: Sendable {
    func fetchStagedImportSession(id: Int64) throws -> StagedImportSession?
}

public protocol ImportDecisionReading: Sendable {
    func fetchExistingSourceRowHashes(accountID: UUID, rowHashes: Set<String>) throws -> Set<String>
    func fetchExistingSourceRowHashCounts(accountID: UUID, rowHashes: Set<String>) throws -> [String: Int]
    func fetchLikelyDuplicateTransactions(
        accountID: UUID,
        candidates: [NormalizedImportCandidate]
    ) throws -> [LikelyDuplicateCandidate]
}

public protocol ReviewQueueReading: Sendable {
    func fetchPendingReviewItems() throws -> [PendingReviewItem]
}

public protocol ReviewQueueWriting: Sendable {
    func keepBothForLikelyDuplicateReviewItem(id: UUID, resolvedAt: Date) throws -> ReviewDecisionEvent
    func approveClassificationReviewItem(
        id: UUID,
        assignment: ClassificationAssignment,
        createRule: Bool,
        resolvedAt: Date
    ) throws -> ReviewDecisionEvent
}

public protocol ReviewDecisionReading: Sendable {
    func fetchReviewDecisionEvents(reviewItemID: UUID) throws -> [ReviewDecisionEvent]
}

public protocol ClassificationRuleReading: Sendable {
    func fetchClassificationRules() throws -> [ClassificationRule]
}

public protocol TransactionLedgerReading: Sendable {
    func fetchTransactionLedger(filter: TransactionLedgerFilter) throws -> [TransactionLedgerRow]
    func fetchTransactionDetail(id: UUID) throws -> TransactionDetail?
    func fetchTransactionImportOrigins() throws -> [TransactionImportOrigin]
}

public protocol ReportingReading: Sendable {
    func fetchMonthlyReport(referenceDate: Date) throws -> MonthlyReport
}

public protocol TargetWriting: Sendable {
    func createMonthlyTarget(_ draft: MonthlyTargetDraft, createdAt: Date) throws -> MonthlyTarget
}

public protocol TransactionLedgerWriting: Sendable {
    func updateTransactionLedgerFields(id: UUID, draft: TransactionLedgerEditDraft) throws
}

public typealias WorkspaceStoring = WorkspaceReading & AccountWriting
