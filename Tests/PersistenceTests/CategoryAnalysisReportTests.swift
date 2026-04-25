import Domain
import Foundation
import Persistence
import Testing

@Test
func categoryAnalysisReportReconcilesCategoryGroupRowToLedgerSlice() throws {
    let databaseURL = try homeDashboardTemporaryDatabaseURL()
    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()

    let account = try store.createAccount(named: "Checking", kind: .checking, institutionName: "Local Bank")
    let groceries = UUID(uuidString: "00000000-0000-0000-0000-000000000921")!
    let dining = UUID(uuidString: "00000000-0000-0000-0000-000000000922")!
    let food = UUID(uuidString: "00000000-0000-0000-0000-000000000923")!
    try homeDashboardInsertCategoryGroup(databaseURL: databaseURL, id: food, name: "Food")
    try homeDashboardInsertCategory(databaseURL: databaseURL, id: groceries, name: "Groceries", kind: "expense", categoryGroupID: food)
    try homeDashboardInsertCategory(databaseURL: databaseURL, id: dining, name: "Dining", kind: "expense", categoryGroupID: food)

    try homeDashboardInsertAcceptedExpense(
        databaseURL: databaseURL,
        accountID: account.id,
        categoryID: groceries,
        amount: Decimal(-50),
        transactionDate: homeDashboardUTCDate(year: 2026, month: 4, day: 5)
    )
    try homeDashboardInsertPendingExpense(
        databaseURL: databaseURL,
        accountID: account.id,
        categoryID: dining,
        amount: Decimal(-25),
        transactionDate: homeDashboardUTCDate(year: 2026, month: 4, day: 8)
    )

    let context = AnalysisContext(
        range: .monthToDate,
        referenceDate: homeDashboardUTCDate(year: 2026, month: 4, day: 15),
        scope: .workspace,
        comparison: .none,
        metricBasis: .includedVisibleExpenses
    )

    let report = try store.fetchCategoryAnalysisReport(context: context)
    let row = try #require(report.rows.first(where: { $0.title == "Food" }))
    let filter = ledgerFilter(for: row.evidence)
    let ledger = try store.fetchTransactionLedger(filter: filter)

    #expect(row.currentSpend == Decimal(75))
    #expect(ledgerExpenseTotal(ledger) == row.currentSpend)
}

@Test
func categoryAnalysisReportCapturesComparisonDeltaForCategoryGroupContribution() throws {
    let databaseURL = try homeDashboardTemporaryDatabaseURL()
    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()

    let account = try store.createAccount(named: "Checking", kind: .checking, institutionName: "Local Bank")
    let groceries = UUID(uuidString: "00000000-0000-0000-0000-000000000931")!
    let dining = UUID(uuidString: "00000000-0000-0000-0000-000000000932")!
    let food = UUID(uuidString: "00000000-0000-0000-0000-000000000933")!
    try homeDashboardInsertCategoryGroup(databaseURL: databaseURL, id: food, name: "Food")
    try homeDashboardInsertCategory(databaseURL: databaseURL, id: groceries, name: "Groceries", kind: "expense", categoryGroupID: food)
    try homeDashboardInsertCategory(databaseURL: databaseURL, id: dining, name: "Dining", kind: "expense", categoryGroupID: food)

    try homeDashboardInsertAcceptedExpense(
        databaseURL: databaseURL,
        accountID: account.id,
        categoryID: groceries,
        amount: Decimal(-80),
        transactionDate: homeDashboardUTCDate(year: 2026, month: 4, day: 3)
    )
    try homeDashboardInsertAcceptedExpense(
        databaseURL: databaseURL,
        accountID: account.id,
        categoryID: dining,
        amount: Decimal(-20),
        transactionDate: homeDashboardUTCDate(year: 2026, month: 4, day: 6)
    )
    try homeDashboardInsertAcceptedExpense(
        databaseURL: databaseURL,
        accountID: account.id,
        categoryID: groceries,
        amount: Decimal(-25),
        transactionDate: homeDashboardUTCDate(year: 2026, month: 3, day: 3)
    )

    let context = AnalysisContext(
        range: .monthToDate,
        referenceDate: homeDashboardUTCDate(year: 2026, month: 4, day: 15),
        scope: .workspace,
        comparison: .previousPeriod,
        metricBasis: .includedVisibleExpenses
    )

    let report = try store.fetchCategoryAnalysisReport(context: context)
    let row = try #require(report.rows.first(where: { $0.title == "Food" }))

    #expect(row.currentSpend == Decimal(100))
    #expect(row.comparisonSpend == Decimal(25))
    #expect(row.delta == Decimal(75))
}

private func ledgerExpenseTotal(_ rows: [TransactionLedgerRow]) -> Decimal {
    rows.reduce(Decimal.zero) { partialResult, row in
        partialResult + abs(row.amount)
    }
}

private func ledgerFilter(for evidence: InsightEvidence) -> TransactionLedgerFilter {
    TransactionLedgerFilter(
        startDate: evidence.resolvedInterval.start,
        endDate: Calendar(identifier: .gregorian).date(byAdding: .second, value: -1, to: evidence.resolvedInterval.end),
        categoryGroupID: {
            if case .categoryGroup(let id) = evidence.destination.scope {
                return id
            }
            return nil
        }(),
        direction: .expense,
        reviewStatuses: Set([.accepted, .pending]),
        visibility: .active
    )
}
