import Application
import Domain
import Foundation
import SwiftUI
import Testing

@testable import AlderwiseApp

@Test
func analysisInspectorPlaceholderProvidesInstructionalNoSelectionContent() {
    let placeholder = AnalysisInspectorView<AnalysisOverviewSelection, EmptyView>.placeholderContent(
        description: "Select a trend signal, driver, or support row to inspect its evidence and drill into matching transactions."
    )

    #expect(AnalysisInspectorView<AnalysisOverviewSelection, EmptyView>.showsPlaceholder(for: Optional<AnalysisOverviewSelection>.none))
    #expect(placeholder.title == "Nothing Selected")
    #expect(placeholder.systemImage == "sidebar.right")
    #expect(placeholder.guidance.count == 2)
    #expect(placeholder.guidance.contains("Select a row in the canvas to lock the inspector to that signal."))
    #expect(placeholder.guidance.contains("Use the primary action here to continue into transactions or the next workflow."))
}

@Test
func analysisInspectorEvidenceGroupingSeparatesIntervalAndReconciliationRule() {
    let evidence = InsightEvidence(
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

    let grouping = AnalysisInspectorView<AnalysisMerchantsSelection, EmptyView>.evidenceGrouping(for: evidence)

    #expect(grouping.title == "Evidence")
    #expect(grouping.items.count == 2)
    #expect(grouping.items.map { $0.label } == ["Window", "Reconciled By"])
    #expect(grouping.items.map { $0.value } == ["Apr 1, 2026 – Apr 16, 2026", "Exact transaction sum"])
}

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
@MainActor
func analysisInspectorSelectionDoesNotRevealInspectorWhenCommittedWhileHidden() {
    let model = WorkspaceShellModel(store: nil, service: nil)
    let selection = AnalysisOverviewSelection.driver(
        AnalysisSpendRow(
            title: "Dining",
            scope: .category(analysisInspectorStateID("00000000-0000-0000-0000-000000001090")),
            currentSpend: Decimal(180),
            comparisonSpend: Decimal(40),
            delta: Decimal(140),
            evidence: InsightEvidence(
                metricBasis: .includedVisibleExpenses,
                resolvedInterval: DateInterval(
                    start: analysisInspectorUTCDate(year: 2026, month: 4, day: 1),
                    end: analysisInspectorUTCDate(year: 2026, month: 4, day: 16)
                ),
                scope: .category(analysisInspectorStateID("00000000-0000-0000-0000-000000001090")),
                reconciliationRule: .exactTransactionSum,
                destination: InsightEvidenceDestination(
                    scope: .category(analysisInspectorStateID("00000000-0000-0000-0000-000000001090")),
                    direction: .expense
                )
            )
        )
    )

    model.setAnalysisInspectorVisible(false)
    model.setAnalysisOverviewSelection(selection)

    #expect(model.analysisOverviewSelection == selection)
    #expect(model.analysisToolbarState.isInspectorVisible == false)
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

@Test
func analysisInspectorPageSpecificActionVisibilityMatchesEachPageWorkflow() {
    let overviewSelection = AnalysisOverviewSelection.driver(
        AnalysisSpendRow(
            title: "Dining",
            scope: .category(analysisInspectorStateID("00000000-0000-0000-0000-000000001120")),
            currentSpend: Decimal(180),
            comparisonSpend: Decimal(40),
            delta: Decimal(140),
            evidence: InsightEvidence(
                metricBasis: .includedVisibleExpenses,
                resolvedInterval: DateInterval(
                    start: analysisInspectorUTCDate(year: 2026, month: 4, day: 1),
                    end: analysisInspectorUTCDate(year: 2026, month: 4, day: 16)
                ),
                scope: .category(analysisInspectorStateID("00000000-0000-0000-0000-000000001120")),
                reconciliationRule: .exactTransactionSum,
                destination: InsightEvidenceDestination(
                    scope: .category(analysisInspectorStateID("00000000-0000-0000-0000-000000001120")),
                    direction: .expense
                )
            )
        )
    )
    let categoriesSelection = AnalysisCategoriesSelection.row(
        AnalysisSpendRow(
            title: "Food",
            scope: .category(analysisInspectorStateID("00000000-0000-0000-0000-000000001121")),
            currentSpend: Decimal(320),
            comparisonSpend: Decimal(260),
            delta: Decimal(60),
            evidence: InsightEvidence(
                metricBasis: .includedVisibleExpenses,
                resolvedInterval: DateInterval(
                    start: analysisInspectorUTCDate(year: 2026, month: 4, day: 1),
                    end: analysisInspectorUTCDate(year: 2026, month: 4, day: 16)
                ),
                scope: .category(analysisInspectorStateID("00000000-0000-0000-0000-000000001121")),
                reconciliationRule: .exactTransactionSum,
                destination: InsightEvidenceDestination(
                    scope: .category(analysisInspectorStateID("00000000-0000-0000-0000-000000001121")),
                    direction: .expense
                )
            )
        )
    )
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
    let targetID = analysisInspectorStateID("00000000-0000-0000-0000-000000001122")
    let categoriesSnapshot = AnalysisCategoriesSnapshot(
        context: AnalysisContext(),
        report: CategoryAnalysisReport(context: AnalysisContext(), rows: [categoriesSelection.row]),
        targetProgress: [
            TargetProgress(
                id: targetID,
                name: "Food Budget",
                scope: .category(analysisInspectorStateID("00000000-0000-0000-0000-000000001121")),
                monthlyLimit: Decimal(500),
                spent: Decimal(320),
                remaining: Decimal(180),
                paceDelta: Decimal(20)
            )
        ]
    )

    let overviewLayout = AnalysisOverviewView.inspectorActionLayout(for: overviewSelection)
    let categoriesWithTargetLayout = AnalysisCategoriesView.inspectorActionLayout(
        for: categoriesSelection,
        snapshot: categoriesSnapshot
    )
    let categoriesWithoutTargetLayout = AnalysisCategoriesView.inspectorActionLayout(
        for: categoriesSelection,
        snapshot: AnalysisCategoriesSnapshot(
            context: AnalysisContext(),
            report: CategoryAnalysisReport(context: AnalysisContext(), rows: [categoriesSelection.row]),
            targetProgress: []
        )
    )
    let merchantsLayout = AnalysisMerchantsView.inspectorActionLayout(for: merchantSelection)

    #expect(overviewLayout.primaryActionTitle == "Show Transactions")
    #expect(overviewLayout.secondaryActionTitles.isEmpty)
    #expect(categoriesWithTargetLayout.primaryActionTitle == "Show Transactions")
    #expect(categoriesWithTargetLayout.secondaryActionTitles == ["Open Target"])
    #expect(categoriesWithoutTargetLayout.secondaryActionTitles.isEmpty)
    #expect(merchantsLayout.primaryActionTitle == "Show Transactions")
    #expect(merchantsLayout.secondaryActionTitles == ["Open Rules"])
}

@Test
@MainActor
func analysisInspectorRetainsCommittedSelectionAfterDrilldownAndReturn() {
    let model = WorkspaceShellModel(store: nil, service: nil)
    let selection = AnalysisMerchantsSelection.merchant(
        MerchantAnalysisRow(
            key: MerchantReportKey(normalizedName: "blue bottle"),
            title: "blue bottle",
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

    model.showAnalysis(page: .merchants)
    model.setAnalysisMerchantsSelection(selection)
    model.showAnalysisTransactions(filter: TransactionLedgerFilter(
        normalizedMerchantName: "blue bottle",
        direction: .expense,
        reviewStatuses: Set([.accepted, .pending]),
        visibility: .active
    ))
    model.showAnalysis(page: .merchants)

    #expect(model.analysisMerchantsSelection == selection)
    #expect(model.pendingAppSectionNavigation == .analysis)
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

private extension AnalysisCategoriesSelection {
    var row: AnalysisSpendRow {
        switch self {
        case .row(let row):
            return row
        }
    }
}
