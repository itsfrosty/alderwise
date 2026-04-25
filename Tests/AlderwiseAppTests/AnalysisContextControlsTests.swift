import Application
import Domain
import SwiftUI
import Testing

@testable import AlderwiseApp

@Test
func analysisContextControlsExposeOnlyTheSupportedRangeAndComparisonOptions() {
    #expect(AnalysisContextControls.supportedRanges == [
        .monthToDate,
        .lastFullMonth,
        .yearToDate,
    ])
    #expect(AnalysisContextControls.supportedComparisons == [
        .previousPeriod,
        .samePeriodLastYear,
        .none,
    ])
}

@Test
func analysisContextControlsBindSelectionsThroughAnalysisContext() {
    var context = AnalysisContext(
        range: .lastFullMonth,
        comparison: .samePeriodLastYear
    )
    let rangeBinding = AnalysisContextControls.rangeSelection(
        getContext: { context },
        setRange: { context.range = $0 }
    )
    let comparisonBinding = AnalysisContextControls.comparisonSelection(
        getContext: { context },
        setComparison: { context.comparison = $0 }
    )

    #expect(rangeBinding.wrappedValue == .lastFullMonth)
    #expect(comparisonBinding.wrappedValue == .samePeriodLastYear)

    rangeBinding.wrappedValue = .yearToDate
    comparisonBinding.wrappedValue = .none

    #expect(context.range == .yearToDate)
    #expect(context.comparison == .none)
}

@Test
func analysisContextControlsDoNotExposeDeferredControls() {
    #expect(AnalysisContextControls.supportedRanges.contains(.custom) == false)
    #expect(AnalysisContextControls.supportedComparisons.contains(.rollingAverage3Months) == false)
    #expect(AnalysisContextControls.supportedComparisons.contains(.rollingAverage12Months) == false)
    #expect(AnalysisContextControls.supportsInteractiveScope == false)
    #expect(AnalysisContextControls.supportsAdvancedQualifiers == false)
}

@Test
func analysisContextControlsShowTheReadOnlyScopeLabelForTheVisiblePageOnly() {
    let categoriesContext = AnalysisContext(
        range: .monthToDate,
        scope: .workspace,
        comparison: .previousPeriod,
        metricBasis: .acceptedExpenses
    )
    let snapshot = AnalysisSnapshot(
        overview: AnalysisOverviewSnapshot(
            context: AnalysisContext(
                range: .monthToDate,
                scope: .workspace,
                comparison: .previousPeriod,
                metricBasis: .includedVisibleExpenses
            ),
            report: OverviewReport(
                context: AnalysisContext(),
                currentSpend: Decimal(120),
                comparisonSpend: Decimal(80),
                drivers: [],
                recurring: []
            ),
            monthlyReport: .empty,
            projectedInsights: []
        ),
        categories: AnalysisCategoriesSnapshot(
            context: categoriesContext,
            report: CategoryAnalysisReport(context: categoriesContext, rows: []),
            targetProgress: []
        )
    )

    #expect(
        AnalysisContextControls.scopeLabel(
            for: .overview,
            snapshot: snapshot,
            fallbackContext: AnalysisContext()
        ) == "All visible spending"
    )
    #expect(
        AnalysisContextControls.scopeLabel(
            for: .categories,
            snapshot: snapshot,
            fallbackContext: AnalysisContext()
        ) == "Accepted spending"
    )
    #expect(
        AnalysisContextControls.scopeLabel(
            for: .merchants,
            snapshot: snapshot,
            fallbackContext: AnalysisContext()
        ) == nil
    )
}
