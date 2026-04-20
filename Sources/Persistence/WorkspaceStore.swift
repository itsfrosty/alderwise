import Domain
import Foundation
import GRDB

public final class WorkspaceStore: @unchecked Sendable, WorkspaceStoring, StagedImportWriting, StagedImportReading {
    private let databaseQueue: DatabaseQueue

    public init(databaseQueue: DatabaseQueue) {
        self.databaseQueue = databaseQueue
    }

    public static func inMemory() throws -> WorkspaceStore {
        WorkspaceStore(databaseQueue: try DatabaseQueue())
    }

    public static func at(databaseURL: URL) throws -> WorkspaceStore {
        WorkspaceStore(databaseQueue: try DatabaseQueue(path: databaseURL.path))
    }

    public static func live() throws -> WorkspaceStore {
        let location = try WorkspaceLocation.live()
        return WorkspaceStore(databaseQueue: try DatabaseQueue(path: location.databasePath))
    }

    public func bootstrap() throws {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("create-v1-schema") { db in
            try db.execute(sql: "PRAGMA foreign_keys = ON")

            try db.create(table: "accounts") { table in
                table.column("id", .text).primaryKey()
                table.column("name", .text).notNull()
                table.column("kind", .text).notNull()
                table.column("institution_name", .text)
                table.column("created_at", .datetime).notNull()
            }

            try db.create(table: "source_files") { table in
                table.autoIncrementedPrimaryKey("id")
                table.column("account_id", .text).notNull().indexed().references("accounts", onDelete: .cascade)
                table.column("original_filename", .text).notNull()
                table.column("content_hash", .text).notNull()
                table.column("imported_at", .datetime).notNull()
                table.column("row_count", .integer).notNull()
            }

            try db.create(table: "source_rows") { table in
                table.autoIncrementedPrimaryKey("id")
                table.column("source_file_id", .integer).notNull().indexed().references("source_files", onDelete: .cascade)
                table.column("source_line_number", .integer).notNull()
                table.column("row_hash", .text).notNull().indexed()
                table.column("raw_payload", .text).notNull()
                table.column("validation_status", .text).notNull()
            }

            try db.create(table: "import_sessions") { table in
                table.autoIncrementedPrimaryKey("id")
                table.column("account_id", .text).notNull().indexed().references("accounts", onDelete: .cascade)
                table.column("source_file_id", .integer).notNull().indexed().references("source_files", onDelete: .cascade)
                table.column("mapping_json", .text).notNull()
                table.column("valid_row_count", .integer).notNull()
                table.column("invalid_row_count", .integer).notNull()
                table.column("status", .text).notNull()
                table.column("created_at", .datetime).notNull()
            }

            try db.create(table: "merchants") { table in
                table.column("id", .text).primaryKey()
                table.column("normalized_name", .text).notNull()
                table.column("created_at", .datetime).notNull()
            }

            try db.create(table: "categories") { table in
                table.column("id", .text).primaryKey()
                table.column("name", .text).notNull()
                table.column("kind", .text).notNull()
            }

            try db.create(table: "category_groups") { table in
                table.column("id", .text).primaryKey()
                table.column("name", .text).notNull()
            }

            try db.create(table: "transactions") { table in
                table.column("id", .text).primaryKey()
                table.column("account_id", .text).notNull().indexed().references("accounts", onDelete: .cascade)
                table.column("import_session_id", .integer).references("import_sessions", onDelete: .setNull)
                table.column("merchant_id", .text).references("merchants", onDelete: .setNull)
                table.column("category_id", .text).references("categories", onDelete: .setNull)
                table.column("raw_description", .text).notNull()
                table.column("normalized_merchant_name", .text)
                table.column("amount", .double).notNull()
                table.column("transaction_date", .date).notNull()
                table.column("posted_date", .date)
                table.column("direction", .text).notNull()
                table.column("decision_source", .text).notNull()
                table.column("decision_source_reference", .text)
                table.column("confidence", .double)
                table.column("review_status", .text).notNull()
                table.column("duplicate_status", .text).notNull()
                table.column("notes", .text)
            }

            try db.create(table: "rules") { table in
                table.column("id", .text).primaryKey()
                table.column("pattern", .text).notNull()
                table.column("category_id", .text).references("categories", onDelete: .setNull)
                table.column("merchant_name", .text)
                table.column("created_at", .datetime).notNull()
            }

            try db.create(table: "review_items") { table in
                table.column("id", .text).primaryKey()
                table.column("transaction_id", .text).references("transactions", onDelete: .cascade)
                table.column("type", .text).notNull()
                table.column("status", .text).notNull()
                table.column("created_at", .datetime).notNull()
            }

            try db.create(table: "targets") { table in
                table.column("id", .text).primaryKey()
                table.column("category_id", .text).references("categories", onDelete: .cascade)
                table.column("category_group_id", .text).references("category_groups", onDelete: .cascade)
                table.column("monthly_limit", .double).notNull()
                table.column("created_at", .datetime).notNull()
            }

            try db.create(table: "decision_events") { table in
                table.column("id", .text).primaryKey()
                table.column("transaction_id", .text).notNull().indexed().references("transactions", onDelete: .cascade)
                table.column("source", .text).notNull()
                table.column("details", .text).notNull()
                table.column("created_at", .datetime).notNull()
            }
        }
        migrator.registerMigration("expand-staged-import-schema") { db in
            try db.execute(sql: "PRAGMA foreign_keys = ON")

            let sourceFileColumns = try columnNames(in: "source_files", db: db)
            if !sourceFileColumns.contains("original_filename") {
                try db.execute(sql: "ALTER TABLE source_files ADD COLUMN original_filename TEXT NOT NULL DEFAULT ''")
            }
            if !sourceFileColumns.contains("row_count") {
                try db.execute(sql: "ALTER TABLE source_files ADD COLUMN row_count INTEGER NOT NULL DEFAULT 0")
            }

            let sourceRowColumns = try columnNames(in: "source_rows", db: db)
            if !sourceRowColumns.contains("source_line_number") {
                try db.execute(sql: "ALTER TABLE source_rows ADD COLUMN source_line_number INTEGER NOT NULL DEFAULT 0")
            }
            if !sourceRowColumns.contains("validation_status") {
                try db.execute(sql: "ALTER TABLE source_rows ADD COLUMN validation_status TEXT NOT NULL DEFAULT 'valid'")
            }

            let sessionColumns = try columnNames(in: "import_sessions", db: db)
            if !sessionColumns.contains("source_file_id") {
                try db.execute(sql: "ALTER TABLE import_sessions ADD COLUMN source_file_id INTEGER REFERENCES source_files(id) ON DELETE CASCADE")
            }
            if !sessionColumns.contains("mapping_json") {
                try db.execute(sql: "ALTER TABLE import_sessions ADD COLUMN mapping_json TEXT NOT NULL DEFAULT '{}'")
            }
            if !sessionColumns.contains("valid_row_count") {
                try db.execute(sql: "ALTER TABLE import_sessions ADD COLUMN valid_row_count INTEGER NOT NULL DEFAULT 0")
            }
            if !sessionColumns.contains("invalid_row_count") {
                try db.execute(sql: "ALTER TABLE import_sessions ADD COLUMN invalid_row_count INTEGER NOT NULL DEFAULT 0")
            }
        }

        try migrator.migrate(databaseQueue)
    }

