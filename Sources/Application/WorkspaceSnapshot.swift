import Domain

public struct WorkspaceSnapshot: Equatable, Sendable {
    public var summary: WorkspaceSummary
    public var accounts: [Account]

    public init(summary: WorkspaceSummary, accounts: [Account]) {
        self.summary = summary
        self.accounts = accounts
    }
}
