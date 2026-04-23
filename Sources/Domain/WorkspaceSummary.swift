public struct WorkspaceSummary: Equatable, Sendable {
    public var accountCount: Int
    public var transactionCount: Int
    public var reviewCount: Int
    public var targetCount: Int
    public var hiddenTransactionCount: Int

    public init(
        accountCount: Int,
        transactionCount: Int,
        reviewCount: Int,
        targetCount: Int,
        hiddenTransactionCount: Int = 0
    ) {
        self.accountCount = accountCount
        self.transactionCount = transactionCount
        self.reviewCount = reviewCount
        self.targetCount = targetCount
        self.hiddenTransactionCount = hiddenTransactionCount
    }

    public static let empty = WorkspaceSummary(
        accountCount: 0,
        transactionCount: 0,
        reviewCount: 0,
        targetCount: 0,
        hiddenTransactionCount: 0
    )
}
