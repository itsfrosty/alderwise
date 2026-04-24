import Application
import Domain
import Foundation
import Testing

@testable import AlderwiseApp

@Test
@MainActor
func importingOneCSVSelectionOpensABatchPreflightSessionInsteadOfTheLegacyPreview() throws {
    let files = try CSVImportQueueTestFiles.make(
        [
            ("checking-april.csv", "Date,Description,Amount\n2026-04-01,Coffee,-4.75\n"),
        ]
    )
    let model = WorkspaceShellModel(store: nil, service: WorkspaceService(store: WorkspaceShellModelCSVImportQueueStore()))

    model.importCSV(from: .success(files.urls))

    #expect(model.batchImportSession?.draft.items.map(\.originalFilename) == ["checking-april.csv"])
    #expect(model.batchImportSession?.draft.isReadyForImport == true)
    #expect(model.importErrorMessage == nil)
}

@Test
@MainActor
func confirmingBatchImportStagesTheQueuedSelectionAndDismissesTheBatchSession() async throws {
    let files = try CSVImportQueueTestFiles.make(
        [
            ("checking-april.csv", "Date,Description,Amount\n2026-04-01,Coffee,-4.75\n"),
        ]
    )
    let store = WorkspaceShellModelCSVImportQueueStore()
    let service = WorkspaceService(store: store)
    let model = WorkspaceShellModel(store: nil, service: service)

    model.importCSV(from: .success(files.urls))

    _ = try #require(model.batchImportSession)

    model.confirmBatchCSVImport()
    #expect(model.batchImportSession?.importPhase == .staging)

    await waitForBatchImportCompletion(in: model)

    #expect(store.createdSessions.map(\.originalFilename) == ["checking-april.csv"])
    #expect(model.batchImportSession == nil)
    #expect(
        model.importResultMessage
            == "1 imported to Transactions, 0 skipped, 1 sent to Review, 0 likely duplicates waiting in Review."
    )
    #expect(model.importErrorMessage == nil)
}

@Test
@MainActor
func importingMultipleCSVFilesCreatesASingleBatchSessionWithAllItems() throws {
    let files = try CSVImportQueueTestFiles.make(
        [
            ("checking-april.csv", "Date,Description,Amount\n2026-04-01,Coffee,-4.75\n"),
            ("checking-may.csv", "Date,Description,Amount\n2026-05-01,Payroll\n"),
        ]
    )
    let model = WorkspaceShellModel(store: nil, service: WorkspaceService(store: WorkspaceShellModelCSVImportQueueStore()))

    model.importCSV(from: .success(files.urls))

    #expect(model.batchImportSession?.draft.items.map(\.originalFilename) == ["checking-april.csv", "checking-may.csv"])
    #expect(model.batchImportSession?.draft.selectedItem?.originalFilename == "checking-may.csv")
    #expect(model.batchImportSession?.draft.isReadyForImport == false)
    #expect(model.importErrorMessage == nil)
}

@Test
func csvImportPreviewSheetExplainsVenmoDerivedCategorization() throws {
    let preview = try CSVImportPreviewService().makePreview(from: venmoStatementCSV())

    #expect(CSVImportPreviewEditorContent.descriptionSemanticsLines(for: preview) == [
        "Venmo imports keep the Note column as the raw description.",
        "Used for categorization: Jordan Example",
        "Used for categorization: Taylor Example",
    ])
}

@Test
func csvImportPreviewEditorSelectionKeepsAmountModesConsistentAndSyncsIncomingMappings() {
    var selection = CSVImportPreviewEditorSelection(
        mapping: CSVColumnMapping(
            dateColumnIndex: 0,
            descriptionColumnIndex: 1,
            amount: .singleSignedAmount(columnIndex: 2)
        )
    )

    selection.signedAmountColumnIndex = 3
    #expect(selection.mapping.amount == .singleSignedAmount(columnIndex: 3))

    selection.debitColumnIndex = 4
    selection.creditColumnIndex = 5
    #expect(selection.mapping.amount == .debitCredit(debitColumnIndex: 4, creditColumnIndex: 5))
    #expect(selection.signedAmountColumnIndex == nil)

    selection.sync(
        from: CSVColumnMapping(
            dateColumnIndex: 6,
            descriptionColumnIndex: 7,
            amount: .singleSignedAmount(columnIndex: 8)
        )
    )
    #expect(selection.dateColumnIndex == 6)
    #expect(selection.descriptionColumnIndex == 7)
    #expect(selection.signedAmountColumnIndex == 8)
    #expect(selection.debitColumnIndex == nil)
    #expect(selection.creditColumnIndex == nil)
    #expect(selection.mapping.amount == .singleSignedAmount(columnIndex: 8))
}

