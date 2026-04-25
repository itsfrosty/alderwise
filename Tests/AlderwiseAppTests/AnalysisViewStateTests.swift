import Application
import Domain
import Foundation
import Testing

@testable import AlderwiseApp

@Test
@MainActor
func analysisOverviewStartsWithoutSelectionWhenPresented() {
    let model = WorkspaceShellModel(store: nil, service: nil)

    model.presentAnalysisOverview()

    #expect(model.isPresentingAnalysisOverview)
    #expect(model.analysisOverviewSelection == nil)
}

@Test
@MainActor
func analysisOverviewCommitsSelectionWithoutDismissingPresentation() {
    let model = WorkspaceShellModel(store: nil, service: nil)
    let selection = AnalysisOverviewSelection.driver(
        AnalysisSpendRow(
            title: "Dining",
            scope: .category(analysisViewStateID("00000000-0000-0000-0000-000000000401")),
            currentSpend: Decimal(180),
            comparisonSpend: Decimal(40),
            delta: Decimal(140),
            evidence: InsightEvidence(
                metricBasis: .includedVisibleExpenses,
                resolvedInterval: DateInterval(
                    start: analysisViewStateUTCDate(year: 2026, month: 4, day: 1),
                    end: analysisViewStateUTCDate(year: 2026, month: 4, day: 16)
                ),
                scope: .category(analysisViewStateID("00000000-0000-0000-0000-000000000401")),
                reconciliationRule: .exactTransactionSum,
                destination: InsightEvidenceDestination(
                    scope: .category(analysisViewStateID("00000000-0000-0000-0000-000000000401")),
                    direction: .expense
                )
            )
        )
    )

    model.presentAnalysisOverview()
    model.setAnalysisOverviewSelection(selection)

    #expect(model.isPresentingAnalysisOverview)
    #expect(model.analysisOverviewSelection == selection)
}

@Test
@MainActor
func analysisOverviewSelectionSurvivesTransactionDrilldownAndReopen() {
    let model = WorkspaceShellModel(store: nil, service: nil)
    let selection = AnalysisOverviewSelection.recurring(
        MerchantRecurringReportRow(
            detail: RecurringChargeInsightDetail(
                accountID: analysisViewStateID("00000000-0000-0000-0000-000000000501"),
                normalizedMerchantName: "netflix",
                cadence: .monthly,
                observationCount: 3,
                amountRange: RecurringChargeAmountRange(minimum: Decimal(15.49), maximum: Decimal(15.49)),
                supportingTransactionIDs: [
                    analysisViewStateID("00000000-0000-0000-0000-000000000511"),
                    analysisViewStateID("00000000-0000-0000-0000-000000000512"),
                    analysisViewStateID("00000000-0000-0000-0000-000000000513"),
                ],
                firstObservedDate: analysisViewStateUTCDate(year: 2026, month: 2, day: 9),
                lastObservedDate: analysisViewStateUTCDate(year: 2026, month: 4, day: 9),
                nextExpectedDateWindow: nil
            ),
            evidence: InsightEvidence(
                metricBasis: .includedVisibleExpenses,
                resolvedInterval: DateInterval(
                    start: analysisViewStateUTCDate(year: 2026, month: 2, day: 9),
                    end: analysisViewStateUTCDate(year: 2026, month: 4, day: 10)
                ),
                scope: .merchant("netflix"),
                reconciliationRule: .recurringObservationSet,
                destination: InsightEvidenceDestination(scope: .merchant("netflix"), direction: .expense)
            )
        )
    )

    model.presentAnalysisOverview()
    model.setAnalysisOverviewSelection(selection)
    model.showTransactions(
        filter: TransactionLedgerFilter(
            normalizedMerchantName: "netflix",
            direction: .expense,
            reviewStatuses: Set([.accepted, .pending]),
            visibility: .active
        )
    )
    model.dismissAnalysisOverview()
    model.presentAnalysisOverview()

    #expect(model.pendingAppSectionNavigation == .transactions)
    #expect(model.isPresentingAnalysisOverview)
    #expect(model.analysisOverviewSelection == selection)
}

private func analysisViewStateUTCDate(year: Int, month: Int, day: Int) -> Date {
    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = day
    components.calendar = analysisViewStateUTCCalendar
    return components.date!
}

private let analysisViewStateUTCCalendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
    return calendar
}()

private func analysisViewStateID(_ value: String) -> UUID {
    UUID(uuidString: value)!
}
