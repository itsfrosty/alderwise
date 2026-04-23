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
