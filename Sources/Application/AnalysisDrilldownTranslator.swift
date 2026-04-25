import Domain
import Foundation

public enum AnalysisDrilldownTranslator {
    public static func translate(
        context: AnalysisContext,
        evidence: InsightEvidence
    ) -> TransactionLedgerFilter {
        TransactionLedgerFilter(
            startDate: evidence.resolvedInterval.start,
            endDate: inclusiveEndDate(for: evidence.resolvedInterval.end),
            normalizedMerchantName: merchantName(for: evidence.destination.scope),
            accountID: accountID(for: evidence.destination.scope),
            categoryID: categoryID(for: evidence.destination.scope),
            categoryGroupID: categoryGroupID(for: evidence.destination.scope),
            uncategorizedOnly: isUncategorized(evidence.destination.scope),
            direction: evidence.destination.direction,
            reviewStatuses: resolvedReviewStatuses(context: context, basis: evidence.metricBasis),
            visibility: context.qualifiers.visibility
        )
    }

    private static func resolvedReviewStatuses(
        context: AnalysisContext,
        basis: ReportingExpenseBasis
    ) -> Set<TransactionReviewStatus>? {
        if let explicitReviewStatus = context.qualifiers.reviewStatus {
            return [explicitReviewStatus]
        }

        switch basis {
        case .includedVisibleExpenses:
            return [.accepted, .pending]
        case .acceptedExpenses:
            return [.accepted]
        }
    }

    private static func inclusiveEndDate(for exclusiveEndDate: Date) -> Date? {
        Calendar.alderwiseUTC.date(byAdding: DateComponents(second: -1), to: exclusiveEndDate)
    }

    private static func merchantName(for scope: InsightEvidenceScope) -> String? {
        if case .merchant(let merchantName) = scope {
            return merchantName
        }
        return nil
    }

    private static func accountID(for scope: InsightEvidenceScope) -> UUID? {
        if case .account(let accountID) = scope {
            return accountID
        }
        return nil
    }

    private static func categoryID(for scope: InsightEvidenceScope) -> UUID? {
        if case .category(let categoryID) = scope {
            return categoryID
        }
        return nil
    }

    private static func categoryGroupID(for scope: InsightEvidenceScope) -> UUID? {
        if case .categoryGroup(let categoryGroupID) = scope {
            return categoryGroupID
        }
        return nil
    }

    private static func isUncategorized(_ scope: InsightEvidenceScope) -> Bool {
        if case .uncategorized = scope {
            return true
        }
        return false
    }
}

private extension Calendar {
    static var alderwiseUTC: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar
    }
}
