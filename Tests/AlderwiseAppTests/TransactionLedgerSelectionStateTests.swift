import Domain
import Foundation
import Testing

@testable import AlderwiseApp

@Test
func currentSelectionRemainsWhenStillVisible() {
    let keptID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    let rows = [
        makeRow(id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!),
        makeRow(id: keptID),
    ]

    let nextSelection = TransactionLedgerSelectionState.selectionAfterReload(
        currentSelectionID: keptID,
        visibleRows: rows
    )

    #expect(nextSelection == keptID)
}

@Test
func selectionFallsBackToFirstVisibleTransactionWhenCurrentSelectionIsFilteredOut() {
    let firstVisibleID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    let rows = [
        makeRow(id: firstVisibleID),
        makeRow(id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!),
    ]

    let nextSelection = TransactionLedgerSelectionState.selectionAfterReload(
        currentSelectionID: UUID(uuidString: "99999999-9999-9999-9999-999999999999")!,
        visibleRows: rows
    )

    #expect(nextSelection == firstVisibleID)
}

@Test
func selectionFallsBackToFirstVisibleTransactionWhenThereIsNoCurrentSelection() {
    let firstVisibleID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    let rows = [
        makeRow(id: firstVisibleID),
        makeRow(id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!),
    ]

    let nextSelection = TransactionLedgerSelectionState.selectionAfterReload(
        currentSelectionID: nil,
        visibleRows: rows
    )

    #expect(nextSelection == firstVisibleID)
}

@Test
func selectionClearsWhenFilteredLedgerIsEmpty() {
    let nextSelection = TransactionLedgerSelectionState.selectionAfterReload(
        currentSelectionID: UUID(uuidString: "99999999-9999-9999-9999-999999999999")!,
        visibleRows: []
    )

    #expect(nextSelection == nil)
}

private func makeRow(id: UUID) -> TransactionLedgerRow {
    TransactionLedgerRow(
        id: id,
        accountID: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!,
        accountName: "Checking",
        categoryID: nil,
        categoryName: nil,
        rawDescription: "Memo",
        merchantName: "Merchant",
        amount: Decimal(-10),
        transactionDate: Date(timeIntervalSince1970: 0),
        postedDate: nil,
        direction: .expense,
        reviewStatus: .accepted,
        importOrigin: nil
    )
}
