import Domain
import Foundation

struct TransactionDetailDraftCoordinator {
    enum SelectionChangeDecision: Equatable {
        case proceed
        case promptToSaveDiscardOrCancel
    }

    enum PendingSelectionChange: Equatable {
        case none
        case selection(UUID?)
    }

    private(set) var currentSelectionID: UUID?
    private(set) var currentDraft: TransactionLedgerEditDraft?
    private var savedDraft: TransactionLedgerEditDraft?
    private(set) var pendingSelection: PendingSelectionChange = .none

    init(selectionID: UUID? = nil, detail: TransactionDetail? = nil) {
        load(selectionID: selectionID, detail: detail)
    }

    var isDirty: Bool {
        Self.normalizedDraft(currentDraft) != Self.normalizedDraft(savedDraft)
    }

    mutating func load(selectionID: UUID?, detail: TransactionDetail?) {
        if selectionID == currentSelectionID, isDirty {
            return
        }

        currentSelectionID = selectionID
        let draft = detail.map(Self.makeDraft(from:))
        currentDraft = draft
        savedDraft = draft
        pendingSelection = .none
    }

    mutating func updateDraft(_ draft: TransactionLedgerEditDraft?) {
        currentDraft = draft
    }

    mutating func selectionChangeDecision(for proposedSelectionID: UUID?) -> SelectionChangeDecision {
        guard proposedSelectionID != currentSelectionID else {
            pendingSelection = .none
            return .proceed
        }

        guard isDirty else {
            pendingSelection = .none
            return .proceed
        }

        pendingSelection = .selection(proposedSelectionID)
        return .promptToSaveDiscardOrCancel
    }

    mutating func discardChanges() -> PendingSelectionChange {
        currentDraft = savedDraft
        let pendingSelection = pendingSelection
        self.pendingSelection = .none
        return pendingSelection
    }

    mutating func cancelPendingSelectionChange() {
        pendingSelection = .none
    }

    mutating func saveSucceeded() -> PendingSelectionChange {
        savedDraft = currentDraft
        let pendingSelection = pendingSelection
        self.pendingSelection = .none
        return pendingSelection
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
