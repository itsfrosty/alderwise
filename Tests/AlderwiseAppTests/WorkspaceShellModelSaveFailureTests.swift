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
func hidingSelectedTransactionFallsBackToNextVisibleSelection() {
    let store = WorkspaceShellModelVisibilityStore()
    let service = WorkspaceService(store: store)
    let model = WorkspaceShellModel(store: nil, service: service)
    let hiddenID = model.selectedTransactionID

    let didHide = model.setSelectedTransactionHidden(true)

    #expect(didHide == true)
    #expect(hiddenID != nil)
    #expect(model.selectedTransactionID == WorkspaceShellModelVisibilityStore.fourthTransactionID)
    #expect(model.selectedTransactionDetail?.row.id == WorkspaceShellModelVisibilityStore.fourthTransactionID)
    #expect(model.transactionDetailErrorMessage == nil)
}

@Test
@MainActor
func unhidingSelectedHiddenTransactionFallsBackToRemainingHiddenSelection() {
    let store = WorkspaceShellModelVisibilityStore()
    let service = WorkspaceService(store: store)
    let model = WorkspaceShellModel(store: nil, service: service)
    model.updateTransactionFilter(TransactionLedgerFilter(visibility: .hidden))

    let didUnhide = model.setSelectedTransactionHidden(false)

    #expect(didUnhide == true)
    #expect(model.selectedTransactionID == WorkspaceShellModelVisibilityStore.thirdTransactionID)
    #expect(model.selectedTransactionDetail?.row.id == WorkspaceShellModelVisibilityStore.thirdTransactionID)
    #expect(model.transactionFilter.visibility == .hidden)
}

@Test
@MainActor
func failedHideTransactionDoesNotClearSelectionOrState() {
    let store = WorkspaceShellModelFailureStore(behavior: .writeFails)
    let service = WorkspaceService(store: store)
    let model = WorkspaceShellModel(store: nil, service: service)

    let currentID = model.selectedTransactionID!

    let didHide = model.setSelectedTransactionHidden(true)

    #expect(didHide == false)
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

@Test
@MainActor
func resetRequiredWorkspaceBlocksNormalUseAndKeepsRecoveryActionsAvailable() {
    let store = WorkspaceShellModelFailureStore(behavior: .requiresReset)
    let service = WorkspaceService(store: store)
    let model = WorkspaceShellModel(store: nil, service: service)

    #expect({
        if case .failed(let message) = model.state {
            return message.contains("older default taxonomy")
        }
        return false
    }())
    #expect(model.workspaceMetadata?.requiresReset == true)
    #expect(model.workspaceStatus == .available(WorkspaceMetadata(
        databaseURL: URL(fileURLWithPath: "/tmp/alderwise-test.sqlite"),
        databaseExists: true,
        databaseSizeBytes: 0,
        modifiedAt: nil,
        requiresReset: true,
        resetReason: "This workspace was created with an older default taxonomy. Back up if needed, then reset and reimport to continue with this version of Alderwise."
    )))
    #expect(model.selectedTransactionID == nil)
    #expect(model.learnedRuleManagerSnapshot == nil)
}

