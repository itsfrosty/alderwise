import Domain
import Foundation

enum TransactionLedgerSelectionState {
    static func selectionAfterReload(
        currentSelectionID: UUID?,
        visibleRows: [TransactionLedgerRow]
    ) -> UUID? {
        if let currentSelectionID,
           visibleRows.contains(where: { $0.id == currentSelectionID }) {
            return currentSelectionID
        }

        return visibleRows.first?.id
    }
}
