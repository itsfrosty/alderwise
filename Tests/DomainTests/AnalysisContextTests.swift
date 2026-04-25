import Domain
import Foundation
import Testing

@Test
func analysisContextStoresResolvedSingleDimensionScope() {
    let resolvedInterval = DateInterval(
        start: analysisUTCDate(year: 2026, month: 4, day: 1),
        end: analysisUTCDate(year: 2026, month: 4, day: 25)
    )
    let merchantName = "blue bottle"
    let context = AnalysisContext(
        range: .monthToDate,
        resolvedInterval: resolvedInterval,
        scope: .merchant(merchantName),
        comparison: .previousPeriod,
        metricBasis: .includedVisibleExpenses,
        qualifiers: AnalysisQualifiers(
            visibility: .active,
            reviewStatus: .pending,
            uncategorizedOnly: false,
            recurringOnly: true
        )
    )

    #expect(context.range == .monthToDate)
    #expect(context.resolvedInterval == resolvedInterval)
    #expect(context.scope == .merchant(merchantName))
    #expect(context.comparison == .previousPeriod)
    #expect(context.metricBasis == .includedVisibleExpenses)
    #expect(context.qualifiers.reviewStatus == .pending)
    #expect(context.qualifiers.recurringOnly)
}

@Test
func analysisContextDefaultsToWorkspaceScopeAndActiveVisibility() {
    let context = AnalysisContext()

    #expect(context.range == .monthToDate)
    #expect(context.resolvedInterval == nil)
    #expect(context.scope == .workspace)
    #expect(context.comparison == .none)
    #expect(context.metricBasis == .includedVisibleExpenses)
    #expect(context.qualifiers == AnalysisQualifiers())
}

private func analysisUTCDate(year: Int, month: Int, day: Int) -> Date {
    var components = DateComponents()
    components.calendar = Calendar(identifier: .gregorian)
    components.timeZone = TimeZone(secondsFromGMT: 0)
    components.year = year
    components.month = month
    components.day = day
    return components.date!
}
