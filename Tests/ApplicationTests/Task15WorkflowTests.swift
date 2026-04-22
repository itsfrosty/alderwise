import Application
import Domain
import Foundation
import Persistence
import Testing

@Test
func firstRunWorkflowLoadsHomeReadyEmptySnapshot() throws {
    let service = try task15Service()

    let snapshot = try service.loadSnapshot()

    #expect(snapshot.summary.accountCount == 0)
    #expect(snapshot.summary.transactionCount == 0)
    #expect(snapshot.summary.reviewCount == 0)
    #expect(snapshot.summary.targetCount == 0)
    #expect(snapshot.accounts.isEmpty)
    #expect(snapshot.transactions.isEmpty)
    #expect(snapshot.pendingReviewItems.isEmpty)
    #expect(snapshot.monthlyReport.currentMonthAcceptedSpend == 0)
    #expect(snapshot.categories.isEmpty == false)
    #expect(snapshot.categoryGroups.isEmpty == false)
}

@Test
func importWorkflowStagesRowsIntoLedger() throws {
    let service = try task15Service()
    let account = try service.createAccount(named: "Checking", kind: .checking, institutionName: "Local Bank")
    let csv = """
    Date,Description,Amount
    2026-04-01,Coffee Shop,-4.75
    2026-04-02,Payroll,1250.00
    """

    let result = try task15Stage(csv: csv, account: account, service: service)
    let snapshot = try service.loadSnapshot()

    #expect(result.summary.importedRowCount == 2)
    #expect(result.summary.skippedRowCount == 0)
    #expect(snapshot.summary.transactionCount == 2)
    #expect(snapshot.transactions.map(\.importOrigin?.originalFilename).allSatisfy { $0 == "checking.csv" })
}

@Test
func reviewCompletionWorkflowLearnsRuleForLaterImports() throws {
    let service = try task15Service()
    let account = try service.createAccount(named: "Checking", kind: .checking, institutionName: "Local Bank")
    let category = try #require(try service.loadSnapshot().categories.first { $0.kind == .expense })
    let firstCSV = """
    Date,Description,Amount
    2026-04-01,SQ Coffee Stand,-4.75
    """
    _ = try task15Stage(csv: firstCSV, account: account, service: service)
    let reviewItem = try #require(try service.loadSnapshot().pendingReviewItems.first)

    try service.approveClassificationReviewItem(
        id: reviewItem.id,
        assignment: ClassificationAssignment(categoryID: category.id, merchantName: "Coffee Stand"),
        ruleLearning: .exactNormalizedMerchant(pattern: "sq coffee stand"),
        resolvedAt: Date(timeIntervalSince1970: 1_775_171_260)
    )
    let afterApproval = try service.loadSnapshot()

    let secondCSV = """
    Date,Description,Amount
    2026-04-03,SQ Coffee Stand,-5.25
    """
    _ = try task15Stage(csv: secondCSV, account: account, service: service)
    let afterSecondImport = try service.loadSnapshot()

    #expect(afterApproval.pendingReviewItems.isEmpty)
    #expect(afterSecondImport.pendingReviewItems.isEmpty)
    #expect(afterSecondImport.transactions.filter { $0.reviewStatus == .accepted }.count == 2)
}

@Test
func transactionDetailWorkflowRoundTripsEditableFieldsAndProvenance() throws {
    let service = try task15Service()
    let account = try service.createAccount(named: "Checking", kind: .checking, institutionName: "Local Bank")
    let category = try #require(try service.loadSnapshot().categories.first { $0.kind == .expense })
    let csv = """
    Date,Description,Amount
    2026-04-01,Taco Shop,-12.50
    """
    _ = try task15Stage(csv: csv, account: account, service: service)
    let transaction = try #require(try service.loadSnapshot().transactions.first)

    try service.updateTransactionLedgerFields(
        id: transaction.id,
        draft: TransactionLedgerEditDraft(
            merchantName: "Neighborhood Tacos",
            categoryID: category.id,
            notes: "weekly lunch"
        )
    )
    let detail = try #require(try service.loadTransactionDetail(id: transaction.id))

    #expect(detail.row.merchantName == "Neighborhood Tacos")
    #expect(detail.row.categoryID == category.id)
    #expect(detail.notes == "weekly lunch")
    #expect(detail.row.reviewStatus == .accepted)
    #expect(detail.importOrigin?.originalFilename == "checking.csv")
}

@Test
func targetCreationWorkflowUpdatesSnapshotAndAcceptedExpenseProgress() throws {
    let service = try task15Service()
    let account = try service.createAccount(named: "Checking", kind: .checking, institutionName: "Local Bank")
    let category = try #require(try service.loadSnapshot().categories.first { $0.kind == .expense })
    let csv = """
    Date,Description,Amount
    2026-04-01,Market,-40.00
    2026-04-02,Unreviewed Shop,-90.00
    """
    _ = try task15Stage(csv: csv, account: account, service: service)
    let firstTransaction = try #require(try service.loadSnapshot().transactions.first { $0.rawDescription == "Market" })
    try service.updateTransactionLedgerFields(
        id: firstTransaction.id,
        draft: TransactionLedgerEditDraft(
            merchantName: "Market",
            categoryID: category.id,
            notes: nil
        )
    )

    let target = try service.createMonthlyTarget(
        MonthlyTargetDraft(scope: .category(category.id), monthlyLimit: Decimal(100)),
        createdAt: Date(timeIntervalSince1970: 1_775_171_260)
    )
    let snapshot = try service.loadSnapshot()

    #expect(snapshot.summary.targetCount == 1)
    #expect(snapshot.monthlyReport.targets.map(\.id) == [target.id])
    #expect(snapshot.monthlyReport.targets.map(\.spent) == [Decimal(40)])
    #expect(snapshot.monthlyReport.targets.map(\.remaining) == [Decimal(60)])
}

