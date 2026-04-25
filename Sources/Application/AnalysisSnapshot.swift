import Domain
import Foundation

public struct AnalysisSnapshot: Equatable, Sendable {
    public var overview: AnalysisOverviewSnapshot?
    public var categories: AnalysisCategoriesSnapshot?
    public var merchants: AnalysisMerchantsSnapshot?

    public init(
        overview: AnalysisOverviewSnapshot? = nil,
        categories: AnalysisCategoriesSnapshot? = nil,
        merchants: AnalysisMerchantsSnapshot? = nil
    ) {
        self.overview = overview
        self.categories = categories
        self.merchants = merchants
    }

    public static let empty = AnalysisSnapshot()
}

public struct AnalysisOverviewSnapshot: Equatable, Sendable {
    public var context: AnalysisContext
    public var report: OverviewReport
    public var monthlyReport: MonthlyReport
    public var projectedInsights: [WorkspaceInsight]

    public init(
        context: AnalysisContext,
        report: OverviewReport,
        monthlyReport: MonthlyReport,
        projectedInsights: [WorkspaceInsight]
    ) {
        self.context = context
        self.report = report
        self.monthlyReport = monthlyReport
        self.projectedInsights = projectedInsights
    }

    public func transactionFilter(
        for selection: AnalysisOverviewSelection
    ) -> TransactionLedgerFilter {
        AnalysisDrilldownTranslator.translate(
            context: context,
            evidence: selection.evidence
        )
    }
}

public enum AnalysisOverviewSelection: Equatable, Sendable {
    case insight(WorkspaceInsight)
    case driver(AnalysisSpendRow)
    case recurring(MerchantRecurringReportRow)

    public var evidence: InsightEvidence {
        switch self {
        case .insight(let insight):
            insight.evidence
        case .driver(let row):
            row.evidence
        case .recurring(let row):
            row.evidence
        }
    }
}

public struct AnalysisCategoriesSnapshot: Equatable, Sendable {
    public var context: AnalysisContext
    public var report: CategoryAnalysisReport
    public var targetProgress: [TargetProgress]

    public init(
        context: AnalysisContext,
        report: CategoryAnalysisReport,
        targetProgress: [TargetProgress]
    ) {
        self.context = context
        self.report = report
        self.targetProgress = targetProgress
    }

    public func transactionFilter(
        for selection: AnalysisCategoriesSelection
    ) -> TransactionLedgerFilter {
        AnalysisDrilldownTranslator.translate(context: context, evidence: selection.evidence)
    }

    public func targetProgress(
        for selection: AnalysisCategoriesSelection
    ) -> TargetProgress? {
        switch selection {
        case .row(let row):
            return targetProgress.first(where: { target in
                analysisTargetScopeMatches(target.scope, evidenceScope: row.scope)
            })
        }
    }
}

public enum AnalysisCategoriesSelection: Equatable, Sendable {
    case row(AnalysisSpendRow)

    public var evidence: InsightEvidence {
        switch self {
        case .row(let row):
            row.evidence
        }
    }
}

public struct AnalysisMerchantsSnapshot: Equatable, Sendable {
    public var context: AnalysisContext
    public var report: MerchantAnalysisReport

    public init(
        context: AnalysisContext,
        report: MerchantAnalysisReport
    ) {
        self.context = context
        self.report = report
    }

    public func transactionFilter(
        for selection: AnalysisMerchantsSelection
    ) -> TransactionLedgerFilter {
        AnalysisDrilldownTranslator.translate(context: context, evidence: selection.evidence)
    }
}

public enum AnalysisMerchantsSelection: Equatable, Sendable {
    case merchant(MerchantAnalysisRow)
    case recurring(MerchantRecurringReportRow)

    public var evidence: InsightEvidence {
        switch self {
        case .merchant(let row):
            row.evidence
        case .recurring(let row):
            row.evidence
        }
    }
}

private func analysisTargetScopeMatches(
    _ targetScope: TargetScope,
    evidenceScope: InsightEvidenceScope
) -> Bool {
    switch (targetScope, evidenceScope) {
    case (.category(let lhs), .category(let rhs)):
        return lhs == rhs
    case (.categoryGroup(let lhs), .categoryGroup(let rhs)):
        return lhs == rhs
    default:
        return false
    }
}
