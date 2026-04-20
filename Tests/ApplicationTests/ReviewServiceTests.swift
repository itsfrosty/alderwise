import Application
import Domain
import Foundation
import Testing

private struct StubReviewQueueStore: ReviewQueueReading {
    var items: [PendingReviewItem]

    func fetchPendingReviewItems() throws -> [PendingReviewItem] {
        items
    }
}

private final class RecordingReviewQueueStore: @unchecked Sendable, ReviewQueueReading, ReviewQueueWriting {
    var items: [PendingReviewItem] = []
    var resolvedReviewItemID: UUID?
    var resolvedAt: Date?
    var returnedEvent = ReviewDecisionEvent(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000777")!,
        reviewItemID: UUID(uuidString: "00000000-0000-0000-0000-000000000555")!,
        sourceRowID: 42,
        action: .keepBoth,
        details: "User kept both the staged row and existing transaction after duplicate review.",
        createdAt: Date(timeIntervalSince1970: 1_775_171_260)
    )
    var approvedClassificationReviewItemID: UUID?
    var approvedAssignment: ClassificationAssignment?
    var approvedCreateRule: Bool?

    func fetchPendingReviewItems() throws -> [PendingReviewItem] {
        items
    }

    func keepBothForLikelyDuplicateReviewItem(id: UUID, resolvedAt: Date) throws -> ReviewDecisionEvent {
        resolvedReviewItemID = id
        self.resolvedAt = resolvedAt
        return returnedEvent
    }

    func approveClassificationReviewItem(
        id: UUID,
        assignment: ClassificationAssignment,
        createRule: Bool,
        resolvedAt: Date
    ) throws -> ReviewDecisionEvent {
        approvedClassificationReviewItemID = id
        approvedAssignment = assignment
        approvedCreateRule = createRule
        self.resolvedAt = resolvedAt
        return returnedEvent
    }
}

@Test
func loadPendingReviewItemsReturnsStoreItems() throws {
    let accountID = UUID(uuidString: "00000000-0000-0000-0000-000000000123")!
    let duplicateTransactionID = UUID(uuidString: "00000000-0000-0000-0000-000000000999")!
    let item = PendingReviewItem(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000555")!,
        type: .likelyDuplicate,
        status: .pending,
        reason: "Same account, amount, normalized merchant, and nearby date.",
        createdAt: Date(timeIntervalSince1970: 1_775_171_200),
        sourceFile: PendingReviewSourceFile(
            accountID: accountID,
            originalFilename: "checking-april.csv"
        ),
        sourceRow: PendingReviewSourceRow(
            id: 42,
            sourceLineNumber: 2,
            rowHash: "row-1-sha256",
            rawPayload: #"["2026-04-01","Coffee Shop","-4.75"]"#
        ),
        duplicateTransactionID: duplicateTransactionID
    )
    let service = ReviewService(store: StubReviewQueueStore(items: [item]))

    let items = try service.loadPendingReviewItems()

    #expect(items == [item])
}

@Test
func keepBothLikelyDuplicateDelegatesToStoreAndReturnsDecisionEvent() throws {
    let store = RecordingReviewQueueStore()
    let service = ReviewService(store: store)
    let reviewItemID = UUID(uuidString: "00000000-0000-0000-0000-000000000555")!
    let resolvedAt = Date(timeIntervalSince1970: 1_775_171_260)

    let event = try service.keepBothLikelyDuplicateReviewItem(id: reviewItemID, resolvedAt: resolvedAt)

    #expect(store.resolvedReviewItemID == reviewItemID)
    #expect(store.resolvedAt == resolvedAt)
    #expect(event == store.returnedEvent)
}

@Test
func approveClassificationDelegatesToStoreAndReturnsDecisionEvent() throws {
    let store = RecordingReviewQueueStore()
    let service = ReviewService(store: store)
    let reviewItemID = UUID(uuidString: "00000000-0000-0000-0000-000000000555")!
    let categoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000111")!
    let assignment = ClassificationAssignment(categoryID: categoryID, merchantName: "Coffee Shop")
    let resolvedAt = Date(timeIntervalSince1970: 1_775_171_260)

    let event = try service.approveClassificationReviewItem(
        id: reviewItemID,
        assignment: assignment,
        createRule: true,
        resolvedAt: resolvedAt
    )

    #expect(store.approvedClassificationReviewItemID == reviewItemID)
    #expect(store.approvedAssignment == assignment)
    #expect(store.approvedCreateRule == true)
    #expect(store.resolvedAt == resolvedAt)
    #expect(event == store.returnedEvent)
}