@Test
func targetManagementWorkflowSupportsEditDeleteAndHomeSelection() throws {
    let service = try task15Service()
    let account = try service.createAccount(named: "Checking", kind: .checking, institutionName: "Local Bank")
    let snapshot = try service.loadSnapshot()
    let category = try #require(snapshot.categories.first { $0.kind == .expense })
    let categoryGroup = try #require(snapshot.categoryGroups.first)
    let csv = """
    Date,Description,Amount
    2026-04-01,Market,-40.00
    """
    _ = try task15Stage(csv: csv, account: account, service: service)
    let reviewItem = try #require(try service.loadSnapshot().pendingReviewItems.first)
    try service.approveClassificationReviewItem(
        id: reviewItem.id,
        assignment: ClassificationAssignment(categoryID: category.id, merchantName: "Market"),
        ruleLearning: nil,
        resolvedAt: Date(timeIntervalSince1970: 1_775_171_260)
    )

    let created = try service.createMonthlyTarget(
        MonthlyTargetDraft(scope: .category(category.id), monthlyLimit: Decimal(100)),
        createdAt: Date(timeIntervalSince1970: 1_775_171_260)
    )
    try service.updateMonthlyTarget(
        id: created.id,
        MonthlyTargetDraft(scope: .categoryGroup(categoryGroup.id), monthlyLimit: Decimal(20))
    )

    let updatedTargets = try service.fetchManagedTargets(referenceDate: Date(timeIntervalSince1970: 1_775_171_200))
    let refreshedSnapshot = try service.loadSnapshot()

    #expect(updatedTargets.map(\.id) == [created.id])
    #expect(updatedTargets.map(\.scope) == [.categoryGroup(categoryGroup.id)])
    #expect(refreshedSnapshot.homeDashboard?.primaryAction?.destination == .targets(created.id))

    try service.deleteMonthlyTarget(id: created.id)

    #expect(try service.fetchManagedTargets(referenceDate: Date(timeIntervalSince1970: 1_775_171_200)).isEmpty)
    #expect(try service.loadSnapshot().monthlyReport.targets.isEmpty)
}

func workspaceSnapshotIncludesComputedHomeDashboard() throws {
    let service = try task15Service()
    let account = try service.createAccount(named: "Checking", kind: .checking, institutionName: "Local Bank")
    let category = try #require(try service.loadSnapshot().categories.first { $0.kind == .expense })
    let csv = """
    Date,Description,Amount
    2026-04-01,Market,-40.00
    """
    _ = try task15Stage(csv: csv, account: account, service: service)
    let transaction = try #require(try service.loadSnapshot().transactions.first)
    try service.updateTransactionLedgerFields(
        id: transaction.id,
        draft: TransactionLedgerEditDraft(
            merchantName: "Market",
            categoryID: category.id,
            notes: nil
        )
    )

    let snapshot = try service.loadSnapshot()

    #expect(snapshot.homeDashboard != nil)
    #expect(snapshot.homeDashboard?.hero.amount == Decimal(40))
    #expect(snapshot.homeDashboard?.primaryAction?.title == "Finish 1 items in Review")
    #expect(snapshot.homeDashboard?.primaryAction?.destination == .review)
}

@Test
func importResultMessageReportsDistinctImportedSkippedReviewAndDuplicateCounts() {
    let summary = StagedImportDecisionSummary(
        importedRowCount: 1,
        skippedRowCount: 2,
        pendingClassificationReviewRowCount: 3,
        flaggedDuplicateRowCount: 4
    )

    #expect(
        ImportResultMessage.make(for: .staged, summary: summary)
            == "1 imported to Transactions, 2 skipped, 3 sent to Review, 4 likely duplicates waiting in Review."
    )
    #expect(
        ImportResultMessage.make(for: .exactReimportNoOp, summary: summary)
            == "2 rows already imported. No changes made."
    )
}

private func task15Service() throws -> WorkspaceService {
    let store = try WorkspaceStore.at(databaseURL: task15TemporaryDatabaseURL())
    try store.bootstrap()
    return WorkspaceService(store: store)
}

private func task15Stage(csv: String, account: Account, service: WorkspaceService) throws -> StagedCSVImportResult {
    try service.stageCSVImport(
        preview: CSVImportPreviewService().makePreview(from: csv),
        account: account,
        originalFilename: "checking.csv",
        csvText: csv,
        importedAt: Date(timeIntervalSince1970: 1_775_171_200)
    )
}

private func task15TemporaryDatabaseURL() throws -> URL {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory.appending(path: "workspace.sqlite")
}
