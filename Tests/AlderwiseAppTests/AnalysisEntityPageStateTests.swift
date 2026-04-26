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
func categoriesPageUsesStableIdentityForUpdatedRowsWithTheSameEntity() {
    let originalRow = analysisEntityCategoriesRow(
        title: "Food",
        scope: .category(analysisEntityPageStateID("00000000-0000-0000-0000-000000001005")),
        currentSpend: Decimal(120),
        comparisonSpend: Decimal(80)
    )
    let updatedRow = analysisEntityCategoriesRow(
        title: "Food",
        scope: .category(analysisEntityPageStateID("00000000-0000-0000-0000-000000001005")),
        currentSpend: Decimal(220),
        comparisonSpend: Decimal(80)
    )
    let differentRow = analysisEntityCategoriesRow(
        title: "Travel",
        scope: .category(analysisEntityPageStateID("00000000-0000-0000-0000-000000001006")),
        currentSpend: Decimal(220),
        comparisonSpend: Decimal(80)
    )

    #expect(AnalysisCategoriesView.rowIdentity(for: originalRow) == AnalysisCategoriesView.rowIdentity(for: updatedRow))
    #expect(AnalysisCategoriesView.rowIdentity(for: originalRow) != AnalysisCategoriesView.rowIdentity(for: differentRow))
}

@Test
func categoriesPageSwitchesSortThroughStateTransitionAndPreservesSelection() {
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
    var state = AnalysisScreenState()
    let snapshot = analysisEntityCategoriesSnapshot(rows: [food, travel])

    state.setCategoriesSelection(.row(food))
    let initialOrder = state.categories.sortedRows(in: snapshot)

    state.setCategoriesSort(.largestDelta)
    let sortedOrder = state.categories.sortedRows(in: snapshot)

    #expect(initialOrder.map(\.scope) == [
        food.scope,
        travel.scope,
    ])
    #expect(state.categories.selection == .row(food))
    #expect(sortedOrder.map(\.scope) == [
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
        currentSpend: Decimal(420),
        comparisonSpend: Decimal(120)
    )
    let selectedRow = analysisEntityCategoriesRow(
        title: "Food",
        scope: .category(analysisEntityPageStateID("00000000-0000-0000-0000-000000001042")),
        currentSpend: Decimal(180),
        comparisonSpend: Decimal(120)
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

    #expect(state.sortedRows(in: snapshot).first?.scope == firstRow.scope)
    #expect(state.selectedTargetProgress(in: snapshot)?.id == selectedTarget.id)
}

@Test
func categoriesCommittedSelectionDrivesTrendAndNextStepAcrossSortChanges() throws {
    let selectedScope = analysisEntityPageStateID("00000000-0000-0000-0000-000000001071")
    let selectedRow = analysisEntityCategoriesRow(
        title: "Food",
        scope: .category(selectedScope),
        currentSpend: Decimal(180),
        comparisonSpend: Decimal(120)
    )
    let otherRow = analysisEntityCategoriesRow(
        title: "Travel",
        scope: .category(analysisEntityPageStateID("00000000-0000-0000-0000-000000001072")),
        currentSpend: Decimal(420),
        comparisonSpend: Decimal(40)
    )
    let target = analysisEntityTargetProgress(
        id: analysisEntityPageStateID("00000000-0000-0000-0000-000000001073"),
        name: "Food Budget",
        scope: .category(selectedScope)
    )
    var state = AnalysisScreenState.CategoriesState()
    state.selection = .row(selectedRow)

    let snapshot = analysisEntityCategoriesSnapshot(
        rows: [otherRow, selectedRow],
        targetProgress: [target]
    )
    let initialLayout = AnalysisCategoriesView.pageLayout(
        for: snapshot,
        sort: state.sort,
        selection: state.selection
    )

    state.sort = .largestDelta
    let updatedLayout = AnalysisCategoriesView.pageLayout(
        for: snapshot,
        sort: state.sort,
        selection: state.selection
    )
    let nextStep = AnalysisCategoriesView.selectedCategoryNextStep(
        selection: state.selection,
        snapshot: snapshot
    )

    #expect(try #require(initialLayout.card(kind: .selectedCategoryTrend)).footerAction.secondaryTitles == ["Open Target"])
    #expect(try #require(updatedLayout.card(kind: .selectedCategoryTrend)).footerAction.secondaryTitles == ["Open Target"])
    #expect(nextStep.kind == .linkedTarget(targetID: target.id))
}

@Test
func merchantsPageDefaultsToLargestCurrentSpend() {
    let bakery = analysisEntityMerchantRow(
        title: "Bakery",
        normalizedName: "bakery",
        currentSpend: Decimal(180),
        comparisonSpend: Decimal(120)
    )
    let coffee = analysisEntityMerchantRow(
        title: "Coffee",
        normalizedName: "coffee",
        currentSpend: Decimal(320),
        comparisonSpend: Decimal(100)
    )
    let state = AnalysisScreenState.MerchantsState()

    #expect(state.sort == .largestCurrentSpend)
    #expect(state.sortedMerchants(in: analysisEntityMerchantsSnapshot(merchants: [bakery, coffee])).map(\.key) == [
        coffee.key,
        bakery.key,
    ])
}

