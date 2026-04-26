import Application
import Domain
import Foundation
import Testing

@testable import AlderwiseApp

@Test
@MainActor
func analysisShellStartsWithoutCommittedSelectionOnPageOpen() {
    let model = WorkspaceShellModel(store: nil, service: nil)

    model.showAnalysis(page: .overview)

    #expect(model.analysisToolbarState.selectedPage == .overview)
    #expect(model.analysisOverviewSelection == nil)
    #expect(model.analysisCategoriesSelection == nil)
    #expect(model.analysisMerchantsSelection == nil)
}

@Test
@MainActor
func analysisShellKeepsInspectorHiddenWithCommittedSelectionAcrossWideAndNarrowWidths() {
    let model = WorkspaceShellModel(store: nil, service: nil)
    let selection = AnalysisOverviewSelection.driver(
        AnalysisSpendRow(
            title: "Dining",
            scope: .category(analysisShellContractID("00000000-0000-0000-0000-000000001301")),
            currentSpend: Decimal(180),
            comparisonSpend: Decimal(40),
            delta: Decimal(140),
            evidence: InsightEvidence(
                metricBasis: .includedVisibleExpenses,
                resolvedInterval: DateInterval(
                    start: analysisShellContractUTCDate(year: 2026, month: 4, day: 1),
                    end: analysisShellContractUTCDate(year: 2026, month: 4, day: 16)
                ),
                scope: .category(analysisShellContractID("00000000-0000-0000-0000-000000001301")),
                reconciliationRule: .exactTransactionSum,
                destination: InsightEvidenceDestination(
                    scope: .category(analysisShellContractID("00000000-0000-0000-0000-000000001301")),
                    direction: .expense
                )
            )
        )
    )

    model.setAnalysisInspectorVisible(false)
    model.setAnalysisOverviewSelection(selection)

    let wide = AnalysisInspectorPresentation.resolve(
        isRequested: model.analysisToolbarState.isInspectorVisible,
        availableWidth: AnalysisView.persistentInspectorMinimumWidth + 1
    )
    let narrow = AnalysisInspectorPresentation.resolve(
        isRequested: model.analysisToolbarState.isInspectorVisible,
        availableWidth: AnalysisView.persistentInspectorMinimumWidth
    )

    #expect(model.analysisOverviewSelection == selection)
    #expect(model.analysisToolbarState.isInspectorVisible == false)
    #expect(wide == .hidden)
    #expect(narrow == .hidden)
    #expect(narrow.shouldPresentTransientInspector(hasSelection: true) == false)
}

@Test
@MainActor
func analysisShellTransientDismissalKeepsSelectionAndPageSwitchPreservesInspectorState() {
    let model = WorkspaceShellModel(store: nil, service: nil)
    let categoriesSelection = AnalysisCategoriesSelection.row(
        AnalysisSpendRow(
            title: "Food",
            scope: .category(analysisShellContractID("00000000-0000-0000-0000-000000001302")),
            currentSpend: Decimal(320),
            comparisonSpend: Decimal(260),
            delta: Decimal(60),
            evidence: InsightEvidence(
                metricBasis: .includedVisibleExpenses,
                resolvedInterval: DateInterval(
                    start: analysisShellContractUTCDate(year: 2026, month: 4, day: 1),
                    end: analysisShellContractUTCDate(year: 2026, month: 4, day: 16)
                ),
                scope: .category(analysisShellContractID("00000000-0000-0000-0000-000000001302")),
                reconciliationRule: .exactTransactionSum,
                destination: InsightEvidenceDestination(
                    scope: .category(analysisShellContractID("00000000-0000-0000-0000-000000001302")),
                    direction: .expense
                )
            )
        )
    )

    model.showAnalysis(page: .categories)
    model.setAnalysisCategoriesSelection(categoriesSelection)
    model.setAnalysisInspectorVisible(true)
    let dismissInspector = AnalysisView.dismissTransientInspector(
        setInspectorVisible: model.setAnalysisInspectorVisible
    )
    dismissInspector()
    model.selectAnalysisPage(.merchants)
    model.selectAnalysisPage(.categories)

    #expect(model.analysisCategoriesSelection == categoriesSelection)
    #expect(model.analysisToolbarState.selectedPage == .categories)
    #expect(model.analysisToolbarState.isInspectorVisible == false)
}

@Test
func analysisShellWidthTransitionKeepsInspectorOwnershipWithSelectionAlreadyCommitted() {
    let persistent = AnalysisInspectorPresentation.resolve(
        isRequested: true,
        availableWidth: AnalysisView.persistentInspectorMinimumWidth + 1
    )
    let transient = AnalysisInspectorPresentation.resolve(
        isRequested: true,
        availableWidth: AnalysisView.persistentInspectorMinimumWidth
    )
    let hiddenWide = AnalysisInspectorPresentation.resolve(
        isRequested: false,
        availableWidth: AnalysisView.persistentInspectorMinimumWidth + 1
    )
    let hiddenNarrow = AnalysisInspectorPresentation.resolve(
        isRequested: false,
        availableWidth: AnalysisView.persistentInspectorMinimumWidth
    )

    #expect(persistent == .persistent)
    #expect(transient == .transient)
    #expect(hiddenWide == .hidden)
    #expect(hiddenNarrow == .hidden)
    #expect(transient.shouldPresentTransientInspector(hasSelection: false))
    #expect(transient.shouldPresentTransientInspector(hasSelection: true))
}

@Test
func analysisShellPageChromeRemainsReadOnlyMetadataWhileToolbarOwnsInteractions() {
    #expect(AnalysisContextControls.supportsInteractiveScope == false)
    #expect(AnalysisContextControls.supportsAdvancedQualifiers == false)
    #expect(AnalysisContextControls.supportedRanges == [.monthToDate, .lastFullMonth, .yearToDate])
    #expect(AnalysisContextControls.supportedComparisons == [.previousPeriod, .samePeriodLastYear, .none])
}

private func analysisShellContractUTCDate(year: Int, month: Int, day: Int) -> Date {
    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = day
    components.calendar = analysisShellContractUTCCalendar
    return components.date!
}

private let analysisShellContractUTCCalendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
    return calendar
}()

private func analysisShellContractID(_ value: String) -> UUID {
    UUID(uuidString: value)!
}
