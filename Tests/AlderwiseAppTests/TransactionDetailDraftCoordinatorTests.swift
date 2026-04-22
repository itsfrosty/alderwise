import Domain
import Foundation
import Testing

@testable import AlderwiseApp

@Test
func cleanSelectionChangeProceedsImmediately() {
    let currentID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    let nextID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    var coordinator = TransactionDetailDraftCoordinator(
        selectionID: currentID,
        detail: makeDetail(id: currentID)
    )

    let decision = coordinator.selectionChangeDecision(for: nextID)

    #expect(decision == .proceed)
    #expect(coordinator.isDirty == false)
    #expect(coordinator.pendingSelection == .none)
}

@Test
func dirtySelectionChangeBlocksAndRecordsPendingTargetSelection() {
    let currentID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    let nextID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    var coordinator = TransactionDetailDraftCoordinator(
        selectionID: currentID,
        detail: makeDetail(id: currentID)
    )

    coordinator.updateDraft(
        TransactionLedgerEditDraft(
            merchantName: "Updated Merchant",
            categoryID: nil,
            notes: "Edited notes"
        )
    )

    let decision = coordinator.selectionChangeDecision(for: nextID)

    #expect(decision == .promptToSaveDiscardOrCancel)
    #expect(coordinator.isDirty == true)
    #expect(coordinator.pendingSelection == .selection(nextID))
}

@Test
func discardAppliesPendingSelection() {
    let currentID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    let nextID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    let detail = makeDetail(id: currentID)
    var coordinator = TransactionDetailDraftCoordinator(
        selectionID: currentID,
        detail: detail
    )

    coordinator.updateDraft(
        TransactionLedgerEditDraft(
            merchantName: "Updated Merchant",
            categoryID: nil,
            notes: "Edited notes"
        )
    )
    _ = coordinator.selectionChangeDecision(for: nextID)

    let appliedSelection = coordinator.discardChanges()

    #expect(appliedSelection == .selection(nextID))
    #expect(coordinator.pendingSelection == .none)
    #expect(coordinator.isDirty == false)
    #expect(coordinator.currentDraft == TransactionDetailDraftCoordinator.makeDraft(from: detail))
}

@Test
func cancelKeepsCurrentSelectionAndCurrentDraft() {
    let currentID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    let nextID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    var coordinator = TransactionDetailDraftCoordinator(
        selectionID: currentID,
        detail: makeDetail(id: currentID)
    )
    let editedDraft = TransactionLedgerEditDraft(
        merchantName: "Updated Merchant",
        categoryID: nil,
        notes: "Edited notes"
    )

    coordinator.updateDraft(editedDraft)
    _ = coordinator.selectionChangeDecision(for: nextID)
    coordinator.cancelPendingSelectionChange()

    #expect(coordinator.currentSelectionID == currentID)
    #expect(coordinator.currentDraft == editedDraft)
    #expect(coordinator.pendingSelection == .none)
    #expect(coordinator.isDirty == true)
}

@Test
func successfulSaveClearsDirtyStateAndAppliesPendingSelection() {
    let currentID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    let nextID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    var coordinator = TransactionDetailDraftCoordinator(
        selectionID: currentID,
        detail: makeDetail(id: currentID)
    )
    let editedDraft = TransactionLedgerEditDraft(
        merchantName: "Updated Merchant",
        categoryID: nil,
        notes: "Edited notes"
    )

    coordinator.updateDraft(editedDraft)
    _ = coordinator.selectionChangeDecision(for: nextID)

    let appliedSelection = coordinator.completeSave(didSucceed: true)

    #expect(appliedSelection == .selection(nextID))
    #expect(coordinator.pendingSelection == .none)
    #expect(coordinator.isSelectionChangePromptPresented == false)
    #expect(coordinator.currentDraft == editedDraft)
    #expect(coordinator.isDirty == false)
}

@Test
func failedSavePreservesDirtyDraftAndPendingSelection() {
    let currentID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    let nextID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    var coordinator = TransactionDetailDraftCoordinator(
        selectionID: currentID,
        detail: makeDetail(id: currentID)
    )
    let editedDraft = TransactionLedgerEditDraft(
        merchantName: "Updated Merchant",
        categoryID: nil,
        notes: "Edited notes"
    )

    coordinator.updateDraft(editedDraft)
    _ = coordinator.selectionChangeDecision(for: nextID)

    let appliedSelection = coordinator.completeSave(didSucceed: false)

    #expect(appliedSelection == .none)
    #expect(coordinator.pendingSelection == .selection(nextID))
    #expect(coordinator.isSelectionChangePromptPresented == true)
    #expect(coordinator.currentDraft == editedDraft)
    #expect(coordinator.isDirty == true)
}

