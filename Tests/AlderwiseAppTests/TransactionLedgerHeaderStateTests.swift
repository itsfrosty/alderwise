import Domain
import Foundation
import Testing

@testable import AlderwiseApp

@Test
func filteredCountUsesRenderedRowList() {
    let state = TransactionLedgerHeaderState(
        rows: [makeRow(), makeRow()],
        filter: TransactionLedgerFilter(searchText: "coffee")
    )

    #expect(state.filteredResultCountText == "2 transactions")
}

@Test
func emptyFilterProducesAllTransactionsScope() {
    let state = TransactionLedgerHeaderState(
        rows: [makeRow()],
        filter: .empty
    )

    #expect(state.scopeSummaryText == "Active transactions")
    #expect(state.activeChips.isEmpty)
    #expect(state.zeroResultsState == nil)
}

@Test
func searchOnlyFilterProducesExpectedScopeAndChip() {
    let state = TransactionLedgerHeaderState(
        rows: [makeRow()],
        filter: TransactionLedgerFilter(searchText: "coffee")
    )

    #expect(state.scopeSummaryText == "Search: \"coffee\"")
    #expect(state.activeChips == [.search("coffee")])
}

@Test
func whitespaceOnlySearchDoesNotProduceActiveSearchState() {
    let state = TransactionLedgerHeaderState(
        rows: [makeRow()],
        filter: TransactionLedgerFilter(searchText: "  \n\t  ")
    )

    #expect(state.scopeSummaryText == "Active transactions")
    #expect(state.activeChips.isEmpty)
    #expect(state.zeroResultsState == nil)
}

@Test
func categoryOnlyFilterProducesExpectedScopeAndChip() {
    let categoryID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    let state = TransactionLedgerHeaderState(
        rows: [makeRow()],
        filter: TransactionLedgerFilter(categoryID: categoryID),
        categoryName: "Groceries"
    )

    #expect(state.scopeSummaryText == "Category: Groceries")
    #expect(state.activeChips == [.category(categoryID, "Groceries")])
}

@Test
func importOnlyFilterProducesExpectedScopeAndChip() {
    let state = TransactionLedgerHeaderState(
        rows: [makeRow()],
        filter: TransactionLedgerFilter(importSessionID: 42),
        importSessionName: "april.csv"
    )

    #expect(state.scopeSummaryText == "Import: april.csv")
    #expect(state.activeChips == [.importSession(42, "april.csv")])
}

@Test
func ruleFilterOnlyProducesExpectedScopeAndChip() {
    let ruleID = UUID(uuidString: "55555555-5555-5555-5555-555555555555")!
    let state = TransactionLedgerHeaderState(
        rows: [makeRow()],
        filter: TransactionLedgerFilter(
            ruleFilterIntent: TransactionLedgerRuleFilterIntent(
                source: .learnedRule(ruleID),
                merchantPattern: "coffee shop",
                merchantLabel: "Coffee Shop",
                matchKind: .exactNormalizedMerchant
            )
        )
    )

    #expect(state.scopeSummaryText == "Matching rule: Coffee Shop")
    #expect(
        state.activeChips
            == [
                .ruleMatch(
                    .learnedRule(ruleID),
                    "Coffee Shop"
                )
            ]
    )
}

@Test
func dateOnlyFilterProducesExpectedScopeAndChip() {
    let formatting = fixedFormatting()
    let startDate = makeDate(year: 2026, month: 1, day: 5)
    let endDate = makeDate(year: 2026, month: 1, day: 9)
    let state = TransactionLedgerHeaderState(
        rows: [makeRow()],
        filter: TransactionLedgerFilter(startDate: startDate, endDate: endDate),
        formatting: formatting
    )

    #expect(state.scopeSummaryText == "Date: Jan 5, 2026 - Jan 9, 2026")
    #expect(state.activeChips == [.dateRange(start: startDate, end: endDate)])
}

@Test
func startOnlyDateFilterProducesExpectedScopeAndChip() {
    let formatting = fixedFormatting()
    let startDate = makeDate(year: 2026, month: 1, day: 5)
    let state = TransactionLedgerHeaderState(
        rows: [makeRow()],
        filter: TransactionLedgerFilter(startDate: startDate),
        formatting: formatting
    )

    #expect(state.scopeSummaryText == "Date: From Jan 5, 2026")
    #expect(state.activeChips == [.dateRange(start: startDate, end: nil)])
    #expect(state.activeChips.first?.text(using: formatting) == "From Jan 5, 2026")
}

