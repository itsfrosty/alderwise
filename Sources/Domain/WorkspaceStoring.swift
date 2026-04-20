public protocol WorkspaceReading: Sendable {
    func fetchSummary() throws -> WorkspaceSummary
    func fetchAccounts() throws -> [Account]
}

public protocol AccountWriting: Sendable {
    func createAccount(named: String, kind: AccountKind, institutionName: String?) throws -> Account
}

public protocol StagedImportWriting: Sendable {
    func createStagedImportSession(_ draft: StagedImportSessionDraft) throws -> StagedImportSession
}

public protocol StagedImportReading: Sendable {
    func fetchStagedImportSession(id: Int64) throws -> StagedImportSession?
}

public typealias WorkspaceStoring = WorkspaceReading & AccountWriting
