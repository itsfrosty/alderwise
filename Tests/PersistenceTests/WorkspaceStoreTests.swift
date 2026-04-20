import Domain
import Foundation
import GRDB
import Persistence
import Testing

@Test
func workspaceLocationProvidesDecodedDatabasePath() {
    let databaseURL = URL(fileURLWithPath: "/Users/example/Library/Application Support/Alderwise/workspace.sqlite")
    let location = WorkspaceLocation(databaseURL: databaseURL)

    #expect(location.databasePath == "/Users/example/Library/Application Support/Alderwise/workspace.sqlite")
    #expect(!location.databasePath.contains("%20"))
}

@Test
func bootstrapCreatesSchemaAndReturnsEmptySummary() throws {
    let store = try WorkspaceStore.inMemory()

    try store.bootstrap()

    let summary = try store.fetchSummary()
    let accounts = try store.fetchAccounts()

    #expect(summary == .empty)
    #expect(accounts.isEmpty)
}

@Test
func createdAccountsAppearInSummaryAndFetchResults() throws {
    let store = try WorkspaceStore.inMemory()
    try store.bootstrap()

    _ = try store.createAccount(named: "Checking", kind: .checking, institutionName: "Local Bank")
    _ = try store.createAccount(named: "Card", kind: .creditCard, institutionName: "Visa")

    let summary = try store.fetchSummary()
    let accounts = try store.fetchAccounts()

    #expect(summary.accountCount == 2)
    #expect(accounts.map(\.name) == ["Card", "Checking"])
}

@Test
func stagedImportRecordsRoundTripThroughOnDiskWorkspace() throws {
    let databaseURL = try temporaryDatabaseURL()
    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()

    let account = try store.createAccount(named: "Checking", kind: .checking, institutionName: "Local Bank")
    let importedAt = Date(timeIntervalSince1970: 1_776_662_400)
    let mapping = CSVColumnMapping(
        dateColumnIndex: 0,
        descriptionColumnIndex: 1,
        amount: .singleSignedAmount(columnIndex: 2)
    )

    let session = try store.createStagedImportSession(
        StagedImportSessionDraft(
            accountID: account.id,
            originalFilename: "checking-april.csv",
            contentHash: "file-sha256",
            importedAt: importedAt,
            rows: [
                StagedSourceRowDraft(
                    sourceLineNumber: 2,
                    rawPayload: #"["2026-04-01","Coffee","-4.50"]"#,
                    rowHash: "row-1-sha256",
                    validationStatus: .valid
                ),
                StagedSourceRowDraft(
                    sourceLineNumber: 3,
                    rawPayload: #"["","Missing date","-10.00"]"#,
                    rowHash: "row-2-sha256",
                    validationStatus: .invalid
                ),
            ],
            mapping: mapping,
            validRowCount: 1,
            invalidRowCount: 1,
            status: .staged
        )
    )

    let fetched = try #require(try store.fetchStagedImportSession(id: session.id))

    #expect(fetched.sourceFile.accountID == account.id)
    #expect(fetched.sourceFile.originalFilename == "checking-april.csv")
    #expect(fetched.sourceFile.contentHash == "file-sha256")
    #expect(fetched.sourceFile.importedAt == importedAt)
    #expect(fetched.sourceFile.rowCount == 2)
    #expect(fetched.mapping == mapping)
    #expect(fetched.validRowCount == 1)
    #expect(fetched.invalidRowCount == 1)
    #expect(fetched.status == .staged)
    #expect(fetched.rows.map(\.sourceLineNumber) == [2, 3])
    #expect(fetched.rows.map(\.validationStatus) == [.valid, .invalid])
    #expect(fetched.rows.map(\.rawPayload) == [
        #"["2026-04-01","Coffee","-4.50"]"#,
        #"["","Missing date","-10.00"]"#,
    ])
}

@Test
func migratedLegacySourceFilesWithFilenameColumnAcceptStagedImports() throws {
    let databaseURL = try temporaryDatabaseURL()
    try createLegacyWorkspaceWithFilenameSourceFiles(at: databaseURL)

    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()

    let account = try store.createAccount(named: "Checking", kind: .checking, institutionName: "Local Bank")
    let session = try store.createStagedImportSession(
        StagedImportSessionDraft(
            accountID: account.id,
            originalFilename: "checking-april.csv",
            contentHash: "file-sha256",
            importedAt: Date(timeIntervalSince1970: 1_776_662_400),
            rows: [
                StagedSourceRowDraft(
                    sourceLineNumber: 2,
                    rawPayload: #"["2026-04-01","Coffee","-4.50"]"#,
                    rowHash: "row-1-sha256",
                    validationStatus: .valid
                ),
            ],
            mapping: CSVColumnMapping(
                dateColumnIndex: 0,
                descriptionColumnIndex: 1,
                amount: .singleSignedAmount(columnIndex: 2)
            ),
            validRowCount: 1,
            invalidRowCount: 0,
            status: .staged
        )
    )

    #expect(session.sourceFile.originalFilename == "checking-april.csv")
    #expect(session.rows.map(\.sourceLineNumber) == [2])
}

private func temporaryDatabaseURL() throws -> URL {
    let directory = FileManager.default.temporaryDirectory
        .appending(path: "AlderwisePersistenceTests-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory.appending(path: "workspace.sqlite")
}

private func createLegacyWorkspaceWithFilenameSourceFiles(at databaseURL: URL) throws {
    let queue = try DatabaseQueue(path: databaseURL.path)
    try queue.write { db in
        try db.execute(sql: "PRAGMA foreign_keys = ON")
        try db.execute(sql: "CREATE TABLE grdb_migrations (identifier TEXT NOT NULL PRIMARY KEY)")
        try db.execute(sql: "INSERT INTO grdb_migrations (identifier) VALUES ('create-v1-schema')")

        try db.execute(
            sql: """
            CREATE TABLE accounts (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                kind TEXT NOT NULL,
                institution_name TEXT,
                created_at DATETIME NOT NULL
            )
            """
        )
        try db.execute(
            sql: """
            CREATE TABLE source_files (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                account_id TEXT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
                filename TEXT NOT NULL,
                content_hash TEXT NOT NULL,
                imported_at DATETIME NOT NULL
            )
            """
        )
        try db.execute(
            sql: """
            CREATE TABLE source_rows (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                source_file_id INTEGER NOT NULL REFERENCES source_files(id) ON DELETE CASCADE,
                row_hash TEXT NOT NULL,
                raw_payload TEXT NOT NULL
            )
            """
        )
        try db.execute(
            sql: """
            CREATE TABLE import_sessions (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                account_id TEXT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
                status TEXT NOT NULL,
                created_at DATETIME NOT NULL
            )
            """
        )
        try db.execute(sql: "CREATE TABLE transactions (id TEXT PRIMARY KEY)")
        try db.execute(sql: "CREATE TABLE review_items (id TEXT PRIMARY KEY, status TEXT NOT NULL)")
        try db.execute(sql: "CREATE TABLE targets (id TEXT PRIMARY KEY)")
    }
}
