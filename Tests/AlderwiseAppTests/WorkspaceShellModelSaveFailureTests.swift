import Application
import Domain
import Foundation
import Testing

@testable import AlderwiseApp

@Test
@MainActor
func failedTransactionSaveDoesNotClearSelectionOrState() {
    let currentID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    let store = SaveFailureWorkspaceStore()
    let service = WorkspaceService(store: store)
    let model = WorkspaceShellModel(store: nil, service: service)
    let draft = TransactionLedgerEditDraft(
        merchantName: "Updated Merchant",
        categoryID: nil,
        notes: "Edited notes"
    )

    model.selectedTransactionID = currentID

    let didSave = model.updateSelectedTransaction(draft: draft)

    #expect(didSave == false)
    #expect(model.selectedTransactionID == currentID)
    #expect(model.transactionDetailErrorMessage == SaveFailureWorkspaceStore.updateError.localizedDescription)
    #expect({
        if case .loaded = model.state {
            return true
        }
        return false
    }())
}

private struct SaveFailureWorkspaceStore: WorkspaceStoring, StagedImportWriting, ImportDecisionReading, TargetManaging, WorkspaceMaintenanceManaging, WorkspacePreferencesManaging, TransactionLedgerWriting {
    static let updateError = SaveFailureError()

    func fetchSummary() throws -> WorkspaceSummary {
        .empty
    }

    func fetchAccounts() throws -> [Account] {
        []
    }

    func fetchManagementAccounts() throws -> [Account] {
        []
    }

    func fetchImportEligibleAccounts() throws -> [Account] {
        []
    }

    func fetchLedgerFilterAccounts() throws -> [Account] {
        []
    }

    func fetchPermanentlyDeletableAccountIDs() throws -> Set<UUID> {
        []
    }

    func fetchCategories() throws -> [BudgetCategory] {
        []
    }

    func fetchCategoryGroups() throws -> [BudgetCategoryGroup] {
        []
    }

    func createAccount(named: String, kind: AccountKind, institutionName: String?) throws -> Account {
        Account(name: named, kind: kind, institutionName: institutionName)
    }

    func updateAccount(id: UUID, named: String, kind: AccountKind, institutionName: String?) throws -> Account {
        Account(id: id, name: named, kind: kind, institutionName: institutionName)
    }

    func archiveAccount(id: UUID, archivedAt: Date) throws -> Account {
        Account(id: id, name: "Archived", kind: .checking, institutionName: nil, archivedAt: archivedAt)
    }

    func restoreAccount(id: UUID) throws -> Account {
        Account(id: id, name: "Restored", kind: .checking, institutionName: nil)
    }

    func deleteAccountPermanently(id: UUID) throws {}

    func createStagedImportSession(_ draft: StagedImportSessionDraft) throws -> StagedImportSession {
        fatalError("Not used in this test")
    }

    func fetchExistingSourceRowHashes(accountID: UUID, rowHashes: Set<String>) throws -> Set<String> {
        []
    }

    func fetchExistingSourceRowHashCounts(accountID: UUID, rowHashes: Set<String>) throws -> [String: Int] {
        [:]
    }

    func fetchLikelyDuplicateTransactions(
        accountID: UUID,
        candidates: [NormalizedImportCandidate]
    ) throws -> [LikelyDuplicateCandidate] {
        []
    }

    func fetchManagedTargets(referenceDate: Date) throws -> [ManagedMonthlyTarget] {
        []
    }

    func createMonthlyTarget(_ draft: MonthlyTargetDraft, createdAt: Date) throws -> MonthlyTarget {
        fatalError("Not used in this test")
    }

    func updateMonthlyTarget(id: UUID, _ draft: MonthlyTargetDraft) throws -> MonthlyTarget {
        fatalError("Not used in this test")
    }

    func deleteMonthlyTarget(id: UUID) throws {}

    func fetchWorkspaceMetadata() throws -> WorkspaceMetadata {
        WorkspaceMetadata(
            databaseURL: URL(fileURLWithPath: "/tmp/alderwise-test.sqlite"),
            databaseExists: true,
            databaseSizeBytes: 0,
            modifiedAt: nil
        )
    }

    func createWorkspaceBackup(in directory: URL?, now: Date) throws -> WorkspaceBackup {
        fatalError("Not used in this test")
    }

    func restoreWorkspaceBackup(
        from backupURL: URL,
        safetyBackupDirectory: URL?,
        now: Date
    ) throws -> WorkspaceRestoreResult {
        fatalError("Not used in this test")
    }

    func resetWorkspace() throws -> WorkspaceResetResult {
        fatalError("Not used in this test")
    }

    func fetchWorkspacePreferences() throws -> WorkspacePreferences {
        .default
    }

    func updateWorkspacePreferences(_ preferences: WorkspacePreferences) throws {}

    func updateTransactionLedgerFields(id: UUID, draft: TransactionLedgerEditDraft) throws {
        throw SaveFailureError()
    }
}

private struct SaveFailureError: LocalizedError {
    var errorDescription: String? {
        "Transaction save failed."
    }
}
