import Foundation

public struct MonthlyReport: Equatable, Sendable {
    public var monthStart: Date
    public var currentMonthAcceptedSpend: Decimal
    public var lastMonthAcceptedSpend: Decimal
    public var pendingReviewCount: Int
    public var targets: [TargetProgress]

    public init(
        monthStart: Date,
        currentMonthAcceptedSpend: Decimal,
        lastMonthAcceptedSpend: Decimal,
        pendingReviewCount: Int,
        targets: [TargetProgress]
    ) {
        self.monthStart = monthStart
        self.currentMonthAcceptedSpend = currentMonthAcceptedSpend
        self.lastMonthAcceptedSpend = lastMonthAcceptedSpend
        self.pendingReviewCount = pendingReviewCount
        self.targets = targets
    }

    public static let empty = MonthlyReport(
        monthStart: Date(timeIntervalSince1970: 0),
        currentMonthAcceptedSpend: 0,
        lastMonthAcceptedSpend: 0,
        pendingReviewCount: 0,
        targets: []
    )
}

public enum TargetScope: Equatable, Sendable {
    case category(UUID)
    case categoryGroup(UUID)
}

public struct MonthlyTargetDraft: Equatable, Sendable {
    public var scope: TargetScope
    public var monthlyLimit: Decimal

    public init(scope: TargetScope, monthlyLimit: Decimal) {
        self.scope = scope
        self.monthlyLimit = monthlyLimit
    }
}

public struct MonthlyTarget: Identifiable, Equatable, Sendable {
    public var id: UUID
    public var scope: TargetScope
    public var monthlyLimit: Decimal
    public var createdAt: Date

    public init(id: UUID, scope: TargetScope, monthlyLimit: Decimal, createdAt: Date) {
        self.id = id
        self.scope = scope
        self.monthlyLimit = monthlyLimit
        self.createdAt = createdAt
    }
}

public struct TargetProgress: Identifiable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var scope: TargetScope
    public var monthlyLimit: Decimal
    public var spent: Decimal
    public var remaining: Decimal
    public var paceDelta: Decimal

    public init(
        id: UUID,
        name: String,
        scope: TargetScope,
        monthlyLimit: Decimal,
        spent: Decimal,
        remaining: Decimal,
        paceDelta: Decimal
    ) {
        self.id = id
        self.name = name
        self.scope = scope
        self.monthlyLimit = monthlyLimit
        self.spent = spent
        self.remaining = remaining
        self.paceDelta = paceDelta
    }
}
