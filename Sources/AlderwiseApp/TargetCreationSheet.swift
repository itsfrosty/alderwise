import Domain
import SwiftUI

struct TargetCreationSheet: View {
    let categories: [BudgetCategory]
    let categoryGroups: [BudgetCategoryGroup]
    var onCancel: () -> Void
    var onCreate: (MonthlyTargetDraft) -> Void

    @State private var selectedScopeKind = TargetScopeKind.category
    @State private var selectedCategoryID: UUID?
    @State private var selectedCategoryGroupID: UUID?
    @State private var monthlyLimit = ""

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
            Text("Create Target")
                .font(.title2.bold())

            Form {
                Picker("Scope", selection: $selectedScopeKind) {
                    ForEach(TargetScopeKind.allCases) { kind in
                        Text(kind.title).tag(kind)
                    }
                }
                .pickerStyle(.segmented)

                if selectedScopeKind == .category {
                    Picker("Category", selection: $selectedCategoryID) {
                        Text("Choose Category").tag(Optional<UUID>.none)
                        ForEach(expenseCategories) { category in
                            Text(category.name).tag(Optional(category.id))
                        }
                    }
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

            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("Create") {
                    if let draft {
                        onCreate(draft)
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
            selectedCategoryID = selectedCategoryID ?? expenseCategories.first?.id
            selectedCategoryGroupID = selectedCategoryGroupID ?? categoryGroups.first?.id
        }
    }
}

private enum TargetScopeKind: String, CaseIterable, Identifiable {
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
