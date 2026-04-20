import Foundation

public enum ReviewItemType: String, Codable, Equatable, Sendable {
    case lowConfidenceCategory = "low_confidence_category"
    case conflictingRuleOutcome = "conflicting_rule_outcome"
    case likelyDuplicate = "likely_duplicate"
    case malformedRow = "malformed_row"
    case recurringHint = "recurring_hint"
}

public enum ReviewItemStatus: String, Codable, Equatable, Sendable {
    case pending
    case resolved
}

public struct PendingReviewSourceFile: Equatable, Sendable {
    public var accountID: UUID
    public var originalFilename: String

    public init(accountID: UUID, originalFilename: String) {
        self.accountID = accountID
        self.originalFilename = originalFilename
    }
}

public struct PendingReviewSourceRow: Equatable, Sendable {
    public var id: Int64
    public var sourceLineNumber: Int
    public var rowHash: String
    public var rawPayload: String

    public init(id: Int64, sourceLineNumber: Int, rowHash: String, rawPayload: String) {
        self.id = id
        self.sourceLineNumber = sourceLineNumber
        self.rowHash = rowHash
        self.rawPayload = rawPayload
    }
}

public struct PendingReviewItem: Equatable, Sendable {
    public var id: UUID
    public var type: ReviewItemType
    public var status: ReviewItemStatus
    public var reason: String?
    public var createdAt: Date
    public var sourceFile: PendingReviewSourceFile
    public var sourceRow: PendingReviewSourceRow
    public var duplicateTransactionID: UUID?

    public init(
        id: UUID,
        type: ReviewItemType,
        status: ReviewItemStatus,
        reason: String?,
        createdAt: Date,
        sourceFile: PendingReviewSourceFile,
        sourceRow: PendingReviewSourceRow,
        duplicateTransactionID: UUID?
    ) {
        self.id = id
        self.type = type
        self.status = status
        self.reason = reason
        self.createdAt = createdAt
        self.sourceFile = sourceFile
        self.sourceRow = sourceRow
        self.duplicateTransactionID = duplicateTransactionID
    }
}
