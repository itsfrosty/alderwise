import Foundation

public enum AnalysisRange: Equatable, Sendable {
    case monthToDate
    case lastFullMonth
    case yearToDate
    case custom(DateInterval)
}

public enum AnalysisScope: Equatable, Sendable {
    case workspace
    case category(UUID)
    case categoryGroup(UUID)
    case merchant(String)
    case account(UUID)
}

public enum AnalysisComparisonMode: Equatable, Sendable {
    case none
    case previousPeriod
    case samePeriodLastYear
    case rollingAverage(months: Int)
}

public struct AnalysisQualifiers: Equatable, Sendable {
    public var visibility: TransactionVisibilityFilter
    public var reviewStatus: TransactionReviewStatus?
    public var uncategorizedOnly: Bool
    public var recurringOnly: Bool

    public init(
        visibility: TransactionVisibilityFilter = .active,
        reviewStatus: TransactionReviewStatus? = nil,
        uncategorizedOnly: Bool = false,
        recurringOnly: Bool = false
    ) {
        self.visibility = visibility
        self.reviewStatus = reviewStatus
        self.uncategorizedOnly = uncategorizedOnly
        self.recurringOnly = recurringOnly
    }
}

public struct AnalysisContext: Equatable, Sendable {
    public var range: AnalysisRange
    public var resolvedInterval: DateInterval?
    public var scope: AnalysisScope
    public var comparison: AnalysisComparisonMode
    public var metricBasis: ReportingExpenseBasis
    public var qualifiers: AnalysisQualifiers

    public init(
        range: AnalysisRange = .monthToDate,
        resolvedInterval: DateInterval? = nil,
        scope: AnalysisScope = .workspace,
        comparison: AnalysisComparisonMode = .none,
        metricBasis: ReportingExpenseBasis = .includedVisibleExpenses,
        qualifiers: AnalysisQualifiers = AnalysisQualifiers()
    ) {
        self.range = range
        self.resolvedInterval = resolvedInterval
        self.scope = scope
        self.comparison = comparison
        self.metricBasis = metricBasis
        self.qualifiers = qualifiers
    }
}
