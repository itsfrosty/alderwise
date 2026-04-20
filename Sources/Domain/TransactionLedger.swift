import Foundation

public enum TransactionReviewStatus: String, Codable, CaseIterable, Equatable, Sendable {
    case accepted
    case pending
    case rejected
}

public enum TransactionDirection: String, Codable, CaseIterable, Equatable, Sendable {
    case expense
    case income
    case transfer
}

public struct TransactionImportOrigin: Equatable, Sendable {
    public var id: Int64
    public var originalFilename: String
    public var importedAt: Date

    public init(id: Int64, originalFilename: String, importedAt: Date) {
        self.id = id
        self.originalFilename = originalFilename
        self.importedAt = importedAt
    }
}

public struct TransactionLedgerFilter: Equatable, Sendable {
    public var searchText: String
    public var startDate: Date?
    public var endDate: Date?
    public var accountID: UUID?
    public var categoryID: UUID?
    public var reviewStatus: TransactionReviewStatus?
    public var importSessionID: Int64?

    public init(
        searchText: String = "",
        startDate: Date? = nil,
        endDate: Date? = nil,
        accountID: UUID? = nil,
        categoryID: UUID? = nil,
        reviewStatus: TransactionReviewStatus? = nil,
        importSessionID: Int64? = nil
    ) {
        self.searchText = searchText
        self.startDate = startDate
        self.endDate = endDate
        self.accountID = accountID
        self.categoryID = categoryID
        self.reviewStatus = reviewStatus
        self.importSessionID = importSessionID
    }

    public static let empty = TransactionLedgerFilter()
}

public struct TransactionLedgerRow: Identifiable, Equatable, Sendable {
    public var id: UUID
    public var accountID: UUID
    public var accountName: String
    public var categoryID: UUID?
    public var categoryName: String?
    public var rawDescription: String
    public var merchantName: String
    public var amount: Decimal
    public var transactionDate: Date
    public var postedDate: Date?
    public var direction: TransactionDirection
    public var reviewStatus: TransactionReviewStatus
    public var importOrigin: TransactionImportOrigin?

    public init(
        id: UUID,
        accountID: UUID,
        accountName: String,
        categoryID: UUID?,
        categoryName: String?,
        rawDescription: String,
        merchantName: String,
        amount: Decimal,
        transactionDate: Date,
        postedDate: Date?,
        direction: TransactionDirection,
        reviewStatus: TransactionReviewStatus,
        importOrigin: TransactionImportOrigin?
    ) {
        self.id = id
        self.accountID = accountID
        self.accountName = accountName
        self.categoryID = categoryID
        self.categoryName = categoryName
        self.rawDescription = rawDescription
        self.merchantName = merchantName
        self.amount = amount
        self.transactionDate = transactionDate
        self.postedDate = postedDate
        self.direction = direction
        self.reviewStatus = reviewStatus
        self.importOrigin = importOrigin
    }
}

public struct TransactionDetail: Equatable, Sendable {
    public var row: TransactionLedgerRow
    public var notes: String?
    public var decisionSource: ClassificationDecisionSource?
    public var decisionSourceReference: String?
    public var confidence: Double?
    public var duplicateStatus: String

    public init(
        row: TransactionLedgerRow,
        notes: String?,
        decisionSource: ClassificationDecisionSource?,
        decisionSourceReference: String?,
        confidence: Double?,
        duplicateStatus: String
    ) {
        self.row = row
        self.notes = notes
        self.decisionSource = decisionSource
        self.decisionSourceReference = decisionSourceReference
        self.confidence = confidence
        self.duplicateStatus = duplicateStatus
    }

    public var importOrigin: TransactionImportOrigin? {
        row.importOrigin
    }
}

public struct TransactionLedgerEditDraft: Equatable, Sendable {
    public var merchantName: String
    public var categoryID: UUID?
    public var notes: String?

    public init(merchantName: String, categoryID: UUID?, notes: String?) {
        self.merchantName = merchantName
        self.categoryID = categoryID
        self.notes = notes
    }
}
