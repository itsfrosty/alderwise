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

    @discardableResult
    public func createAccount(
        named: String,
        kind: AccountKind,
        institutionName: String?
    ) throws -> Account {
        try store.createAccount(
            named: named.trimmingCharacters(in: .whitespacesAndNewlines),
            kind: kind,
            institutionName: institutionName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        )
    }

    public func seedSampleDataIfNeeded() throws {
        let existingAccounts = try store.fetchAccounts()
        guard existingAccounts.isEmpty else {
            return
        }

        _ = try createAccount(
            named: "Checking",
            kind: .checking,
            institutionName: "Local Bank"
        )
        _ = try createAccount(
            named: "Daily Card",
            kind: .creditCard,
            institutionName: "Sample Card"
        )
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
