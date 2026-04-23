import Foundation

public struct WorkspaceInsightSummary: Equatable, Sendable {
    public var insights: [WorkspaceInsight]

    public init(insights: [WorkspaceInsight]) {
        self.insights = insights
    }

    public static let empty = WorkspaceInsightSummary(insights: [])
}

public struct WorkspaceInsight: Equatable, Sendable {
    public var kind: WorkspaceInsightKind
    public var confidence: Double
    public var rank: Int
    public var score: Double

    public init(
        kind: WorkspaceInsightKind,
        confidence: Double,
        rank: Int,
        score: Double
    ) {
        self.kind = kind
        self.confidence = confidence
        self.rank = rank
        self.score = score
    }
}

public enum WorkspaceInsightKind: Equatable, Sendable {
    case recurringCharge(RecurringChargeInsightDetail)
}
