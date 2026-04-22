import Foundation
import Domain

public struct WorkspaceSnapshot: Equatable, Sendable {
    public var summary: WorkspaceSummary
    public var managementAccounts: [Account]
    public var importEligibleAccounts: [Account]
    public var ledgerFilterAccounts: [Account]
    public var permanentlyDeletableAccountIDs: Set<UUID>
    public var categories: [BudgetCategory]
    public var categoryGroups: [BudgetCategoryGroup]
    public var pendingReviewItems: [PendingReviewItem]
    public var transactions: [TransactionLedgerRow]
    public var transactionImportOrigins: [TransactionImportOrigin]
    public var monthlyReport: MonthlyReport
    public var homeDashboard: HomeDashboardSnapshot?

    public var accounts: [Account] {
        managementAccounts
    }

    public init(
        summary: WorkspaceSummary,
        managementAccounts: [Account],
        importEligibleAccounts: [Account]? = nil,
        ledgerFilterAccounts: [Account]? = nil,
        permanentlyDeletableAccountIDs: Set<UUID> = [],
        categories: [BudgetCategory] = [],
        categoryGroups: [BudgetCategoryGroup] = [],
        pendingReviewItems: [PendingReviewItem] = [],
        transactions: [TransactionLedgerRow] = [],
        transactionImportOrigins: [TransactionImportOrigin] = [],
        monthlyReport: MonthlyReport = .empty,
        homeDashboard: HomeDashboardSnapshot? = nil
    ) {
        self.summary = summary
        self.managementAccounts = managementAccounts
        self.importEligibleAccounts = importEligibleAccounts ?? managementAccounts.filter { !$0.isArchived }
        self.ledgerFilterAccounts = ledgerFilterAccounts ?? managementAccounts
        self.permanentlyDeletableAccountIDs = permanentlyDeletableAccountIDs
        self.categories = categories
        self.categoryGroups = categoryGroups
        self.pendingReviewItems = pendingReviewItems
        self.transactions = transactions
        self.transactionImportOrigins = transactionImportOrigins
        self.monthlyReport = monthlyReport
        self.homeDashboard = homeDashboard
    }

    public init(
        summary: WorkspaceSummary,
        accounts: [Account],
        categories: [BudgetCategory] = [],
        categoryGroups: [BudgetCategoryGroup] = [],
        pendingReviewItems: [PendingReviewItem] = [],
        transactions: [TransactionLedgerRow] = [],
        transactionImportOrigins: [TransactionImportOrigin] = [],
        monthlyReport: MonthlyReport = .empty,
        homeDashboard: HomeDashboardSnapshot? = nil
    ) {
        self.init(
            summary: summary,
            managementAccounts: accounts,
            categories: categories,
            categoryGroups: categoryGroups,
            pendingReviewItems: pendingReviewItems,
            transactions: transactions,
            transactionImportOrigins: transactionImportOrigins,
            monthlyReport: monthlyReport,
            homeDashboard: homeDashboard
        )
    }
}
