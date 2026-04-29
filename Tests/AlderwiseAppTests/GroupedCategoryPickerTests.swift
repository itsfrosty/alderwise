import Domain
import Foundation
import Testing

@testable import AlderwiseApp

@Test
func groupedCategoryPickerPrependsPromptAndPreservesProvidedCategoryOrder() {
    let homeID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    let groceriesID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    let incomeID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
    let categories = [
        BudgetCategory(id: homeID, name: "Home & Utilities", kind: .expense),
        BudgetCategory(id: groceriesID, name: "Groceries", kind: .expense),
        BudgetCategory(id: incomeID, name: "Income", kind: .income)
    ]

    #expect(
        GroupedCategoryPicker.optionTitles(prompt: "Choose Category", categories: categories) == [
            "Choose Category",
            "Home & Utilities",
            "Groceries",
            "Income"
        ]
    )
    #expect(
        GroupedCategoryPicker.optionIDs(prompt: "Choose Category", categories: categories) == [
            nil,
            homeID,
            groceriesID,
            incomeID
        ]
    )
}

@Test
func groupedCategoryPickerDoesNotReintroduceLegacyGroupingSections() {
    let diningGroupID = UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!
    let diningID = UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!
    let travelID = UUID(uuidString: "cccccccc-cccc-cccc-cccc-cccccccccccc")!
    let categories = [
        BudgetCategory(id: diningID, name: "Dining", kind: .expense, groupID: diningGroupID),
        BudgetCategory(id: travelID, name: "Travel", kind: .expense)
    ]

    #expect(
        GroupedCategoryPicker.optionTitles(prompt: "All Categories", categories: categories) == [
            "All Categories",
            "Dining",
            "Travel"
        ]
    )
}
