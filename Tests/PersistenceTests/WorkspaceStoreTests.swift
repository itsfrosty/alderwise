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
    let duplicateTransactionID = UUID(uuidString: "00000000-0000-0000-0000-000000000999")!
    try insertTransaction(
        databaseURL: databaseURL,
        id: duplicateTransactionID,
        accountID: account.id,
        normalizedMerchantName: "missing date",
        amount: Decimal(-10.00),
        transactionDate: Date(timeIntervalSince1970: 1_776_662_400)
    )
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
                    validationStatus: .valid,
                    importDecision: .imported(reason: "New source row.")
                ),
                StagedSourceRowDraft(
                    sourceLineNumber: 3,
                    rawPayload: #"["","Missing date","-10.00"]"#,
                    rowHash: "row-2-sha256",
                    validationStatus: .invalid,
                    importDecision: .flaggedLikelyDuplicate(
                        existingTransactionID: duplicateTransactionID,
                        reason: "Same account, amount, normalized merchant, and nearby date."
                    )
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
    #expect(fetched.rows.map(\.importDecision) == [
        .imported(reason: "New source row."),
        .flaggedLikelyDuplicate(
            existingTransactionID: duplicateTransactionID,
            reason: "Same account, amount, normalized merchant, and nearby date."
        ),
    ])
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

