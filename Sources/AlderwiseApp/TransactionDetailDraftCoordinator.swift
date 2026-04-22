import Domain
import Foundation

struct TransactionDetailDraftCoordinator {
    enum SelectionChangeDecision: Equatable {
        case proceed
        case promptToSaveDiscardOrCancel
    }

    enum ReloadDecision: Equatable {
        case applyLoadedSelection
        case preserveCurrentDraftAndPrompt
    }

    enum PendingSelectionChange: Equatable {
        case none
        case selection(UUID?)
    }

    private(set) var currentSelectionID: UUID?
    private(set) var currentDraft: TransactionLedgerEditDraft?
    private var savedDraft: TransactionLedgerEditDraft?
    private(set) var pendingSelection: PendingSelectionChange = .none
    private(set) var isSelectionChangePromptPresented = false

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
        isSelectionChangePromptPresented = false
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
            isSelectionChangePromptPresented = false
            return .proceed
        }

        pendingSelection = .selection(proposedSelectionID)
        isSelectionChangePromptPresented = true
        return .promptToSaveDiscardOrCancel
    }

    mutating func reloadDecision(for selectionID: UUID?, detail: TransactionDetail?) -> ReloadDecision {
        guard selectionID != currentSelectionID else {
            load(selectionID: selectionID, detail: detail)
            return .applyLoadedSelection
        }

        guard isDirty else {
            load(selectionID: selectionID, detail: detail)
            return .applyLoadedSelection
        }

        pendingSelection = .selection(selectionID)
        isSelectionChangePromptPresented = true
        return .preserveCurrentDraftAndPrompt
    }

    mutating func discardChanges() -> PendingSelectionChange {
        currentDraft = savedDraft
        let pendingSelection = pendingSelection
        self.pendingSelection = .none
        isSelectionChangePromptPresented = false
        return pendingSelection
    }

    mutating func cancelPendingSelectionChange() {
        pendingSelection = .none
        isSelectionChangePromptPresented = false
    }

    mutating func completeSave(didSucceed: Bool) -> PendingSelectionChange {
        guard didSucceed else {
            return .none
        }

        savedDraft = currentDraft
        let pendingSelection = pendingSelection
        self.pendingSelection = .none
        isSelectionChangePromptPresented = false
        return pendingSelection
    }

    mutating func dismissSelectionChangePrompt() {
        isSelectionChangePromptPresented = false
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
