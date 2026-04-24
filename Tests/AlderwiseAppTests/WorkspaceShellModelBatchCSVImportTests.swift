import Application
import Domain
import Foundation
import Testing

@testable import AlderwiseApp

@Suite
struct WorkspaceShellModelBatchCSVImportTests {
    @Test
    func accountCreationSheetStatePreservesEnteredValuesOnValidationFailure() {
        var state = AccountCreationSheetState(
            name: "   ",
            institutionName: "Local Bank",
            kind: .savings,
            errorMessage: nil
        )

        let didSubmit = state.submit { _, _, _ in
            Issue.record("Validation failures should not call onCreate.")
        }

        #expect(didSubmit == false)
        #expect(state.name == "   ")
        #expect(state.institutionName == "Local Bank")
        #expect(state.kind == .savings)
        #expect(state.errorMessage == "Enter an account name.")
    }

    @Test
    func accountCreationSheetStatePreservesEnteredValuesOnServiceFailure() {
        var state = AccountCreationSheetState(
            name: "Travel Card",
            institutionName: "Visa",
            kind: .creditCard,
            errorMessage: nil
        )

        let didSubmit = state.submit { _, _, _ in
            throw BatchCSVImportTestError(message: "Create failed")
        }

        #expect(didSubmit == false)
        #expect(state.name == "Travel Card")
        #expect(state.institutionName == "Visa")
        #expect(state.kind == .creditCard)
        #expect(state.errorMessage == "Create failed")
    }

    @Test
    @MainActor
    func generalAndImportScopedAccountCreationRoutesRemainDistinguishable() throws {
        let model = makeModel()
        let session = try makeBatchImportSession(
            importEligibleAccounts: [existingAccount(id: "00000000-0000-0000-0000-000000000401", name: "Checking")]
        )
        let itemID = try #require(session.draft.items.first?.id)

        model.beginAccountCreation()
        #expect(model.accountCreationRoute == .general)

        model.presentBatchImportSession(session)
        model.beginBatchImportAccountCreation(itemID: itemID)

        #expect(model.accountCreationRoute == .batchImport(itemID: itemID))
    }

    @Test
    @MainActor
    func openingAccountCreationFromABatchItemRecordsTheTriggerAndCancelKeepsTheSelectedItem() throws {
        let model = makeModel()
        let session = try makeBatchImportSession(
            importEligibleAccounts: [
                existingAccount(id: "00000000-0000-0000-0000-000000000402", name: "Checking"),
                existingAccount(id: "00000000-0000-0000-0000-000000000403", name: "Savings"),
            ]
        )
        let triggeringItemID = try #require(session.draft.items.first?.id)
        let selectedItemID = try #require(session.draft.items.last?.id)

        session.selectItem(id: selectedItemID)
        model.presentBatchImportSession(session)

        model.beginBatchImportAccountCreation(itemID: triggeringItemID)
        #expect(model.accountCreationRoute == .batchImport(itemID: triggeringItemID))
        #expect(model.batchImportSession?.draft.selectedItemID == selectedItemID)

        model.cancelAccountCreation()

        #expect(model.accountCreationRoute == nil)
        #expect(model.batchImportSession?.draft.selectedItemID == selectedItemID)
    }

    @Test
    @MainActor
    func accountCreationFailureKeepsTheImportScopedRouteOpenAndPreservesBatchSelection() throws {
        let store = WorkspaceShellModelBatchCSVImportStore()
        store.createAccountError = BatchCSVImportTestError(message: "Create failed")
        let model = makeModel(store: store)
        let session = try makeBatchImportSession(
            importEligibleAccounts: [store.initialAccount]
        )
        let triggeringItemID = try #require(session.draft.items.first?.id)
        let selectedItemID = try #require(session.draft.items.last?.id)
        let originalAccountIDs = session.draft.items.map(\.selectedAccountID)

        session.selectItem(id: selectedItemID)
        model.presentBatchImportSession(session)
        model.beginBatchImportAccountCreation(itemID: triggeringItemID)

        #expect(throws: BatchCSVImportTestError.self) {
            try model.createAccount(name: "Travel Card", kind: .creditCard, institutionName: "Visa")
        }

