import Foundation

public enum InsightEvidenceScope: Equatable, Sendable {
    case workspace
    case category(UUID)
    case categoryGroup(UUID)
    case merchant(String)
    case uncategorized
    case account(UUID)
}

public enum InsightEvidenceReconciliationRule: Equatable, Sendable {
    case exactTransactionSum
    case recurringObservationSet
}

public struct InsightEvidenceDestination: Equatable, Sendable {
    public var scope: InsightEvidenceScope
    public var direction: TransactionDirection?

    public init(
        scope: InsightEvidenceScope,
        direction: TransactionDirection? = .expense
    ) {
        self.scope = scope
        self.direction = direction
    }
}

public struct InsightEvidence: Equatable, Sendable {
    public var metricBasis: ReportingExpenseBasis
    public var resolvedInterval: DateInterval
    public var scope: InsightEvidenceScope
    public var reconciliationRule: InsightEvidenceReconciliationRule
    public var destination: InsightEvidenceDestination

    public init(
        metricBasis: ReportingExpenseBasis,
        resolvedInterval: DateInterval,
        scope: InsightEvidenceScope,
        reconciliationRule: InsightEvidenceReconciliationRule,
        destination: InsightEvidenceDestination
    ) {
        self.metricBasis = metricBasis
        self.resolvedInterval = resolvedInterval
        self.scope = scope
        self.reconciliationRule = reconciliationRule
        self.destination = destination
    }
}
