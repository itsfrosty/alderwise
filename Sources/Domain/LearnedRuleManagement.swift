import Foundation

public enum LearnedRuleLifecycle: Equatable, Sendable {
    case active
    case disabled(disabledAt: Date)

    public var disabledAt: Date? {
        switch self {
        case .active:
            nil
        case .disabled(let disabledAt):
            disabledAt
        }
    }
}

public struct LearnedRuleSummary: Identifiable, Equatable, Sendable {
    public var id: UUID
    public var merchantPattern: String
    public var categoryID: UUID?
    public var merchantName: String?
    public var matchKind: ClassificationRuleMatchKind
    public var createdAt: Date
    public var lifecycle: LearnedRuleLifecycle

    public init(
        id: UUID,
        merchantPattern: String,
        categoryID: UUID?,
        merchantName: String?,
        matchKind: ClassificationRuleMatchKind,
        createdAt: Date,
        lifecycle: LearnedRuleLifecycle
    ) {
        self.id = id
        self.merchantPattern = merchantPattern
        self.categoryID = categoryID
        self.merchantName = merchantName
        self.matchKind = matchKind
        self.createdAt = createdAt
        self.lifecycle = lifecycle
    }

    public var isDisabled: Bool {
        if case .disabled = lifecycle {
            true
        } else {
            false
        }
    }

    public var disabledAt: Date? {
        lifecycle.disabledAt
    }
}

public struct ManagedLearnedRule: Identifiable, Equatable, Sendable {
    public var id: UUID
    public var merchantPattern: String
    public var categoryID: UUID?
    public var merchantName: String?
    public var matchKind: ClassificationRuleMatchKind
    public var createdAt: Date
    public var lifecycle: LearnedRuleLifecycle

    public init(
        id: UUID,
        merchantPattern: String,
        categoryID: UUID?,
        merchantName: String?,
        matchKind: ClassificationRuleMatchKind,
        createdAt: Date,
        lifecycle: LearnedRuleLifecycle
    ) {
        self.id = id
        self.merchantPattern = merchantPattern
        self.categoryID = categoryID
        self.merchantName = merchantName
        self.matchKind = matchKind
        self.createdAt = createdAt
        self.lifecycle = lifecycle
    }

    public var isDisabled: Bool {
        if case .disabled = lifecycle {
            true
        } else {
            false
        }
    }

    public var disabledAt: Date? {
        lifecycle.disabledAt
    }
}

public protocol LearnedRuleReading: Sendable {
    func fetchLearnedRuleSummaries() throws -> [LearnedRuleSummary]
    func fetchLearnedRuleSummary(id: UUID) throws -> LearnedRuleSummary?
    func fetchLearnedRuleDetail(id: UUID) throws -> ManagedLearnedRule?
}

public struct LearnedRuleImpactPreview: Equatable, Sendable {
    public var matchedAcceptedTransactionCount: Int
    public var matchedPendingReviewItemCount: Int

    public init(
        matchedAcceptedTransactionCount: Int,
        matchedPendingReviewItemCount: Int
    ) {
        self.matchedAcceptedTransactionCount = matchedAcceptedTransactionCount
        self.matchedPendingReviewItemCount = matchedPendingReviewItemCount
    }
}

public enum LearnedRuleImpactPreviewState: Equatable, Sendable {
    case ready(LearnedRuleImpactPreview)
    case noEligiblePreview
    case unavailable
}

public protocol LearnedRulePreviewReading: Sendable {
    func previewLearnedRuleImpact(
        reviewItemID: UUID,
        merchantPattern: String,
        matchKind: ClassificationRuleMatchKind
    ) throws -> LearnedRuleImpactPreview
}

public protocol LearnedRuleWriting: Sendable {
    func disableLearnedRule(id: UUID, disabledAt: Date) throws -> ManagedLearnedRule
    func enableLearnedRule(id: UUID) throws -> ManagedLearnedRule
}

public typealias LearnedRuleManaging = LearnedRuleReading & LearnedRuleWriting
