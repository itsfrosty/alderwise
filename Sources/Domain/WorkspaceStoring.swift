import Foundation

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

public protocol ImportDecisionReading: Sendable {
    func fetchExistingSourceRowHashes(accountID: UUID, rowHashes: Set<String>) throws -> Set<String>
    func fetchExistingSourceRowHashCounts(accountID: UUID, rowHashes: Set<String>) throws -> [String: Int]
    func fetchLikelyDuplicateTransactions(
        accountID: UUID,
        candidates: [NormalizedImportCandidate]
    ) throws -> [LikelyDuplicateCandidate]
}

public typealias WorkspaceStoring = WorkspaceReading & AccountWriting
