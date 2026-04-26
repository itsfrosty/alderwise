import Application
import Domain
import Foundation
import Testing

@testable import AlderwiseApp

@Test
func overviewInspectorContentUsesTypedSections() {
    let selection = AnalysisOverviewSelection.driver(
        AnalysisSpendRow(
            title: "Dining",
            scope: .category(analysisInspectorContentID("00000000-0000-0000-0000-000000002101")),
            currentSpend: Decimal(180),
            comparisonSpend: Decimal(120),
            delta: Decimal(60),
            evidence: analysisInspectorContentEvidence(
                scope: .category(analysisInspectorContentID("00000000-0000-0000-0000-000000002101"))
            )
        )
    )

    let content = AnalysisOverviewView.inspectorContent(for: selection)

    #expect(content.sections.map(\.kind) == [.summary, .evidenceKV, .metricRow, .bulletList])
}

@Test
func categoriesInspectorContentIncludesTargetTagsWhenLinkedTargetExists() {
    let categoryID = analysisInspectorContentID("00000000-0000-0000-0000-000000002102")
    let scope = InsightEvidenceScope.category(categoryID)
    let row = AnalysisSpendRow(
        title: "Food",
        scope: scope,
        currentSpend: Decimal(220),
        comparisonSpend: Decimal(160),
        delta: Decimal(60),
        evidence: analysisInspectorContentEvidence(scope: scope)
    )
    let selection = AnalysisCategoriesSelection.row(row)
    let snapshot = AnalysisCategoriesSnapshot(
        context: AnalysisContext(),
        report: CategoryAnalysisReport(context: AnalysisContext(), rows: [row]),
        targetProgress: [
            TargetProgress(
                id: analysisInspectorContentID("00000000-0000-0000-0000-000000002103"),
                name: "Food Target",
                scope: .category(categoryID),
                monthlyLimit: Decimal(400),
                spent: Decimal(220),
                remaining: Decimal(180),
                paceDelta: Decimal(-15)
            )
        ]
    )

    let content = AnalysisCategoriesView.inspectorContent(for: selection, snapshot: snapshot)

    #expect(content.sections.map(\.kind).contains(.tagList))
}

@Test
func categoriesInspectorContentUsesNextStepBulletsWithoutLinkedTarget() {
    let categoryID = analysisInspectorContentID("00000000-0000-0000-0000-000000002106")
    let scope = InsightEvidenceScope.category(categoryID)
    let row = AnalysisSpendRow(
        title: "Food",
        scope: scope,
        currentSpend: Decimal(220),
        comparisonSpend: Decimal(160),
        delta: Decimal(60),
        evidence: analysisInspectorContentEvidence(scope: scope)
    )
    let selection = AnalysisCategoriesSelection.row(row)
    let snapshot = AnalysisCategoriesSnapshot(
        context: AnalysisContext(),
        report: CategoryAnalysisReport(context: AnalysisContext(), rows: [row]),
        targetProgress: []
    )

    let content = AnalysisCategoriesView.inspectorContent(for: selection, snapshot: snapshot)

    #expect(content.sections.map(\.kind).contains(.bulletList))
    #expect(content.sections.map(\.kind).contains(.tagList) == false)
}

@Test
func merchantsInspectorContentUsesTypedSectionsForRecurringSelections() {
    let selection = AnalysisMerchantsSelection.recurring(
        MerchantRecurringReportRow(
            detail: RecurringChargeInsightDetail(
                accountID: analysisInspectorContentID("00000000-0000-0000-0000-000000002104"),
                normalizedMerchantName: "netflix",
                cadence: .monthly,
                observationCount: 3,
                amountRange: RecurringChargeAmountRange(minimum: Decimal(15.49), maximum: Decimal(15.49)),
                supportingTransactionIDs: [analysisInspectorContentID("00000000-0000-0000-0000-000000002105")],
                firstObservedDate: analysisInspectorContentUTCDate(year: 2026, month: 2, day: 9),
                lastObservedDate: analysisInspectorContentUTCDate(year: 2026, month: 4, day: 9),
                nextExpectedDateWindow: nil
            ),
            evidence: analysisInspectorContentEvidence(scope: .merchant("netflix"))
        )
    )

    let content = AnalysisMerchantsView.inspectorContent(for: selection)

    #expect(content.sections.map(\.kind) == [.summary, .evidenceKV, .metricRow, .tagList])
}

@Test
func merchantsInspectorContentUsesTypedSectionsForMerchantSelections() {
    let selection = AnalysisMerchantsSelection.merchant(
        MerchantAnalysisRow(
            key: MerchantReportKey(normalizedName: "blue bottle"),
            title: "Blue Bottle",
            currentSpend: Decimal(84),
            comparisonSpend: Decimal(36),
            delta: Decimal(48),
            evidence: analysisInspectorContentEvidence(scope: .merchant("blue bottle"))
        )
    )

    let content = AnalysisMerchantsView.inspectorContent(for: selection)

    #expect(content.sections.map(\.kind) == [.summary, .evidenceKV, .metricRow, .tagList])
}

private func analysisInspectorContentEvidence(scope: InsightEvidenceScope) -> InsightEvidence {
    InsightEvidence(
        metricBasis: .includedVisibleExpenses,
        resolvedInterval: DateInterval(
            start: analysisInspectorContentUTCDate(year: 2026, month: 4, day: 1),
            end: analysisInspectorContentUTCDate(year: 2026, month: 4, day: 15)
        ),
        scope: scope,
        reconciliationRule: .exactTransactionSum,
        destination: InsightEvidenceDestination(
            scope: scope,
            direction: .expense
        )
    )
}

private func analysisInspectorContentUTCDate(year: Int, month: Int, day: Int) -> Date {
    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = day
    components.calendar = analysisInspectorContentUTCCalendar
    return components.date!
}

private let analysisInspectorContentUTCCalendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
    return calendar
}()

private func analysisInspectorContentID(_ value: String) -> UUID {
    UUID(uuidString: value)!
}
