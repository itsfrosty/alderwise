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
