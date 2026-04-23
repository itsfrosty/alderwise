import Domain
import Foundation
import Testing

@testable import AlderwiseApp

@Test
@MainActor
func selectingCategoryClearsUncategorizedOnlyFilter() {
    let categoryID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    let original = TransactionLedgerFilter(
        categoryGroupID: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
        uncategorizedOnly: true,
        visibility: .all
    )

    let next = TransactionLedgerView.applyingCategorySelection(categoryID, to: original)

    #expect(next.categoryID == categoryID)
    #expect(next.categoryGroupID == nil)
    #expect(next.uncategorizedOnly == false)
    #expect(next.visibility == .all)
}

@Test
@MainActor
func activeEmptyStateOffersHiddenRecoveryWhenWorkspaceHasHiddenTransactions() {
    let state = TransactionLedgerView.emptyLedgerState(
        for: .active,
        summary: WorkspaceSummary(
            accountCount: 1,
            transactionCount: 0,
            reviewCount: 0,
            targetCount: 0,
            hiddenTransactionCount: 2
        )
    )

    #expect(state.title == "No active transactions")
    #expect(state.description == "Imported transactions appear here as the ledger grows. Hidden transactions only appear in Hidden or All.")
    #expect(state.action == .showHidden)
}

@Test
@MainActor
func activeEmptyStateSkipsHiddenRecoveryWhenWorkspaceHasNoHiddenTransactions() {
    let state = TransactionLedgerView.emptyLedgerState(
        for: .active,
        summary: WorkspaceSummary(
            accountCount: 1,
            transactionCount: 0,
            reviewCount: 0,
            targetCount: 0
        )
    )

    #expect(state.title == "No active transactions")
    #expect(state.description == "Imported transactions appear here as the ledger grows.")
    #expect(state.action == nil)
}
