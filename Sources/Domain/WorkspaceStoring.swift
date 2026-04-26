import Foundation

public protocol WorkspaceReading: Sendable {
    func fetchSummary() throws -> WorkspaceSummary
    func fetchAccounts() throws -> [Account]
    func fetchManagementAccounts() throws -> [Account]
    func fetchImportEligibleAccounts() throws -> [Account]
    func fetchLedgerFilterAccounts() throws -> [Account]
    func fetchPermanentlyDeletableAccountIDs() throws -> Set<UUID>
    func fetchCategories() throws -> [BudgetCategory]
    func fetchCategoryGroups() throws -> [BudgetCategoryGroup]
}

public protocol AccountWriting: Sendable {
    func createAccount(named: String, kind: AccountKind, institutionName: String?) throws -> Account
    func updateAccount(id: UUID, named: String, kind: AccountKind, institutionName: String?) throws -> Account
    func archiveAccount(id: UUID, archivedAt: Date) throws -> Account
    func restoreAccount(id: UUID) throws -> Account
    func deleteAccountPermanently(id: UUID) throws
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

public struct ImportAccountInferenceEvidenceQuery: Equatable, Sendable {
    public var originalFilename: String
    public var normalizedHeaderNames: [String]
    public var nonBlankColumnIndexesByRow: [[Int]]
    public var profile: CSVImportProfile
    public var bootstrapMapping: CSVColumnMapping?

    public init(
        originalFilename: String,
        normalizedHeaderNames: [String],
        nonBlankColumnIndexesByRow: [[Int]],
        profile: CSVImportProfile,
        bootstrapMapping: CSVColumnMapping?
    ) {
        self.originalFilename = originalFilename
        self.normalizedHeaderNames = normalizedHeaderNames
        self.nonBlankColumnIndexesByRow = nonBlankColumnIndexesByRow
        self.profile = profile
        self.bootstrapMapping = bootstrapMapping
    }
}

public struct ImportAccountInferenceAccountEvidence: Equatable, Sendable {
    public var positiveMatchCount: Int
    public var overrideCount: Int

    public init(
        positiveMatchCount: Int = 0,
        overrideCount: Int = 0
    ) {
        self.positiveMatchCount = positiveMatchCount
        self.overrideCount = overrideCount
    }
}

public protocol ImportAccountInferenceReading: Sendable {
    func fetchImportAccountInferenceEvidence(
        for query: ImportAccountInferenceEvidenceQuery
    ) throws -> [UUID: ImportAccountInferenceAccountEvidence]

    func fetchBootstrapImportAccountInferenceEvidence(
        for query: ImportAccountInferenceEvidenceQuery
    ) throws -> [UUID: Int]
}

public protocol ImportAccountInferenceWriting: Sendable {
    func recordImportAccountInferenceFeedback(
        for query: ImportAccountInferenceEvidenceQuery,
        stagedImportSessionID: Int64?,
        selectedAccountID: UUID,
        suggestedAccountID: UUID?
    ) throws
}

public protocol ReviewQueueReading: Sendable {
    func fetchPendingReviewItems() throws -> [PendingReviewItem]
}

public protocol ReviewQueueWriting: Sendable {
    func keepBothForLikelyDuplicateReviewItem(id: UUID, resolvedAt: Date) throws -> ReviewDecisionEvent
    func approveClassificationReviewItem(
        id: UUID,
        assignment: ClassificationAssignment,
        ruleLearning: ReviewRuleLearningOption?,
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

public protocol AnalysisReportReading: Sendable {
    func fetchOverviewReport(context: AnalysisContext) throws -> OverviewReport
    func fetchCategoryAnalysisReport(context: AnalysisContext) throws -> CategoryAnalysisReport
    func fetchMerchantAnalysisReport(context: AnalysisContext) throws -> MerchantAnalysisReport
}

public protocol WorkspaceInsightReading: Sendable {
    func fetchWorkspaceInsightSummary(referenceDate: Date) throws -> WorkspaceInsightSummary
}

public protocol TargetManagementReading: Sendable {
    func fetchManagedTargets(referenceDate: Date) throws -> [ManagedMonthlyTarget]
}

public protocol TargetWriting: Sendable {
    func createMonthlyTarget(_ draft: MonthlyTargetDraft, createdAt: Date) throws -> MonthlyTarget
    func updateMonthlyTarget(id: UUID, _ draft: MonthlyTargetDraft) throws -> MonthlyTarget
    func deleteMonthlyTarget(id: UUID) throws
}

public typealias TargetManaging = TargetManagementReading & TargetWriting

public protocol TransactionLedgerWriting: Sendable {
    func updateTransactionLedgerFields(id: UUID, draft: TransactionLedgerEditDraft) throws
    func setTransactionHidden(id: UUID, isHidden: Bool) throws
}

public typealias WorkspaceStoring = WorkspaceReading & AccountWriting
