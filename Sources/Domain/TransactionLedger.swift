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

public enum TransactionVisibilityFilter: String, Codable, CaseIterable, Equatable, Sendable {
    case active
    case hidden
    case all
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

public struct TransactionLedgerRuleFilterIntent: Equatable, Sendable {
    public enum Source: Hashable, Sendable {
        case learnedRule(UUID)
    }

    public var source: Source
    public var merchantPattern: String
    public var merchantLabel: String
    public var matchKind: ClassificationRuleMatchKind

    public init(
        source: Source,
        merchantPattern: String,
        merchantLabel: String,
        matchKind: ClassificationRuleMatchKind
    ) {
        self.source = source
        self.merchantPattern = merchantPattern
        self.merchantLabel = merchantLabel
        self.matchKind = matchKind
    }

    public func matches(
        _ row: TransactionLedgerRow,
        merchantNormalizer: MerchantNormalizer = MerchantNormalizer()
    ) -> Bool {
        LearnedRuleMatcher.matches(
            merchantPattern: merchantPattern,
            matchKind: matchKind,
            candidate: LearnedRuleMatchCandidate(
                normalizedMerchantName: merchantNormalizer.normalize(row.merchantName),
                rawDescription: row.rawDescription
            ),
            merchantNormalizer: merchantNormalizer
        )
    }
}

public struct TransactionLedgerFilter: Equatable, Sendable {
    public var searchText: String
    public var startDate: Date?
    public var endDate: Date?
    public var normalizedMerchantName: String?
    public var accountID: UUID?
    public var categoryID: UUID?
    public var categoryGroupID: UUID?
    public var uncategorizedOnly: Bool
    public var direction: TransactionDirection?
    public var reviewStatus: TransactionReviewStatus?
    public var reviewStatuses: Set<TransactionReviewStatus>?
    public var visibility: TransactionVisibilityFilter?
    public var importSessionID: Int64?
    public var ruleFilterIntent: TransactionLedgerRuleFilterIntent?

    public init(
        searchText: String = "",
        startDate: Date? = nil,
        endDate: Date? = nil,
        normalizedMerchantName: String? = nil,
        accountID: UUID? = nil,
        categoryID: UUID? = nil,
        categoryGroupID: UUID? = nil,
        uncategorizedOnly: Bool = false,
        direction: TransactionDirection? = nil,
        reviewStatus: TransactionReviewStatus? = nil,
        reviewStatuses: Set<TransactionReviewStatus>? = nil,
        visibility: TransactionVisibilityFilter? = nil,
        importSessionID: Int64? = nil,
        ruleFilterIntent: TransactionLedgerRuleFilterIntent? = nil
    ) {
        self.searchText = searchText
        self.startDate = startDate
        self.endDate = endDate
        self.normalizedMerchantName = normalizedMerchantName
        self.accountID = accountID
        self.categoryID = categoryID
        self.categoryGroupID = categoryGroupID
        self.uncategorizedOnly = uncategorizedOnly
        self.direction = direction
        self.reviewStatus = reviewStatus
        self.reviewStatuses = reviewStatuses
        self.visibility = visibility
        self.importSessionID = importSessionID
        self.ruleFilterIntent = ruleFilterIntent
    }

    public static let empty = TransactionLedgerFilter()
}

public struct TransactionLedgerRow: Identifiable, Equatable, Sendable {
    public var id: UUID
    public var accountID: UUID
    public var accountName: String
    public var isHidden: Bool
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
        isHidden: Bool = false,
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
        self.isHidden = isHidden
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
    public var ruleProvenance: TransactionRuleProvenance?
    public var confidence: Double?
    public var duplicateStatus: String

    public init(
        row: TransactionLedgerRow,
        notes: String?,
        decisionSource: ClassificationDecisionSource?,
        decisionSourceReference: String?,
        ruleProvenance: TransactionRuleProvenance? = nil,
        confidence: Double?,
        duplicateStatus: String
    ) {
        self.row = row
        self.notes = notes
        self.decisionSource = decisionSource
        self.decisionSourceReference = decisionSourceReference
        self.ruleProvenance = ruleProvenance
        self.confidence = confidence
        self.duplicateStatus = duplicateStatus
    }

    public var importOrigin: TransactionImportOrigin? {
        row.importOrigin
    }
}

public enum TransactionRuleProvenance: Equatable, Sendable {
    case learnedRule(TransactionLearnedRuleProvenance)
    case seededSource(TransactionSeededRuleSourceProvenance)
}

public struct TransactionLearnedRuleProvenance: Equatable, Sendable {
    public var id: UUID
    public var merchantPattern: String
    public var categoryID: UUID?
    public var categoryName: String?
    public var merchantName: String?
    public var matchKind: ClassificationRuleMatchKind
    public var lifecycle: LearnedRuleLifecycle

    public init(
        id: UUID,
        merchantPattern: String,
        categoryID: UUID?,
        categoryName: String?,
        merchantName: String?,
        matchKind: ClassificationRuleMatchKind,
        lifecycle: LearnedRuleLifecycle
    ) {
        self.id = id
        self.merchantPattern = merchantPattern
        self.categoryID = categoryID
        self.categoryName = categoryName
        self.merchantName = merchantName
        self.matchKind = matchKind
        self.lifecycle = lifecycle
    }

    public var isDisabled: Bool {
        if case .disabled = lifecycle {
            true
        } else {
            false
        }
    }

    public var disabledAt: Date? {
        lifecycle.disabledAt
    }
}

public enum TransactionSeededRuleSourceKind: Equatable, Sendable {
    case deterministicRule
    case curatedPrefill
}

public struct TransactionSeededRuleSourceProvenance: Equatable, Sendable {
    public var id: String
    public var kind: TransactionSeededRuleSourceKind
    public var merchantPattern: String
    public var categoryID: UUID
    public var categoryName: String?
    public var merchantName: String?
    public var matchKind: ClassificationRuleMatchKind

    public init(
        id: String,
        kind: TransactionSeededRuleSourceKind,
        merchantPattern: String,
        categoryID: UUID,
        categoryName: String?,
        merchantName: String?,
        matchKind: ClassificationRuleMatchKind
    ) {
        self.id = id
        self.kind = kind
        self.merchantPattern = merchantPattern
        self.categoryID = categoryID
        self.categoryName = categoryName
        self.merchantName = merchantName
        self.matchKind = matchKind
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