        #expect(model.accountCreationRoute == .batchImport(itemID: triggeringItemID))
        #expect(model.batchImportSession?.draft.selectedItemID == selectedItemID)
        #expect(model.batchImportSession?.draft.items.map(\.selectedAccountID) == originalAccountIDs)
    }

    @Test
    @MainActor
    func replacingBatchImportSessionClearsTheImportScopedAccountCreationRoute() throws {
        let store = WorkspaceShellModelBatchCSVImportStore()
        let model = makeModel(store: store)
        let originalSession = try makeBatchImportSession(
            importEligibleAccounts: [store.initialAccount]
        )
        let triggeringItemID = try #require(originalSession.draft.items.first?.id)

        model.presentBatchImportSession(originalSession)
        model.beginBatchImportAccountCreation(itemID: triggeringItemID)

        let replacementSession = try makeBatchImportSession(
            importEligibleAccounts: [store.initialAccount]
        )
        model.presentBatchImportSession(replacementSession)

        #expect(model.accountCreationRoute == nil)
        #expect(model.snapshot.importEligibleAccounts.map(\.id) == [store.initialAccount.id])
    }

    @Test
    @MainActor
    func successfulCreateClearsTheRouteAndAssignsTheNewAccountOnlyToTheTriggeringBatchItem() throws {
        let store = WorkspaceShellModelBatchCSVImportStore()
        let model = makeModel(store: store)
        let session = try makeBatchImportSession(
            importEligibleAccounts: [store.initialAccount]
        )
        let firstItemID = try #require(session.draft.items.first?.id)
        let secondItemID = try #require(session.draft.items.last?.id)
        let originalAccountID = try #require(session.draft.items.first?.selectedAccountID)

        model.presentBatchImportSession(session)
        model.beginBatchImportAccountCreation(itemID: secondItemID)

        let createdAccount = try model.createAccount(
            name: "Travel Card",
            kind: .creditCard,
            institutionName: "Visa"
        )

        #expect(model.accountCreationRoute == nil)
        #expect(model.batchImportSession?.draft.selectedItemID == firstItemID)
        #expect(accountID(for: firstItemID, in: model) == originalAccountID)
        #expect(accountID(for: secondItemID, in: model) == createdAccount.id)
        #expect(model.snapshot.importEligibleAccounts.map(\.id) == [originalAccountID, createdAccount.id])
    }

    @Test
    @MainActor
    func importingOneCSVOpensTheBatchPreflightFlowInsteadOfTheLegacyPreviewSheet() throws {
        let files = try BatchCSVImportSessionTestFiles.make(
            [("checking-april.csv", "Date,Description,Amount\n2026-04-01,Coffee,-4.75\n")]
        )
        let model = makeModel()

        model.importCSV(from: .success(files.urls))

        #expect(model.batchImportSession?.draft.items.map(\.originalFilename) == ["checking-april.csv"])
        #expect(model.batchImportSession?.draft.selectedItem?.originalFilename == "checking-april.csv")
        #expect(model.isPresentingImportPreview == false)
        #expect(model.csvImportPreview == nil)
        #expect(model.pendingCSVImport == nil)
        #expect(model.importErrorMessage == nil)
    }

    @Test
    @MainActor
    func importingMultipleCSVFilesCreatesOneBatchSessionAndSelectsTheFirstBlockedFile() throws {
        let files = try BatchCSVImportSessionTestFiles.make(
            [
                ("ready.csv", "Date,Description,Amount\n2026-04-01,Coffee,-4.75\n"),
                ("blocked.csv", "Date,Description,Amount\n2026-04-01,Coffee\n"),
                ("later.csv", "Date,Description,Amount\n2026-04-02,Payroll,1200.00\n"),
            ]
        )
        let model = makeModel()

        model.importCSV(from: .success(files.urls))

        #expect(model.batchImportSession?.draft.items.map(\.originalFilename) == ["ready.csv", "blocked.csv", "later.csv"])
        #expect(model.batchImportSession?.draft.selectedItem?.originalFilename == "blocked.csv")
        #expect(model.batchImportSession?.draft.isReadyForImport == false)
        #expect(model.isPresentingImportPreview == false)
        #expect(model.csvImportPreview == nil)
        #expect(model.pendingCSVImport == nil)
        #expect(model.importErrorMessage == nil)
    }

    @MainActor
    private func makeModel(
        store: WorkspaceShellModelBatchCSVImportStore = WorkspaceShellModelBatchCSVImportStore()
    ) -> WorkspaceShellModel {
        WorkspaceShellModel(store: nil, service: WorkspaceService(store: store))
    }

    @MainActor
    private func makeBatchImportSession(
        importEligibleAccounts: [Account]
    ) throws -> BatchCSVImportSession {
        let files = try BatchCSVImportSessionTestFiles.make(
            [
                ("checking-april.csv", "Date,Description,Amount\n2026-04-01,Coffee,-4.75\n"),
                ("checking-may.csv", "Date,Description,Amount\n2026-05-01,Payroll,1250.00\n"),
            ]
        )

        return BatchCSVImportSession(
            selectedURLs: files.urls,
            importEligibleAccounts: importEligibleAccounts
        )
    }

    @MainActor
    private func accountID(for itemID: UUID, in model: WorkspaceShellModel) -> UUID? {
        model.batchImportSession?.draft.items.first(where: { $0.id == itemID })?.selectedAccountID
    }
}

