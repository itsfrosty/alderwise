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
    #expect(coordinator.pendingSelectionID == nil)
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
    #expect(coordinator.pendingSelectionID == nextID)
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

    #expect(appliedSelection == nextID)
    #expect(coordinator.pendingSelectionID == nil)
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
    #expect(coordinator.pendingSelectionID == nil)
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

    let appliedSelection = coordinator.saveSucceeded()

    #expect(appliedSelection == nextID)
    #expect(coordinator.pendingSelectionID == nil)
    #expect(coordinator.currentDraft == editedDraft)
    #expect(coordinator.isDirty == false)
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