@Test
func endOnlyDateFilterProducesExpectedScopeAndChip() {
    let formatting = fixedFormatting()
    let endDate = makeDate(year: 2026, month: 1, day: 9)
    let state = TransactionLedgerHeaderState(
        rows: [makeRow()],
        filter: TransactionLedgerFilter(endDate: endDate),
        formatting: formatting
    )

    #expect(state.scopeSummaryText == "Date: Through Jan 9, 2026")
    #expect(state.activeChips == [.dateRange(start: nil, end: endDate)])
    #expect(state.activeChips.first?.text(using: formatting) == "Through Jan 9, 2026")
}

@Test
func categoryGroupFilterProducesExpectedScopeAndChip() {
    let groupID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
    let state = TransactionLedgerHeaderState(
        rows: [makeRow()],
        filter: TransactionLedgerFilter(categoryGroupID: groupID),
        categoryGroupName: "Food & Drink"
    )

    #expect(state.scopeSummaryText == "Category group: Food & Drink")
    #expect(state.activeChips == [.categoryGroup(groupID, "Food & Drink")])
}

@Test
func visibilityFilterProducesExpectedScopeAndChip() {
    let state = TransactionLedgerHeaderState(
        rows: [makeRow()],
        filter: TransactionLedgerFilter(visibility: .hidden)
    )

    #expect(state.scopeSummaryText == "Visibility: Hidden")
    #expect(state.activeChips == [.visibility(.hidden)])
}

@Test
func uncategorizedFilterProducesExpectedScopeAndChip() {
    let state = TransactionLedgerHeaderState(
        rows: [makeRow()],
        filter: TransactionLedgerFilter(uncategorizedOnly: true)
    )

    #expect(state.scopeSummaryText == "Category: Uncategorized")
    #expect(state.activeChips == [.uncategorized])
}

@Test
func removingCategoryGroupChipClearsOnlyCategoryGroupFilter() {
    let accountID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    let categoryGroupID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
    let filter = TransactionLedgerFilter(
        searchText: "coffee",
        accountID: accountID,
        categoryGroupID: categoryGroupID,
        direction: .expense
    )

    let nextFilter = TransactionLedgerHeaderState.removing(
        .categoryGroup(categoryGroupID, "Food & Drink"),
        from: filter
    )

    #expect(nextFilter.searchText == "coffee")
    #expect(nextFilter.accountID == accountID)
    #expect(nextFilter.categoryGroupID == nil)
    #expect(nextFilter.direction == .expense)
}

@Test
func removingVisibilityChipClearsOnlyVisibilityFilter() {
    let categoryID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    let filter = TransactionLedgerFilter(
        categoryID: categoryID,
        reviewStatus: .pending,
        visibility: .hidden
    )

    let nextFilter = TransactionLedgerHeaderState.removing(.visibility(.hidden), from: filter)

    #expect(nextFilter.categoryID == categoryID)
    #expect(nextFilter.reviewStatus == .pending)
    #expect(nextFilter.visibility == nil)
}

@Test
func removingUncategorizedChipClearsOnlyUncategorizedFilter() {
    let filter = TransactionLedgerFilter(
        uncategorizedOnly: true,
        direction: .expense,
        visibility: .all
    )

    let nextFilter = TransactionLedgerHeaderState.removing(.uncategorized, from: filter)

    #expect(nextFilter.uncategorizedOnly == false)
    #expect(nextFilter.direction == .expense)
    #expect(nextFilter.visibility == .all)
}

@Test
func zeroResultsStateReturnsResetAndClearSearchAffordances() {
    let state = TransactionLedgerHeaderState(
        rows: [],
        filter: TransactionLedgerFilter(
            searchText: "coffee",
            categoryID: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        ),
        categoryName: "Groceries"
    )

    #expect(state.zeroResultsState?.title == "No transactions match these filters")
    #expect(state.zeroResultsState?.message == "Try removing a filter or clearing the current search to broaden the ledger.")
    #expect(state.zeroResultsState?.showsResetFilters == true)
    #expect(state.zeroResultsState?.showsClearSearch == true)
}

