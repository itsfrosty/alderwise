import Application
import Domain
import Foundation
import Testing

@testable import AlderwiseApp

@Test
func analysisToolbarStateRepairsUnavailablePageAgainstAvailableSnapshots() {
    let categoriesSnapshot = AnalysisCategoriesSnapshot(
        context: AnalysisContext(),
        report: CategoryAnalysisReport(context: AnalysisContext(), rows: []),
        targetProgress: []
    )

    let repaired = AnalysisToolbarState(
        selectedPage: .merchants,
        isInspectorVisible: false
    ).repaired(for: AnalysisSnapshot(categories: categoriesSnapshot))

    #expect(repaired.selectedPage == .categories)
    #expect(repaired.isInspectorVisible == false)
}

@Test
@MainActor
func analysisInspectorVisibilityAndPagePersistAcrossTransactionNavigation() {
    let model = WorkspaceShellModel(store: nil, service: nil)

    model.selectAnalysisPage(.merchants)
    model.setAnalysisInspectorVisible(false)
    model.showTransactions(
        filter: TransactionLedgerFilter(
            normalizedMerchantName: "netflix",
            direction: .expense,
            reviewStatuses: Set([.accepted, .pending]),
            visibility: .active
        )
    )

    #expect(model.analysisToolbarState.selectedPage == .merchants)
    #expect(model.analysisToolbarState.isInspectorVisible == false)
    #expect(model.pendingAppSectionNavigation == .transactions)
}

@Test
func merchantInspectorActionVisibilityPreservesMerchantPatternHandoffForMerchantAndRecurringSelections() {
    let merchantSelection = AnalysisMerchantsSelection.merchant(
        MerchantAnalysisRow(
            key: MerchantReportKey(normalizedName: "blue bottle"),
            title: "Blue Bottle",
            currentSpend: Decimal(48),
            comparisonSpend: Decimal(12),
            delta: Decimal(36),
            evidence: InsightEvidence(
                metricBasis: .includedVisibleExpenses,
                resolvedInterval: DateInterval(
                    start: analysisInspectorUTCDate(year: 2026, month: 4, day: 1),
                    end: analysisInspectorUTCDate(year: 2026, month: 4, day: 16)
                ),
                scope: .merchant("blue bottle"),
                reconciliationRule: .exactTransactionSum,
                destination: InsightEvidenceDestination(
                    scope: .merchant("blue bottle"),
                    direction: .expense
                )
            )
        )
    )
    let recurringSelection = AnalysisMerchantsSelection.recurring(
        MerchantRecurringReportRow(
            detail: RecurringChargeInsightDetail(
                accountID: analysisInspectorStateID("00000000-0000-0000-0000-000000001101"),
                normalizedMerchantName: "netflix",
                cadence: .monthly,
                observationCount: 3,
                amountRange: RecurringChargeAmountRange(
                    minimum: Decimal(15.49),
                    maximum: Decimal(15.49)
                ),
                supportingTransactionIDs: [
                    analysisInspectorStateID("00000000-0000-0000-0000-000000001102")
                ],
                firstObservedDate: analysisInspectorUTCDate(year: 2026, month: 2, day: 9),
                lastObservedDate: analysisInspectorUTCDate(year: 2026, month: 4, day: 9),
                nextExpectedDateWindow: nil
            ),
            evidence: InsightEvidence(
                metricBasis: .includedVisibleExpenses,
                resolvedInterval: DateInterval(
                    start: analysisInspectorUTCDate(year: 2026, month: 2, day: 9),
                    end: analysisInspectorUTCDate(year: 2026, month: 4, day: 10)
                ),
                scope: .merchant("netflix"),
                reconciliationRule: .recurringObservationSet,
                destination: InsightEvidenceDestination(
                    scope: .merchant("netflix"),
                    direction: .expense
                )
            )
        )
    )

    #expect(AnalysisMerchantsView.inspectorActions(for: merchantSelection).showsTransactions)
    #expect(AnalysisMerchantsView.inspectorActions(for: merchantSelection).ruleHandoffMerchantName == "blue bottle")
    #expect(AnalysisMerchantsView.inspectorActions(for: recurringSelection).showsTransactions)
    #expect(AnalysisMerchantsView.inspectorActions(for: recurringSelection).ruleHandoffMerchantName == "netflix")
}

private func analysisInspectorUTCDate(year: Int, month: Int, day: Int) -> Date {
    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = day
    components.calendar = analysisInspectorUTCCalendar
    return components.date!
}

private let analysisInspectorUTCCalendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
    return calendar
}()

private func analysisInspectorStateID(_ value: String) -> UUID {
    UUID(uuidString: value)!
}
