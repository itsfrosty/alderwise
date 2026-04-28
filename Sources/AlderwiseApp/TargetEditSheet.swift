import Domain
import SwiftUI

struct TargetEditSheet: View {
    let target: ManagedMonthlyTarget
    let categories: [BudgetCategory]
    let categoryGroups: [BudgetCategoryGroup]
    var onCancel: () -> Void
    var onSave: (MonthlyTargetDraft) throws -> Void

    @State private var selectedCategoryID: UUID?
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

        _selectedCategoryID = State(initialValue: TargetEditorLogic.initialSelectedCategoryID(for: target.scope))
        _monthlyLimit = State(initialValue: NSDecimalNumber(decimal: target.monthlyLimit).stringValue)
    }

    var body: some View {
        TargetDraftEditorForm(
            title: "Edit Target",
            submitTitle: "Save",
            categories: categories,
            categoryGroups: categoryGroups,
            selectedCategoryID: $selectedCategoryID,
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
