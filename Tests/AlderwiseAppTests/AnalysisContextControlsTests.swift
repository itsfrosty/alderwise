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

    #expect(rangeBinding.wrappedValue == .some(.lastFullMonth))
    #expect(comparisonBinding.wrappedValue == .some(.samePeriodLastYear))

    rangeBinding.wrappedValue = .yearToDate
    comparisonBinding.wrappedValue = .some(.none)

    #expect(context.range == .yearToDate)
    #expect(context.comparison == .none)
}

@Test
func analysisContextControlsDoNotExposeDeferredControls() {
    #expect(AnalysisContextControls.RangeOption.allCases == AnalysisContextControls.supportedRanges)
    #expect(AnalysisContextControls.ComparisonOption.allCases == AnalysisContextControls.supportedComparisons)
    #expect(AnalysisContextControls.supportsInteractiveScope == false)
    #expect(AnalysisContextControls.supportsAdvancedQualifiers == false)
}

@Test
func analysisContextControlsKeepToolbarOwnershipBoundedToRangeAndCompare() {
    #expect(AnalysisContextControls.supportedRanges.isEmpty == false)
    #expect(AnalysisContextControls.supportedComparisons.isEmpty == false)
    #expect(AnalysisContextControls.supportsInteractiveScope == false)
    #expect(AnalysisContextControls.supportsAdvancedQualifiers == false)
}

@Test
func analysisContextControlsDoNotCoerceUnsupportedSourceOfTruthValues() {
    let rangeBinding = AnalysisContextControls.rangeSelection(
        getContext: {
            AnalysisContext(
                range: .custom(
                    DateInterval(
                        start: Date(timeIntervalSince1970: 0),
                        end: Date(timeIntervalSince1970: 60)
                    )
                )
            )
        },
        setRange: { _ in }
    )
    let comparisonBinding = AnalysisContextControls.comparisonSelection(
        getContext: {
            AnalysisContext(
                comparison: .rollingAverage(months: 3)
            )
        },
        setComparison: { _ in }
    )

    #expect(rangeBinding.wrappedValue == nil)
    #expect(comparisonBinding.wrappedValue == nil)
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
            snapshot: snapshot
        ) == "All visible spending"
    )
    #expect(
        AnalysisContextControls.scopeLabel(
            for: .categories,
            snapshot: snapshot
        ) == "Accepted spending"
    )
    #expect(
        AnalysisContextControls.scopeLabel(
            for: .merchants,
            snapshot: snapshot
        ) == nil
    )
    #expect(
        AnalysisContextControls.metricBasisLabel(
            for: .overview,
            snapshot: snapshot
        ) == "All visible spending"
    )
    #expect(
        AnalysisContextControls.metricBasisLabel(
            for: .categories,
            snapshot: snapshot
        ) == "Accepted spending"
    )
}