private final class WorkspaceShellModelFailureStore: @unchecked Sendable, WorkspaceStoring, StagedImportWriting, ImportDecisionReading, TargetManaging, WorkspaceMaintenanceManaging, WorkspacePreferencesManaging, TransactionLedgerReading, TransactionLedgerWriting {
    enum Behavior {
        case writeFails
        case reloadFailsAfterWrite
        case requiresReset
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
            modifiedAt: nil,
            requiresReset: behavior == .requiresReset,
            resetReason: behavior == .requiresReset
                ? "This workspace was created with an older default taxonomy. Back up if needed, then reset and reimport to continue with this version of Alderwise."
                : nil
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
        case .requiresReset:
            Issue.record("updateTransactionLedgerFields should not be reached for reset-required workspace tests")
        }
    }

    func setTransactionHidden(id: UUID, isHidden: Bool) throws {
        switch behavior {
        case .writeFails:
            throw Self.updateError
        case .reloadFailsAfterWrite:
            didWriteTransaction = true
        case .requiresReset:
            Issue.record("setTransactionHidden should not be reached for reset-required workspace tests")
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

private final class WorkspaceShellModelVisibilityStore: @unchecked Sendable, WorkspaceStoring, StagedImportWriting, ImportDecisionReading, TargetManaging, WorkspaceMaintenanceManaging, WorkspacePreferencesManaging, TransactionLedgerReading, TransactionLedgerWriting {
    static let firstTransactionID = UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!
    static let secondTransactionID = UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!
    static let thirdTransactionID = UUID(uuidString: "cccccccc-cccc-cccc-cccc-cccccccccccc")!
    static let fourthTransactionID = UUID(uuidString: "dddddddd-dddd-dddd-dddd-dddddddddddd")!

    private var hiddenTransactionIDs: Set<UUID> = [firstTransactionID, thirdTransactionID]

    func fetchSummary() throws -> WorkspaceSummary {
        WorkspaceSummary(accountCount: 1, transactionCount: 2, reviewCount: 0, targetCount: 0)
    }

    func fetchAccounts() throws -> [Account] { [] }
    func fetchManagementAccounts() throws -> [Account] { [] }
    func fetchImportEligibleAccounts() throws -> [Account] { [] }
    func fetchLedgerFilterAccounts() throws -> [Account] { [] }
    func fetchPermanentlyDeletableAccountIDs() throws -> Set<UUID> { [] }
    func fetchCategories() throws -> [BudgetCategory] { [] }
    func fetchCategoryGroups() throws -> [BudgetCategoryGroup] { [] }
    func createAccount(named: String, kind: AccountKind, institutionName: String?) throws -> Account { fatalError("Not used in this test") }
    func updateAccount(id: UUID, named: String, kind: AccountKind, institutionName: String?) throws -> Account { fatalError("Not used in this test") }
    func archiveAccount(id: UUID, archivedAt: Date) throws -> Account { fatalError("Not used in this test") }
    func restoreAccount(id: UUID) throws -> Account { fatalError("Not used in this test") }
    func deleteAccountPermanently(id: UUID) throws {}
    func createStagedImportSession(_ draft: StagedImportSessionDraft) throws -> StagedImportSession { fatalError("Not used in this test") }
    func fetchExistingSourceRowHashes(accountID: UUID, rowHashes: Set<String>) throws -> Set<String> { [] }
    func fetchExistingSourceRowHashCounts(accountID: UUID, rowHashes: Set<String>) throws -> [String: Int] { [:] }
    func fetchLikelyDuplicateTransactions(accountID: UUID, candidates: [NormalizedImportCandidate]) throws -> [LikelyDuplicateCandidate] { [] }
    func fetchManagedTargets(referenceDate: Date) throws -> [ManagedMonthlyTarget] { [] }
    func createMonthlyTarget(_ draft: MonthlyTargetDraft, createdAt: Date) throws -> MonthlyTarget { fatalError("Not used in this test") }
    func updateMonthlyTarget(id: UUID, _ draft: MonthlyTargetDraft) throws -> MonthlyTarget { fatalError("Not used in this test") }
    func deleteMonthlyTarget(id: UUID) throws {}
    func fetchWorkspaceMetadata() throws -> WorkspaceMetadata {
        WorkspaceMetadata(
            databaseURL: URL(fileURLWithPath: "/tmp/alderwise-visibility-test.sqlite"),
            databaseExists: true,
            databaseSizeBytes: 0,
            modifiedAt: nil
        )
    }
    func createWorkspaceBackup(in directory: URL?, now: Date) throws -> WorkspaceBackup { fatalError("Not used in this test") }
    func restoreWorkspaceBackup(from backupURL: URL, safetyBackupDirectory: URL?, now: Date) throws -> WorkspaceRestoreResult { fatalError("Not used in this test") }
    func resetWorkspace() throws -> WorkspaceResetResult { fatalError("Not used in this test") }
    func fetchWorkspacePreferences() throws -> WorkspacePreferences { .default }
    func updateWorkspacePreferences(_ preferences: WorkspacePreferences) throws {}

    func updateTransactionLedgerFields(id: UUID, draft: TransactionLedgerEditDraft) throws {
        fatalError("Not used in this test")
    }

    func setTransactionHidden(id: UUID, isHidden: Bool) throws {
        if isHidden {
            hiddenTransactionIDs.insert(id)
        } else {
            hiddenTransactionIDs.remove(id)
        }
    }

    func fetchTransactionLedger(filter: TransactionLedgerFilter) throws -> [TransactionLedgerRow] {
        rows.filter { row in
            switch filter.visibility ?? .active {
            case .active:
                return row.isHidden == false
            case .hidden:
                return row.isHidden
            case .all:
                return true
            }
        }
    }

    func fetchTransactionDetail(id: UUID) throws -> TransactionDetail? {
        guard let row = rows.first(where: { $0.id == id }) else {
            return nil
        }
        return TransactionDetail(
            row: row,
            notes: nil,
            decisionSource: nil,
            decisionSourceReference: nil,
            confidence: nil,
            duplicateStatus: "unique"
        )
    }

    func fetchTransactionImportOrigins() throws -> [TransactionImportOrigin] { [] }

    private var rows: [TransactionLedgerRow] {
        [
            makeRow(id: Self.firstTransactionID, merchantName: "First Hidden", isHidden: hiddenTransactionIDs.contains(Self.firstTransactionID)),
            makeRow(id: Self.secondTransactionID, merchantName: "Second Active", isHidden: hiddenTransactionIDs.contains(Self.secondTransactionID)),
            makeRow(id: Self.thirdTransactionID, merchantName: "Third Hidden", isHidden: hiddenTransactionIDs.contains(Self.thirdTransactionID)),
            makeRow(id: Self.fourthTransactionID, merchantName: "Fourth Active", isHidden: hiddenTransactionIDs.contains(Self.fourthTransactionID)),
        ]
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

private func makeRow(id: UUID, merchantName: String = "Merchant", isHidden: Bool = false) -> TransactionLedgerRow {
    TransactionLedgerRow(
        id: id,
        accountID: UUID(uuidString: "dddddddd-dddd-dddd-dddd-dddddddddddd")!,
        accountName: "Checking",
        isHidden: isHidden,
        categoryID: UUID(uuidString: "eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee")!,
        categoryName: "Dining",
        rawDescription: "Memo",
        merchantName: merchantName,
        amount: Decimal(-10),
        transactionDate: Date(timeIntervalSince1970: 0),
        postedDate: nil,
        direction: .expense,
        reviewStatus: .accepted,
        importOrigin: nil
    )
}
