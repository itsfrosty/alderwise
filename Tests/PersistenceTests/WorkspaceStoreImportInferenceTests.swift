import Domain
import Foundation
import GRDB
import Persistence
import Testing

@Test
func bootstrapCreatesImportAccountInferenceEvidenceTable() throws {
    let databaseURL = try temporaryDatabaseURL()
    let store = try WorkspaceStore.at(databaseURL: databaseURL)

    try store.bootstrap()

    let columns = try tableColumnNames(
        databaseURL: databaseURL,
        tableName: "import_account_inference_evidence"
    )

    #expect(columns == [
        "staged_import_session_id",
        "feedback_kind",
        "selected_account_id",
        "losing_account_id",
        "normalized_filename",
        "profile",
        "normalized_header_names_json",
        "non_blank_column_indexes_by_row_json",
    ])
}

@Test
func feedbackWritesAreIdempotentPerStagedImportSession() throws {
    let databaseURL = try temporaryDatabaseURL()
    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()

    let account = try store.createAccount(named: "Checking", kind: .checking, institutionName: "Local Bank")
    let session = try makeStagedImportSession(
        store: store,
        accountID: account.id,
        originalFilename: "checking-april.csv"
    )
    let query = makeInferenceEvidenceQuery(originalFilename: "checking-april.csv")

    try store.recordImportAccountInferenceFeedback(
        for: query,
        stagedImportSessionID: session.id,
        selectedAccountID: account.id,
        suggestedAccountID: account.id
    )
    try store.recordImportAccountInferenceFeedback(
        for: query,
        stagedImportSessionID: session.id,
        selectedAccountID: account.id,
        suggestedAccountID: account.id
    )

    let aggregated = try store.fetchImportAccountInferenceEvidence(for: query)
    let accountEvidence = try #require(aggregated[account.id])
    let rows = try fetchPersistedInferenceEvidenceRows(databaseURL: databaseURL)

    #expect(accountEvidence.positiveMatchCount == 1)
    #expect(accountEvidence.overrideCount == 0)
    #expect(rows.count == 1)
}

@Test
func manualAssignmentFromInitiallyUnassignedFileRecordsPositiveHistoryWithoutOverridePenalty() throws {
    let databaseURL = try temporaryDatabaseURL()
    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()

    let account = try store.createAccount(named: "Checking", kind: .checking, institutionName: "Local Bank")
    let session = try makeStagedImportSession(
        store: store,
        accountID: account.id,
        originalFilename: "checking-april.csv"
    )
    let query = makeInferenceEvidenceQuery(originalFilename: "checking-april.csv")

    try store.recordImportAccountInferenceFeedback(
        for: query,
        stagedImportSessionID: session.id,
        selectedAccountID: account.id,
        suggestedAccountID: nil
    )

    let aggregated = try store.fetchImportAccountInferenceEvidence(for: query)
    let accountEvidence = try #require(aggregated[account.id])
    let rows = try fetchPersistedInferenceEvidenceRows(databaseURL: databaseURL)

    #expect(accountEvidence.positiveMatchCount == 1)
    #expect(accountEvidence.overrideCount == 0)
    #expect(rows == [
        PersistedInferenceEvidenceRow(
            feedbackKind: "manualAssignment",
            selectedAccountID: account.id,
            losingAccountID: nil
        ),
    ])
}

@Test
func changedSuggestionRecordsOverrideAgainstLosingCandidate() throws {
    let databaseURL = try temporaryDatabaseURL()
    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()

    let selectedAccount = try store.createAccount(
        named: "Checking",
        kind: .checking,
        institutionName: "Local Bank"
    )
    let losingAccount = try store.createAccount(
        named: "Card",
        kind: .creditCard,
        institutionName: "Visa"
    )
    let session = try makeStagedImportSession(
        store: store,
        accountID: selectedAccount.id,
        originalFilename: "checking-april.csv"
    )
    let query = makeInferenceEvidenceQuery(originalFilename: "checking-april.csv")

    try store.recordImportAccountInferenceFeedback(
        for: query,
        stagedImportSessionID: session.id,
        selectedAccountID: selectedAccount.id,
        suggestedAccountID: losingAccount.id
    )

    let aggregated = try store.fetchImportAccountInferenceEvidence(for: query)
    let selectedEvidence = try #require(aggregated[selectedAccount.id])
    let losingEvidence = try #require(aggregated[losingAccount.id])
    let rows = try fetchPersistedInferenceEvidenceRows(databaseURL: databaseURL)

    #expect(selectedEvidence.positiveMatchCount == 1)
    #expect(selectedEvidence.overrideCount == 0)
    #expect(losingEvidence.positiveMatchCount == 0)
    #expect(losingEvidence.overrideCount == 1)
    #expect(rows == [
        PersistedInferenceEvidenceRow(
            feedbackKind: "overrodeSuggestion",
            selectedAccountID: selectedAccount.id,
            losingAccountID: losingAccount.id
        ),
    ])
}

