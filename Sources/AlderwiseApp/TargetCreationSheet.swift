import Domain
import SwiftUI

struct TargetCreationSheet: View {
    let categories: [BudgetCategory]
    let categoryGroups: [BudgetCategoryGroup]
    var onCancel: () -> Void
    var onCreate: (MonthlyTargetDraft) throws -> Void

    @State private var selectedScopeKind = TargetScopeKind.category
    @State private var selectedCategoryID: UUID?
    @State private var selectedCategoryGroupID: UUID?
    @State private var monthlyLimit = ""
    @State private var errorMessage: String?

    var body: some View {
        TargetDraftEditorForm(
            title: "Create Target",
            submitTitle: "Create",
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
    @Binding var selectedScopeKind: TargetScopeKind
    @Binding var selectedCategoryID: UUID?
    @Binding var selectedCategoryGroupID: UUID?
    @Binding var monthlyLimit: String
    let errorMessage: String?
    var onCancel: () -> Void
    var onSubmit: (MonthlyTargetDraft) -> Void

    private var expenseCategories: [BudgetCategory] {
        categories.filter { $0.kind == .expense }
    }

    private var amount: Decimal? {
        Decimal(string: monthlyLimit.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private var draft: MonthlyTargetDraft? {
        guard let amount, amount > 0 else {
            return nil
        }

        switch selectedScopeKind {
        case .category:
            guard let selectedCategoryID else {
                return nil
            }
            return MonthlyTargetDraft(scope: .category(selectedCategoryID), monthlyLimit: amount)
        case .categoryGroup:
            guard let selectedCategoryGroupID else {
                return nil
            }
            return MonthlyTargetDraft(scope: .categoryGroup(selectedCategoryGroupID), monthlyLimit: amount)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(title)
                .font(.title2.bold())

            Form {
                Picker("Scope", selection: $selectedScopeKind) {
                    ForEach(TargetScopeKind.allCases) { kind in
                        Text(kind.title).tag(kind)
                    }
                }
                .pickerStyle(.segmented)

                if selectedScopeKind == .category {
                    GroupedCategoryPicker(
                        title: "Category",
                        prompt: "Choose Category",
                        categories: expenseCategories,
                        categoryGroups: categoryGroups,
                        selection: $selectedCategoryID
                    )
                } else {
                    Picker("Group", selection: $selectedCategoryGroupID) {
                        Text("Choose Group").tag(Optional<UUID>.none)
                        ForEach(categoryGroups) { group in
                            Text(group.name).tag(Optional(group.id))
                        }
                    }
                }

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
        .onAppear {
            if selectedScopeKind == .category {
                selectedCategoryID = selectedCategoryID ?? expenseCategories.first?.id
            } else {
                selectedCategoryGroupID = selectedCategoryGroupID ?? categoryGroups.first?.id
            }
        }
        .onChange(of: selectedScopeKind) { _, newValue in
            switch newValue {
            case .category:
                selectedCategoryID = selectedCategoryID ?? expenseCategories.first?.id
            case .categoryGroup:
                selectedCategoryGroupID = selectedCategoryGroupID ?? categoryGroups.first?.id
            }
        }
    }
}

enum TargetScopeKind: String, CaseIterable, Identifiable {
    case category
    case categoryGroup

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .category:
            "Category"
        case .categoryGroup:
            "Group"
        }
    }
}