@Test
func zeroResultsStateWithOnlySearchShowsClearSearchAffordance() {
    let state = TransactionLedgerHeaderState(
        rows: [],
        filter: TransactionLedgerFilter(searchText: "coffee")
    )

    #expect(state.zeroResultsState?.title == "No transactions match these filters")
    #expect(state.zeroResultsState?.message == "Try clearing the current search to broaden the ledger.")
    #expect(state.zeroResultsState?.showsResetFilters == false)
    #expect(state.zeroResultsState?.showsClearSearch == true)
}

@Test
func zeroResultsStateWithOnlyNonSearchFiltersShowsResetAffordance() {
    let state = TransactionLedgerHeaderState(
        rows: [],
        filter: TransactionLedgerFilter(direction: .expense)
    )

    #expect(state.zeroResultsState?.title == "No transactions match these filters")
    #expect(state.zeroResultsState?.message == "Try removing one or more filters to broaden the ledger.")
    #expect(state.zeroResultsState?.showsResetFilters == true)
    #expect(state.zeroResultsState?.showsClearSearch == false)
}

@Test
func zeroResultsStateWithOnlyRuleFilterShowsResetAffordance() {
    let ruleID = UUID(uuidString: "66666666-6666-6666-6666-666666666666")!
    let state = TransactionLedgerHeaderState(
        rows: [],
        filter: TransactionLedgerFilter(
            ruleFilterIntent: TransactionLedgerRuleFilterIntent(
                source: .learnedRule(ruleID),
                merchantPattern: "coffee shop",
                merchantLabel: "Coffee Shop",
                matchKind: .prefixNormalizedMerchant
            )
        )
    )

    #expect(state.zeroResultsState?.title == "No transactions match these filters")
    #expect(state.zeroResultsState?.message == "Try removing one or more filters to broaden the ledger.")
    #expect(state.zeroResultsState?.showsResetFilters == true)
    #expect(state.zeroResultsState?.showsClearSearch == false)
}

@Test
func dateRangeChipFormattingIsDeterministic() {
    let formatting = fixedFormatting()
    let startDate = makeDate(year: 2026, month: 2, day: 3)
    let endDate = makeDate(year: 2026, month: 2, day: 7)
    let chip = TransactionLedgerHeaderState.Chip.dateRange(start: startDate, end: endDate)

    #expect(chip.text(using: formatting) == "Feb 3, 2026 - Feb 7, 2026")
}

@Test
func injectedFormattingUsesLocalizedDateOrder() {
    let timeZone = TimeZone(secondsFromGMT: 0)!
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    let formatting = TransactionLedgerHeaderState.Formatting(
        locale: Locale(identifier: "en_GB"),
        timeZone: timeZone,
        calendar: calendar
    )
    let chip = TransactionLedgerHeaderState.Chip.dateRange(
        start: makeDate(year: 2026, month: 1, day: 5),
        end: makeDate(year: 2026, month: 1, day: 9)
    )

    #expect(chip.text(using: formatting) == "5 Jan 2026 - 9 Jan 2026")
}

@Test
func removingOneChipMutatesOnlyTheMatchingFilterField() {
    let accountID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    let categoryID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    let filter = TransactionLedgerFilter(
        searchText: "coffee",
        accountID: accountID,
        categoryID: categoryID,
        direction: .expense,
        reviewStatus: .pending,
        importSessionID: 42
    )

    let nextFilter = TransactionLedgerHeaderState.removing(.review(.pending), from: filter)

    #expect(nextFilter.searchText == "coffee")
    #expect(nextFilter.accountID == accountID)
    #expect(nextFilter.categoryID == categoryID)
    #expect(nextFilter.direction == .expense)
    #expect(nextFilter.reviewStatus == nil)
    #expect(nextFilter.importSessionID == 42)
}

@Test
func removingCategoryChipClearsOnlyCategoryID() {
    let categoryID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    let categoryGroupID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
    let filter = TransactionLedgerFilter(
        categoryID: categoryID,
        categoryGroupID: categoryGroupID,
        reviewStatus: .accepted
    )

    let nextFilter = TransactionLedgerHeaderState.removing(
        .category(categoryID, "Groceries"),
        from: filter
    )

    #expect(nextFilter.categoryID == nil)
    #expect(nextFilter.categoryGroupID == categoryGroupID)
    #expect(nextFilter.reviewStatus == .accepted)
}