@Test
func merchantsPageSelectionAfterSortingRemainsAnchoredToMerchantIdentity() {
    let selectedMerchant = analysisEntityMerchantRow(
        title: "Blue Bottle",
        normalizedName: "blue bottle",
        currentSpend: Decimal(120),
        comparisonSpend: Decimal(80)
    )
    let alphabeticallyFirst = analysisEntityMerchantRow(
        title: "Apple Market",
        normalizedName: "apple market",
        currentSpend: Decimal(320),
        comparisonSpend: Decimal(60)
    )
    var state = AnalysisScreenState.MerchantsState()
    let snapshot = analysisEntityMerchantsSnapshot(merchants: [selectedMerchant, alphabeticallyFirst])

    state.selection = .merchant(selectedMerchant)
    let spendOrder = state.sortedMerchants(in: snapshot)

    state.sort = .alphabetical
    let alphabeticalOrder = state.sortedMerchants(in: snapshot)

    #expect(spendOrder.map(\.key) == [
        alphabeticallyFirst.key,
        selectedMerchant.key,
    ])
    #expect(alphabeticalOrder.map(\.key) == [
        alphabeticallyFirst.key,
        selectedMerchant.key,
    ])
    #expect(state.selection == .merchant(selectedMerchant))
    #expect(state.selectedRuleHandoffMerchantName == selectedMerchant.key.normalizedName)
}

@Test
func recurringCommitmentsSelectionAfterSortingRemainsAnchoredToRecurringIdentity() {
    let selectedRecurring = analysisEntityRecurringRow(
        normalizedName: "netflix",
        accountID: analysisEntityPageStateID("00000000-0000-0000-0000-000000001061"),
        cadence: .monthly,
        observationCount: 3,
        maximumAmount: Decimal(15.49)
    )
    let largerRecurring = analysisEntityRecurringRow(
        normalizedName: "spotify",
        accountID: analysisEntityPageStateID("00000000-0000-0000-0000-000000001062"),
        cadence: .monthly,
        observationCount: 4,
        maximumAmount: Decimal(19.99)
    )
    var state = AnalysisScreenState.MerchantsState()
    let snapshot = analysisEntityMerchantsSnapshot(recurring: [selectedRecurring, largerRecurring])

    state.selection = .recurring(selectedRecurring)
    let spendOrder = state.sortedRecurring(in: snapshot)

    state.sort = .alphabetical
    let alphabeticalOrder = state.sortedRecurring(in: snapshot)

    #expect(spendOrder.map(\.detail.normalizedMerchantName) == [
        "spotify",
        "netflix",
    ])
    #expect(alphabeticalOrder.map(\.detail.normalizedMerchantName) == [
        "netflix",
        "spotify",
    ])
    #expect(state.selection == .recurring(selectedRecurring))
    #expect(state.selectedRuleHandoffMerchantName == nil)
}

@Test
func merchantsPageSelectionRepairsWhenTheMerchantStillExistsAfterSnapshotChanges() {
    let selectedMerchant = analysisEntityMerchantRow(
        title: "Blue Bottle",
        normalizedName: "blue bottle",
        currentSpend: Decimal(120),
        comparisonSpend: Decimal(80)
    )
    let updatedSelectedMerchant = analysisEntityMerchantRow(
        title: "Blue Bottle",
        normalizedName: "blue bottle",
        currentSpend: Decimal(220),
        comparisonSpend: Decimal(80)
    )
    let otherMerchant = analysisEntityMerchantRow(
        title: "Apple Market",
        normalizedName: "apple market",
        currentSpend: Decimal(320),
        comparisonSpend: Decimal(60)
    )
    var state = AnalysisScreenState()

    state.setMerchantsSelection(.merchant(selectedMerchant))
    state.repairSelections(for: AnalysisSnapshot(
        merchants: analysisEntityMerchantsSnapshot(merchants: [otherMerchant, updatedSelectedMerchant])
    ))

    #expect(state.merchants.selection == .merchant(updatedSelectedMerchant))
    #expect(state.merchants.selectedRuleHandoffMerchantName == updatedSelectedMerchant.key.normalizedName)
}

