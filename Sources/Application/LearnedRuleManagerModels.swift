import Domain
import Foundation

public enum LearnedRuleManagerMode: Equatable, Sendable {
    case learned
    case seeded
}

public enum SeededRuleSourceKind: Equatable, Sendable {
    case deterministicRule
    case curatedPrefill
}

public struct ManagedLearnedRuleRow: Identifiable, Equatable, Sendable {
    public var id: UUID
    public var merchantPattern: String
    public var categoryID: UUID?
    public var merchantName: String?
    public var matchKind: ClassificationRuleMatchKind
    public var createdAt: Date
    public var isDisabled: Bool
    public var disabledAt: Date?

    public init(
        id: UUID,
        merchantPattern: String,
        categoryID: UUID?,
        merchantName: String?,
        matchKind: ClassificationRuleMatchKind,
        createdAt: Date,
        isDisabled: Bool,
        disabledAt: Date?
    ) {
        self.id = id
        self.merchantPattern = merchantPattern
        self.categoryID = categoryID
        self.merchantName = merchantName
        self.matchKind = matchKind
        self.createdAt = createdAt
        self.isDisabled = isDisabled
        self.disabledAt = disabledAt
    }

    public init(summary: LearnedRuleSummary) {
        self.init(
            id: summary.id,
            merchantPattern: summary.merchantPattern,
            categoryID: summary.categoryID,
            merchantName: summary.merchantName,
            matchKind: summary.matchKind,
            createdAt: summary.createdAt,
            isDisabled: summary.isDisabled,
            disabledAt: summary.disabledAt
        )
    }

    public init(rule: ManagedLearnedRule) {
        self.init(
            id: rule.id,
            merchantPattern: rule.merchantPattern,
            categoryID: rule.categoryID,
            merchantName: rule.merchantName,
            matchKind: rule.matchKind,
            createdAt: rule.createdAt,
            isDisabled: rule.isDisabled,
            disabledAt: rule.disabledAt
        )
    }

    public static var sectionTitle: String {
        RuleDisplayText.yourRules
    }

    public static var detailSourceText: String {
        "Learned from Review"
    }
}

public struct SeededRuleSourceRow: Identifiable, Equatable, Sendable {
    public var id: String
    public var merchantPattern: String
    public var categoryID: UUID
    public var merchantName: String?
    public var matchKind: ClassificationRuleMatchKind
    public var sourceKind: SeededRuleSourceKind

    public init(
        id: String,
        merchantPattern: String,
        categoryID: UUID,
        merchantName: String?,
        matchKind: ClassificationRuleMatchKind,
        sourceKind: SeededRuleSourceKind
    ) {
        self.id = id
        self.merchantPattern = merchantPattern
        self.categoryID = categoryID
        self.merchantName = merchantName
        self.matchKind = matchKind
        self.sourceKind = sourceKind
    }
}

public struct LearnedRuleManagerSectionSnapshot<Row: Equatable & Sendable>: Equatable, Sendable {
    public var mode: LearnedRuleManagerMode
    public var rows: [Row]

    public init(mode: LearnedRuleManagerMode, rows: [Row]) {
        self.mode = mode
        self.rows = rows
    }
}

public struct LearnedRuleManagerSnapshot: Equatable, Sendable {
    public var learned: LearnedRuleManagerSectionSnapshot<ManagedLearnedRuleRow>
    public var seeded: LearnedRuleManagerSectionSnapshot<SeededRuleSourceRow>

    public init(
        learned: LearnedRuleManagerSectionSnapshot<ManagedLearnedRuleRow>,
        seeded: LearnedRuleManagerSectionSnapshot<SeededRuleSourceRow>
    ) {
        self.learned = learned
        self.seeded = seeded
    }
}

public enum LearnedRuleDraftSheetMode: Equatable, Sendable {
    case newRule
    case duplicateRule(sourceRuleID: UUID)
}

public struct LearnedRuleDraftSheet: Identifiable, Equatable, Sendable {
    public static let basicAllowedMatchKinds: [ClassificationRuleMatchKind] = [
        .exactNormalizedMerchant,
        .prefixNormalizedMerchant,
    ]
    public static let unsupportedMatchKindMessage = "Contains rules are not available in manual authoring yet."

    public var id: UUID
    public var mode: LearnedRuleDraftSheetMode
    public var draft: LearnedRuleDraft

    public init(
        id: UUID = UUID(),
        mode: LearnedRuleDraftSheetMode,
        draft: LearnedRuleDraft
    ) {
        self.id = id
        self.mode = mode
        self.draft = draft
    }

    public static func newRule(
        id: UUID = UUID(),
        draft: LearnedRuleDraft = LearnedRuleDraft()
    ) -> LearnedRuleDraftSheet {
        LearnedRuleDraftSheet(id: id, mode: .newRule, draft: draft)
    }

    public static func duplicateRule(
        sourceRuleID: UUID,
        draft: LearnedRuleDraft,
        id: UUID = UUID()
    ) -> LearnedRuleDraftSheet {
        LearnedRuleDraftSheet(
            id: id,
            mode: .duplicateRule(sourceRuleID: sourceRuleID),
            draft: draft
        )
    }

    public var title: String {
        switch mode {
        case .newRule:
            "New Rule"
        case .duplicateRule:
            "Duplicate Rule"
        }
    }

    public var confirmationTitle: String {
        switch mode {
        case .newRule:
            "Save Rule"
        case .duplicateRule:
            "Save Duplicate"
        }
    }

    public var allowedMatchKinds: [ClassificationRuleMatchKind] {
        Self.basicAllowedMatchKinds
    }

    public static func supportsBasicManualAuthoring(
        matchKind: ClassificationRuleMatchKind
    ) -> Bool {
        basicAllowedMatchKinds.contains(matchKind)
    }

    public var canSave: Bool {
        draft.categoryID != nil
            && draft.normalizedMerchantPattern != nil
            && allowedMatchKinds.contains(draft.matchKind)
    }
}

public struct LearnedRulesDestination: Equatable, Sendable {
    public var mode: LearnedRuleManagerMode
    public var selectedLearnedRuleID: UUID?

    public init(mode: LearnedRuleManagerMode, selectedLearnedRuleID: UUID? = nil) {
        self.mode = mode
        self.selectedLearnedRuleID = selectedLearnedRuleID
    }
}

public enum SettingsDestination: Equatable, Sendable {
    case overview
    case learnedRules(LearnedRulesDestination)

    public static func learnedRulesRoute(selectedLearnedRuleID: UUID? = nil) -> SettingsDestination {
        .learnedRules(
            LearnedRulesDestination(
                mode: .learned,
                selectedLearnedRuleID: selectedLearnedRuleID
            )
        )
    }
}

public extension SeededRuleSourceKind {
    var sectionTitle: String {
        switch self {
        case .deterministicRule:
            RuleDisplayText.builtInAutoApplied
        case .curatedPrefill:
            RuleDisplayText.builtInReviewFirst
        }
    }

    var detailSourceTypeText: String {
        switch self {
        case .deterministicRule:
            "Built-In Auto-Applied rule"
        case .curatedPrefill:
            "Built-In Review-First hint"
        }
    }
}
