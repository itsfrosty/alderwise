import Application
import Domain
import Foundation
import Testing

@testable import AlderwiseApp

@Test
func deepLinkToSelectedLearnedRuleClearsStaleSearchWhenTheRuleWouldBeHidden() {
    let categoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000601")!
    let selectedRuleID = UUID(uuidString: "00000000-0000-0000-0000-000000000602")!
    let learnedRows = [
        ManagedLearnedRuleRow(
            id: selectedRuleID,
            merchantPattern: "coffee shop",
            categoryID: categoryID,
            merchantName: "Coffee Shop",
            matchKind: .exactNormalizedMerchant,
            createdAt: Date(timeIntervalSince1970: 1_776_355_260),
            isDisabled: false,
            disabledAt: nil
        )
    ]

    let searchText = LearnedRulesManagerRouteSync.revealedSearchTextForDeepLink(
        currentSearchText: "groceries",
        selectedLearnedRuleID: selectedRuleID,
        learnedRows: learnedRows,
        categoryNamesByID: [categoryID: "Dining"]
    )

    #expect(searchText.isEmpty)
}

@Test
func deepLinkToSelectedLearnedRuleKeepsSearchWhenTheRuleAlreadyMatches() {
    let categoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000611")!
    let selectedRuleID = UUID(uuidString: "00000000-0000-0000-0000-000000000612")!
    let learnedRows = [
        ManagedLearnedRuleRow(
            id: selectedRuleID,
            merchantPattern: "coffee shop",
            categoryID: categoryID,
            merchantName: "Coffee Shop",
            matchKind: .exactNormalizedMerchant,
            createdAt: Date(timeIntervalSince1970: 1_776_355_260),
            isDisabled: false,
            disabledAt: nil
        )
    ]

    let searchText = LearnedRulesManagerRouteSync.revealedSearchTextForDeepLink(
        currentSearchText: "coffee",
        selectedLearnedRuleID: selectedRuleID,
        learnedRows: learnedRows,
        categoryNamesByID: [categoryID: "Dining"]
    )

    #expect(searchText == "coffee")
}

@Test
func merchantPatternHandoffPrefillsRulesSearchWhenThereIsNoExplicitDeepLink() {
    let categoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000621")!
    let matchingRule = ManagedLearnedRuleRow(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000622")!,
        merchantPattern: "blue bottle",
        categoryID: categoryID,
        merchantName: "Blue Bottle",
        matchKind: .exactNormalizedMerchant,
        createdAt: Date(timeIntervalSince1970: 1_776_355_260),
        isDisabled: false,
        disabledAt: nil
    )
    let nonMatchingRule = ManagedLearnedRuleRow(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000623")!,
        merchantPattern: "netflix",
        categoryID: categoryID,
        merchantName: "Netflix",
        matchKind: .exactNormalizedMerchant,
        createdAt: Date(timeIntervalSince1970: 1_776_355_261),
        isDisabled: false,
        disabledAt: nil
    )
    let searchText = LearnedRulesManagerRouteSync.searchTextForNavigation(
        currentSearchText: "",
        destination: LearnedRulesDestination(mode: .learned, selection: nil),
        merchantPatternHandoff: " blue bottle ",
        learnedRows: [matchingRule, nonMatchingRule],
        categoryNamesByID: [categoryID: "Dining"]
    )

    #expect(searchText == " blue bottle ")
    #expect(LearnedRulesManagerRouteSync.matchesLearnedRule(matchingRule, searchText: searchText, categoryName: "Dining"))
    #expect(LearnedRulesManagerRouteSync.matchesLearnedRule(nonMatchingRule, searchText: searchText, categoryName: "Dining") == false)
}

@Test
func explicitLearnedRuleDeepLinkOverridesMerchantPatternHandoffSearch() {
    let categoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000631")!
    let selectedRuleID = UUID(uuidString: "00000000-0000-0000-0000-000000000632")!
    let learnedRows = [
        ManagedLearnedRuleRow(
            id: selectedRuleID,
            merchantPattern: "coffee shop",
            categoryID: categoryID,
            merchantName: "Coffee Shop",
            matchKind: .exactNormalizedMerchant,
            createdAt: Date(timeIntervalSince1970: 1_776_355_260),
            isDisabled: false,
            disabledAt: nil
        )
    ]

    let searchText = LearnedRulesManagerRouteSync.searchTextForNavigation(
        currentSearchText: "groceries",
        destination: LearnedRulesDestination(mode: .learned, selection: .learnedRule(selectedRuleID)),
        merchantPatternHandoff: "blue bottle",
        learnedRows: learnedRows,
        categoryNamesByID: [categoryID: "Dining"]
    )

    #expect(searchText.isEmpty)
}
