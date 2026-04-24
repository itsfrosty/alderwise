import Application
import Domain
import Foundation
import Testing

@testable import AlderwiseApp

@Test
@MainActor
func sessionBuildsOneDraftItemPerSelectedFileAndRetainsLoadedCSVText() throws {
    let files = try BatchCSVImportSessionTestFiles.make(
        [
            ("checking-april.csv", "Date,Description,Amount\n2026-04-01,Coffee,-4.75\n"),
            ("checking-may.csv", "Date,Description,Amount\n2026-05-01,Payroll,1250.00\n"),
        ]
    )

    let session = BatchCSVImportSession(
        selectedURLs: files.urls,
        importEligibleAccounts: [batchCSVImportAccount(id: "00000000-0000-0000-0000-000000000101", name: "Checking")]
    )

    try FileManager.default.removeItem(at: files.directoryURL)

    #expect(session.importPhase == .editing)
    #expect(session.draft.items.map(\.originalFilename) == ["checking-april.csv", "checking-may.csv"])
    #expect(session.draft.selectedItem?.originalFilename == "checking-april.csv")

    let firstItem = try #require(session.draft.items.first)
    let secondItem = try #require(session.draft.items.last)

    guard case .loaded(let firstCSVText, let firstPreview) = firstItem.content else {
        Issue.record("Expected first batch item to load successfully.")
        return
    }
    guard case .loaded(let secondCSVText, let secondPreview) = secondItem.content else {
        Issue.record("Expected second batch item to load successfully.")
        return
    }

    #expect(firstCSVText.contains("Coffee"))
    #expect(firstPreview.previewRows.map(\.sourceLineNumber) == [2])
    #expect(firstItem.selectedAccountID == batchCSVImportAccountID("00000000-0000-0000-0000-000000000101"))
    #expect(secondCSVText.contains("Payroll"))
    #expect(secondPreview.previewRows.map(\.sourceLineNumber) == [2])
    #expect(secondItem.selectedAccountID == batchCSVImportAccountID("00000000-0000-0000-0000-000000000101"))
    #expect(session.draft.isReadyForImport)
}

@Test
@MainActor
func sessionSelectsFirstBlockedItemAndKeepsMixedLoadFailuresScopedPerItem() throws {
    let fileManager = FileManager.default
    let directoryURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)

    let validURL = directoryURL.appendingPathComponent("valid.csv")
    try "Date,Description,Amount\n2026-04-01,Coffee,-4.75\n".write(to: validURL, atomically: true, encoding: .utf8)

    let parseFailedURL = directoryURL.appendingPathComponent("parse-failed.csv")
    try "Date,Description,Amount\n2026-04-01,Coffee\n".write(to: parseFailedURL, atomically: true, encoding: .utf8)

    let readFailedURL = directoryURL.appendingPathComponent("read-failed.csv", isDirectory: true)
    try fileManager.createDirectory(at: readFailedURL, withIntermediateDirectories: true)

    let session = BatchCSVImportSession(
        selectedURLs: [validURL, parseFailedURL, readFailedURL],
        importEligibleAccounts: [batchCSVImportAccount(id: "00000000-0000-0000-0000-000000000201", name: "Checking")]
    )

    #expect(session.draft.items.map(\.originalFilename) == ["valid.csv", "parse-failed.csv", "read-failed.csv"])
    #expect(session.draft.selectedItem?.originalFilename == "parse-failed.csv")
    #expect(session.draft.isReadyForImport == false)

    guard case .loaded(let csvText, let preview) = session.draft.items[0].content else {
        Issue.record("Expected the first batch item to remain loaded even when later items fail.")
        return
    }
    #expect(csvText.contains("Coffee"))
    #expect(preview.validation.isReadyForImport)
    #expect(session.draft.items[0].selectedAccountID == batchCSVImportAccountID("00000000-0000-0000-0000-000000000201"))

    guard case .loadFailed(let parseFailureMessage) = session.draft.items[1].content else {
        Issue.record("Expected parse failures to be stored on the item.")
        return
    }
    #expect(parseFailureMessage.contains("has 2 columns"))
    #expect(session.draft.items[1].selectedAccountID == nil)

    guard case .loadFailed(let readFailureMessage) = session.draft.items[2].content else {
        Issue.record("Expected read failures to be stored on the item.")
        return
    }
    #expect(readFailureMessage.isEmpty == false)
    #expect(session.draft.items[2].selectedAccountID == nil)
}

@Test
@MainActor
func sessionDoesNotAutoSelectAnAccountWhenMultipleEligibleAccountsExist() throws {
    let files = try BatchCSVImportSessionTestFiles.make(
        [
            ("checking.csv", "Date,Description,Amount\n2026-04-01,Coffee,-4.75\n"),
            ("savings.csv", "Date,Description,Amount\n2026-04-02,Interest,1.25\n"),
        ]
    )

    let session = BatchCSVImportSession(
        selectedURLs: files.urls,
        importEligibleAccounts: [
            batchCSVImportAccount(id: "00000000-0000-0000-0000-000000000301", name: "Checking"),
            batchCSVImportAccount(id: "00000000-0000-0000-0000-000000000302", name: "Savings"),
        ]
    )

    #expect(session.draft.selectedItem?.originalFilename == "checking.csv")
    #expect(session.draft.items.allSatisfy { $0.selectedAccountID == nil })
    #expect(session.draft.items.allSatisfy { $0.isReadyForImport == false })
    #expect(session.draft.isReadyForImport == false)
}