private struct BatchCSVImportSessionTestFiles {
    let directoryURL: URL
    let urls: [URL]

    static func make(_ files: [(filename: String, contents: String)]) throws -> BatchCSVImportSessionTestFiles {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        var urls: [URL] = []
        for file in files {
            let url = directoryURL.appendingPathComponent(file.filename)
            try file.contents.write(to: url, atomically: true, encoding: .utf8)
            urls.append(url)
        }

        return BatchCSVImportSessionTestFiles(directoryURL: directoryURL, urls: urls)
    }
}

private struct BatchCSVImportTestError: Error, Equatable, LocalizedError {
    let message: String

    var errorDescription: String? { message }
}

private final class WorkspaceShellModelBatchCSVImportStore: @unchecked Sendable, WorkspaceStoring, StagedImportWriting, ImportDecisionReading, TargetManaging, WorkspaceMaintenanceManaging, WorkspacePreferencesManaging {
    let initialAccount = existingAccount(
        id: "00000000-0000-0000-0000-000000000404",
        name: "Checking"
    )

    var createAccountError: BatchCSVImportTestError?

    private var accounts: [Account]

    init() {
        accounts = [initialAccount]
    }

    func fetchSummary() throws -> WorkspaceSummary {
        .empty
    }

    func fetchAccounts() throws -> [Account] {
        accounts
    }

    func fetchManagementAccounts() throws -> [Account] {
        accounts
    }

    func fetchImportEligibleAccounts() throws -> [Account] {
        accounts
    }

    func fetchLedgerFilterAccounts() throws -> [Account] {
        accounts
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
        if let createAccountError {
            throw createAccountError
        }

        let account = Account(name: named, kind: kind, institutionName: institutionName)
        accounts.append(account)
        return account
    }

    func updateAccount(id: UUID, named: String, kind: AccountKind, institutionName: String?) throws -> Account {
        Account(id: id, name: named, kind: kind, institutionName: institutionName)
    }

    func archiveAccount(id: UUID, archivedAt: Date) throws -> Account {
        try #require(accounts.first(where: { $0.id == id }))
    }

    func restoreAccount(id: UUID) throws -> Account {
        try #require(accounts.first(where: { $0.id == id }))
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
            databaseURL: URL(fileURLWithPath: "/tmp/alderwise-batch-import.sqlite"),
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
}

private func existingAccount(id: String, name: String) -> Account {
    Account(
        id: UUID(uuidString: id)!,
        name: name,
        kind: .checking,
        institutionName: "Local Bank"
    )
}
