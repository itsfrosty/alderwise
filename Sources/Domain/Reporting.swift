import Foundation

public struct MonthlyReport: Equatable, Sendable {
    public var monthStart: Date
    public var currentMonthAcceptedSpend: Decimal
    public var lastMonthAcceptedSpend: Decimal
    public var pendingReviewCount: Int
    public var targets: [TargetProgress]
    public var hasActiveTargets: Bool
    public var totalMonthlyTargetLimit: Decimal
    public var expectedPaceSpend: Decimal
    public var paceDelta: Decimal
    public var paceSeries: [MonthlySpendPoint]
    public var drivers: [MonthlySpendingDriver]
    public var biggestShift: MonthlySpendingDriver?

    public init(
        monthStart: Date,
        currentMonthAcceptedSpend: Decimal,
        lastMonthAcceptedSpend: Decimal,
        pendingReviewCount: Int,
        targets: [TargetProgress],
        hasActiveTargets: Bool,
        totalMonthlyTargetLimit: Decimal,
        expectedPaceSpend: Decimal,
        paceDelta: Decimal,
        paceSeries: [MonthlySpendPoint],
        drivers: [MonthlySpendingDriver],
        biggestShift: MonthlySpendingDriver?
    ) {
        self.monthStart = monthStart
        self.currentMonthAcceptedSpend = currentMonthAcceptedSpend
        self.lastMonthAcceptedSpend = lastMonthAcceptedSpend
        self.pendingReviewCount = pendingReviewCount
        self.targets = targets
        self.hasActiveTargets = hasActiveTargets
        self.totalMonthlyTargetLimit = totalMonthlyTargetLimit
        self.expectedPaceSpend = expectedPaceSpend
        self.paceDelta = paceDelta
        self.paceSeries = paceSeries
        self.drivers = drivers
        self.biggestShift = biggestShift
    }

    public static let empty = MonthlyReport(
        monthStart: Date(timeIntervalSince1970: 0),
        currentMonthAcceptedSpend: 0,
        lastMonthAcceptedSpend: 0,
        pendingReviewCount: 0,
        targets: [],
        hasActiveTargets: false,
        totalMonthlyTargetLimit: 0,
        expectedPaceSpend: 0,
        paceDelta: 0,
        paceSeries: [],
        drivers: [],
        biggestShift: nil
    )
}

public struct MonthlySpendPoint: Equatable, Sendable {
    public var day: Int
    public var actualSpend: Decimal
    public var expectedSpend: Decimal

    public init(day: Int, actualSpend: Decimal, expectedSpend: Decimal) {
        self.day = day
        self.actualSpend = actualSpend
        self.expectedSpend = expectedSpend
    }
}

/// Reporting emits driver rows at the category-group level when possible for readability.
/// Categories without a group remain category-scoped so every accepted expense can still
/// participate in driver analysis without downstream re-aggregation.
public enum SpendingDriverScope: Hashable, Sendable {
    case category(UUID)
    case categoryGroup(UUID)

    public var categoryID: UUID? {
        switch self {
        case .category(let id):
            return id
        case .categoryGroup:
            return nil
        }
    }

    public var categoryGroupID: UUID? {
        switch self {
        case .category:
            return nil
        case .categoryGroup(let id):
            return id
        }
    }
}

public struct MonthlySpendingDriver: Equatable, Sendable {
    public var title: String
    public var scope: SpendingDriverScope
    public var currentPeriodSpend: Decimal
    public var comparisonPeriodSpend: Decimal
    public var delta: Decimal

    public init(
        title: String,
        scope: SpendingDriverScope,
        currentPeriodSpend: Decimal,
        comparisonPeriodSpend: Decimal,
        delta: Decimal
    ) {
        self.title = title
        self.scope = scope
        self.currentPeriodSpend = currentPeriodSpend
        self.comparisonPeriodSpend = comparisonPeriodSpend
        self.delta = delta
    }
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
