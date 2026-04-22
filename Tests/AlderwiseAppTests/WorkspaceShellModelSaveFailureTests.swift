import Application
import Domain
import Foundation
import Testing

@testable import AlderwiseApp

@Test
@MainActor
func failedTransactionSaveDoesNotClearSelectionOrState() {
    let store = WorkspaceShellModelFailureStore(behavior: .writeFails)
    let service = WorkspaceService(store: store)
    let model = WorkspaceShellModel(store: nil, service: service)
    let draft = TransactionLedgerEditDraft(
        merchantName: "Updated Merchant",
        categoryID: nil,
        notes: "Edited notes"
    )

    let currentID = model.selectedTransactionID!

    let didSave = model.updateSelectedTransaction(draft: draft)

    #expect(didSave == false)
    #expect(model.selectedTransactionID == currentID)
    #expect(model.transactionDetailErrorMessage == WorkspaceShellModelFailureStore.updateError.localizedDescription)
    #expect({
        if case .loaded = model.state {
            return true
        }
        return false
    }())
}

@Test
@MainActor
func successfulTransactionSaveFallsBackToWorkspaceFailureWhenReloadFails() {
    let store = WorkspaceShellModelFailureStore(behavior: .reloadFailsAfterWrite)
    let service = WorkspaceService(store: store)
    let model = WorkspaceShellModel(store: nil, service: service)
    let draft = TransactionLedgerEditDraft(
        merchantName: "Updated Merchant",
        categoryID: nil,
        notes: "Edited notes"
    )

    let didSave = model.updateSelectedTransaction(draft: draft)

    #expect(didSave == false)
    #expect(model.selectedTransactionID == nil)
    #expect(model.selectedTransactionDetail == nil)
    #expect(model.transactionDetailErrorMessage == nil)
    #expect(model.workspaceStatus == .failedToOpen(WorkspaceShellModelFailureStore.reloadError.localizedDescription))
    #expect({
        if case .failed = model.state {
            return true
        }
        return false
    }())
}

private final class WorkspaceShellModelFailureStore: @unchecked Sendable, WorkspaceStoring, StagedImportWriting, ImportDecisionReading, TargetManaging, WorkspaceMaintenanceManaging, WorkspacePreferencesManaging, TransactionLedgerReading, TransactionLedgerWriting {
    enum Behavior {
        case writeFails
        case reloadFailsAfterWrite
    }

    static let updateError = SaveFailureError()
    static let reloadError = ReloadFailureError()

    private let behavior: Behavior
    private var didWriteTransaction = false
    private let transactionID = UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!

    init(behavior: Behavior) {
        self.behavior = behavior
    }

    func fetchSummary() throws -> WorkspaceSummary {
        if behavior == .reloadFailsAfterWrite, didWriteTransaction {
            throw Self.reloadError
        }

        return .empty
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
        switch behavior {
        case .writeFails:
            throw Self.updateError
        case .reloadFailsAfterWrite:
            didWriteTransaction = true
        }
    }

    func fetchTransactionLedger(filter: TransactionLedgerFilter) throws -> [TransactionLedgerRow] {
        [makeRow()]
    }

    func fetchTransactionDetail(id: UUID) throws -> TransactionDetail? {
        guard id == transactionID else {
            return nil
        }

        return makeDetail()
    }

    func fetchTransactionImportOrigins() throws -> [TransactionImportOrigin] {
        []
    }

    private func makeRow() -> TransactionLedgerRow {
        TransactionLedgerRow(
            id: transactionID,
            accountID: UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!,
            accountName: "Checking",
            categoryID: UUID(uuidString: "cccccccc-cccc-cccc-cccc-cccccccccccc")!,
            categoryName: "Dining",
            rawDescription: "Memo",
            merchantName: "Merchant",
            amount: Decimal(-10),
            transactionDate: Date(timeIntervalSince1970: 0),
            postedDate: nil,
            direction: .expense,
            reviewStatus: .accepted,
            importOrigin: nil
        )
    }

    private func makeDetail() -> TransactionDetail {
        TransactionDetail(
            row: makeRow(),
            notes: "Original notes",
            decisionSource: nil,
            decisionSourceReference: nil,
            confidence: nil,
            duplicateStatus: "unique"
        )
    }
}

private struct SaveFailureError: LocalizedError {
    var errorDescription: String? {
        "Transaction save failed."
    }
}

private struct ReloadFailureError: LocalizedError {
    var errorDescription: String? {
        "Transaction reload failed."
    }
}
