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

public enum ReviewDecisionAction: String, Codable, Equatable, Sendable {
    case keepBoth = "keep_both"
    case approveSuggestion = "approve_suggestion"
    case changeCategory = "change_category"
    case renameMerchant = "rename_merchant"
    case createRule = "create_rule"
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
    public var classification: PendingReviewClassification?

    public init(
        id: UUID,
        type: ReviewItemType,
        status: ReviewItemStatus,
        reason: String?,
        createdAt: Date,
        sourceFile: PendingReviewSourceFile,
        sourceRow: PendingReviewSourceRow,
        duplicateTransactionID: UUID?,
        classification: PendingReviewClassification? = nil
    ) {
        self.id = id
        self.type = type
        self.status = status
        self.reason = reason
        self.createdAt = createdAt
        self.sourceFile = sourceFile
        self.sourceRow = sourceRow
        self.duplicateTransactionID = duplicateTransactionID
        self.classification = classification
    }
}

public struct PendingReviewClassification: Equatable, Sendable {
    public var normalizedMerchantName: String
    public var prefill: ClassificationAssignment?
    public var source: ClassificationDecisionSource?
    public var sourceReference: String?
    public var confidence: Double?

    public init(
        normalizedMerchantName: String,
        prefill: ClassificationAssignment?,
        source: ClassificationDecisionSource?,
        sourceReference: String?,
        confidence: Double?
    ) {
        self.normalizedMerchantName = normalizedMerchantName
        self.prefill = prefill
        self.source = source
        self.sourceReference = sourceReference
        self.confidence = confidence
    }
}

public struct ReviewDecisionEvent: Equatable, Sendable {
    public var id: UUID
    public var reviewItemID: UUID
    public var sourceRowID: Int64
    public var action: ReviewDecisionAction
    public var details: String
    public var createdAt: Date

    public init(
        id: UUID,
        reviewItemID: UUID,
        sourceRowID: Int64,
        action: ReviewDecisionAction,
        details: String,
        createdAt: Date
    ) {
        self.id = id
        self.reviewItemID = reviewItemID
        self.sourceRowID = sourceRowID
        self.action = action
        self.details = details
        self.createdAt = createdAt
    }
}
