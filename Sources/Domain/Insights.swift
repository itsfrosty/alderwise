import Foundation

public struct WorkspaceInsightSummary: Equatable, Sendable {
    public var insights: [WorkspaceInsight]
    public var homeProjectedInsights: [WorkspaceInsight]
    public var homeProjectionCaps: WorkspaceInsightProjectionCaps

    public init(
        insights: [WorkspaceInsight],
        homeProjectedInsights: [WorkspaceInsight]? = nil,
        homeProjectionCaps: WorkspaceInsightProjectionCaps = .phase1Home
    ) {
        self.insights = insights
        self.homeProjectionCaps = homeProjectionCaps
        self.homeProjectedInsights = homeProjectedInsights
            ?? WorkspaceInsightProjectionPolicy.projectHome(from: insights, caps: homeProjectionCaps)
    }

    public static let empty = WorkspaceInsightSummary(insights: [])
}

public struct WorkspaceInsight: Equatable, Sendable {
    public var kind: WorkspaceInsightKind
    public var confidence: Double
    public var rank: Int
    public var score: Double
    public var suppressionKey: String
    public var evidence: InsightEvidence
    public var tieBreaker: WorkspaceInsightTieBreaker

    public var family: WorkspaceInsightFamily {
        switch kind {
        case .recurringCharge:
            .recurringCharge
        case .spendDriverChange:
            .spendDriverChange
        }
    }

    public init(
        kind: WorkspaceInsightKind,
        confidence: Double,
        rank: Int,
        score: Double,
        suppressionKey: String,
        evidence: InsightEvidence,
        tieBreaker: WorkspaceInsightTieBreaker
    ) {
        self.kind = kind
        self.confidence = confidence
        self.rank = rank
        self.score = score
        self.suppressionKey = suppressionKey
        self.evidence = evidence
        self.tieBreaker = tieBreaker
    }
}

public enum WorkspaceInsightKind: Equatable, Sendable {
    case recurringCharge(RecurringChargeInsightDetail)
    case spendDriverChange(SpendDriverChangeInsightDetail)
}

public enum WorkspaceInsightFamily: String, Equatable, Sendable {
    case recurringCharge
    case spendDriverChange
}

public struct WorkspaceInsightTieBreaker: Equatable, Sendable {
    public var primaryDate: Date?
    public var secondaryKey: String
    public var tertiaryKey: String

    public init(
        primaryDate: Date?,
        secondaryKey: String,
        tertiaryKey: String
    ) {
        self.primaryDate = primaryDate
        self.secondaryKey = secondaryKey
        self.tertiaryKey = tertiaryKey
    }
}

public struct WorkspaceInsightCandidate: Equatable, Sendable {
    public var kind: WorkspaceInsightKind
    public var confidence: Double
    public var score: Double
    public var suppressionKey: String
    public var evidence: InsightEvidence
    public var tieBreaker: WorkspaceInsightTieBreaker

    public var family: WorkspaceInsightFamily {
        switch kind {
        case .recurringCharge:
            .recurringCharge
        case .spendDriverChange:
            .spendDriverChange
        }
    }

    public init(
        kind: WorkspaceInsightKind,
        confidence: Double,
        score: Double,
        suppressionKey: String,
        evidence: InsightEvidence,
        tieBreaker: WorkspaceInsightTieBreaker
    ) {
        self.kind = kind
        self.confidence = confidence
        self.score = score
        self.suppressionKey = suppressionKey
        self.evidence = evidence
        self.tieBreaker = tieBreaker
    }
}

public struct WorkspaceInsightProjectionCaps: Equatable, Sendable {
    public var homeMaxTotal: Int
    public var homeMaxPerFamily: Int

    public init(homeMaxTotal: Int, homeMaxPerFamily: Int) {
        self.homeMaxTotal = homeMaxTotal
        self.homeMaxPerFamily = homeMaxPerFamily
    }

    public static let phase1Home = WorkspaceInsightProjectionCaps(
        homeMaxTotal: 3,
        homeMaxPerFamily: 1
    )
}

public enum WorkspaceInsightRanker {
    public static func rankPhase1(_ candidates: [WorkspaceInsightCandidate]) -> [WorkspaceInsight] {
        candidates
            .sorted(by: compareCandidates)
            .enumerated()
            .map { index, candidate in
                WorkspaceInsight(
                    kind: candidate.kind,
                    confidence: candidate.confidence,
                    rank: index + 1,
                    score: candidate.score,
                    suppressionKey: candidate.suppressionKey,
                    evidence: candidate.evidence,
                    tieBreaker: candidate.tieBreaker
                )
            }
    }

    private static func compareCandidates(
        _ lhs: WorkspaceInsightCandidate,
        _ rhs: WorkspaceInsightCandidate
    ) -> Bool {
        if lhs.score != rhs.score {
            return lhs.score > rhs.score
        }
        if lhs.confidence != rhs.confidence {
            return lhs.confidence > rhs.confidence
        }
        if lhs.tieBreaker.primaryDate != rhs.tieBreaker.primaryDate {
            return (lhs.tieBreaker.primaryDate ?? .distantPast) > (rhs.tieBreaker.primaryDate ?? .distantPast)
        }
        if lhs.tieBreaker.secondaryKey != rhs.tieBreaker.secondaryKey {
            let lhsKey = lhs.tieBreaker.secondaryKey.lowercased()
            let rhsKey = rhs.tieBreaker.secondaryKey.lowercased()
            if lhsKey != rhsKey {
                return lhsKey < rhsKey
            }
            return lhs.tieBreaker.secondaryKey < rhs.tieBreaker.secondaryKey
        }
        let lhsKey = lhs.tieBreaker.tertiaryKey.lowercased()
        let rhsKey = rhs.tieBreaker.tertiaryKey.lowercased()
        if lhsKey != rhsKey {
            return lhsKey < rhsKey
        }
        return lhs.tieBreaker.tertiaryKey < rhs.tieBreaker.tertiaryKey
    }
}

public enum WorkspaceInsightProjectionPolicy {
    public static func projectHome(
        from rankedInsights: [WorkspaceInsight],
        caps: WorkspaceInsightProjectionCaps = .phase1Home
    ) -> [WorkspaceInsight] {
        var projected: [WorkspaceInsight] = []
        var projectedFamilies: [WorkspaceInsightFamily: Int] = [:]
        var projectedSuppressionKeys = Set<String>()

        for insight in rankedInsights {
            if projected.count >= caps.homeMaxTotal {
                break
            }
            if projectedSuppressionKeys.contains(insight.suppressionKey) {
                continue
            }
            if projectedFamilies[insight.family, default: 0] >= caps.homeMaxPerFamily {
                continue
            }
            projected.append(insight)
            projectedFamilies[insight.family, default: 0] += 1
            projectedSuppressionKeys.insert(insight.suppressionKey)
        }

        return projected
    }
}

public struct SpendDriverChangeInsightDetail: Equatable, Sendable {
    public var title: String
    public var scope: SpendingDriverScope
    public var currentSpend: Decimal
    public var comparisonSpend: Decimal
    public var delta: Decimal

    public init(
        title: String,
        scope: SpendingDriverScope,
        currentSpend: Decimal,
        comparisonSpend: Decimal,
        delta: Decimal
    ) {
        self.title = title
        self.scope = scope
        self.currentSpend = currentSpend
        self.comparisonSpend = comparisonSpend
        self.delta = delta
    }
}
