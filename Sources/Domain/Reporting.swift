import Foundation

public enum ReportingExpenseBasis: String, Equatable, Sendable {
    case includedVisibleExpenses
    case acceptedExpenses
}

public struct MonthlyReport: Equatable, Sendable {
    public var monthStart: Date
    public var currentMonthAcceptedSpend: Decimal
    public var lastMonthAcceptedSpend: Decimal
    public var expenseBasis: ReportingExpenseBasis
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
        expenseBasis: ReportingExpenseBasis = .includedVisibleExpenses,
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
        self.expenseBasis = expenseBasis
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

    public var currentMonthIncludedVisibleSpend: Decimal {
        currentMonthAcceptedSpend
    }

    public var lastMonthIncludedVisibleSpend: Decimal {
        lastMonthAcceptedSpend
    }

    public static let empty = MonthlyReport(
        monthStart: Date(timeIntervalSince1970: 0),
        currentMonthAcceptedSpend: 0,
        lastMonthAcceptedSpend: 0,
        expenseBasis: .includedVisibleExpenses,
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
/// Categories without a group remain category-scoped so every included expense can still
/// participate in driver analysis without downstream re-aggregation.
public enum SpendingDriverScope: Hashable, Sendable {
    case category(UUID)
    case categoryGroup(UUID)
    case uncategorized
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

public struct TargetHistoryMonth: Equatable, Sendable {
    public var monthStart: Date
    public var spent: Decimal
    public var monthlyLimit: Decimal

    public init(monthStart: Date, spent: Decimal, monthlyLimit: Decimal) {
        self.monthStart = monthStart
        self.spent = spent
        self.monthlyLimit = monthlyLimit
    }

    public var overshoot: Decimal {
        max(spent - monthlyLimit, .zero)
    }

    public var hit: Bool {
        spent <= monthlyLimit
    }
}

public struct TargetHistorySummary: Equatable, Sendable {
    public var months: [TargetHistoryMonth]
    public var hitRate: Decimal
    public var overshootRate: Decimal
    public var averageSpend: Decimal
    public var averageOvershoot: Decimal

    public init(
        months: [TargetHistoryMonth],
        hitRate: Decimal,
        overshootRate: Decimal,
        averageSpend: Decimal,
        averageOvershoot: Decimal
    ) {
        self.months = months
        self.hitRate = hitRate
        self.overshootRate = overshootRate
        self.averageSpend = averageSpend
        self.averageOvershoot = averageOvershoot
    }

    public static let empty = TargetHistorySummary(
        months: [],
        hitRate: .zero,
        overshootRate: .zero,
        averageSpend: .zero,
        averageOvershoot: .zero
    )
}

public enum TargetCalibrationDirection: Equatable, Sendable {
    case increase
    case decrease
}

public struct TargetCalibrationSuggestion: Equatable, Sendable {
    public var recommendedMonthlyLimit: Decimal
    public var direction: TargetCalibrationDirection
    public var delta: Decimal

    public init(
        recommendedMonthlyLimit: Decimal,
        direction: TargetCalibrationDirection,
        delta: Decimal
    ) {
        self.recommendedMonthlyLimit = recommendedMonthlyLimit
        self.direction = direction
        self.delta = delta
    }
}
