import Domain
import Foundation
import Persistence
import Testing

@Test
func overviewReportReconcilesDriverEvidenceToLedgerSlice() throws {
    let databaseURL = try homeDashboardTemporaryDatabaseURL()
    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()

    let account = try store.createAccount(named: "Checking", kind: .checking, institutionName: "Local Bank")
    let groceries = UUID(uuidString: "00000000-0000-0000-0000-000000000911")!
    let travel = UUID(uuidString: "00000000-0000-0000-0000-000000000912")!
    let food = UUID(uuidString: "00000000-0000-0000-0000-000000000913")!
    try homeDashboardInsertCategoryGroup(databaseURL: databaseURL, id: food, name: "Food")
    try homeDashboardInsertCategory(databaseURL: databaseURL, id: groceries, name: "Groceries", kind: "expense", categoryGroupID: food)
    try homeDashboardInsertCategory(databaseURL: databaseURL, id: travel, name: "Travel", kind: "expense")

    try homeDashboardInsertAcceptedExpense(
        databaseURL: databaseURL,
        accountID: account.id,
        categoryID: groceries,
        amount: Decimal(-60),
        transactionDate: homeDashboardUTCDate(year: 2026, month: 4, day: 5)
    )
    try homeDashboardInsertPendingExpense(
        databaseURL: databaseURL,
        accountID: account.id,
        categoryID: groceries,
        amount: Decimal(-20),
        transactionDate: homeDashboardUTCDate(year: 2026, month: 4, day: 10)
    )
    try homeDashboardInsertAcceptedExpense(
        databaseURL: databaseURL,
        accountID: account.id,
        categoryID: travel,
        amount: Decimal(-30),
        transactionDate: homeDashboardUTCDate(year: 2026, month: 4, day: 11)
    )
    try homeDashboardInsertAcceptedExpense(
        databaseURL: databaseURL,
        accountID: account.id,
        categoryID: groceries,
        amount: Decimal(-10),
        transactionDate: homeDashboardUTCDate(year: 2026, month: 3, day: 5)
    )

    let context = AnalysisContext(
        range: .monthToDate,
        referenceDate: homeDashboardUTCDate(year: 2026, month: 4, day: 15),
        scope: .workspace,
        comparison: .previousPeriod,
        metricBasis: .includedVisibleExpenses
    )

    let report = try store.fetchOverviewReport(context: context)
    let driver = try #require(report.drivers.first(where: { $0.title == "Food" }))
    let filter = ledgerFilter(for: driver.evidence)
    let ledger = try store.fetchTransactionLedger(filter: filter)

    #expect(report.currentSpend == Decimal(110))
    #expect(report.comparisonSpend == Decimal(10))
    #expect(driver.currentSpend == Decimal(80))
    #expect(driver.comparisonSpend == Decimal(10))
    #expect(ledgerExpenseTotal(ledger) == driver.currentSpend)
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
