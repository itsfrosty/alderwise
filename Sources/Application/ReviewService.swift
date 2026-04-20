import Domain
import Foundation

public struct ReviewService: Sendable {
    private let reader: any ReviewQueueReading
    private let writer: (any ReviewQueueWriting)?

    public init(store: any ReviewQueueReading) {
        self.reader = store
        self.writer = store as? any ReviewQueueWriting
    }

    public func loadPendingReviewItems() throws -> [PendingReviewItem] {
        try reader.fetchPendingReviewItems()
    }

    public func keepBothLikelyDuplicateReviewItem(id: UUID, resolvedAt: Date = Date()) throws -> ReviewDecisionEvent {
        guard let writer else {
            throw ReviewServiceError.reviewMutationsUnavailable
        }

        return try writer.keepBothForLikelyDuplicateReviewItem(id: id, resolvedAt: resolvedAt)
    }

    public func approveClassificationReviewItem(
        id: UUID,
        assignment: ClassificationAssignment,
        createRule: Bool,
        resolvedAt: Date = Date()
    ) throws -> ReviewDecisionEvent {
        guard let writer else {
            throw ReviewServiceError.reviewMutationsUnavailable
        }

        return try writer.approveClassificationReviewItem(
            id: id,
            assignment: assignment,
            createRule: createRule,
            resolvedAt: resolvedAt
        )
    }
}

private enum ReviewServiceError: Error {
    case reviewMutationsUnavailable
}