@Test
func removingDateRangeChipClearsBothDates() {
    let startDate = makeDate(year: 2026, month: 1, day: 5)
    let endDate = makeDate(year: 2026, month: 1, day: 9)
    let filter = TransactionLedgerFilter(
        startDate: startDate,
        endDate: endDate,
        importSessionID: 42
    )

    let nextFilter = TransactionLedgerHeaderState.removing(
        .dateRange(start: startDate, end: endDate),
        from: filter
    )

    #expect(nextFilter.startDate == nil)
    #expect(nextFilter.endDate == nil)
    #expect(nextFilter.importSessionID == 42)
}

@Test
func removingSearchChipPreservesOtherFilters() {
    let accountID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    let filter = TransactionLedgerFilter(
        searchText: "coffee",
        accountID: accountID,
        direction: .expense
    )

    let nextFilter = TransactionLedgerHeaderState.removing(.search("coffee"), from: filter)

    #expect(nextFilter.searchText.isEmpty)
    #expect(nextFilter.accountID == accountID)
    #expect(nextFilter.direction == .expense)
}

@Test
func removingRuleMatchChipClearsOnlyRuleFilterIntent() {
    let accountID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    let ruleID = UUID(uuidString: "77777777-7777-7777-7777-777777777777")!
    let filter = TransactionLedgerFilter(
        accountID: accountID,
        ruleFilterIntent: TransactionLedgerRuleFilterIntent(
            source: .learnedRule(ruleID),
            merchantPattern: "coffee shop",
            merchantLabel: "Coffee Shop",
            matchKind: .exactNormalizedMerchant
        )
    )

    let nextFilter = TransactionLedgerHeaderState.removing(
        .ruleMatch(.learnedRule(ruleID), "Coffee Shop"),
        from: filter
    )

    #expect(nextFilter.accountID == accountID)
    #expect(nextFilter.ruleFilterIntent == nil)
}

@Test
func removingMultipleTypedChipsSupportsSharedResetPath() {
    let accountID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    let startDate = makeDate(year: 2026, month: 1, day: 5)
    let filter = TransactionLedgerFilter(
        searchText: "coffee",
        startDate: startDate,
        accountID: accountID,
        direction: .expense
    )

    let nextFilter = TransactionLedgerHeaderState.removing(
        [
            .account(accountID, "Checking"),
            .direction(.expense),
            .dateRange(start: startDate, end: nil),
        ],
        from: filter
    )

    #expect(nextFilter.searchText == "coffee")
    #expect(nextFilter.startDate == nil)
    #expect(nextFilter.endDate == nil)
    #expect(nextFilter.accountID == nil)
    #expect(nextFilter.direction == nil)
}

private func makeRow(id: UUID = UUID()) -> TransactionLedgerRow {
    TransactionLedgerRow(
        id: id,
        accountID: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
        accountName: "Checking",
        categoryID: UUID(uuidString: "22222222-2222-2222-2222-222222222222"),
        categoryName: "Groceries",
        rawDescription: "COFFEE SHOP",
        merchantName: "Coffee Shop",
        amount: Decimal(-4.75),
        transactionDate: makeDate(year: 2026, month: 1, day: 5),
        postedDate: nil,
        direction: .expense,
        reviewStatus: .accepted,
        importOrigin: TransactionImportOrigin(
            id: 42,
            originalFilename: "april.csv",
            importedAt: makeDate(year: 2026, month: 1, day: 10)
        )
    )
}

private func fixedFormatting() -> TransactionLedgerHeaderState.Formatting {
    let timeZone = TimeZone(secondsFromGMT: 0)!
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    return TransactionLedgerHeaderState.Formatting(
        locale: Locale(identifier: "en_US_POSIX"),
        timeZone: timeZone,
        calendar: calendar,
        dateTemplate: "MMM d, yyyy"
    )
}

private func makeDate(year: Int, month: Int, day: Int) -> Date {
    var components = DateComponents()
    components.calendar = Calendar(identifier: .gregorian)
    components.timeZone = TimeZone(secondsFromGMT: 0)
    components.year = year
    components.month = month
    components.day = day
    return components.date!
}
