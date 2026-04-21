import Domain
import SwiftUI

struct GroupedCategoryPicker: View {
    let title: String
    let prompt: String
    let categories: [BudgetCategory]
    let categoryGroups: [BudgetCategoryGroup]
    let selection: Binding<UUID?>

    var body: some View {
        Picker(title, selection: selection) {
            Text(prompt).tag(Optional<UUID>.none)
            ForEach(groupedCategories, id: \.group.id) { item in
                Section(item.group.name) {
                    ForEach(item.categories) { category in
                        Text(category.name).tag(Optional(category.id))
                    }
                }
            }
            if !ungroupedCategories.isEmpty {
                Section("Other") {
                    ForEach(ungroupedCategories) { category in
                        Text(category.name).tag(Optional(category.id))
                    }
                }
            }
        }
    }

    private var groupedCategories: [(group: BudgetCategoryGroup, categories: [BudgetCategory])] {
        categoryGroups.compactMap { group in
            let groupCategories = categories
                .filter { $0.groupID == group.id }
            guard !groupCategories.isEmpty else {
                return nil
            }
            return (group, groupCategories)
        }
    }

    private var ungroupedCategories: [BudgetCategory] {
        categories
            .filter { category in
                category.groupID == nil || !categoryGroups.contains { group in
                    group.id == category.groupID
                }
            }
    }
}
