import Domain
import Foundation

struct TransactionDetailDraftCoordinator {
    enum SelectionChangeDecision: Equatable {
        case proceed
        case promptToSaveDiscardOrCancel
    }

    private(set) var currentSelectionID: UUID?
    private(set) var currentDraft: TransactionLedgerEditDraft?
    private var savedDraft: TransactionLedgerEditDraft?
    private(set) var pendingSelectionID: UUID?

    init(selectionID: UUID? = nil, detail: TransactionDetail? = nil) {
        load(selectionID: selectionID, detail: detail)
    }

    var isDirty: Bool {
        Self.normalizedDraft(currentDraft) != Self.normalizedDraft(savedDraft)
    }

    mutating func load(selectionID: UUID?, detail: TransactionDetail?) {
        currentSelectionID = selectionID
        let draft = detail.map(Self.makeDraft(from:))
        currentDraft = draft
        savedDraft = draft
        pendingSelectionID = nil
    }

    mutating func updateDraft(_ draft: TransactionLedgerEditDraft?) {
        currentDraft = draft
    }

    mutating func selectionChangeDecision(for proposedSelectionID: UUID?) -> SelectionChangeDecision {
        guard proposedSelectionID != currentSelectionID else {
            pendingSelectionID = nil
            return .proceed
        }

        guard isDirty else {
            pendingSelectionID = nil
            return .proceed
        }

        pendingSelectionID = proposedSelectionID
        return .promptToSaveDiscardOrCancel
    }

    mutating func discardChanges() -> UUID? {
        currentDraft = savedDraft
        let pendingSelectionID = pendingSelectionID
        self.pendingSelectionID = nil
        return pendingSelectionID
    }

    mutating func cancelPendingSelectionChange() {
        pendingSelectionID = nil
    }

    mutating func saveSucceeded() -> UUID? {
        savedDraft = currentDraft
        let pendingSelectionID = pendingSelectionID
        self.pendingSelectionID = nil
        return pendingSelectionID
    }

    static func makeDraft(from detail: TransactionDetail) -> TransactionLedgerEditDraft {
        TransactionLedgerEditDraft(
            merchantName: detail.row.merchantName,
            categoryID: detail.row.categoryID,
            notes: detail.notes ?? ""
        )
    }

    private static func normalizedDraft(_ draft: TransactionLedgerEditDraft?) -> TransactionLedgerEditDraft? {
        guard var draft else {
            return nil
        }

        if draft.notes == "" {
            draft.notes = nil
        }

        return draft
    }
}
