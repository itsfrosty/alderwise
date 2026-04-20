import Foundation

public struct MerchantNormalizer: Sendable {
    public init() {}

    public func normalize(_ description: String) -> String {
        description
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: #"x{4,}\d+"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\bnull\b"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"[^a-z0-9]+"#, with: " ", options: .regularExpression)
            .split(separator: " ")
            .joined(separator: " ")
    }
}

public struct NormalizedImportCandidate: Equatable, Sendable {
    public var rowHash: String
    public var sourceLineNumber: Int
    public var transactionDate: Date
    public var rawDescription: String
    public var normalizedMerchantName: String
    public var amount: Decimal

    public init(
        rowHash: String,
        sourceLineNumber: Int,
        transactionDate: Date,
        rawDescription: String,
        normalizedMerchantName: String,
        amount: Decimal
    ) {
        self.rowHash = rowHash
        self.sourceLineNumber = sourceLineNumber
        self.transactionDate = transactionDate
        self.rawDescription = rawDescription
        self.normalizedMerchantName = normalizedMerchantName
        self.amount = amount
    }
}

public struct LikelyDuplicateCandidate: Equatable, Sendable {
    public var rowHash: String
    public var existingTransactionID: UUID
    public var reason: String

    public init(rowHash: String, existingTransactionID: UUID, reason: String) {
        self.rowHash = rowHash
        self.existingTransactionID = existingTransactionID
        self.reason = reason
    }
}

public enum ImportRowDecision: Codable, Equatable, Sendable {
    case imported(reason: String)
    case skippedExactReimport(reason: String)
    case flaggedLikelyDuplicate(existingTransactionID: UUID, reason: String)
    case keptBothAfterLikelyDuplicateReview(existingTransactionID: UUID, reason: String)

    public var storageKind: String {
        switch self {
        case .imported:
            "imported"
        case .skippedExactReimport:
            "skipped_exact_reimport"
        case .flaggedLikelyDuplicate:
            "flagged_likely_duplicate"
        case .keptBothAfterLikelyDuplicateReview:
            "kept_both_after_likely_duplicate_review"
        }
    }

    public var reason: String {
        switch self {
        case .imported(let reason),
             .skippedExactReimport(let reason),
             .flaggedLikelyDuplicate(_, let reason),
             .keptBothAfterLikelyDuplicateReview(_, let reason):
            reason
        }
    }

    public var duplicateTransactionID: UUID? {
        switch self {
        case .flaggedLikelyDuplicate(let existingTransactionID, _),
             .keptBothAfterLikelyDuplicateReview(let existingTransactionID, _):
            existingTransactionID
        case .imported, .skippedExactReimport:
            nil
        }
    }

    public static func fromStorage(
        kind: String,
        reason: String,
        duplicateTransactionID: UUID?
    ) -> ImportRowDecision {
        switch kind {
        case "skipped_exact_reimport":
            .skippedExactReimport(reason: reason)
        case "kept_both_after_likely_duplicate_review":
            if let duplicateTransactionID {
                .keptBothAfterLikelyDuplicateReview(existingTransactionID: duplicateTransactionID, reason: reason)
            } else {
                .imported(reason: reason)
            }
        case "flagged_likely_duplicate":
            if let duplicateTransactionID {
                .flaggedLikelyDuplicate(existingTransactionID: duplicateTransactionID, reason: reason)
            } else {
                .skippedExactReimport(reason: reason)
            }
        default:
            .imported(reason: reason)
        }
    }
}

public struct StagedImportDecisionSummary: Equatable, Sendable {
    public var importedRowCount: Int
    public var skippedRowCount: Int
    public var flaggedDuplicateRowCount: Int

    public init(importedRowCount: Int, skippedRowCount: Int, flaggedDuplicateRowCount: Int) {
        self.importedRowCount = importedRowCount
        self.skippedRowCount = skippedRowCount
        self.flaggedDuplicateRowCount = flaggedDuplicateRowCount
    }

    public static func make(decisions: [ImportRowDecision]) -> StagedImportDecisionSummary {
        StagedImportDecisionSummary(
            importedRowCount: decisions.filter { $0.storageKind == "imported" }.count,
            skippedRowCount: decisions.filter { $0.storageKind == "skipped_exact_reimport" }.count,
            flaggedDuplicateRowCount: decisions.filter { $0.storageKind == "flagged_likely_duplicate" }.count
        )
    }
}
