import Domain
import Foundation

public struct ReviewPresentation: Sendable {
    public struct ConsequenceLine: Equatable, Sendable {
        public enum Emphasis: Equatable, Sendable {
            case neutral
            case warning
        }

        public let text: String
        public let emphasis: Emphasis

        public init(text: String, emphasis: Emphasis) {
            self.text = text
            self.emphasis = emphasis
        }
    }

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
            return "\(RuleDisplayText.builtInReviewFirst) suggested category: \(categoryName). Review before accepting."
        }
        return "\(RuleDisplayText.builtInReviewFirst) suggestion. Review before accepting."
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

    public func staticConsequences(
        for item: PendingReviewItem,
        createRule: Bool,
        selectedRuleLearning: ReviewRuleLearningOption?
    ) -> [ConsequenceLine] {
        var lines: [ConsequenceLine] = []

        if isCuratedPrefill(item) {
            lines.append(
                ConsequenceLine(
                    text: "\(RuleDisplayText.builtInReviewFirst) suggestions stay review-only until you approve them.",
                    emphasis: .neutral
                )
            )
        }

        guard createRule,
              let selectedRuleLearning = resolvedRuleLearningSelection(
                  for: item,
                  selectedRuleLearning: selectedRuleLearning
              ) else {
            lines.append(
                ConsequenceLine(
                    text: "Approving updates this transaction only. No learned rule will be created.",
                    emphasis: .neutral
                )
            )
            return lines
        }

        lines.append(learnedRuleCreationConsequence(for: selectedRuleLearning))

        if case .prefixNormalizedMerchant(let pattern) = selectedRuleLearning {
            lines.append(
                ConsequenceLine(
                    text: "Shared prefix can match multiple future merchants that start with \(pattern).",
                    emphasis: .warning
                )
            )
        }

        return lines
    }

    public static func sourceLabel(for source: ClassificationDecisionSource?) -> String {
        switch source {
        case .rule:
            "Rule"
        case .curatedPrefill:
            RuleDisplayText.builtInReviewFirst
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
            return "\(RuleDisplayText.builtInReviewFirst): \(categoryName)"
        }
        return RuleDisplayText.builtInReviewFirst
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

    private func learnedRuleCreationConsequence(
        for option: ReviewRuleLearningOption
    ) -> ConsequenceLine {
        switch option {
        case .exactNormalizedMerchant(let pattern):
            ConsequenceLine(
                text: "Approving saves an \(option.title) rule in \(RuleDisplayText.yourRules) for \(pattern).",
                emphasis: .neutral
            )
        case .prefixNormalizedMerchant(let pattern):
            ConsequenceLine(
                text: "Approving saves a \(option.title) rule in \(RuleDisplayText.yourRules) for \(pattern).",
                emphasis: .neutral
            )
        }
    }
}
