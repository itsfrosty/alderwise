import Foundation

public struct AnalysisSpendRow: Equatable, Sendable {
    public var title: String
    public var scope: InsightEvidenceScope
    public var currentSpend: Decimal
    public var comparisonSpend: Decimal
    public var delta: Decimal
    public var evidence: InsightEvidence

    public init(
        title: String,
        scope: InsightEvidenceScope,
        currentSpend: Decimal,
        comparisonSpend: Decimal,
        delta: Decimal,
        evidence: InsightEvidence
    ) {
        self.title = title
        self.scope = scope
        self.currentSpend = currentSpend
        self.comparisonSpend = comparisonSpend
        self.delta = delta
        self.evidence = evidence
    }
}

/// V1 merchant reporting identity is the normalized merchant name already stored on
/// transactions. Keep the contract explicit so later aliasing or merged-identity work
/// can replace this key without rewriting the analysis UI surface.
public struct MerchantReportKey: Hashable, Equatable, Sendable {
    public var normalizedName: String

    public init(normalizedName: String) {
        self.normalizedName = normalizedName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}

public struct MerchantAnalysisRow: Equatable, Sendable {
    public var key: MerchantReportKey
    public var title: String
    public var currentSpend: Decimal
    public var comparisonSpend: Decimal
    public var delta: Decimal
    public var evidence: InsightEvidence

    public init(
        key: MerchantReportKey,
        title: String,
        currentSpend: Decimal,
        comparisonSpend: Decimal,
        delta: Decimal,
        evidence: InsightEvidence
    ) {
        self.key = key
        self.title = title
        self.currentSpend = currentSpend
        self.comparisonSpend = comparisonSpend
        self.delta = delta
        self.evidence = evidence
    }
}

public struct MerchantRecurringReportRow: Equatable, Sendable {
    public var detail: RecurringChargeInsightDetail
    public var evidence: InsightEvidence

    public init(detail: RecurringChargeInsightDetail, evidence: InsightEvidence) {
        self.detail = detail
        self.evidence = evidence
    }
}

public struct OverviewReport: Equatable, Sendable {
    public var context: AnalysisContext
    public var currentSpend: Decimal
    public var comparisonSpend: Decimal?
    public var drivers: [AnalysisSpendRow]
    public var recurring: [MerchantRecurringReportRow]

    public init(
        context: AnalysisContext,
        currentSpend: Decimal,
        comparisonSpend: Decimal?,
        drivers: [AnalysisSpendRow],
        recurring: [MerchantRecurringReportRow]
    ) {
        self.context = context
        self.currentSpend = currentSpend
        self.comparisonSpend = comparisonSpend
        self.drivers = drivers
        self.recurring = recurring
    }
}

public struct CategoryAnalysisReport: Equatable, Sendable {
    public var context: AnalysisContext
    public var rows: [AnalysisSpendRow]

    public init(context: AnalysisContext, rows: [AnalysisSpendRow]) {
        self.context = context
        self.rows = rows
    }
}

public struct MerchantAnalysisReport: Equatable, Sendable {
    public var context: AnalysisContext
    public var merchants: [MerchantAnalysisRow]
    public var recurring: [MerchantRecurringReportRow]

    public init(
        context: AnalysisContext,
        merchants: [MerchantAnalysisRow],
        recurring: [MerchantRecurringReportRow]
    ) {
        self.context = context
        self.merchants = merchants
        self.recurring = recurring
    }
}
