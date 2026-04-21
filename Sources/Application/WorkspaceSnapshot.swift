import Domain

public struct WorkspaceSnapshot: Equatable, Sendable {
    public var summary: WorkspaceSummary
    public var accounts: [Account]
    public var categories: [BudgetCategory]
    public var transactions: [TransactionLedgerRow]
    public var transactionImportOrigins: [TransactionImportOrigin]
    public var monthlyReport: MonthlyReport

    public init(
        summary: WorkspaceSummary,
        accounts: [Account],
        categories: [BudgetCategory] = [],
        transactions: [TransactionLedgerRow] = [],
        transactionImportOrigins: [TransactionImportOrigin] = [],
        monthlyReport: MonthlyReport = .empty
    ) {
        self.summary = summary
        self.accounts = accounts
        self.categories = categories
        self.transactions = transactions
        self.transactionImportOrigins = transactionImportOrigins
        self.monthlyReport = monthlyReport
    }
}
