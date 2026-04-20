import Domain

public struct WorkspaceSnapshot: Equatable, Sendable {
    public var summary: WorkspaceSummary
    public var accounts: [Account]
    public var categories: [BudgetCategory]
    public var transactions: [TransactionLedgerRow]
    public var transactionImportOrigins: [TransactionImportOrigin]

    public init(
        summary: WorkspaceSummary,
        accounts: [Account],
        categories: [BudgetCategory] = [],
        transactions: [TransactionLedgerRow] = [],
        transactionImportOrigins: [TransactionImportOrigin] = []
    ) {
        self.summary = summary
        self.accounts = accounts
        self.categories = categories
        self.transactions = transactions
        self.transactionImportOrigins = transactionImportOrigins
    }
}