@Test
func failedSaveFollowedByImplicitDismissalKeepsPendingSelection() {
    let currentID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    let nextID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    var coordinator = TransactionDetailDraftCoordinator(
        selectionID: currentID,
        detail: makeDetail(id: currentID)
    )
    let editedDraft = TransactionLedgerEditDraft(
        merchantName: "Updated Merchant",
        categoryID: nil,
        notes: "Edited notes"
    )

    coordinator.updateDraft(editedDraft)
    _ = coordinator.selectionChangeDecision(for: nextID)
    _ = coordinator.completeSave(didSucceed: false)
    coordinator.dismissSelectionChangePrompt()

    #expect(coordinator.pendingSelection == .selection(nextID))
    #expect(coordinator.isSelectionChangePromptPresented == false)
    #expect(coordinator.currentDraft == editedDraft)
    #expect(coordinator.isDirty == true)
}

@Test
func userDismissalClearsPendingSelection() {
    let currentID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    let nextID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    var coordinator = TransactionDetailDraftCoordinator(
        selectionID: currentID,
        detail: makeDetail(id: currentID)
    )
    let editedDraft = TransactionLedgerEditDraft(
        merchantName: "Updated Merchant",
        categoryID: nil,
        notes: "Edited notes"
    )

    coordinator.updateDraft(editedDraft)
    _ = coordinator.selectionChangeDecision(for: nextID)
    coordinator.dismissSelectionChangePrompt()

    #expect(coordinator.pendingSelection == .none)
    #expect(coordinator.isSelectionChangePromptPresented == false)
    #expect(coordinator.currentDraft == editedDraft)
    #expect(coordinator.isDirty == true)
}

@Test
func sameSelectionReloadPreservesDirtyDraft() {
    let currentID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    var coordinator = TransactionDetailDraftCoordinator(
        selectionID: currentID,
        detail: makeDetail(id: currentID)
    )
    let editedDraft = TransactionLedgerEditDraft(
        merchantName: "Updated Merchant",
        categoryID: nil,
        notes: "Edited notes"
    )

    coordinator.updateDraft(editedDraft)
    coordinator.load(selectionID: currentID, detail: makeDetail(id: currentID))

    #expect(coordinator.currentDraft == editedDraft)
    #expect(coordinator.isDirty == true)
}

@Test
func dirtyDeselectionIsTrackedExplicitlyAndAppliedAfterSave() {
    let currentID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    var coordinator = TransactionDetailDraftCoordinator(
        selectionID: currentID,
        detail: makeDetail(id: currentID)
    )
    let editedDraft = TransactionLedgerEditDraft(
        merchantName: "Updated Merchant",
        categoryID: nil,
        notes: "Edited notes"
    )

    coordinator.updateDraft(editedDraft)

    let decision = coordinator.selectionChangeDecision(for: nil)
    let appliedSelection = coordinator.completeSave(didSucceed: true)

    #expect(decision == .promptToSaveDiscardOrCancel)
    #expect(coordinator.pendingSelection == .none)
    #expect(coordinator.isSelectionChangePromptPresented == false)
    #expect(appliedSelection == .selection(nil))
}

@Test
func dirtyFilterDrivenSelectionLossIsDeferredUntilUserResolvesPrompt() {
    let currentID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    let fallbackID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    var coordinator = TransactionDetailDraftCoordinator(
        selectionID: currentID,
        detail: makeDetail(id: currentID)
    )
    let editedDraft = TransactionLedgerEditDraft(
        merchantName: "Updated Merchant",
        categoryID: nil,
        notes: "Edited notes"
    )

    coordinator.updateDraft(editedDraft)

    let decision = coordinator.reloadDecision(
        for: fallbackID,
        detail: makeDetail(id: fallbackID)
    )

    #expect(decision == .preserveCurrentDraftAndPrompt)
    #expect(coordinator.currentSelectionID == currentID)
    #expect(coordinator.currentDraft == editedDraft)
    #expect(coordinator.pendingSelection == .selection(fallbackID))
    #expect(coordinator.isDirty == true)
}

private func makeDetail(id: UUID) -> TransactionDetail {
    TransactionDetail(
        row: TransactionLedgerRow(
            id: id,
            accountID: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!,
            accountName: "Checking",
            categoryID: UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!,
            categoryName: "Dining",
            rawDescription: "Memo",
            merchantName: "Merchant",
            amount: Decimal(-10),
            transactionDate: Date(timeIntervalSince1970: 0),
            postedDate: nil,
            direction: .expense,
            reviewStatus: .accepted,
            importOrigin: nil
        ),
        notes: "Original notes",
        decisionSource: nil,
        decisionSourceReference: nil,
        confidence: nil,
        duplicateStatus: "unique"
    )
}
