import Domain
import SwiftUI

struct GroupedCategoryPicker: View {
    struct OptionRow: Equatable {
        let id: UUID?
        let title: String
    }

    let title: String
    let prompt: String
    let categories: [BudgetCategory]
    let categoryGroups: [BudgetCategoryGroup]
    let selection: Binding<UUID?>

    var body: some View {
        Picker(title, selection: selection) {
            ForEach(Array(Self.optionRows(prompt: prompt, categories: categories).enumerated()), id: \.offset) { _, option in
                Text(option.title).tag(option.id)
            }
        }
    }

    nonisolated static func optionRows(
        prompt: String,
        categories: [BudgetCategory]
    ) -> [OptionRow] {
        [
            OptionRow(id: nil, title: prompt)
        ] + categories.map { category in
            OptionRow(id: category.id, title: category.name)
        }
    }
}

#if DEBUG
extension GroupedCategoryPicker {
    static func optionTitles(
        prompt: String,
        categories: [BudgetCategory]
    ) -> [String] {
        optionRows(prompt: prompt, categories: categories).map(\.title)
    }

    static func optionIDs(
        prompt: String,
        categories: [BudgetCategory]
    ) -> [UUID?] {
        optionRows(prompt: prompt, categories: categories).map(\.id)
    }
}
#endif