@Test
@MainActor
func selectingAnItemChangesTheSelectedDetailSourceItem() throws {
    let files = try BatchCSVImportSessionTestFiles.make(
        [
            ("checking.csv", "Date,Description,Amount\n2026-04-01,Coffee,-4.75\n"),
            ("savings.csv", "Date,Description,Amount\n2026-04-02,Interest,1.25\n"),
        ]
    )

    let session = BatchCSVImportSession(
        selectedURLs: files.urls,
        importEligibleAccounts: [batchCSVImportAccount(id: "00000000-0000-0000-0000-000000000501", name: "Checking")]
    )
    let secondItemID = try #require(session.draft.items.last?.id)

    session.selectItem(id: secondItemID)

    #expect(session.draft.selectedItemID == secondItemID)
    #expect(session.draft.selectedItem?.originalFilename == "savings.csv")
}

@Test
@MainActor
func selectingAccountAndChangingMappingOnlyAffectTheSelectedItem() throws {
    let files = try BatchCSVImportSessionTestFiles.make(
        [
            ("checking.csv", "Date,Description,Amount\n2026-04-01,Coffee,-4.75\n"),
            ("savings.csv", "Date,Description,Amount\n2026-04-02,Interest,1.25\n"),
        ]
    )

    let checkingAccount = batchCSVImportAccount(
        id: "00000000-0000-0000-0000-000000000502",
        name: "Checking"
    )
    let savingsAccount = batchCSVImportAccount(
        id: "00000000-0000-0000-0000-000000000503",
        name: "Savings"
    )
    let session = BatchCSVImportSession(
        selectedURLs: files.urls,
        importEligibleAccounts: [checkingAccount, savingsAccount]
    )
    let firstItemID = try #require(session.draft.items.first?.id)
    let secondItemID = try #require(session.draft.items.last?.id)

    session.selectItem(id: firstItemID)
    #expect(session.selectAccount(id: checkingAccount.id, forItemID: firstItemID))

    let firstPreviewBeforeEdit = try #require(preview(forItemID: firstItemID, in: session))

    session.selectItem(id: secondItemID)
    #expect(session.selectAccount(id: savingsAccount.id, forItemID: secondItemID))
    #expect(
        session.updateMapping(
            CSVColumnMapping(
                dateColumnIndex: 0,
                descriptionColumnIndex: 1,
                amount: nil
            ),
            forItemID: secondItemID
        )
    )

    let firstItem = try #require(session.draft.items.first(where: { $0.id == firstItemID }))
    let secondItem = try #require(session.draft.items.first(where: { $0.id == secondItemID }))
    let firstPreviewAfterEdit = try #require(preview(forItemID: firstItemID, in: session))
    let secondPreview = try #require(preview(forItemID: secondItemID, in: session))

    #expect(firstItem.selectedAccountID == checkingAccount.id)
    #expect(firstPreviewBeforeEdit.mapping == firstPreviewAfterEdit.mapping)
    #expect(firstPreviewAfterEdit.validation.isReadyForImport)

    #expect(secondItem.selectedAccountID == savingsAccount.id)
    #expect(secondPreview.mapping.amount == nil)
    #expect(secondPreview.validation.isReadyForImport == false)
}

@Test
@MainActor
func removingABlockedFileUpdatesReadinessAndSelectionAndKeepsImportAllDisabledUntilThen() throws {
    let fileManager = FileManager.default
    let directoryURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)

    let validURL = directoryURL.appendingPathComponent("valid.csv")
    try "Date,Description,Amount\n2026-04-01,Coffee,-4.75\n".write(to: validURL, atomically: true, encoding: .utf8)

    let blockedURL = directoryURL.appendingPathComponent("blocked.csv")
    try "Date,Description,Amount\n2026-04-01,Coffee\n".write(to: blockedURL, atomically: true, encoding: .utf8)

    let session = BatchCSVImportSession(
        selectedURLs: [validURL, blockedURL],
        importEligibleAccounts: [batchCSVImportAccount(id: "00000000-0000-0000-0000-000000000504", name: "Checking")]
    )
    let blockedItemID = try #require(session.draft.selectedItemID)

    #expect(session.draft.selectedItem?.originalFilename == "blocked.csv")
    #expect(session.draft.isReadyForImport == false)

    #expect(session.removeItem(id: blockedItemID))

    #expect(session.draft.items.map(\.originalFilename) == ["valid.csv"])
    #expect(session.draft.selectedItem?.originalFilename == "valid.csv")
    #expect(session.draft.isReadyForImport)
}

