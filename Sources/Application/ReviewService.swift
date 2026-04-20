import Domain
import Foundation

public struct ReviewService: Sendable {
    private let store: any ReviewQueueReading

    public init(store: any ReviewQueueReading) {
        self.store = store
    }

    public func loadPendingReviewItems() throws -> [PendingReviewItem] {
        try store.fetchPendingReviewItems()
    }
}