    public func fetchSummary() throws -> WorkspaceSummary {
        try databaseQueue.read { db in
            let accountCount = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM accounts") ?? 0
            let transactionCount = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM transactions") ?? 0
            let reviewCount = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM review_items WHERE status = 'pending'") ?? 0
            let targetCount = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM targets") ?? 0

            return WorkspaceSummary(
                accountCount: accountCount,
                transactionCount: transactionCount,
                reviewCount: reviewCount,
                targetCount: targetCount
            )
        }
    }

    public func fetchAccounts() throws -> [Account] {
        try databaseQueue.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT id, name, kind, institution_name, created_at
                FROM accounts
                ORDER BY name ASC
                """
            )

            return rows.map { row in
                Account(
                    id: UUID(uuidString: row["id"]) ?? UUID(),
                    name: row["name"],
                    kind: AccountKind(rawValue: row["kind"]) ?? .checking,
                    institutionName: row["institution_name"],
                    createdAt: row["created_at"]
                )
            }
        }
    }

    public func createAccount(named: String, kind: AccountKind, institutionName: String?) throws -> Account {
        let account = Account(name: named, kind: kind, institutionName: institutionName)
        try databaseQueue.write { db in
            try db.execute(
                sql: """
                INSERT INTO accounts (id, name, kind, institution_name, created_at)
                VALUES (?, ?, ?, ?, ?)
                """,
                arguments: [
                    account.id.uuidString,
                    account.name,
                    account.kind.rawValue,
                    account.institutionName,
                    account.createdAt,
                ]
            )
        }
        return account
    }

    public func createStagedImportSession(_ draft: StagedImportSessionDraft) throws -> StagedImportSession {
        let mappingJSON = try String(data: JSONEncoder().encode(draft.mapping), encoding: .utf8) ?? "{}"

        return try databaseQueue.write { db in
            try db.execute(
                sql: """
                INSERT INTO source_files (account_id, original_filename, content_hash, imported_at, row_count)
                VALUES (?, ?, ?, ?, ?)
                """,
                arguments: [
                    draft.accountID.uuidString,
                    draft.originalFilename,
                    draft.contentHash,
                    draft.importedAt,
                    draft.rows.count,
                ]
            )
            let sourceFileID = db.lastInsertedRowID

            let insertSourceRow = try db.makeStatement(
                sql: """
                INSERT INTO source_rows (source_file_id, source_line_number, row_hash, raw_payload, validation_status)
                VALUES (?, ?, ?, ?, ?)
                """
            )
            for row in draft.rows {
                try insertSourceRow.execute(
                    arguments: [
                        sourceFileID,
                        row.sourceLineNumber,
                        row.rowHash,
                        row.rawPayload,
                        row.validationStatus.rawValue,
                    ]
                )
            }

            try db.execute(
                sql: """
                INSERT INTO import_sessions (
                    account_id,
                    source_file_id,
                    mapping_json,
                    valid_row_count,
                    invalid_row_count,
                    status,
                    created_at
                )
                VALUES (?, ?, ?, ?, ?, ?, ?)
                """,
                arguments: [
                    draft.accountID.uuidString,
                    sourceFileID,
                    mappingJSON,
                    draft.validRowCount,
                    draft.invalidRowCount,
                    draft.status.rawValue,
                    draft.importedAt,
                ]
            )
            let sessionID = db.lastInsertedRowID
            guard let session = try fetchStagedImportSession(id: sessionID, db: db) else {
                throw WorkspaceStoreError.insertedStagedSessionNotFound(sessionID)
            }
            return session
        }
    }

    public func fetchStagedImportSession(id: Int64) throws -> StagedImportSession? {
        try databaseQueue.read { db in
            try fetchStagedImportSession(id: id, db: db)
        }
    }

    private func fetchStagedImportSession(id: Int64, db: Database) throws -> StagedImportSession? {
        guard let sessionRow = try Row.fetchOne(
            db,
            sql: """
            SELECT
                import_sessions.id AS import_session_id,
                import_sessions.mapping_json,
                import_sessions.valid_row_count,
                import_sessions.invalid_row_count,
                import_sessions.status,
                source_files.id AS source_file_id,
                source_files.account_id,
                source_files.original_filename,
                source_files.content_hash,
                source_files.imported_at,
                source_files.row_count
            FROM import_sessions
            JOIN source_files ON source_files.id = import_sessions.source_file_id
            WHERE import_sessions.id = ?
            """,
            arguments: [id]
        ) else {
            return nil
        }

        let accountIDText: String = sessionRow["account_id"]
        guard let accountID = UUID(uuidString: accountIDText) else {
            throw WorkspaceStoreError.invalidStoredAccountID(accountIDText)
        }

        let mappingJSON: String = sessionRow["mapping_json"]
        let mapping: CSVColumnMapping
        do {
            mapping = try JSONDecoder().decode(CSVColumnMapping.self, from: Data(mappingJSON.utf8))
        } catch {
            throw WorkspaceStoreError.invalidStoredMapping(error)
        }

        let sourceFileID: Int64 = sessionRow["source_file_id"]
        let rowRecords = try Row.fetchAll(
            db,
            sql: """
            SELECT id, source_file_id, source_line_number, raw_payload, row_hash, validation_status
            FROM source_rows
            WHERE source_file_id = ?
            ORDER BY source_line_number ASC, id ASC
            """,
            arguments: [sourceFileID]
        )

        let rows = rowRecords.map { row in
            StagedSourceRow(
                id: row["id"],
                sourceFileID: row["source_file_id"],
                sourceLineNumber: row["source_line_number"],
                rawPayload: row["raw_payload"],
                rowHash: row["row_hash"],
                validationStatus: StagedSourceRowValidationStatus(rawValue: row["validation_status"]) ?? .invalid
            )
        }

        return StagedImportSession(
            id: sessionRow["import_session_id"],
            sourceFile: StagedSourceFile(
                id: sourceFileID,
                accountID: accountID,
                originalFilename: sessionRow["original_filename"],
                contentHash: sessionRow["content_hash"],
                importedAt: sessionRow["imported_at"],
                rowCount: sessionRow["row_count"]
            ),
            mapping: mapping,
            validRowCount: sessionRow["valid_row_count"],
            invalidRowCount: sessionRow["invalid_row_count"],
            status: ImportSessionStatus(rawValue: sessionRow["status"]) ?? .staged,
            rows: rows
        )
    }
}

private func columnNames(in table: String, db: Database) throws -> Set<String> {
    Set(try db.columns(in: table).map(\.name))
}

private enum WorkspaceStoreError: Error {
    case insertedStagedSessionNotFound(Int64)
    case invalidStoredAccountID(String)
    case invalidStoredMapping(Error)
}