@Test
@MainActor
func confirmBatchImportStagesFilesSequentiallyAndAggregatesMixedStagedAndExactReimportResults() async throws {
    let account = batchCSVImportAccount(
        id: "00000000-0000-0000-0000-000000000601",
        name: "Checking"
    )
    let files = try BatchCSVImportSessionTestFiles.make(
        [
            ("april.csv", "Date,Description,Amount\n2026-04-01,Coffee,-4.75\n"),
            ("april-renamed.csv", "Date,Description,Amount\n2026-04-01,Coffee,-4.75\n"),
            ("may.csv", "Date,Description,Amount\n2026-05-01,Payroll,1250.00\n"),
        ]
    )
    let session = BatchCSVImportSession(
        selectedURLs: files.urls,
        importEligibleAccounts: [account]
    )
    let store = BatchCSVImportSessionExecutionStore(accounts: [account])
    let service = WorkspaceService(store: store)

    let result = await session.confirmBatchCSVImport(service: service, accounts: [account])

    #expect(
        result == .success(
            summary: StagedImportDecisionSummary(
                importedRowCount: 2,
                skippedRowCount: 1,
                pendingClassificationReviewRowCount: 2,
                flaggedDuplicateRowCount: 0
            ),
            outcome: .staged
        )
    )
    #expect(store.createdSessions.map(\.originalFilename) == ["april.csv", "may.csv"])
    #expect(session.importPhase == .editing)
}

@Test
@MainActor
func confirmBatchImportStopsOnFirstUnexpectedFailureAndDoesNotAttemptLaterFiles() async throws {
    let account = batchCSVImportAccount(
        id: "00000000-0000-0000-0000-000000000602",
        name: "Checking"
    )
    let files = try BatchCSVImportSessionTestFiles.make(
        [
            ("april.csv", "Date,Description,Amount\n2026-04-01,Coffee,-4.75\n"),
            ("broken.csv", "Date,Description,Amount\nnot-a-date,Payroll,1250.00\n"),
            ("june.csv", "Date,Description,Amount\n2026-06-01,Rent,-800.00\n"),
        ]
    )
    let session = BatchCSVImportSession(
        selectedURLs: files.urls,
        importEligibleAccounts: [account]
    )
    let store = BatchCSVImportSessionExecutionStore(accounts: [account])
    let service = WorkspaceService(store: store)
    let failedItemID = try #require(
        session.draft.items.first(where: { $0.originalFilename == "broken.csv" })?.id
    )

    let result = await session.confirmBatchCSVImport(service: service, accounts: [account])

    #expect(
        result == .partialFailure(
            BatchCSVImportFailureContext(
                failedItemID: failedItemID,
                failedFilename: "broken.csv",
                stagedFileCount: 1,
                errorDescription: WorkspaceServiceError.importPreviewCouldNotNormalizeRow(line: 2).localizedDescription,
                summary: StagedImportDecisionSummary(
                    importedRowCount: 1,
                    skippedRowCount: 0,
                    pendingClassificationReviewRowCount: 1,
                    flaggedDuplicateRowCount: 0
                ),
                outcome: .staged
            )
        )
    )
    #expect(store.createdSessions.map(\.originalFilename) == ["april.csv"])
    #expect(session.draft.selectedItemID == failedItemID)
    #expect(session.importPhase == .editing)
}

@MainActor
private func preview(forItemID itemID: UUID, in session: BatchCSVImportSession) -> CSVImportPreview? {
    guard let item = session.draft.items.first(where: { $0.id == itemID }) else {
        return nil
    }

    return firstPreview(for: item)
}

private func firstPreview(for item: BatchCSVImportItemDraft) -> CSVImportPreview? {
    guard case .loaded(_, let preview) = item.content else {
        return nil
    }

    return preview
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

private func batchCSVImportAccount(id: String, name: String) -> Account {
    Account(
        id: batchCSVImportAccountID(id),
        name: name,
        kind: .checking,
        institutionName: "Local Bank"
    )
}

private func batchCSVImportAccountID(_ rawValue: String) -> UUID {
    UUID(uuidString: rawValue)!
}

private final class BatchCSVImportSessionExecutionStore: @unchecked Sendable, WorkspaceStoring, StagedImportWriting, ImportDecisionReading {
    let accounts: [Account]
    private(set) var createdSessions: [StagedImportSessionDraft] = []

    init(accounts: [Account]) {
        self.accounts = accounts
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
        Account(name: named, kind: kind, institutionName: institutionName)
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
        let existingHashes = Set(
            createdSessions.flatMap(\.rows).map(\.rowHash).filter { rowHashes.contains($0) }
        )
        return Dictionary(uniqueKeysWithValues: existingHashes.map { ($0, 1) })
    }

    func fetchLikelyDuplicateTransactions(
        accountID: UUID,
        candidates: [NormalizedImportCandidate]
    ) throws -> [LikelyDuplicateCandidate] {
        []
    }
}
