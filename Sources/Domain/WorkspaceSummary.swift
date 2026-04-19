public struct WorkspaceSummary: Equatable, Sendable {
    public var accountCount: Int
    public var transactionCount: Int
    public var reviewCount: Int
    public var targetCount: Int

    public init(
        accountCount: Int,
        transactionCount: Int,
        reviewCount: Int,
        targetCount: Int
    ) {
        self.accountCount = accountCount
        self.transactionCount = transactionCount
        self.reviewCount = reviewCount
        self.targetCount = targetCount
    }

    public static let empty = WorkspaceSummary(
        accountCount: 0,
        transactionCount: 0,
        reviewCount: 0,
        targetCount: 0
    )
}
