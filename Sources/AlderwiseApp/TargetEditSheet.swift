import Domain
import SwiftUI

struct TargetEditSheet: View {
    let target: ManagedMonthlyTarget
    let categories: [BudgetCategory]
    let categoryGroups: [BudgetCategoryGroup]
    var onCancel: () -> Void
    var onSave: (MonthlyTargetDraft) throws -> Void

    @State private var selectedScopeKind: TargetScopeKind
    @State private var selectedCategoryID: UUID?
    @State private var selectedCategoryGroupID: UUID?
    @State private var monthlyLimit: String
    @State private var errorMessage: String?

    init(
        target: ManagedMonthlyTarget,
        categories: [BudgetCategory],
        categoryGroups: [BudgetCategoryGroup],
        onCancel: @escaping () -> Void,
        onSave: @escaping (MonthlyTargetDraft) throws -> Void
    ) {
        self.target = target
        self.categories = categories
        self.categoryGroups = categoryGroups
        self.onCancel = onCancel
        self.onSave = onSave

        switch target.scope {
        case .category(let categoryID):
            _selectedScopeKind = State(initialValue: .category)
            _selectedCategoryID = State(initialValue: categoryID)
            _selectedCategoryGroupID = State(initialValue: nil)
        case .categoryGroup(let groupID):
            _selectedScopeKind = State(initialValue: .categoryGroup)
            _selectedCategoryID = State(initialValue: nil)
            _selectedCategoryGroupID = State(initialValue: groupID)
        }
        _monthlyLimit = State(initialValue: NSDecimalNumber(decimal: target.monthlyLimit).stringValue)
    }

    var body: some View {
        TargetDraftEditorForm(
            title: "Edit Target",
            submitTitle: "Save",
            categories: categories,
            categoryGroups: categoryGroups,
            selectedScopeKind: $selectedScopeKind,
            selectedCategoryID: $selectedCategoryID,
            selectedCategoryGroupID: $selectedCategoryGroupID,
            monthlyLimit: $monthlyLimit,
            errorMessage: errorMessage,
            onCancel: onCancel
        ) { draft in
            do {
                try onSave(draft)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
