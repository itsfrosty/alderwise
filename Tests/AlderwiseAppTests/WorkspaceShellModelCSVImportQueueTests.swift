import Application
import Domain
import Foundation
import Testing

@testable import AlderwiseApp

@Test
@MainActor
func selectingMultipleCSVFilesLoadsTheFirstPreview() throws {
    let files = try CSVImportQueueTestFiles.make(
        [
            ("checking-april.csv", "Date,Description,Amount\n2026-04-01,Coffee,-4.75\n"),
            ("checking-may.csv", "Date,Description,Amount\n2026-05-01,Payroll,1250.00\n"),
        ]
    )
    let model = WorkspaceShellModel(store: nil, service: nil)

    model.importCSV(from: .success(files.urls))

    #expect(model.isPresentingImportPreview == true)
    #expect(model.pendingCSVImport?.originalFilename == "checking-april.csv")
    #expect(model.csvImportPreview?.previewRows.map(\.sourceLineNumber) == [2])
    #expect(model.importErrorMessage == nil)
}

@Test
@MainActor
func confirmingAQueuedCSVImportAdvancesToTheNextPreview() throws {
    let files = try CSVImportQueueTestFiles.make(
        [
            ("checking-april.csv", "Date,Description,Amount\n2026-04-01,Coffee,-4.75\n"),
            ("checking-may.csv", "Date,Description,Amount\n2026-05-01,Payroll,1250.00\n"),
        ]
    )
    let store = WorkspaceShellModelCSVImportQueueStore()
    let service = WorkspaceService(store: store)
    let model = WorkspaceShellModel(store: nil, service: service)
    let firstPreview = try #require(model.csvImportPreviewForSelection(files.urls))
    let account = try #require(model.snapshot.importEligibleAccounts.first)

    model.confirmCSVImport(preview: firstPreview, account: account)

    #expect(store.createdSessions.map(\.originalFilename) == ["checking-april.csv"])
    #expect(model.isPresentingImportPreview == true)
    #expect(model.pendingCSVImport?.originalFilename == "checking-may.csv")
    #expect(model.csvImportPreview?.previewRows.map(\.sourceLineNumber) == [2])
    #expect(model.importResultMessage == nil)
    #expect(model.importErrorMessage == nil)
}

@Test
@MainActor
func confirmingTheLastQueuedCSVImportShowsAnAggregateCompletionMessage() throws {
    let files = try CSVImportQueueTestFiles.make(
        [
            ("checking-april.csv", "Date,Description,Amount\n2026-04-01,Coffee,-4.75\n"),
            ("checking-may.csv", "Date,Description,Amount\n2026-05-01,Payroll,1250.00\n"),
        ]
    )
    let store = WorkspaceShellModelCSVImportQueueStore()
    let service = WorkspaceService(store: store)
    let model = WorkspaceShellModel(store: nil, service: service)
    let account = try #require(model.snapshot.importEligibleAccounts.first)
    let firstPreview = try #require(model.csvImportPreviewForSelection(files.urls))

    model.confirmCSVImport(preview: firstPreview, account: account)
    let secondPreview = try #require(model.csvImportPreview)
    model.confirmCSVImport(preview: secondPreview, account: account)

    #expect(store.createdSessions.map(\.originalFilename) == ["checking-april.csv", "checking-may.csv"])
    #expect(model.isPresentingImportPreview == false)
    #expect(model.pendingCSVImport == nil)
    #expect(model.csvImportPreview == nil)
    #expect(model.importResultMessage == "2 imported to Transactions, 0 skipped, 2 sent to Review, 0 likely duplicates waiting in Review.")
    #expect(model.importErrorMessage == nil)
}

@Test
func csvImportPreviewSheetExplainsVenmoDerivedCategorization() throws {
    let source = try sourceText(in: "Sources/AlderwiseApp/CSVImportPreviewSheet.swift")

    #expect(source.contains("Used for categorization:"))
    #expect(source.contains("Venmo imports keep the Note column as the raw description."))
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

private extension WorkspaceShellModel {
    func csvImportPreviewForSelection(_ urls: [URL]) -> CSVImportPreview? {
        importCSV(from: .success(urls))
        return csvImportPreview
    }
}

private func sourceText(in relativePath: String) throws -> String {
    let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let sourceURL = repoRoot.appendingPathComponent(relativePath)
    return try String(contentsOf: sourceURL, encoding: .utf8)
}
