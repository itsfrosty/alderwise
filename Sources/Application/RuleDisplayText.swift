import Domain

public enum RuleDisplayText {
    public static let yourRules = "Your Rules"
    public static let builtInAutoApplied = "Built-In Auto-Applied"
    public static let builtInReviewFirst = "Built-In Review-First"
    public static let matchedBy = "Matched by"

    public static func matchScopeLabel(for matchKind: ClassificationRuleMatchKind) -> String {
        switch matchKind {
        case .contains:
            "Contains"
        case .exactNormalizedMerchant:
            "Exact merchant"
        case .prefixNormalizedMerchant:
            "Shared prefix"
        }
    }
}

public extension ClassificationRuleMatchKind {
    var ruleDisplayLabel: String {
        RuleDisplayText.matchScopeLabel(for: self)
    }
}
