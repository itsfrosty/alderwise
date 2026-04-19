import Domain

public struct WorkspaceService: Sendable {
    private let store: any WorkspaceStoring

    public init(store: any WorkspaceStoring) {
        self.store = store
    }

    public func loadSnapshot() throws -> WorkspaceSnapshot {
        WorkspaceSnapshot(
            summary: try store.fetchSummary(),
            accounts: try store.fetchAccounts()
        )
    }
}
