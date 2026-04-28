import Domain
import SwiftUI

struct TargetCreationSheet: View {
    let categories: [BudgetCategory]
    let categoryGroups: [BudgetCategoryGroup]
    var onCancel: () -> Void
    var onCreate: (MonthlyTargetDraft) throws -> Void

    @State private var selectedCategoryID: UUID?
    @State private var monthlyLimit = ""
    @State private var errorMessage: String?

    var body: some View {
        TargetDraftEditorForm(
            title: "Create Target",
            submitTitle: "Create",
            categories: categories,
            categoryGroups: categoryGroups,
            selectedCategoryID: $selectedCategoryID,
            monthlyLimit: $monthlyLimit,
            errorMessage: errorMessage,
            onCancel: onCancel
        ) { draft in
            do {
                try onCreate(draft)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

struct TargetDraftEditorForm: View {
    let title: String
    let submitTitle: String
    let categories: [BudgetCategory]
    let categoryGroups: [BudgetCategoryGroup]
    @Binding var selectedCategoryID: UUID?
    @Binding var monthlyLimit: String
    let errorMessage: String?
    var onCancel: () -> Void
    var onSubmit: (MonthlyTargetDraft) -> Void

    private var expenseCategories: [BudgetCategory] {
        TargetEditorLogic.expenseCategories(from: categories)
    }

    private var draft: MonthlyTargetDraft? {
        TargetEditorLogic.draft(selectedCategoryID: selectedCategoryID, monthlyLimit: monthlyLimit)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(title)
                .font(.title2.bold())

            Form {
                GroupedCategoryPicker(
                    title: "Category",
                    prompt: TargetEditorLogic.categoryPrompt,
                    categories: expenseCategories,
                    categoryGroups: categoryGroups,
                    selection: $selectedCategoryID
                )

                TextField("Monthly Amount", text: $monthlyLimit)
            }
            .formStyle(.grouped)

            if let errorMessage, errorMessage.isEmpty == false {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button(submitTitle) {
                    if let draft {
                        onSubmit(draft)
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(draft == nil)
            }
        }
        .padding(24)
        .frame(minWidth: 420, idealWidth: 480)
    }
}

enum TargetEditorLogic {
    static let categoryPrompt = "Choose Category"

    static func expenseCategories(from categories: [BudgetCategory]) -> [BudgetCategory] {
        categories.filter { $0.kind == .expense }
    }

    static func initialSelectedCategoryID(for scope: TargetScope?) -> UUID? {
        guard let scope else {
            return nil
        }
        guard case .category(let categoryID) = scope else {
            return nil
        }
        return categoryID
    }

    static func draft(selectedCategoryID: UUID?, monthlyLimit: String) -> MonthlyTargetDraft? {
        guard
            let selectedCategoryID,
            let amount = Decimal(string: monthlyLimit.trimmingCharacters(in: .whitespacesAndNewlines)),
            amount > 0
        else {
            return nil
        }

        return MonthlyTargetDraft(scope: .category(selectedCategoryID), monthlyLimit: amount)
    }
}