@Test
func exactReimportNoOpDoesNotCreateNewEvidence() throws {
    let databaseURL = try temporaryDatabaseURL()
    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()

    let account = try store.createAccount(named: "Checking", kind: .checking, institutionName: "Local Bank")
    let query = makeInferenceEvidenceQuery(originalFilename: "checking-april.csv")

    try store.recordImportAccountInferenceFeedback(
        for: query,
        stagedImportSessionID: nil,
        selectedAccountID: account.id,
        suggestedAccountID: account.id
    )

    let aggregated = try store.fetchImportAccountInferenceEvidence(for: query)
    let rows = try fetchPersistedInferenceEvidenceRows(databaseURL: databaseURL)

    #expect(aggregated.isEmpty)
    #expect(rows.isEmpty)
}

@Test
func importAccountInferenceEvidenceUsesForeignKeys() throws {
    let databaseURL = try temporaryDatabaseURL()
    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()

    let account = try store.createAccount(named: "Checking", kind: .checking, institutionName: "Local Bank")
    let session = try makeStagedImportSession(
        store: store,
        accountID: account.id,
        originalFilename: "checking-april.csv"
    )
    let query = makeInferenceEvidenceQuery(originalFilename: "checking-april.csv")

    try store.recordImportAccountInferenceFeedback(
        for: query,
        stagedImportSessionID: session.id,
        selectedAccountID: account.id,
        suggestedAccountID: nil
    )

    try deleteImportSession(databaseURL: databaseURL, sessionID: session.id)

    let rows = try fetchPersistedInferenceEvidenceRows(databaseURL: databaseURL)
    #expect(rows.isEmpty)
}

@Test
func bootstrapEvidenceReusesExistingImportHistoryFromSourceFilesAndMappings() throws {
    let databaseURL = try temporaryDatabaseURL()
    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()

    let account = try store.createAccount(named: "Checking", kind: .checking, institutionName: "Local Bank")
    _ = try makeStagedImportSession(
        store: store,
        accountID: account.id,
        originalFilename: "Checking April 2026.csv"
    )

    let bootstrapEvidence = try store.fetchBootstrapImportAccountInferenceEvidence(
        for: makeInferenceEvidenceQuery(originalFilename: "checking-april-2026.CSV")
    )

    #expect(bootstrapEvidence == [account.id: 1])
}

