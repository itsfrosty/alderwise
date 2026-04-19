public protocol WorkspaceReading: Sendable {
    func fetchSummary() throws -> WorkspaceSummary
    func fetchAccounts() throws -> [Account]
}

public protocol AccountWriting: Sendable {
    func createAccount(named: String, kind: AccountKind, institutionName: String?) throws -> Account
}

public typealias WorkspaceStoring = WorkspaceReading & AccountWriting
