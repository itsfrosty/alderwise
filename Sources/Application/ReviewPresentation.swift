import Domain
import Foundation

public struct ReviewPresentation: Sendable {
    private let categoryNamesByID: [UUID: String]

    public init(categories: [BudgetCategory]) {
        categoryNamesByID = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0.name) })
    }

    public func queueSubtitle(for item: PendingReviewItem) -> String {
        let hint = starterHintLabel(for: item)
        return [
            item.sourceFile.originalFilename,
            "Row \(item.sourceRow.sourceLineNumber)",
            hint ?? item.reason,
        ]
        .compactMap { $0 }
        .joined(separator: " · ")
    }

    public func starterHintCaption(for item: PendingReviewItem) -> String? {
        guard isCuratedPrefill(item) else {
            return nil
        }
        if let categoryName = starterHintCategoryName(for: item) {
            return "Starter hint: Suggested category is \(categoryName). Review before accepting."
        }
        return "Starter hint: Review before accepting."
    }

    public func initialCreateRuleValue(for item: PendingReviewItem) -> Bool {
        !isCuratedPrefill(item)
    }

    public func initialRuleLearningSelection(for item: PendingReviewItem) -> ReviewRuleLearningOption? {
        let normalizedMerchantName = item.classification?.normalizedMerchantName ?? ""
        let options = ReviewRuleLearningOption.options(forNormalizedMerchantName: normalizedMerchantName)
        return options.first(where: { option in
            if case .exactNormalizedMerchant = option {
                return true
            }
            return false
        }) ?? options.first
    }

    public func resolvedRuleLearningSelection(
        for item: PendingReviewItem,
        selectedRuleLearning: ReviewRuleLearningOption?
    ) -> ReviewRuleLearningOption? {
        selectedRuleLearning ?? initialRuleLearningSelection(for: item)
    }

    public static func sourceLabel(for source: ClassificationDecisionSource?) -> String {
        switch source {
        case .rule:
            "Rule"
        case .curatedPrefill:
            "Curated starter match"
        case .heuristic:
            "Heuristic"
        case .suggestion:
            "Suggestion"
        case .user:
            "User"
        case nil:
            "Unclassified"
        }
    }

    private func starterHintLabel(for item: PendingReviewItem) -> String? {
        guard isCuratedPrefill(item) else {
            return nil
        }
        if let categoryName = starterHintCategoryName(for: item) {
            return "Starter hint: \(categoryName)"
        }
        return "Starter hint"
    }

    private func starterHintCategoryName(for item: PendingReviewItem) -> String? {
        guard let categoryID = item.classification?.prefill?.categoryID else {
            return nil
        }
        guard let categoryName = categoryNamesByID[categoryID]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !categoryName.isEmpty else {
            return nil
        }
        return categoryName
    }

    private func isCuratedPrefill(_ item: PendingReviewItem) -> Bool {
        item.classification?.source == .curatedPrefill
    }
}
