import Domain
import Foundation
import Persistence
import Testing

@Test
func merchantAnalysisReportReconcilesMerchantRowEvidenceToLedgerSlice() throws {
    let databaseURL = try homeDashboardTemporaryDatabaseURL()
    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()

    let account = try store.createAccount(named: "Checking", kind: .checking, institutionName: "Local Bank")

    _ = try homeDashboardInsertExpense(
        databaseURL: databaseURL,
        accountID: account.id,
        categoryID: nil,
        amount: Decimal(-15),
        transactionDate: homeDashboardUTCDate(year: 2026, month: 1, day: 9),
        reviewStatus: "accepted",
        rawDescription: "Netflix",
        normalizedMerchantName: "netflix"
    )
    _ = try homeDashboardInsertExpense(
        databaseURL: databaseURL,
        accountID: account.id,
        categoryID: nil,
        amount: Decimal(-15),
        transactionDate: homeDashboardUTCDate(year: 2026, month: 2, day: 9),
        reviewStatus: "pending",
        rawDescription: "Netflix",
        normalizedMerchantName: "netflix"
    )
    _ = try homeDashboardInsertExpense(
        databaseURL: databaseURL,
        accountID: account.id,
        categoryID: nil,
        amount: Decimal(-15),
        transactionDate: homeDashboardUTCDate(year: 2026, month: 3, day: 9),
        reviewStatus: "accepted",
        rawDescription: "Netflix",
        normalizedMerchantName: "netflix"
    )
    _ = try homeDashboardInsertExpense(
        databaseURL: databaseURL,
        accountID: account.id,
        categoryID: nil,
        amount: Decimal(-8),
        transactionDate: homeDashboardUTCDate(year: 2026, month: 4, day: 10),
        reviewStatus: "accepted",
        rawDescription: "Blue Bottle",
        normalizedMerchantName: "blue bottle"
    )

    let context = AnalysisContext(
        range: .monthToDate,
        referenceDate: homeDashboardUTCDate(year: 2026, month: 4, day: 15),
        scope: .workspace,
        comparison: .none,
        metricBasis: .includedVisibleExpenses
    )

    let report = try store.fetchMerchantAnalysisReport(context: context)
    let merchant = try #require(report.merchants.first(where: { $0.title == "blue bottle" }))
    let merchantFilter = ledgerFilter(for: merchant.evidence)
    let merchantLedger = try store.fetchTransactionLedger(filter: merchantFilter)
    #expect(merchant.currentSpend == Decimal(8))
    #expect(merchant.key == MerchantReportKey(normalizedName: "blue bottle"))
    #expect(ledgerExpenseTotal(merchantLedger) == merchant.currentSpend)
    #expect(report.recurring.isEmpty)
}

@Test
func merchantAnalysisReportUsesNormalizedMerchantKeyAsStableV1Identity() throws {
    let databaseURL = try homeDashboardTemporaryDatabaseURL()
    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()

    let account = try store.createAccount(named: "Checking", kind: .checking, institutionName: "Local Bank")

    _ = try homeDashboardInsertExpense(
        databaseURL: databaseURL,
        accountID: account.id,
        categoryID: nil,
        amount: Decimal(-12),
        transactionDate: homeDashboardUTCDate(year: 2026, month: 4, day: 2),
        reviewStatus: "accepted",
        rawDescription: "Blue Bottle Coffee",
        normalizedMerchantName: "blue bottle"
    )
    _ = try homeDashboardInsertExpense(
        databaseURL: databaseURL,
        accountID: account.id,
        categoryID: nil,
        amount: Decimal(-18),
        transactionDate: homeDashboardUTCDate(year: 2026, month: 4, day: 7),
        reviewStatus: "pending",
        rawDescription: "BLUE BOTTLE",
        normalizedMerchantName: "blue bottle"
    )

    let context = AnalysisContext(
        range: .monthToDate,
        referenceDate: homeDashboardUTCDate(year: 2026, month: 4, day: 15),
        scope: .workspace,
        comparison: .none,
        metricBasis: .includedVisibleExpenses
    )

    let report = try store.fetchMerchantAnalysisReport(context: context)

    #expect(report.merchants.count == 1)
    #expect(report.merchants.first?.key == MerchantReportKey(normalizedName: "blue bottle"))
    #expect(report.merchants.first?.currentSpend == Decimal(30))
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
        normalizedMerchantName: {
            if case .merchant(let merchantName) = evidence.destination.scope {
                return merchantName
            }
            return nil
        }(),
        direction: .expense,
        reviewStatuses: Set<TransactionReviewStatus>([.accepted, .pending]),
        visibility: .active
    )
}
