import Application
import Domain
import Foundation
import Testing

@testable import AlderwiseApp

@Test
func analysisScreenStateRetainsSelectionAcrossSortOnlyCategoryChanges() {
    let selectedRow = analysisScreenCategoriesRow(
        title: "Food",
        scope: .category(analysisScreenStateID("00000000-0000-0000-0000-000000000901")),
        currentSpend: Decimal(240),
        comparisonSpend: Decimal(150)
    )
    let updatedSelectedRow = analysisScreenCategoriesRow(
        title: "Food",
        scope: .category(analysisScreenStateID("00000000-0000-0000-0000-000000000901")),
        currentSpend: Decimal(260),
        comparisonSpend: Decimal(150)
    )
    let otherRow = analysisScreenCategoriesRow(
        title: "Travel",
        scope: .category(analysisScreenStateID("00000000-0000-0000-0000-000000000902")),
        currentSpend: Decimal(120),
        comparisonSpend: Decimal(80)
    )
    var state = AnalysisScreenState()

    state.categories.sort = .largestDelta
    state.setCategoriesSelection(.row(selectedRow))
    state.repairSelections(for: AnalysisSnapshot(
        categories: AnalysisCategoriesSnapshot(
            context: AnalysisContext(),
            report: CategoryAnalysisReport(
                context: AnalysisContext(),
                rows: [otherRow, updatedSelectedRow]
            ),
            targetProgress: []
        )
    ))

    #expect(state.categories.sort == .largestDelta)
    #expect(state.categories.selection == .row(updatedSelectedRow))
}

@Test
func analysisScreenStateClearsSelectionWhenTheEntityDisappears() {
    var state = AnalysisScreenState()

    state.setMerchantsSelection(.merchant(
        analysisScreenMerchantRow(
            name: "Blue Bottle",
            normalizedName: "blue bottle",
            currentSpend: Decimal(120),
            comparisonSpend: Decimal(40)
        )
    ))
    state.repairSelections(for: AnalysisSnapshot(
        merchants: AnalysisMerchantsSnapshot(
            context: AnalysisContext(),
            report: MerchantAnalysisReport(
                context: AnalysisContext(),
                merchants: [
                    analysisScreenMerchantRow(
                        name: "Netflix",
                        normalizedName: "netflix",
                        currentSpend: Decimal(30),
                        comparisonSpend: Decimal(15)
                    )
                ],
                recurring: []
            )
        )
    ))

    #expect(state.merchants.selection == nil)
}

@Test
func analysisScreenStateRetainsPageLocalSelectionWhenChangingFamilies() {
    var state = AnalysisScreenState()
    let categoriesSelection = AnalysisCategoriesSelection.row(
        analysisScreenCategoriesRow(
            title: "Food",
            scope: .category(analysisScreenStateID("00000000-0000-0000-0000-000000000903")),
            currentSpend: Decimal(240),
            comparisonSpend: Decimal(150)
        )
    )
    let merchantsSelection = AnalysisMerchantsSelection.merchant(
        analysisScreenMerchantRow(
            name: "Blue Bottle",
            normalizedName: "blue bottle",
            currentSpend: Decimal(90),
            comparisonSpend: Decimal(40)
        )
    )

    state.setCategoriesSelection(categoriesSelection)
    state.prepareForPageChange(from: .categories, to: .merchants)
    state.setMerchantsSelection(merchantsSelection)
    state.prepareForPageChange(from: .merchants, to: .categories)

    #expect(state.categories.selection == categoriesSelection)
    #expect(state.merchants.selection == merchantsSelection)
}

@Test
func analysisScreenSortStateRemainsWindowLocal() {
    var leftWindowState = AnalysisScreenState()
    var rightWindowState = AnalysisScreenState()

    leftWindowState.categories.sort = .largestCurrentSpend
    rightWindowState.categories.sort = .largestDelta
    leftWindowState.merchants.sort = .largestCurrentSpend
    rightWindowState.merchants.sort = .alphabetical

    #expect(leftWindowState.categories.sort == .largestCurrentSpend)
    #expect(rightWindowState.categories.sort == .largestDelta)
    #expect(leftWindowState.merchants.sort == .largestCurrentSpend)
    #expect(rightWindowState.merchants.sort == .alphabetical)
}

private func analysisScreenCategoriesRow(
    title: String,
    scope: InsightEvidenceScope,
    currentSpend: Decimal,
    comparisonSpend: Decimal
) -> AnalysisSpendRow {
    AnalysisSpendRow(
        title: title,
        scope: scope,
        currentSpend: currentSpend,
        comparisonSpend: comparisonSpend,
        delta: currentSpend - comparisonSpend,
        evidence: InsightEvidence(
            metricBasis: .includedVisibleExpenses,
            resolvedInterval: DateInterval(
                start: analysisScreenStateUTCDate(year: 2026, month: 4, day: 1),
                end: analysisScreenStateUTCDate(year: 2026, month: 4, day: 16)
            ),
            scope: scope,
            reconciliationRule: .exactTransactionSum,
            destination: InsightEvidenceDestination(
                scope: scope,
                direction: .expense
            )
        )
    )
}

private func analysisScreenMerchantRow(
    name: String,
    normalizedName: String,
    currentSpend: Decimal,
    comparisonSpend: Decimal
) -> MerchantAnalysisRow {
    MerchantAnalysisRow(
        key: MerchantReportKey(normalizedName: normalizedName),
        title: name,
        currentSpend: currentSpend,
        comparisonSpend: comparisonSpend,
        delta: currentSpend - comparisonSpend,
        evidence: InsightEvidence(
            metricBasis: .includedVisibleExpenses,
            resolvedInterval: DateInterval(
                start: analysisScreenStateUTCDate(year: 2026, month: 4, day: 1),
                end: analysisScreenStateUTCDate(year: 2026, month: 4, day: 16)
            ),
            scope: .merchant(normalizedName),
            reconciliationRule: .exactTransactionSum,
            destination: InsightEvidenceDestination(
                scope: .merchant(normalizedName),
                direction: .expense
            )
        )
    )
}

private func analysisScreenStateUTCDate(year: Int, month: Int, day: Int) -> Date {
    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = day
    components.calendar = analysisScreenStateUTCCalendar
    return components.date!
}

private let analysisScreenStateUTCCalendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
    return calendar
}()

private func analysisScreenStateID(_ value: String) -> UUID {
    UUID(uuidString: value)!
}