private struct CSVImportQueueTestFiles {
    let directoryURL: URL
    let urls: [URL]

    static func make(_ files: [(filename: String, contents: String)]) throws -> CSVImportQueueTestFiles {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        var urls: [URL] = []
        for file in files {
            let url = directoryURL.appendingPathComponent(file.filename)
            try file.contents.write(to: url, atomically: true, encoding: .utf8)
            urls.append(url)
        }

        return CSVImportQueueTestFiles(directoryURL: directoryURL, urls: urls)
    }
}

private final class WorkspaceShellModelCSVImportQueueStore: @unchecked Sendable, WorkspaceStoring, StagedImportWriting, ImportDecisionReading, TargetManaging, WorkspaceMaintenanceManaging, WorkspacePreferencesManaging {
    private(set) var createdSessions: [StagedImportSessionDraft] = []

    private let account = Account(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000901")!,
        name: "Checking",
        kind: .checking,
        institutionName: "Local Bank"
    )

    func fetchSummary() throws -> WorkspaceSummary {
        .empty
    }

    func fetchAccounts() throws -> [Account] {
        [account]
    }

    func fetchManagementAccounts() throws -> [Account] {
        [account]
    }

    func fetchImportEligibleAccounts() throws -> [Account] {
        [account]
    }

    func fetchLedgerFilterAccounts() throws -> [Account] {
        [account]
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
        Account(id: id, name: account.name, kind: account.kind, institutionName: account.institutionName, archivedAt: archivedAt)
    }

    func restoreAccount(id: UUID) throws -> Account {
        account
    }

    func deleteAccountPermanently(id: UUID) throws {}

    func createStagedImportSession(_ draft: StagedImportSessionDraft) throws -> StagedImportSession {
        createdSessions.append(draft)

        let sourceFile = StagedSourceFile(
            id: Int64(createdSessions.count),
            accountID: draft.accountID,
            originalFilename: draft.originalFilename,
            contentHash: draft.contentHash,
            importedAt: draft.importedAt,
            rowCount: draft.rows.count
        )
        let rows = draft.rows.enumerated().map { index, row in
            StagedSourceRow(
                id: Int64(index + 1),
                sourceFileID: sourceFile.id,
                sourceLineNumber: row.sourceLineNumber,
                rawPayload: row.rawPayload,
                rowHash: row.rowHash,
                validationStatus: row.validationStatus,
                importDecision: row.importDecision
            )
        }

        return StagedImportSession(
            id: sourceFile.id,
            sourceFile: sourceFile,
            mapping: draft.mapping,
            validRowCount: draft.validRowCount,
            invalidRowCount: draft.invalidRowCount,
            status: draft.status,
            rows: rows
        )
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
            databaseURL: URL(fileURLWithPath: "/tmp/alderwise-import-queue.sqlite"),
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

@MainActor
private func waitForBatchImportCompletion(
    in model: WorkspaceShellModel,
    timeoutNanoseconds: UInt64 = 1_000_000_000
) async {
    let deadline = DispatchTime.now().uptimeNanoseconds + timeoutNanoseconds

    while DispatchTime.now().uptimeNanoseconds < deadline {
        if model.batchImportSession == nil {
            return
        }
        await Task.yield()
    }

    Issue.record("Timed out waiting for batch import completion.")
}

private func venmoStatementCSV() -> String {
    """
    Account Statement - (@alex-example),,,,,,,,,,,,,,,,,,,,,
    Account Activity,,,,,,,,,,,,,,,,,,,,,
    ,ID,Datetime,Type,Status,Note,From,To,Amount (total),Amount (tip),Amount (tax),Amount (fee),Tax Rate,Tax Exempt,Funding Source,Destination,Beginning Balance,Ending Balance,Statement Period Venmo Fees,Terminal Location,Year to Date Venmo Fees,Disclaimer
    ,,,,,,,,,,,,,,,,$7.94,,,,,
    ,4303787187085607348,2025-04-05T02:16:52,Payment,Complete,Groceries,Alex Example,Jordan Example,- $135.00,,0,,0,,Bank Checking *1234,,,,,Venmo,,
    ,4306652244709872490,2025-04-09T01:09:14,Payment,Complete,Birthday dinner,Taylor Example,Alex Example,$42.50,,0,,0,,Venmo balance,,,,,Venmo,,
    ,,,,,,,,,,,,,,,,,$6.94,$0.00,,$0.00,"Disclaimer text"
    """
}