@Test
func bootstrapEvidenceReusesMigratedHistoryWhenLegacyMappingWasUnavailable() throws {
    let databaseURL = try temporaryDatabaseURL()
    try createWorkspaceAtLatestPreInferenceSchema(at: databaseURL)

    let queue = try DatabaseQueue(path: databaseURL.path)
    let accountID = UUID(uuidString: "00000000-0000-0000-0000-000000000801")!
    try queue.write { db in
        try db.execute(
            sql: """
            INSERT INTO accounts (id, name, kind, institution_name, created_at)
            VALUES (?, ?, ?, ?, ?)
            """,
            arguments: [
                accountID.uuidString,
                "Checking",
                AccountKind.checking.rawValue,
                "Local Bank",
                Date(timeIntervalSince1970: 1_776_662_400),
            ]
        )
        try db.execute(
            sql: """
            INSERT INTO source_files (
                id, account_id, original_filename, content_hash, imported_at, row_count
            )
            VALUES (?, ?, ?, ?, ?, ?)
            """,
            arguments: [
                1,
                accountID.uuidString,
                "Checking April 2026.csv",
                "legacy-content-hash",
                Date(timeIntervalSince1970: 1_776_662_400),
                1,
            ]
        )
        try db.execute(
            sql: """
            INSERT INTO import_sessions (
                id, account_id, source_file_id, mapping_json, valid_row_count, invalid_row_count, status, created_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            arguments: [
                1,
                accountID.uuidString,
                1,
                "{}",
                1,
                0,
                ImportSessionStatus.imported.rawValue,
                Date(timeIntervalSince1970: 1_776_662_400),
            ]
        )
    }

    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()

    let bootstrapEvidence = try store.fetchBootstrapImportAccountInferenceEvidence(
        for: makeInferenceEvidenceQuery(originalFilename: "checking-april-2026.csv")
    )

    #expect(bootstrapEvidence == [accountID: 1])
}

@Test
func persistedInferenceEvidenceDoesNotDependOnBootstrapMappingHint() throws {
    let databaseURL = try temporaryDatabaseURL()
    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()

    let account = try store.createAccount(named: "Checking", kind: .checking, institutionName: "Local Bank")
    let session = try makeStagedImportSession(
        store: store,
        accountID: account.id,
        originalFilename: "checking-april.csv"
    )

    try store.recordImportAccountInferenceFeedback(
        for: makeInferenceEvidenceQuery(
            originalFilename: "checking-april.csv",
            bootstrapMapping: CSVColumnMapping(
                dateColumnIndex: 0,
                descriptionColumnIndex: 1,
                amount: .singleSignedAmount(columnIndex: 2),
                profile: .generic
            )
        ),
        stagedImportSessionID: session.id,
        selectedAccountID: account.id,
        suggestedAccountID: nil
    )

    let alternateMappingEvidence = try store.fetchImportAccountInferenceEvidence(
        for: makeInferenceEvidenceQuery(
            originalFilename: "checking-april.csv",
            bootstrapMapping: CSVColumnMapping(
                dateColumnIndex: 3,
                descriptionColumnIndex: 4,
                amount: .singleSignedAmount(columnIndex: 5),
                profile: .generic
            )
        )
    )

    #expect(alternateMappingEvidence[account.id]?.positiveMatchCount == 1)
}

@Test
func migrationFromLatestPreInferenceSchemaSucceeds() throws {
    let databaseURL = try temporaryDatabaseURL()
    try createWorkspaceAtLatestPreInferenceSchema(at: databaseURL)

    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()

    let columns = try tableColumnNames(
        databaseURL: databaseURL,
        tableName: "import_account_inference_evidence"
    )

    #expect(columns.contains("staged_import_session_id"))
}

@Test
func migrationFromLegacyFilenameSchemaSucceeds() throws {
    let databaseURL = try temporaryDatabaseURL()
    try createLegacyWorkspaceWithFilenameSourceFiles(at: databaseURL)

    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()

    let columns = try tableColumnNames(
        databaseURL: databaseURL,
        tableName: "import_account_inference_evidence"
    )

    #expect(columns.contains("normalized_filename"))
}

private struct PersistedInferenceEvidenceRow: Equatable {
    var feedbackKind: String
    var selectedAccountID: UUID
    var losingAccountID: UUID?
}

private func makeInferenceEvidenceQuery(
    originalFilename: String,
    bootstrapMapping: CSVColumnMapping? = CSVColumnMapping(
        dateColumnIndex: 0,
        descriptionColumnIndex: 1,
        amount: .singleSignedAmount(columnIndex: 2),
        profile: .generic
    )
) -> ImportAccountInferenceEvidenceQuery {
    ImportAccountInferenceEvidenceQuery(
        originalFilename: originalFilename,
        normalizedHeaderNames: ["date", "description", "amount"],
        nonBlankColumnIndexesByRow: [[0, 1, 2], [0, 1, 2]],
        profile: .generic,
        bootstrapMapping: bootstrapMapping
    )
}

private func makeStagedImportSession(
    store: WorkspaceStore,
    accountID: UUID,
    originalFilename: String
) throws -> StagedImportSession {
    try store.createStagedImportSession(
        StagedImportSessionDraft(
            accountID: accountID,
            originalFilename: originalFilename,
            contentHash: "content-hash-\(originalFilename)",
            importedAt: Date(timeIntervalSince1970: 1_776_662_400),
            rows: [
                StagedSourceRowDraft(
                    sourceLineNumber: 2,
                    rawPayload: #"["2026-04-01","Coffee","-4.50"]"#,
                    rowHash: "row-hash-\(originalFilename)",
                    validationStatus: .valid
                ),
            ],
            mapping: CSVColumnMapping(
                dateColumnIndex: 0,
                descriptionColumnIndex: 1,
                amount: .singleSignedAmount(columnIndex: 2),
                profile: .generic
            ),
            validRowCount: 1,
            invalidRowCount: 0,
            status: .staged
        )
    )
}

private func tableColumnNames(databaseURL: URL, tableName: String) throws -> [String] {
    let queue = try DatabaseQueue(path: databaseURL.path)
    return try queue.read { db in
        try Row.fetchAll(db, sql: "PRAGMA table_info(\(tableName))").map { row in
            row["name"] as String
        }
    }
}

private func fetchPersistedInferenceEvidenceRows(databaseURL: URL) throws -> [PersistedInferenceEvidenceRow] {
    let queue = try DatabaseQueue(path: databaseURL.path)
    return try queue.read { db in
        try Row.fetchAll(
            db,
            sql: """
            SELECT feedback_kind, selected_account_id, losing_account_id
            FROM import_account_inference_evidence
            ORDER BY staged_import_session_id ASC
            """
        ).map { row in
            PersistedInferenceEvidenceRow(
                feedbackKind: row["feedback_kind"],
                selectedAccountID: UUID(uuidString: row["selected_account_id"])!,
                losingAccountID: (row["losing_account_id"] as String?).flatMap(UUID.init(uuidString:))
            )
        }
    }
}

private func deleteImportSession(databaseURL: URL, sessionID: Int64) throws {
    let queue = try DatabaseQueue(path: databaseURL.path)
    try queue.write { db in
        try db.execute(
            sql: "DELETE FROM import_sessions WHERE id = ?",
            arguments: [sessionID]
        )
    }
}
