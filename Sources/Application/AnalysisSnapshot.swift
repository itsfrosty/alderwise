import Domain
import Foundation

public struct AnalysisSnapshot: Equatable, Sendable {
    public var overview: AnalysisOverviewSnapshot?

    public init(overview: AnalysisOverviewSnapshot? = nil) {
        self.overview = overview
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

    public var title: String {
        switch self {
        case .insight(let insight):
            switch insight.kind {
            case .recurringCharge(let detail):
                detail.normalizedMerchantName.localizedCapitalized
            case .spendDriverChange(let detail):
                detail.title
            }
        case .driver(let row):
            row.title
        case .recurring(let row):
            row.detail.normalizedMerchantName.localizedCapitalized
        }
    }
}