@Test
func sourceRowHashesAreMatchedByAccountAcrossRenamedFiles() throws {
    let databaseURL = try temporaryDatabaseURL()
    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()

    let account = try store.createAccount(named: "Checking", kind: .checking, institutionName: "Local Bank")
    _ = try store.createStagedImportSession(
        StagedImportSessionDraft(
            accountID: account.id,
            originalFilename: "checking-april.csv",
            contentHash: "first-file-hash",
            importedAt: Date(timeIntervalSince1970: 1_776_662_400),
            rows: [
                StagedSourceRowDraft(
                    sourceLineNumber: 2,
                    rawPayload: #"["2026-04-01","Coffee","-4.50"]"#,
                    rowHash: "same-row-hash",
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

    let matches = try store.fetchExistingSourceRowHashes(
        accountID: account.id,
        rowHashes: ["same-row-hash", "new-row-hash"]
    )

    #expect(matches == ["same-row-hash"])
}

@Test
func sourceRowHashCountsPreserveRepeatedRowsForAccount() throws {
    let databaseURL = try temporaryDatabaseURL()
    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()

    let account = try store.createAccount(named: "Checking", kind: .checking, institutionName: "Local Bank")
    _ = try store.createStagedImportSession(
        StagedImportSessionDraft(
            accountID: account.id,
            originalFilename: "checking-april.csv",
            contentHash: "first-file-hash",
            importedAt: Date(timeIntervalSince1970: 1_776_662_400),
            rows: [
                StagedSourceRowDraft(
                    sourceLineNumber: 2,
                    rawPayload: #"["2026-04-01","Coffee","-4.50"]"#,
                    rowHash: "same-row-hash",
                    validationStatus: .valid
                ),
                StagedSourceRowDraft(
                    sourceLineNumber: 3,
                    rawPayload: #"["2026-04-01","Coffee","-4.50"]"#,
                    rowHash: "same-row-hash",
                    validationStatus: .valid
                ),
            ],
            mapping: CSVColumnMapping(
                dateColumnIndex: 0,
                descriptionColumnIndex: 1,
                amount: .singleSignedAmount(columnIndex: 2)
            ),
            validRowCount: 2,
            invalidRowCount: 0,
            status: .staged
        )
    )

    let counts = try store.fetchExistingSourceRowHashCounts(
        accountID: account.id,
        rowHashes: ["same-row-hash", "missing-row-hash"]
    )

    #expect(counts == ["same-row-hash": 2])
}

@Test
func fetchPendingReviewItemsReturnsLikelyDuplicateSourceRowContext() throws {
    let databaseURL = try temporaryDatabaseURL()
    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()

    let account = try store.createAccount(named: "Checking", kind: .checking, institutionName: "Local Bank")
    let duplicateTransactionID = UUID(uuidString: "00000000-0000-0000-0000-000000000999")!
    try insertTransaction(
        databaseURL: databaseURL,
        id: duplicateTransactionID,
        accountID: account.id,
        normalizedMerchantName: "coffee shop",
        amount: Decimal(-4.75),
        transactionDate: Date(timeIntervalSince1970: 1_775_171_200)
    )

    _ = try store.createStagedImportSession(
        StagedImportSessionDraft(
            accountID: account.id,
            originalFilename: "checking-april.csv",
            contentHash: "file-sha256",
            importedAt: Date(timeIntervalSince1970: 1_775_171_200),
            rows: [
                StagedSourceRowDraft(
                    sourceLineNumber: 2,
                    rawPayload: #"["2026-04-01","Coffee Shop","-4.75"]"#,
                    rowHash: "row-1-sha256",
                    validationStatus: .valid,
                    importDecision: .flaggedLikelyDuplicate(
                        existingTransactionID: duplicateTransactionID,
                        reason: "Same account, amount, normalized merchant, and nearby date."
                    )
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

    let reviewItems = try store.fetchPendingReviewItems()

    #expect(reviewItems.count == 1)
    #expect(reviewItems[0].type == .likelyDuplicate)
    #expect(reviewItems[0].status == .pending)
    #expect(reviewItems[0].sourceFile.accountID == account.id)
    #expect(reviewItems[0].sourceFile.originalFilename == "checking-april.csv")
    #expect(reviewItems[0].sourceRow.sourceLineNumber == 2)
    #expect(reviewItems[0].sourceRow.rowHash == "row-1-sha256")
    #expect(reviewItems[0].sourceRow.rawPayload == #"["2026-04-01","Coffee Shop","-4.75"]"#)
    #expect(reviewItems[0].duplicateTransactionID == duplicateTransactionID)
    #expect(reviewItems[0].reason == "Same account, amount, normalized merchant, and nearby date.")
}

@Test
func fetchPendingReviewItemsExcludesResolvedRows() throws {
    let databaseURL = try temporaryDatabaseURL()
    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()

    let account = try store.createAccount(named: "Checking", kind: .checking, institutionName: "Local Bank")
    let duplicateTransactionID = UUID(uuidString: "00000000-0000-0000-0000-000000000999")!
    try insertTransaction(
        databaseURL: databaseURL,
        id: duplicateTransactionID,
        accountID: account.id,
        normalizedMerchantName: "coffee shop",
        amount: Decimal(-4.75),
        transactionDate: Date(timeIntervalSince1970: 1_775_171_200)
    )

    let session = try store.createStagedImportSession(
        StagedImportSessionDraft(
            accountID: account.id,
            originalFilename: "checking-april.csv",
            contentHash: "file-sha256",
            importedAt: Date(timeIntervalSince1970: 1_775_171_200),
            rows: [
                StagedSourceRowDraft(
                    sourceLineNumber: 2,
                    rawPayload: #"["2026-04-01","Coffee Shop","-4.75"]"#,
                    rowHash: "row-1-sha256",
                    validationStatus: .valid,
                    importDecision: .flaggedLikelyDuplicate(
                        existingTransactionID: duplicateTransactionID,
                        reason: "Same account, amount, normalized merchant, and nearby date."
                    )
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

    try updateReviewItemStatus(
        databaseURL: databaseURL,
        sourceRowID: try #require(session.rows.first).id,
        status: .resolved
    )

    let reviewItems = try store.fetchPendingReviewItems()

    #expect(reviewItems.isEmpty)
}

@Test
func fetchPendingReviewItemsThrowsForMalformedStoredIdentifiers() throws {
    let databaseURL = try temporaryDatabaseURL()
    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()

    let account = try store.createAccount(named: "Checking", kind: .checking, institutionName: "Local Bank")
    let duplicateTransactionID = UUID(uuidString: "00000000-0000-0000-0000-000000000999")!
    try insertTransaction(
        databaseURL: databaseURL,
        id: duplicateTransactionID,
        accountID: account.id,
        normalizedMerchantName: "coffee shop",
        amount: Decimal(-4.75),
        transactionDate: Date(timeIntervalSince1970: 1_775_171_200)
    )

    let session = try store.createStagedImportSession(
        StagedImportSessionDraft(
            accountID: account.id,
            originalFilename: "checking-april.csv",
            contentHash: "file-sha256",
            importedAt: Date(timeIntervalSince1970: 1_775_171_200),
            rows: [
                StagedSourceRowDraft(
                    sourceLineNumber: 2,
                    rawPayload: #"["2026-04-01","Coffee Shop","-4.75"]"#,
                    rowHash: "row-1-sha256",
                    validationStatus: .valid,
                    importDecision: .flaggedLikelyDuplicate(
                        existingTransactionID: duplicateTransactionID,
                        reason: "Same account, amount, normalized merchant, and nearby date."
                    )
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

    try corruptReviewItemID(
        databaseURL: databaseURL,
        sourceRowID: try #require(session.rows.first).id,
        invalidID: "not-a-uuid"
    )

    #expect(throws: (any Error).self) {
        _ = try store.fetchPendingReviewItems()
    }
}

@Test
func likelyDuplicateTransactionsMatchNearbyDateAmountAndMerchant() throws {
    let databaseURL = try temporaryDatabaseURL()
    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()

    let account = try store.createAccount(named: "Checking", kind: .checking, institutionName: "Local Bank")
    let transactionID = UUID(uuidString: "00000000-0000-0000-0000-000000000999")!
    try insertTransaction(
        databaseURL: databaseURL,
        id: transactionID,
        accountID: account.id,
        normalizedMerchantName: "coffee shop",
        amount: Decimal(-4.75),
        transactionDate: Date(timeIntervalSince1970: 1_775_171_200)
    )

    let matches = try store.fetchLikelyDuplicateTransactions(
        accountID: account.id,
        candidates: [
            NormalizedImportCandidate(
                rowHash: "incoming-row",
                sourceLineNumber: 2,
                transactionDate: Date(timeIntervalSince1970: 1_775_257_600),
                rawDescription: "SQ *Coffee Shop",
                normalizedMerchantName: "coffee shop",
                amount: Decimal(-4.75)
            ),
        ]
    )

    #expect(matches == [
        LikelyDuplicateCandidate(
            rowHash: "incoming-row",
            existingTransactionID: transactionID,
            reason: "Same account, amount, normalized merchant, and nearby date."
        ),
    ])
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

private func insertTransaction(
    databaseURL: URL,
    id: UUID,
    accountID: UUID,
    normalizedMerchantName: String,
    amount: Decimal,
    transactionDate: Date
) throws {
    let queue = try DatabaseQueue(path: databaseURL.path)
    try queue.write { db in
        try db.execute(
            sql: """
            INSERT INTO transactions (
                id,
                account_id,
                raw_description,
                normalized_merchant_name,
                amount,
                transaction_date,
                direction,
                decision_source,
                review_status,
                duplicate_status
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            arguments: [
                id.uuidString,
                accountID.uuidString,
                "SQ *Coffee Shop",
                normalizedMerchantName,
                NSDecimalNumber(decimal: amount).doubleValue,
                transactionDate,
                "expense",
                "heuristic",
                "accepted",
                "none",
            ]
        )
    }
}

private func updateReviewItemStatus(
    databaseURL: URL,
    sourceRowID: Int64,
    status: ReviewItemStatus
) throws {
    let queue = try DatabaseQueue(path: databaseURL.path)
    try queue.write { db in
        try db.execute(
            sql: """
            UPDATE review_items
            SET status = ?
            WHERE source_row_id = ?
            """,
            arguments: [status.rawValue, sourceRowID]
        )
    }
}

private func corruptReviewItemID(
    databaseURL: URL,
    sourceRowID: Int64,
    invalidID: String
) throws {
    let queue = try DatabaseQueue(path: databaseURL.path)
    try queue.write { db in
        try db.execute(
            sql: """
            UPDATE review_items
            SET id = ?
            WHERE source_row_id = ?
            """,
            arguments: [invalidID, sourceRowID]
        )
    }
}
