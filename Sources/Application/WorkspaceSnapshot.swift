import Domain

public struct WorkspaceSnapshot: Equatable, Sendable {
    public var summary: WorkspaceSummary
    public var accounts: [Account]
    public var categories: [BudgetCategory]
    public var transactions: [TransactionLedgerRow]

    public init(
        summary: WorkspaceSummary,
        accounts: [Account],
        categories: [BudgetCategory] = [],
        transactions: [TransactionLedgerRow] = []
    ) {
        self.summary = summary
        self.accounts = accounts
        self.categories = categories
        self.transactions = transactions
    }
}
