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

public struct LearnedRulesDestination: Equatable, Sendable {
    public var mode: LearnedRuleManagerMode
    public var selectedLearnedRuleID: UUID?

    public init(mode: LearnedRuleManagerMode, selectedLearnedRuleID: UUID? = nil) {
        self.mode = mode
        self.selectedLearnedRuleID = selectedLearnedRuleID
    }
}

public enum SettingsSidebarDestination: Hashable, Sendable {
    case overview
    case backupsAndRecovery
    case rules
}

public enum SettingsDestination: Equatable, Sendable {
    case overview
    case backupsAndRecovery
    case rules(LearnedRulesDestination)

    public var sidebarDestination: SettingsSidebarDestination {
        switch self {
        case .overview:
            .overview
        case .backupsAndRecovery:
            .backupsAndRecovery
        case .rules:
            .rules
        }
    }

    public static func learnedRulesRoute(selectedLearnedRuleID: UUID? = nil) -> SettingsDestination {
        .rules(
            LearnedRulesDestination(
                mode: .learned,
                selectedLearnedRuleID: selectedLearnedRuleID
            )
        )
    }
}