@Test
func merchantsPageRecurringSelectionRepairsWhenTheRecurringSeriesStillExistsAfterSnapshotChanges() {
    let selectedRecurring = analysisEntityRecurringRow(
        normalizedName: "netflix",
        accountID: analysisEntityPageStateID("00000000-0000-0000-0000-000000001071"),
        cadence: .monthly,
        observationCount: 3,
        maximumAmount: Decimal(15.49)
    )
    let updatedSelectedRecurring = analysisEntityRecurringRow(
        normalizedName: "netflix",
        accountID: analysisEntityPageStateID("00000000-0000-0000-0000-000000001071"),
        cadence: .monthly,
        observationCount: 4,
        maximumAmount: Decimal(16.49)
    )
    let otherRecurring = analysisEntityRecurringRow(
        normalizedName: "spotify",
        accountID: analysisEntityPageStateID("00000000-0000-0000-0000-000000001072"),
        cadence: .monthly,
        observationCount: 4,
        maximumAmount: Decimal(19.99)
    )
    var state = AnalysisScreenState()

    state.setMerchantsSelection(.recurring(selectedRecurring))
    state.repairSelections(for: AnalysisSnapshot(
        merchants: analysisEntityMerchantsSnapshot(recurring: [otherRecurring, updatedSelectedRecurring])
    ))

    #expect(state.merchants.selection == .recurring(updatedSelectedRecurring))
    #expect(state.merchants.selectedRuleHandoffMerchantName == nil)
}

@Test
func merchantsContractKeepsRulesHandoffAnchoredToTheSelectedIdentityAcrossSortChanges() throws {
    let selectedMerchant = analysisEntityMerchantRow(
        title: "Blue Bottle",
        normalizedName: "blue bottle",
        currentSpend: Decimal(120),
        comparisonSpend: Decimal(80)
    )
    let otherMerchant = analysisEntityMerchantRow(
        title: "Apple Market",
        normalizedName: "apple market",
        currentSpend: Decimal(320),
        comparisonSpend: Decimal(60)
    )
    var state = AnalysisScreenState.MerchantsState()
    state.selection = .merchant(selectedMerchant)

    let snapshot = analysisEntityMerchantsSnapshot(merchants: [selectedMerchant, otherMerchant])
    let initialLayout = AnalysisMerchantsView.pageLayout(
        for: snapshot,
        sort: state.sort,
        selection: state.selection
    )

    state.sort = .alphabetical
    let updatedLayout = AnalysisMerchantsView.pageLayout(
        for: snapshot,
        sort: state.sort,
        selection: state.selection
    )

    #expect(try #require(initialLayout.card(kind: .topMerchants)).footerAction.secondaryTitles == ["Open Rules"])
    #expect(try #require(updatedLayout.card(kind: .topMerchants)).footerAction.secondaryTitles == ["Open Rules"])
    #expect(state.selectedRuleHandoffMerchantName == "blue bottle")
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

private func analysisEntityMerchantsSnapshot(
    merchants: [MerchantAnalysisRow] = [],
    recurring: [MerchantRecurringReportRow] = []
) -> AnalysisMerchantsSnapshot {
    AnalysisMerchantsSnapshot(
        context: AnalysisContext(),
        report: MerchantAnalysisReport(
            context: AnalysisContext(),
            merchants: merchants,
            recurring: recurring
        )
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

private func analysisEntityMerchantRow(
    title: String,
    normalizedName: String,
    currentSpend: Decimal,
    comparisonSpend: Decimal
) -> MerchantAnalysisRow {
    MerchantAnalysisRow(
        key: MerchantReportKey(normalizedName: normalizedName),
        title: title,
        currentSpend: currentSpend,
        comparisonSpend: comparisonSpend,
        delta: currentSpend - comparisonSpend,
        evidence: InsightEvidence(
            metricBasis: .includedVisibleExpenses,
            resolvedInterval: DateInterval(
                start: analysisEntityPageStateUTCDate(year: 2026, month: 4, day: 1),
                end: analysisEntityPageStateUTCDate(year: 2026, month: 4, day: 16)
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

private func analysisEntityRecurringRow(
    normalizedName: String,
    accountID: UUID,
    cadence: RecurringChargeCadence,
    observationCount: Int,
    maximumAmount: Decimal
) -> MerchantRecurringReportRow {
    MerchantRecurringReportRow(
        detail: RecurringChargeInsightDetail(
            accountID: accountID,
            normalizedMerchantName: normalizedName,
            cadence: cadence,
            observationCount: observationCount,
            amountRange: RecurringChargeAmountRange(
                minimum: maximumAmount,
                maximum: maximumAmount
            ),
            supportingTransactionIDs: [
                analysisEntityPageStateID("00000000-0000-0000-0000-000000001081")
            ],
            firstObservedDate: analysisEntityPageStateUTCDate(year: 2026, month: 2, day: 9),
            lastObservedDate: analysisEntityPageStateUTCDate(year: 2026, month: 4, day: 9),
            nextExpectedDateWindow: nil
        ),
        evidence: InsightEvidence(
            metricBasis: .includedVisibleExpenses,
            resolvedInterval: DateInterval(
                start: analysisEntityPageStateUTCDate(year: 2026, month: 2, day: 9),
                end: analysisEntityPageStateUTCDate(year: 2026, month: 4, day: 10)
            ),
            scope: .merchant(normalizedName),
            reconciliationRule: .recurringObservationSet,
            destination: InsightEvidenceDestination(
                scope: .merchant(normalizedName),
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
