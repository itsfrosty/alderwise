import Application
import Domain
import Foundation
import Testing

@Test
func analysisDrilldownTranslatorBuildsIncludedVisibleCategoryGroupFilter() {
    let interval = DateInterval(
        start: analysisUTCDate(year: 2026, month: 4, day: 1),
        end: analysisUTCDate(year: 2026, month: 4, day: 16)
    )
    let categoryGroupID = UUID(uuidString: "00000000-0000-0000-0000-000000000901")!
    let context = AnalysisContext(
        range: .monthToDate,
        referenceDate: analysisUTCDate(year: 2026, month: 4, day: 15),
        resolvedInterval: interval,
        scope: .workspace,
        comparison: .previousPeriod,
        metricBasis: .includedVisibleExpenses
    )
    let evidence = InsightEvidence(
        metricBasis: .includedVisibleExpenses,
        resolvedInterval: interval,
        scope: .categoryGroup(categoryGroupID),
        reconciliationRule: .exactTransactionSum,
        destination: InsightEvidenceDestination(scope: .categoryGroup(categoryGroupID))
    )

    let filter = AnalysisDrilldownTranslator.translate(context: context, evidence: evidence)

    #expect(filter == TransactionLedgerFilter(
        startDate: interval.start,
        endDate: analysisUTCDate(year: 2026, month: 4, day: 15, hour: 23, minute: 59, second: 59),
        categoryID: nil,
        categoryGroupID: categoryGroupID,
        direction: .expense,
        reviewStatuses: Set([.accepted, .pending]),
        visibility: .active
    ))
}

@Test
func analysisDrilldownTranslatorHonorsExplicitPendingQualifierOverMetricBasis() {
    let interval = DateInterval(
        start: analysisUTCDate(year: 2026, month: 4, day: 1),
        end: analysisUTCDate(year: 2026, month: 4, day: 16)
    )
    let context = AnalysisContext(
        range: .monthToDate,
        referenceDate: analysisUTCDate(year: 2026, month: 4, day: 15),
        resolvedInterval: interval,
        scope: .workspace,
        comparison: .none,
        metricBasis: .includedVisibleExpenses,
        qualifiers: AnalysisQualifiers(reviewStatus: .pending)
    )
    let evidence = InsightEvidence(
        metricBasis: .includedVisibleExpenses,
        resolvedInterval: interval,
        scope: .merchant("netflix"),
        reconciliationRule: .exactTransactionSum,
        destination: InsightEvidenceDestination(scope: .merchant("netflix"))
    )

    let filter = AnalysisDrilldownTranslator.translate(context: context, evidence: evidence)

    #expect(filter.normalizedMerchantName == "netflix")
    #expect(filter.reviewStatuses == Set([.pending]))
    #expect(filter.visibility == .active)
}

@Test
func analysisDrilldownTranslatorBuildsRecurringMerchantFilter() {
    let interval = DateInterval(
        start: analysisUTCDate(year: 2026, month: 2, day: 9),
        end: analysisUTCDate(year: 2026, month: 4, day: 10)
    )
    let context = AnalysisContext(
        range: .custom(interval),
        referenceDate: analysisUTCDate(year: 2026, month: 4, day: 15),
        resolvedInterval: interval,
        scope: .workspace,
        comparison: .none,
        metricBasis: .includedVisibleExpenses
    )
    let evidence = InsightEvidence(
        metricBasis: .includedVisibleExpenses,
        resolvedInterval: interval,
        scope: .merchant("netflix"),
        reconciliationRule: .recurringObservationSet,
        destination: InsightEvidenceDestination(scope: .merchant("netflix"))
    )

    let filter = AnalysisDrilldownTranslator.translate(context: context, evidence: evidence)

    #expect(filter.normalizedMerchantName == "netflix")
    #expect(filter.direction == .expense)
    #expect(filter.reviewStatuses == Set([.accepted, .pending]))
    #expect(filter.startDate == interval.start)
}

@Test
func analysisDrilldownTranslatorPreservesParentScopedAccountWhenEvidenceNarrowsWithinIt() {
    let interval = DateInterval(
        start: analysisUTCDate(year: 2026, month: 4, day: 1),
        end: analysisUTCDate(year: 2026, month: 4, day: 16)
    )
    let accountID = UUID(uuidString: "00000000-0000-0000-0000-000000000902")!
    let categoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000903")!
    let context = AnalysisContext(
        range: .monthToDate,
        referenceDate: analysisUTCDate(year: 2026, month: 4, day: 15),
        resolvedInterval: interval,
        scope: .account(accountID),
        comparison: .previousPeriod,
        metricBasis: .includedVisibleExpenses
    )
    let evidence = InsightEvidence(
        metricBasis: .includedVisibleExpenses,
        resolvedInterval: interval,
        scope: .category(categoryID),
        reconciliationRule: .exactTransactionSum,
        destination: InsightEvidenceDestination(scope: .category(categoryID))
    )

    let filter = AnalysisDrilldownTranslator.translate(context: context, evidence: evidence)

    #expect(filter.accountID == accountID)
    #expect(filter.categoryID == categoryID)
    #expect(filter.reviewStatuses == Set([.accepted, .pending]))
}

private func analysisUTCDate(
    year: Int,
    month: Int,
    day: Int,
    hour: Int = 0,
    minute: Int = 0,
    second: Int = 0
) -> Date {
    var components = DateComponents()
    components.calendar = Calendar(identifier: .gregorian)
    components.timeZone = TimeZone(secondsFromGMT: 0)
    components.year = year
    components.month = month
    components.day = day
    components.hour = hour
    components.minute = minute
    components.second = second
    return components.date!
}
