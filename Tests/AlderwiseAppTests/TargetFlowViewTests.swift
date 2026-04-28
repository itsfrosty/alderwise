import Domain
import Foundation
import Testing

@testable import AlderwiseApp

@Test
func targetEditorCreationRequiresExplicitCategorySelection() {
    let draft = TargetEditorLogic.draft(
        selectedCategoryID: nil,
        monthlyLimit: "150"
    )

    #expect(draft == nil)
}

@Test
func targetEditorDraftBuildsCategoryTargetFromTrimmedAmount() throws {
    let categoryID = targetFlowTestID("00000000-0000-0000-0000-000000004001")

    let draft = try #require(
        TargetEditorLogic.draft(
            selectedCategoryID: categoryID,
            monthlyLimit: " 275.50 "
        )
    )

    #expect(draft.scope == .category(categoryID))
    #expect(draft.monthlyLimit == Decimal(string: "275.50"))
}

@Test
func targetEditorFiltersToExpenseCategoriesOnly() {
    let groupedExpenseID = targetFlowTestID("00000000-0000-0000-0000-000000004002")
    let ungroupedExpenseID = targetFlowTestID("00000000-0000-0000-0000-000000004003")
    let categories = [
        BudgetCategory(id: groupedExpenseID, name: "Food", kind: .expense, groupID: targetFlowTestID("00000000-0000-0000-0000-000000004010")),
        BudgetCategory(id: ungroupedExpenseID, name: "Travel", kind: .expense),
        BudgetCategory(id: targetFlowTestID("00000000-0000-0000-0000-000000004004"), name: "Salary", kind: .income),
        BudgetCategory(id: targetFlowTestID("00000000-0000-0000-0000-000000004005"), name: "Transfer", kind: .transfer),
    ]

    let filtered = TargetEditorLogic.expenseCategories(from: categories)

    #expect(filtered.map(\.id) == [groupedExpenseID, ungroupedExpenseID])
}

@Test
func targetEditorPreservesExistingCategoryScopeSelectionOnEdit() {
    let categoryID = targetFlowTestID("00000000-0000-0000-0000-000000004006")

    let selection = TargetEditorLogic.initialSelectedCategoryID(for: .category(categoryID))

    #expect(selection == categoryID)
}

@Test
func targetEditorClearsLegacyGroupScopeSelectionOnEdit() {
    let groupID = targetFlowTestID("00000000-0000-0000-0000-000000004007")

    let selection = TargetEditorLogic.initialSelectedCategoryID(for: .categoryGroup(groupID))

    #expect(selection == nil)
}

@MainActor
@Test
func targetsManagementUsesCategoryOnlyCopyForNewAndLegacyTargets() {
    #expect(
        TargetsManagementView.emptyStateDescription
        == "Create a monthly limit to track visible spending for an expense category."
    )
    #expect(
        TargetsManagementView.scopeLabel(for: .category(targetFlowTestID("00000000-0000-0000-0000-000000004008")))
        == "Category target"
    )
    #expect(
        TargetsManagementView.scopeLabel(for: .categoryGroup(targetFlowTestID("00000000-0000-0000-0000-000000004009")))
        == "Target needs category reassignment"
    )
}

private func targetFlowTestID(_ value: String) -> UUID {
    UUID(uuidString: value)!
}
