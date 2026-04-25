import Application
import Domain
import Foundation
import Testing

@testable import AlderwiseApp

@Test
func categoriesPageDefaultsToLargestCurrentSpend() {
    let food = analysisEntityCategoriesRow(
        title: "Food",
        scope: .category(analysisEntityPageStateID("00000000-0000-0000-0000-000000001001")),
        currentSpend: Decimal(320),
        comparisonSpend: Decimal(200)
    )
    let travel = analysisEntityCategoriesRow(
        title: "Travel",
        scope: .category(analysisEntityPageStateID("00000000-0000-0000-0000-000000001002")),
        currentSpend: Decimal(140),
        comparisonSpend: Decimal(40)
    )
    let state = AnalysisScreenState.CategoriesState()

    #expect(state.sort == .largestCurrentSpend)
    #expect(state.sortedRows(in: analysisEntityCategoriesSnapshot(rows: [travel, food])).map(\.scope) == [
        food.scope,
        travel.scope,
    ])
}

@Test
func categoriesPageSwitchesSortWithoutClearingSelectionWhenTheEntityStillExists() {
    let food = analysisEntityCategoriesRow(
        title: "Food",
        scope: .category(analysisEntityPageStateID("00000000-0000-0000-0000-000000001011")),
        currentSpend: Decimal(320),
        comparisonSpend: Decimal(250)
    )
    let travel = analysisEntityCategoriesRow(
        title: "Travel",
        scope: .category(analysisEntityPageStateID("00000000-0000-0000-0000-000000001012")),
        currentSpend: Decimal(180),
        comparisonSpend: Decimal(40)
    )
    var state = AnalysisScreenState.CategoriesState()

    state.selection = .row(food)
    state.sort = .largestDelta

    #expect(state.selection == .row(food))
    #expect(state.sortedRows(in: analysisEntityCategoriesSnapshot(rows: [food, travel])).map(\.scope) == [
        travel.scope,
        food.scope,
    ])
}

@Test
func categoriesPageSelectionRepairsWhenTheEntityStillExistsAfterSnapshotChanges() {
    let selectedScope = analysisEntityPageStateID("00000000-0000-0000-0000-000000001021")
    let initialSelectedRow = analysisEntityCategoriesRow(
        title: "Food",
        scope: .category(selectedScope),
        currentSpend: Decimal(180),
        comparisonSpend: Decimal(120)
    )
    let updatedSelectedRow = analysisEntityCategoriesRow(
        title: "Food",
        scope: .category(selectedScope),
        currentSpend: Decimal(260),
        comparisonSpend: Decimal(120)
    )
    let otherRow = analysisEntityCategoriesRow(
        title: "Travel",
        scope: .category(analysisEntityPageStateID("00000000-0000-0000-0000-000000001022")),
        currentSpend: Decimal(210),
        comparisonSpend: Decimal(40)
    )
    var state = AnalysisScreenState()

    state.setCategoriesSelection(.row(initialSelectedRow))
    state.repairSelections(for: AnalysisSnapshot(
        categories: analysisEntityCategoriesSnapshot(rows: [otherRow, updatedSelectedRow])
    ))

    #expect(state.categories.selection == .row(updatedSelectedRow))
}

@Test
func categoriesPageClearsSelectionWhenTheEntityDisappears() {
    let selectedRow = analysisEntityCategoriesRow(
        title: "Food",
        scope: .category(analysisEntityPageStateID("00000000-0000-0000-0000-000000001031")),
        currentSpend: Decimal(180),
        comparisonSpend: Decimal(120)
    )
    let otherRow = analysisEntityCategoriesRow(
        title: "Travel",
        scope: .category(analysisEntityPageStateID("00000000-0000-0000-0000-000000001032")),
        currentSpend: Decimal(210),
        comparisonSpend: Decimal(40)
    )
    var state = AnalysisScreenState()

    state.setCategoriesSelection(.row(selectedRow))
    state.repairSelections(for: AnalysisSnapshot(
        categories: analysisEntityCategoriesSnapshot(rows: [otherRow])
    ))

    #expect(state.categories.selection == nil)
}

@Test
func categoriesPageTargetHandoffFollowsTheSelectedRowInsteadOfTheSortedPosition() {
    let firstRow = analysisEntityCategoriesRow(
        title: "Travel",
        scope: .category(analysisEntityPageStateID("00000000-0000-0000-0000-000000001041")),
        currentSpend: Decimal(320),
        comparisonSpend: Decimal(300)
    )
    let selectedRow = analysisEntityCategoriesRow(
        title: "Food",
        scope: .category(analysisEntityPageStateID("00000000-0000-0000-0000-000000001042")),
        currentSpend: Decimal(180),
        comparisonSpend: Decimal(20)
    )
    let firstTarget = analysisEntityTargetProgress(
        id: analysisEntityPageStateID("00000000-0000-0000-0000-000000001051"),
        name: "Travel Budget",
        scope: .category(analysisEntityPageStateID("00000000-0000-0000-0000-000000001041"))
    )
    let selectedTarget = analysisEntityTargetProgress(
        id: analysisEntityPageStateID("00000000-0000-0000-0000-000000001052"),
        name: "Food Budget",
        scope: .category(analysisEntityPageStateID("00000000-0000-0000-0000-000000001042"))
    )
    var state = AnalysisScreenState.CategoriesState()

    state.sort = .largestDelta
    state.selection = .row(selectedRow)

    let snapshot = analysisEntityCategoriesSnapshot(
        rows: [firstRow, selectedRow],
        targetProgress: [firstTarget, selectedTarget]
    )

    #expect(state.sortedRows(in: snapshot).map(\.scope) == [
        selectedRow.scope,
        firstRow.scope,
    ])
    #expect(state.selectedTargetProgress(in: snapshot)?.id == selectedTarget.id)
}

private func analysisEntityCategoriesSnapshot(
    rows: [AnalysisSpendRow],
    targetProgress: [TargetProgress] = []
) -> AnalysisCategoriesSnapshot {
    AnalysisCategoriesSnapshot(
        context: AnalysisContext(),
        report: CategoryAnalysisReport(context: AnalysisContext(), rows: rows),
        targetProgress: targetProgress
    )
}

private func analysisEntityCategoriesRow(
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
                start: analysisEntityPageStateUTCDate(year: 2026, month: 4, day: 1),
                end: analysisEntityPageStateUTCDate(year: 2026, month: 4, day: 16)
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

private func analysisEntityTargetProgress(
    id: UUID,
    name: String,
    scope: TargetScope
) -> TargetProgress {
    TargetProgress(
        id: id,
        name: name,
        scope: scope,
        monthlyLimit: Decimal(400),
        spent: Decimal(180),
        remaining: Decimal(220),
        paceDelta: Decimal(20)
    )
}

private func analysisEntityPageStateUTCDate(year: Int, month: Int, day: Int) -> Date {
    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = day
    components.calendar = analysisEntityPageStateUTCCalendar
    return components.date!
}

private let analysisEntityPageStateUTCCalendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
    return calendar
}()

private func analysisEntityPageStateID(_ value: String) -> UUID {
    UUID(uuidString: value)!
}
