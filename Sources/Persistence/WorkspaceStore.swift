import Domain
import Foundation
import GRDB

private let workspacePreferenceSuggestionsEnabledKey = "suggestions_enabled"
private let workspacePreferenceSeededHeuristicAutoAcceptEnabledKey = "seeded_heuristic_auto_accept_enabled"

public final class WorkspaceStore: @unchecked Sendable, WorkspaceStoring, LearnedRuleManaging, LearnedRulePreviewReading, StagedImportWriting, StagedImportReading, ImportDecisionReading, ReviewQueueReading, ReviewQueueWriting, ReviewDecisionReading, ClassificationRuleReading, TransactionLedgerReading, TransactionLedgerWriting, ReportingReading, TargetManaging, WorkspaceMaintenanceManaging, WorkspacePreferencesManaging {
    private let databaseQueue: DatabaseQueue
    private let databaseURL: URL?

    public init(databaseQueue: DatabaseQueue, databaseURL: URL? = nil) {
        self.databaseQueue = databaseQueue
        self.databaseURL = databaseURL
    }

    public static func inMemory() throws -> WorkspaceStore {
        WorkspaceStore(databaseQueue: try DatabaseQueue())
    }

    public static func at(databaseURL: URL) throws -> WorkspaceStore {
        WorkspaceStore(databaseQueue: try DatabaseQueue(path: databaseURL.path), databaseURL: databaseURL)
    }

    public static func live() throws -> WorkspaceStore {
        let location = try WorkspaceLocation.live()
        return WorkspaceStore(databaseQueue: try DatabaseQueue(path: location.databasePath), databaseURL: location.databaseURL)
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
                table.column("archived_at", .datetime)
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
                table.column("import_decision_kind", .text).notNull()
                table.column("decision_reason", .text).notNull()
                table.column("duplicate_transaction_id", .text)
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
                table.column("match_kind", .text).notNull().defaults(to: ClassificationRuleMatchKind.contains.rawValue)
                table.column("created_at", .datetime).notNull()
                table.column("disabled_at", .datetime)
            }

            try db.create(table: "review_items") { table in
                table.column("id", .text).primaryKey()
                table.column("transaction_id", .text).references("transactions", onDelete: .cascade)
                table.column("source_row_id", .integer).references("source_rows", onDelete: .cascade)
                table.column("duplicate_transaction_id", .text).references("transactions", onDelete: .setNull)
                table.column("type", .text).notNull()
                table.column("status", .text).notNull()
                table.column("reason", .text)
                table.column("normalized_merchant_name", .text)
                table.column("suggested_category_id", .text)
                table.column("suggested_merchant_name", .text)
                table.column("classification_source", .text)
                table.column("classification_source_reference", .text)
                table.column("classification_confidence", .double)
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
            if sourceFileColumns.contains("filename") {
                try db.execute(
                    sql: """
                    UPDATE source_files
                    SET original_filename = filename
                    WHERE original_filename = ''
                    """
                )
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
            if !sourceRowColumns.contains("import_decision_kind") {
                try db.execute(sql: "ALTER TABLE source_rows ADD COLUMN import_decision_kind TEXT NOT NULL DEFAULT 'imported'")
            }
            if !sourceRowColumns.contains("decision_reason") {
                try db.execute(sql: "ALTER TABLE source_rows ADD COLUMN decision_reason TEXT NOT NULL DEFAULT 'New source row.'")
            }
            if !sourceRowColumns.contains("duplicate_transaction_id") {
                try db.execute(sql: "ALTER TABLE source_rows ADD COLUMN duplicate_transaction_id TEXT")
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

            if try db.tableExists("review_items") {
                let reviewItemColumns = try columnNames(in: "review_items", db: db)
                if !reviewItemColumns.contains("source_row_id") {
                    try db.execute(sql: "ALTER TABLE review_items ADD COLUMN source_row_id INTEGER REFERENCES source_rows(id) ON DELETE CASCADE")
                }
                if !reviewItemColumns.contains("duplicate_transaction_id") {
                    try db.execute(sql: "ALTER TABLE review_items ADD COLUMN duplicate_transaction_id TEXT REFERENCES transactions(id) ON DELETE SET NULL")
                }
                if !reviewItemColumns.contains("reason") {
                    try db.execute(sql: "ALTER TABLE review_items ADD COLUMN reason TEXT")
                }
            }
        }
        migrator.registerMigration("add-review-decision-events") { db in
            try db.execute(sql: "PRAGMA foreign_keys = ON")

            if try !db.tableExists("review_decision_events") {
                try db.create(table: "review_decision_events") { table in
                    table.column("id", .text).primaryKey()
                    table.column("review_item_id", .text).notNull().indexed().references("review_items", onDelete: .cascade)
                    table.column("source_row_id", .integer).notNull().indexed().references("source_rows", onDelete: .cascade)
                    table.column("action", .text).notNull()
                    table.column("details", .text).notNull()
                    table.column("created_at", .datetime).notNull()
                }
            }
        }
        migrator.registerMigration("add-classification-review-context") { db in
            try db.execute(sql: "PRAGMA foreign_keys = ON")

            guard try db.tableExists("review_items") else {
                return
            }

            let reviewItemColumns = try columnNames(in: "review_items", db: db)
            if !reviewItemColumns.contains("normalized_merchant_name") {
                try db.execute(sql: "ALTER TABLE review_items ADD COLUMN normalized_merchant_name TEXT")
            }
            if !reviewItemColumns.contains("suggested_category_id") {
                try db.execute(sql: "ALTER TABLE review_items ADD COLUMN suggested_category_id TEXT")
            }
            if !reviewItemColumns.contains("suggested_merchant_name") {
                try db.execute(sql: "ALTER TABLE review_items ADD COLUMN suggested_merchant_name TEXT")
            }
            if !reviewItemColumns.contains("classification_source") {
                try db.execute(sql: "ALTER TABLE review_items ADD COLUMN classification_source TEXT")
            }
            if !reviewItemColumns.contains("classification_source_reference") {
                try db.execute(sql: "ALTER TABLE review_items ADD COLUMN classification_source_reference TEXT")
            }
            if !reviewItemColumns.contains("classification_confidence") {
                try db.execute(sql: "ALTER TABLE review_items ADD COLUMN classification_confidence DOUBLE")
            }
        }
        migrator.registerMigration("add-category-group-membership") { db in
            try db.execute(sql: "PRAGMA foreign_keys = ON")

            guard try db.tableExists("categories") else {
                return
            }
            let categoryColumns = try columnNames(in: "categories", db: db)
            if !categoryColumns.contains("category_group_id") {
                try db.execute(sql: "ALTER TABLE categories ADD COLUMN category_group_id TEXT REFERENCES category_groups(id) ON DELETE SET NULL")
            }
        }
        migrator.registerMigration("repair-staged-import-ledger-materialization") { db in
            try db.execute(sql: "PRAGMA foreign_keys = ON")

            if try db.tableExists("source_rows") {
                let sourceRowColumns = try columnNames(in: "source_rows", db: db)
                if !sourceRowColumns.contains("import_decision_kind") {
                    try db.execute(sql: "ALTER TABLE source_rows ADD COLUMN import_decision_kind TEXT NOT NULL DEFAULT 'imported'")
                }
                if !sourceRowColumns.contains("decision_reason") {
                    try db.execute(sql: "ALTER TABLE source_rows ADD COLUMN decision_reason TEXT NOT NULL DEFAULT 'New source row.'")
                }
                if !sourceRowColumns.contains("duplicate_transaction_id") {
                    try db.execute(sql: "ALTER TABLE source_rows ADD COLUMN duplicate_transaction_id TEXT")
                }
            }

            if try db.tableExists("review_items") {
                let reviewItemColumns = try columnNames(in: "review_items", db: db)
                if !reviewItemColumns.contains("source_row_id") {
                    try db.execute(sql: "ALTER TABLE review_items ADD COLUMN source_row_id INTEGER REFERENCES source_rows(id) ON DELETE CASCADE")
                }
                if !reviewItemColumns.contains("duplicate_transaction_id") {
                    try db.execute(sql: "ALTER TABLE review_items ADD COLUMN duplicate_transaction_id TEXT REFERENCES transactions(id) ON DELETE SET NULL")
                }
                if !reviewItemColumns.contains("reason") {
                    try db.execute(sql: "ALTER TABLE review_items ADD COLUMN reason TEXT")
                }
            }

            try backfillLedgerTransactionsForLegacyStagedImports(db: db)
        }
        migrator.registerMigration("add-workspace-preferences") { db in
            try db.execute(sql: "PRAGMA foreign_keys = ON")

            if try !db.tableExists("workspace_preferences") {
                try db.create(table: "workspace_preferences") { table in
                    table.column("key", .text).primaryKey()
                    table.column("value", .text).notNull()
                }
            }

            try db.execute(
                sql: """
                INSERT OR IGNORE INTO workspace_preferences (key, value)
                VALUES (?, ?)
                """,
                arguments: [workspacePreferenceSuggestionsEnabledKey, "true"]
            )
        }
        migrator.registerMigration("add-rule-match-kind") { db in
            try db.execute(sql: "PRAGMA foreign_keys = ON")

            guard try db.tableExists("rules") else {
                return
            }

            let ruleColumns = try columnNames(in: "rules", db: db)
            if !ruleColumns.contains("match_kind") {
                try db.execute(
                    sql: """
                    ALTER TABLE rules
                    ADD COLUMN match_kind TEXT NOT NULL DEFAULT 'contains'
                    """
                )
            }
        }
        migrator.registerMigration("add-rule-lifecycle") { db in
            try db.execute(sql: "PRAGMA foreign_keys = ON")

            guard try db.tableExists("rules") else {
                return
            }

            let ruleColumns = try columnNames(in: "rules", db: db)
            if !ruleColumns.contains("disabled_at") {
                try db.execute(
                    sql: """
                    ALTER TABLE rules
                    ADD COLUMN disabled_at DATETIME
                    """
                )
            }
        }
        migrator.registerMigration("add-seeded-heuristic-auto-accept-preference") { db in
            try db.execute(sql: "PRAGMA foreign_keys = ON")

            guard try db.tableExists("workspace_preferences") else {
                return
            }

            try db.execute(
                sql: """
                INSERT OR IGNORE INTO workspace_preferences (key, value)
                VALUES (?, ?)
                """,
                arguments: [workspacePreferenceSeededHeuristicAutoAcceptEnabledKey, "false"]
            )
        }
        migrator.registerMigration("accept-user-categorized-pending-transactions") { db in
            try db.execute(sql: "PRAGMA foreign_keys = ON")

            guard try db.tableExists("transactions") else {
                return
            }

            let transactionColumns = try columnNames(in: "transactions", db: db)
            guard transactionColumns.contains("category_id"),
                  transactionColumns.contains("decision_source"),
                  transactionColumns.contains("review_status"),
                  transactionColumns.contains("duplicate_status")
            else {
                return
            }

            try db.execute(
                sql: """
                UPDATE transactions
                SET review_status = ?,
                    decision_source_reference = NULL
                WHERE review_status = ?
                    AND decision_source = ?
                    AND category_id IS NOT NULL
                    AND duplicate_status = ?
                """,
                arguments: [
                    TransactionReviewStatus.accepted.rawValue,
                    TransactionReviewStatus.pending.rawValue,
                    ClassificationDecisionSource.user.rawValue,
                    "none",
                ]
            )
        }
        migrator.registerMigration("enforce-target-scope-invariants") { db in
            try db.execute(sql: "PRAGMA foreign_keys = ON")
            try installTargetScopeWriteGuards(db: db)
        }
        migrator.registerMigration("add-account-archive-state") { db in
            try db.execute(sql: "PRAGMA foreign_keys = ON")

            guard try db.tableExists("accounts") else {
                return
            }

            let accountColumns = try columnNames(in: "accounts", db: db)
            if !accountColumns.contains("archived_at") {
                try db.execute(sql: "ALTER TABLE accounts ADD COLUMN archived_at DATETIME")
            }
        }

        try migrator.migrate(databaseQueue)
        try seedDefaultBudgetTaxonomy()
    }

    public func fetchSummary() throws -> WorkspaceSummary {
        try databaseQueue.read { db in
            let accountCount = try Int.fetchOne(
                db,
                sql: "SELECT COUNT(*) FROM accounts WHERE archived_at IS NULL"
            ) ?? 0
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
        try fetchManagementAccounts()
    }

    public func fetchManagementAccounts() throws -> [Account] {
        try databaseQueue.read { db in
            try fetchAccountRows(
                db: db,
                sql: """
                SELECT id, name, kind, institution_name, created_at, archived_at
                FROM accounts
                ORDER BY CASE WHEN archived_at IS NULL THEN 0 ELSE 1 END, name ASC
                """
            )
        }
    }

    public func fetchImportEligibleAccounts() throws -> [Account] {
        try databaseQueue.read { db in
            try fetchAccountRows(
                db: db,
                sql: """
                SELECT id, name, kind, institution_name, created_at, archived_at
                FROM accounts
                WHERE archived_at IS NULL
                ORDER BY name ASC
                """
            )
        }
    }

    public func fetchLedgerFilterAccounts() throws -> [Account] {
        try databaseQueue.read { db in
            try fetchAccountRows(
                db: db,
                sql: """
                SELECT id, name, kind, institution_name, created_at, archived_at
                FROM accounts
                ORDER BY name ASC
                """
            )
        }
    }

    public func fetchPermanentlyDeletableAccountIDs() throws -> Set<UUID> {
        try databaseQueue.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT id
                FROM accounts
                WHERE NOT EXISTS (
                    SELECT 1 FROM source_files WHERE source_files.account_id = accounts.id
                )
                  AND NOT EXISTS (
                    SELECT 1 FROM import_sessions WHERE import_sessions.account_id = accounts.id
                )
                  AND NOT EXISTS (
                    SELECT 1 FROM transactions WHERE transactions.account_id = accounts.id
                )
                """
            )

            return Set(rows.compactMap { row in
                let idText: String = row["id"]
                return UUID(uuidString: idText)
            })
        }
    }

    public func fetchCategories() throws -> [BudgetCategory] {
        try databaseQueue.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT id, name, kind, category_group_id
                FROM categories
                ORDER BY \(defaultBudgetCategoryOrderSQL(column: "id")), name ASC
                """
            )

            return try rows.map { row in
                let idText: String = row["id"]
                guard let id = UUID(uuidString: idText) else {
                    throw WorkspaceStoreError.invalidStoredReviewItem(field: "categories.id", value: idText)
                }
                let kindText: String = row["kind"]
                guard let kind = BudgetCategoryKind(rawValue: kindText) else {
                    throw WorkspaceStoreError.invalidStoredReviewItem(field: "categories.kind", value: kindText)
                }
                let groupID: UUID?
                if let groupIDText = row["category_group_id"] as String? {
                    guard let storedGroupID = UUID(uuidString: groupIDText) else {
                        throw WorkspaceStoreError.invalidStoredReviewItem(field: "categories.category_group_id", value: groupIDText)
                    }
                    groupID = storedGroupID
                } else {
                    groupID = nil
                }
                return BudgetCategory(id: id, name: row["name"], kind: kind, groupID: groupID)
            }
        }
    }

    public func fetchCategoryGroups() throws -> [BudgetCategoryGroup] {
        try databaseQueue.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT id, name
                FROM category_groups
                ORDER BY \(defaultCategoryGroupOrderSQL(column: "id")), name ASC
                """
            )

            return try rows.map { row in
                let idText: String = row["id"]
                guard let id = UUID(uuidString: idText) else {
                    throw WorkspaceStoreError.invalidStoredReviewItem(field: "category_groups.id", value: idText)
                }
                return BudgetCategoryGroup(id: id, name: row["name"])
            }
        }
    }

    private func seedDefaultBudgetTaxonomy() throws {
        try databaseQueue.write { db in
            try db.execute(sql: "PRAGMA foreign_keys = ON")
            guard try db.tableExists("categories"),
                  try db.tableExists("category_groups"),
                  try columnNames(in: "categories", db: db).contains("category_group_id")
            else {
                return
            }

            for group in defaultCategoryGroups {
                try db.execute(
                    sql: """
                    INSERT INTO category_groups (id, name)
                    VALUES (?, ?)
                    ON CONFLICT(id) DO UPDATE SET name = excluded.name
                    """,
                    arguments: [group.id.uuidString, group.name]
                )
            }

            for category in defaultBudgetCategories {
                let groupID = try seededCategoryGroupIDPreservingTargetDisjointness(
                    for: category,
                    db: db
                )
                try db.execute(
                    sql: """
                    INSERT INTO categories (id, name, kind, category_group_id)
                    VALUES (?, ?, ?, ?)
                    ON CONFLICT(id) DO UPDATE SET
                        name = excluded.name,
                        kind = excluded.kind,
                        category_group_id = excluded.category_group_id
                    """,
                    arguments: [
                        category.id.uuidString,
                        category.name,
                        category.kind.rawValue,
                        groupID?.uuidString,
                    ]
                )
            }

            try pruneObsoleteDefaultTaxonomy(db: db)
        }
    }

    public func fetchPendingReviewItems() throws -> [PendingReviewItem] {
        try databaseQueue.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT
                    review_items.id,
                    review_items.type,
                    review_items.status,
                    review_items.reason,
                    review_items.created_at,
                    review_items.duplicate_transaction_id,
                    review_items.normalized_merchant_name,
                    review_items.suggested_category_id,
                    review_items.suggested_merchant_name,
                    review_items.classification_source,
                    review_items.classification_source_reference,
                    review_items.classification_confidence,
                    source_rows.id AS source_row_id,
                    source_rows.source_line_number,
                    source_rows.row_hash,
                    source_rows.raw_payload,
                    source_files.account_id,
                    source_files.original_filename
                FROM review_items
                JOIN source_rows ON source_rows.id = review_items.source_row_id
                JOIN source_files ON source_files.id = source_rows.source_file_id
                LEFT JOIN transactions ON transactions.id = review_items.transaction_id
                WHERE review_items.status = ?
                  AND (
                    review_items.type != ?
                    OR transactions.review_status IS NULL
                    OR transactions.review_status = ?
                  )
                ORDER BY review_items.created_at ASC, review_items.id ASC
                """,
                arguments: [
                    ReviewItemStatus.pending.rawValue,
                    ReviewItemType.lowConfidenceCategory.rawValue,
                    TransactionReviewStatus.pending.rawValue,
                ]
            )

            return try rows.map { row in
                let reviewItemIDText: String = row["id"]
                guard let id = UUID(uuidString: reviewItemIDText) else {
                    throw WorkspaceStoreError.invalidStoredReviewItem(field: "id", value: reviewItemIDText)
                }

                let typeText: String = row["type"]
                guard let type = ReviewItemType(rawValue: typeText) else {
                    throw WorkspaceStoreError.invalidStoredReviewItem(field: "type", value: typeText)
                }

                let statusText: String = row["status"]
                guard let status = ReviewItemStatus(rawValue: statusText) else {
                    throw WorkspaceStoreError.invalidStoredReviewItem(field: "status", value: statusText)
                }

                let accountIDText: String = row["account_id"]
                guard let accountID = UUID(uuidString: accountIDText) else {
                    throw WorkspaceStoreError.invalidStoredReviewItem(field: "account_id", value: accountIDText)
                }

                return PendingReviewItem(
                    id: id,
                    type: type,
                    status: status,
                    reason: row["reason"],
                    createdAt: row["created_at"],
                    sourceFile: PendingReviewSourceFile(
                        accountID: accountID,
                        originalFilename: row["original_filename"]
                    ),
                    sourceRow: PendingReviewSourceRow(
                        id: row["source_row_id"],
                        sourceLineNumber: row["source_line_number"],
                        rowHash: row["row_hash"],
                        rawPayload: row["raw_payload"]
                    ),
                    duplicateTransactionID: (row["duplicate_transaction_id"] as String?).flatMap(UUID.init(uuidString:)),
                    classification: try pendingReviewClassification(from: row)
                )
            }
        }
    }

    public func fetchReviewDecisionEvents(reviewItemID: UUID) throws -> [ReviewDecisionEvent] {
        try databaseQueue.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT id, review_item_id, source_row_id, action, details, created_at
                FROM review_decision_events
                WHERE review_item_id = ?
                ORDER BY created_at ASC, id ASC
                """,
                arguments: [reviewItemID.uuidString]
            )

            return try rows.map { row in
                let eventIDText: String = row["id"]
                guard let eventID = UUID(uuidString: eventIDText) else {
                    throw WorkspaceStoreError.invalidStoredReviewItem(field: "review_decision_events.id", value: eventIDText)
                }

                let reviewItemIDText: String = row["review_item_id"]
                guard let storedReviewItemID = UUID(uuidString: reviewItemIDText) else {
                    throw WorkspaceStoreError.invalidStoredReviewItem(field: "review_decision_events.review_item_id", value: reviewItemIDText)
                }

                let actionText: String = row["action"]
                guard let action = ReviewDecisionAction(rawValue: actionText) else {
                    throw WorkspaceStoreError.invalidStoredReviewItem(field: "review_decision_events.action", value: actionText)
                }

                return ReviewDecisionEvent(
                    id: eventID,
                    reviewItemID: storedReviewItemID,
                    sourceRowID: row["source_row_id"],
                    action: action,
                    details: row["details"],
                    createdAt: row["created_at"]
                )
            }
        }
    }

    public func keepBothForLikelyDuplicateReviewItem(id: UUID, resolvedAt: Date) throws -> ReviewDecisionEvent {
        try databaseQueue.write { db in
            guard let row = try Row.fetchOne(
                db,
                sql: """
                SELECT
                    review_items.id,
                    review_items.type,
                    review_items.status,
                    review_items.duplicate_transaction_id,
                    review_items.source_row_id,
                    source_rows.raw_payload,
                    source_files.account_id,
                    import_sessions.id AS import_session_id,
                    import_sessions.mapping_json
                FROM review_items
                JOIN source_rows ON source_rows.id = review_items.source_row_id
                JOIN source_files ON source_files.id = source_rows.source_file_id
                JOIN import_sessions ON import_sessions.source_file_id = source_files.id
                WHERE review_items.id = ?
                """,
                arguments: [id.uuidString]
            ) else {
                throw WorkspaceStoreError.reviewItemNotFound(id)
            }

            let typeText: String = row["type"]
            guard typeText == ReviewItemType.likelyDuplicate.rawValue else {
                throw WorkspaceStoreError.unsupportedReviewItemType(typeText)
            }

            let statusText: String = row["status"]
            guard statusText == ReviewItemStatus.pending.rawValue else {
                throw WorkspaceStoreError.reviewItemNotPending(id)
            }

            let duplicateTransactionIDText: String = try requireString(
                row["duplicate_transaction_id"],
                field: "review_items.duplicate_transaction_id"
            )
            guard let duplicateTransactionID = UUID(uuidString: duplicateTransactionIDText) else {
                throw WorkspaceStoreError.invalidStoredReviewItem(
                    field: "review_items.duplicate_transaction_id",
                    value: duplicateTransactionIDText
                )
            }

            let sourceRowID: Int64 = row["source_row_id"]
            let accountIDText: String = try requireString(
                row["account_id"],
                field: "source_files.account_id"
            )
            guard let accountID = UUID(uuidString: accountIDText) else {
                throw WorkspaceStoreError.invalidStoredReviewItem(
                    field: "source_files.account_id",
                    value: accountIDText
                )
            }
            let importSessionID: Int64 = row["import_session_id"]
            let rawPayload: String = try requireString(
                row["raw_payload"],
                field: "source_rows.raw_payload"
            )
            let mappingJSON: String = try requireString(
                row["mapping_json"],
                field: "import_sessions.mapping_json"
            )
            let transaction = try stagedTransactionDraft(rawPayload: rawPayload, mappingJSON: mappingJSON)
            let details = "User kept both the staged row and existing transaction after duplicate review."
            let event = ReviewDecisionEvent(
                id: UUID(),
                reviewItemID: id,
                sourceRowID: sourceRowID,
                action: .keepBoth,
                details: details,
                createdAt: resolvedAt
            )

            try insertTransaction(
                id: UUID(),
                accountID: accountID,
                importSessionID: importSessionID,
                transaction: transaction,
                classification: nil,
                db: db
            )

            try db.execute(
                sql: """
                UPDATE review_items
                SET status = ?
                WHERE id = ?
                """,
                arguments: [ReviewItemStatus.resolved.rawValue, id.uuidString]
            )

            try db.execute(
                sql: """
                UPDATE source_rows
                SET import_decision_kind = ?, decision_reason = ?, duplicate_transaction_id = ?
                WHERE id = ?
                """,
                arguments: [
                    ImportRowDecision.keptBothAfterLikelyDuplicateReview(
                        existingTransactionID: duplicateTransactionID,
                        reason: details
                    ).storageKind,
                    details,
                    duplicateTransactionID.uuidString,
                    sourceRowID,
                ]
            )

            try db.execute(
                sql: """
                INSERT INTO review_decision_events (
                    id,
                    review_item_id,
                    source_row_id,
                    action,
                    details,
                    created_at
                )
                VALUES (?, ?, ?, ?, ?, ?)
                """,
                arguments: [
                    event.id.uuidString,
                    event.reviewItemID.uuidString,
                    event.sourceRowID,
                    event.action.rawValue,
                    event.details,
                    event.createdAt,
                ]
            )

            return event
        }
    }

    public func approveClassificationReviewItem(
        id: UUID,
        assignment: ClassificationAssignment,
        ruleLearning: ReviewRuleLearningOption?,
        resolvedAt: Date
    ) throws -> ReviewDecisionEvent {
        try databaseQueue.write { db in
            guard let row = try Row.fetchOne(
                db,
                sql: """
                SELECT
                    id,
                    type,
                    status,
                    source_row_id,
                    normalized_merchant_name,
                    transaction_id
                FROM review_items
                WHERE id = ?
                """,
                arguments: [id.uuidString]
            ) else {
                throw WorkspaceStoreError.reviewItemNotFound(id)
            }

            let typeText: String = row["type"]
            guard typeText == ReviewItemType.lowConfidenceCategory.rawValue else {
                throw WorkspaceStoreError.unsupportedReviewItemType(typeText)
            }

            let statusText: String = row["status"]
            guard statusText == ReviewItemStatus.pending.rawValue else {
                throw WorkspaceStoreError.reviewItemNotPending(id)
            }

            let sourceRowID: Int64 = row["source_row_id"]
            let transactionIDText = row["transaction_id"] as String?
            let merchantPattern = try requireString(
                row["normalized_merchant_name"],
                field: "review_items.normalized_merchant_name"
            )
            let approvedMerchantName = assignment.merchantName?.nilIfEmpty ?? merchantPattern
            let details: String
            if let ruleLearning {
                switch ruleLearning {
                case .exactNormalizedMerchant:
                    details = "User approved classification and created an exact merchant rule."
                case .prefixNormalizedMerchant:
                    details = "User approved classification and created a shared-prefix merchant rule."
                }
            } else {
                details = "User approved classification without creating a merchant rule."
            }
            let event = ReviewDecisionEvent(
                id: UUID(),
                reviewItemID: id,
                sourceRowID: sourceRowID,
                action: .approveSuggestion,
                details: details,
                createdAt: resolvedAt
            )

            try db.execute(
                sql: """
                UPDATE review_items
                SET status = ?
                WHERE id = ?
                """,
                arguments: [ReviewItemStatus.resolved.rawValue, id.uuidString]
            )

            if let transactionIDText {
                try db.execute(
                    sql: """
                    UPDATE transactions
                    SET category_id = ?,
                        normalized_merchant_name = ?,
                    decision_source = ?,
                    decision_source_reference = NULL,
                    confidence = ?,
                    review_status = ?
                WHERE id = ?
                """,
                    arguments: [
                        assignment.categoryID.uuidString,
                        approvedMerchantName,
                        ClassificationDecisionSource.user.rawValue,
                        1.0,
                        TransactionReviewStatus.accepted.rawValue,
                        transactionIDText,
                    ]
                )
            }

            if let ruleLearning {
                let sanitizedRuleLearning = ruleLearning.resolvingEmptyPattern(fallbackPattern: merchantPattern)
                let learnedRuleID = UUID()
                try db.execute(
                    sql: """
                    INSERT INTO rules (id, pattern, category_id, merchant_name, match_kind, created_at, disabled_at)
                    VALUES (?, ?, ?, ?, ?, ?, ?)
                    """,
                    arguments: [
                        learnedRuleID.uuidString,
                        sanitizedRuleLearning.pattern,
                        assignment.categoryID.uuidString,
                        assignment.merchantName,
                        sanitizedRuleLearning.matchKind.rawValue,
                        resolvedAt,
                        nil,
                    ]
                )
                try backfillTransactionsMatchingLearnedRule(
                    db: db,
                    learnedRuleID: learnedRuleID,
                    learnedRule: sanitizedRuleLearning,
                    assignment: assignment,
                    resolvedAt: resolvedAt
                )
            }

            try db.execute(
                sql: """
                INSERT INTO review_decision_events (
                    id,
                    review_item_id,
                    source_row_id,
                    action,
                    details,
                    created_at
                )
                VALUES (?, ?, ?, ?, ?, ?)
                """,
                arguments: [
                    event.id.uuidString,
                    event.reviewItemID.uuidString,
                    event.sourceRowID,
                    event.action.rawValue,
                    event.details,
                    event.createdAt,
                ]
            )

            return event
        }
    }

    public func fetchClassificationRules() throws -> [ClassificationRule] {
        try databaseQueue.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT rules.id, rules.pattern, rules.category_id, rules.merchant_name, rules.match_kind
                FROM rules
                JOIN categories ON categories.id = rules.category_id
                WHERE rules.disabled_at IS NULL
                ORDER BY CASE rules.match_kind
                    WHEN 'exact_normalized_merchant' THEN 0
                    WHEN 'prefix_normalized_merchant' THEN 1
                    ELSE 2
                END ASC,
                rules.created_at DESC,
                rules.id DESC
                """
            )

            return try rows.map { row in
                let ruleIDText: String = row["id"]
                guard let ruleID = UUID(uuidString: ruleIDText) else {
                    throw WorkspaceStoreError.invalidStoredReviewItem(field: "rules.id", value: ruleIDText)
                }

                let categoryIDText: String = try requireString(row["category_id"], field: "rules.category_id")
                guard let categoryID = UUID(uuidString: categoryIDText) else {
                    throw WorkspaceStoreError.invalidStoredReviewItem(field: "rules.category_id", value: categoryIDText)
                }
                let matchKindText = (row["match_kind"] as String?) ?? ClassificationRuleMatchKind.contains.rawValue
                guard let matchKind = ClassificationRuleMatchKind(rawValue: matchKindText) else {
                    throw WorkspaceStoreError.invalidStoredReviewItem(field: "rules.match_kind", value: matchKindText)
                }

                return ClassificationRule(
                    id: ruleID,
                    merchantPattern: row["pattern"],
                    categoryID: categoryID,
                    merchantName: row["merchant_name"],
                    matchKind: matchKind
                )
            }
        }
    }

    public func previewLearnedRuleImpact(
        merchantPattern: String,
        matchKind: ClassificationRuleMatchKind,
        excludingReviewItemID: UUID?
    ) throws -> LearnedRuleImpactPreview {
        try databaseQueue.read { db in
            let matchedCandidates = try matchingTransactionCandidatesForLearnedRule(
                db: db,
                merchantPattern: merchantPattern,
                matchKind: matchKind
            )
            let matchedTransactionIDs = matchedCandidates.map(\.transactionID)
            let siblingReviewItems = try fetchPendingSiblingReviewItems(
                db: db,
                matchedTransactionIDs: matchedTransactionIDs,
                excludingReviewItemID: excludingReviewItemID?.uuidString
            )
            return LearnedRuleImpactPreview(
                matchedAcceptedTransactionCount: matchedCandidates.filter {
                    $0.reviewStatus == TransactionReviewStatus.accepted.rawValue
                }.count,
                matchedPendingReviewItemCount: siblingReviewItems.count
            )
        }
    }

    public func fetchLearnedRuleSummaries() throws -> [LearnedRuleSummary] {
        try databaseQueue.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT id, pattern, category_id, merchant_name, match_kind, created_at, disabled_at
                FROM rules
                ORDER BY CASE WHEN disabled_at IS NULL THEN 0 ELSE 1 END ASC,
                created_at DESC,
                id DESC
                """
            )
            return try rows.map(learnedRuleSummary(from:))
        }
    }

    public func fetchLearnedRuleSummary(id: UUID) throws -> LearnedRuleSummary? {
        try databaseQueue.read { db in
            guard let row = try Row.fetchOne(
                db,
                sql: """
                SELECT id, pattern, category_id, merchant_name, match_kind, created_at, disabled_at
                FROM rules
                WHERE id = ?
                """,
                arguments: [id.uuidString]
            ) else {
                return nil
            }
            return try learnedRuleSummary(from: row)
        }
    }

    public func fetchLearnedRuleDetail(id: UUID) throws -> ManagedLearnedRule? {
        try databaseQueue.read { db in
            guard let row = try Row.fetchOne(
                db,
                sql: """
                SELECT id, pattern, category_id, merchant_name, match_kind, created_at, disabled_at
                FROM rules
                WHERE id = ?
                """,
                arguments: [id.uuidString]
            ) else {
                return nil
            }
            return try learnedRuleDetail(from: row)
        }
    }

    public func createLearnedRule(_ draft: LearnedRuleDraft, createdAt: Date) throws -> ManagedLearnedRule {
        try databaseQueue.write { db in
            guard let merchantPattern = draft.normalizedMerchantPattern else {
                throw WorkspaceStoreError.invalidLearnedRulePattern
            }

            let learnedRuleID = UUID()
            try db.execute(
                sql: """
                INSERT INTO rules (id, pattern, category_id, merchant_name, match_kind, created_at, disabled_at)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                """,
                arguments: [
                    learnedRuleID.uuidString,
                    merchantPattern,
                    draft.categoryID?.uuidString,
                    draft.merchantName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                    draft.matchKind.rawValue,
                    createdAt,
                    nil,
                ]
            )

            guard let createdRule = try learnedRuleDetail(id: learnedRuleID, db: db) else {
                throw WorkspaceStoreError.learnedRuleNotFound(learnedRuleID)
            }
            return createdRule
        }
    }

    public func disableLearnedRule(id: UUID, disabledAt: Date) throws -> ManagedLearnedRule {
        try databaseQueue.write { db in
            try db.execute(
                sql: """
                UPDATE rules
                SET disabled_at = ?
                WHERE id = ?
                """,
                arguments: [disabledAt, id.uuidString]
            )

            guard let updatedRule = try learnedRuleDetail(id: id, db: db) else {
                throw WorkspaceStoreError.learnedRuleNotFound(id)
            }
            return updatedRule
        }
    }

    public func enableLearnedRule(id: UUID) throws -> ManagedLearnedRule {
        try databaseQueue.write { db in
            try db.execute(
                sql: """
                UPDATE rules
                SET disabled_at = NULL
                WHERE id = ?
                """,
                arguments: [id.uuidString]
            )

            guard let updatedRule = try learnedRuleDetail(id: id, db: db) else {
                throw WorkspaceStoreError.learnedRuleNotFound(id)
            }
            return updatedRule
        }
    }

    private func learnedRuleSummary(from row: Row) throws -> LearnedRuleSummary {
        let ruleIDText: String = row["id"]
        guard let ruleID = UUID(uuidString: ruleIDText) else {
            throw WorkspaceStoreError.invalidStoredReviewItem(field: "rules.id", value: ruleIDText)
        }

        let categoryID: UUID?
        if let categoryIDText = row["category_id"] as String? {
            guard let parsedCategoryID = UUID(uuidString: categoryIDText) else {
                throw WorkspaceStoreError.invalidStoredReviewItem(field: "rules.category_id", value: categoryIDText)
            }
            categoryID = parsedCategoryID
        } else {
            categoryID = nil
        }

        let matchKindText = (row["match_kind"] as String?) ?? ClassificationRuleMatchKind.contains.rawValue
        guard let matchKind = ClassificationRuleMatchKind(rawValue: matchKindText) else {
            throw WorkspaceStoreError.invalidStoredReviewItem(field: "rules.match_kind", value: matchKindText)
        }

        let createdAt: Date = row["created_at"]
        let disabledAt: Date? = row["disabled_at"]
        let lifecycle: LearnedRuleLifecycle
        if let disabledAt {
            lifecycle = .disabled(disabledAt: disabledAt)
        } else {
            lifecycle = .active
        }

        return LearnedRuleSummary(
            id: ruleID,
            merchantPattern: row["pattern"],
            categoryID: categoryID,
            merchantName: row["merchant_name"],
            matchKind: matchKind,
            createdAt: createdAt,
            lifecycle: lifecycle
        )
    }

    private func learnedRuleDetail(from row: Row) throws -> ManagedLearnedRule {
        let summary = try learnedRuleSummary(from: row)
        return ManagedLearnedRule(
            id: summary.id,
            merchantPattern: summary.merchantPattern,
            categoryID: summary.categoryID,
            merchantName: summary.merchantName,
            matchKind: summary.matchKind,
            createdAt: summary.createdAt,
            lifecycle: summary.lifecycle
        )
    }

    private func learnedRuleDetail(id: UUID, db: Database) throws -> ManagedLearnedRule? {
        guard let row = try Row.fetchOne(
            db,
            sql: """
            SELECT id, pattern, category_id, merchant_name, match_kind, created_at, disabled_at
            FROM rules
            WHERE id = ?
            """,
            arguments: [id.uuidString]
        ) else {
            return nil
        }
        return try learnedRuleDetail(from: row)
    }

    private func backfillTransactionsMatchingLearnedRule(
        db: Database,
        learnedRuleID: UUID,
        learnedRule: ReviewRuleLearningOption,
        assignment: ClassificationAssignment,
        resolvedAt: Date
    ) throws {
        let matchedTransactionIDs = try matchingTransactionCandidatesForLearnedRule(
            db: db,
            merchantPattern: learnedRule.pattern,
            matchKind: learnedRule.matchKind
        ).map(\.transactionID)
        guard !matchedTransactionIDs.isEmpty else {
            return
        }

        let placeholders = Array(repeating: "?", count: matchedTransactionIDs.count).joined(separator: ", ")
        var arguments: StatementArguments = [
            assignment.categoryID.uuidString,
            ClassificationDecisionSource.rule.rawValue,
            learnedRuleID.uuidString,
            1.0,
            TransactionReviewStatus.accepted.rawValue,
        ]
        _ = arguments.append(contentsOf: StatementArguments(matchedTransactionIDs))
        try db.execute(
            sql: """
            UPDATE transactions
            SET category_id = ?,
                decision_source = ?,
                decision_source_reference = ?,
                confidence = ?,
                review_status = ?
            WHERE id IN (\(placeholders))
            """,
            arguments: arguments
        )

        let siblingReviewItems = try fetchPendingSiblingReviewItems(
            db: db,
            matchedTransactionIDs: matchedTransactionIDs
        )
        try resolveSiblingReviewItemsResolvedByBackfill(
            db: db,
            siblingReviewItems: siblingReviewItems,
            resolvedAt: resolvedAt
        )
    }

    private func fetchPendingSiblingReviewItems(
        db: Database,
        matchedTransactionIDs: [String],
        excludingReviewItemID: String? = nil
    ) throws -> [(reviewItemID: String, sourceRowID: Int64)] {
        guard !matchedTransactionIDs.isEmpty else {
            return []
        }

        let placeholders = Array(repeating: "?", count: matchedTransactionIDs.count).joined(separator: ", ")
        let arguments = StatementArguments(matchedTransactionIDs)
        let rows = try Row.fetchAll(
            db,
            sql: """
            SELECT id, source_row_id
            FROM review_items
            WHERE transaction_id IN (\(placeholders))
              AND status = ?
              AND type = ?
              AND (? IS NULL OR id != ?)
            """,
            arguments: {
                var argumentsWithFilters = arguments
                _ = argumentsWithFilters.append(contentsOf: StatementArguments([
                    ReviewItemStatus.pending.rawValue,
                    ReviewItemType.lowConfidenceCategory.rawValue,
                    excludingReviewItemID,
                    excludingReviewItemID,
                ]))
                return argumentsWithFilters
            }()
        )

        return rows.map { row in
            (
                reviewItemID: row["id"],
                sourceRowID: row["source_row_id"]
            )
        }
    }

    private func resolveSiblingReviewItemsResolvedByBackfill(
        db: Database,
        siblingReviewItems: [(reviewItemID: String, sourceRowID: Int64)],
        resolvedAt: Date
    ) throws {
        guard !siblingReviewItems.isEmpty else {
            return
        }

        let reviewItemIDs = siblingReviewItems.map(\.reviewItemID)
        let placeholders = Array(repeating: "?", count: reviewItemIDs.count).joined(separator: ", ")
        try db.execute(
            sql: """
            UPDATE review_items
            SET status = ?
            WHERE id IN (\(placeholders))
            """,
            arguments: StatementArguments([ReviewItemStatus.resolved.rawValue] + reviewItemIDs)
        )

        for siblingReviewItem in siblingReviewItems {
            try db.execute(
                sql: """
                INSERT INTO review_decision_events (
                    id,
                    review_item_id,
                    source_row_id,
                    action,
                    details,
                    created_at
                )
                VALUES (?, ?, ?, ?, ?, ?)
                """,
                arguments: [
                    UUID().uuidString,
                    siblingReviewItem.reviewItemID,
                    siblingReviewItem.sourceRowID,
                    ReviewDecisionAction.autoResolvedByLearnedRuleBackfill.rawValue,
                    "Automatically resolved after learned-rule backfill.",
                    resolvedAt,
                ]
            )
        }
    }

    private func matchingTransactionCandidatesForLearnedRule(
        db: Database,
        merchantPattern: String,
        matchKind: ClassificationRuleMatchKind
    ) throws -> [LearnedRuleBackfillCandidate] {
        let backfillableDecisionSources = learnedRuleBackfillDecisionSources.map(\.rawValue)
        let candidateRows = try Row.fetchAll(
            db,
            sql: """
            SELECT id, normalized_merchant_name, raw_description, review_status
            FROM transactions
            WHERE review_status = ?
               OR (
                    review_status = ?
                AND decision_source IN (?, ?)
               )
            """,
            arguments: [
                TransactionReviewStatus.pending.rawValue,
                TransactionReviewStatus.accepted.rawValue,
                backfillableDecisionSources[0],
                backfillableDecisionSources[1],
            ]
        )

        return try candidateRows.compactMap { row -> LearnedRuleBackfillCandidate? in
            let transactionID = try requireString(row["id"], field: "transactions.id")
            let rawDescription = try requireString(row["raw_description"], field: "transactions.raw_description")
            let reviewStatus = try requireString(row["review_status"], field: "transactions.review_status")
            let candidate = LearnedRuleMatchCandidate(
                normalizedMerchantName: (row["normalized_merchant_name"] as String?) ?? "",
                rawDescription: rawDescription
            )
            guard LearnedRuleMatcher.matches(
                merchantPattern: merchantPattern,
                matchKind: matchKind,
                candidate: candidate
            ) else {
                return nil
            }
            return LearnedRuleBackfillCandidate(
                transactionID: transactionID,
                reviewStatus: reviewStatus
            )
        }
    }

    private func resolvePendingLowConfidenceReviewItems(
        db: Database,
        transactionIDs: [String]
    ) throws {
        guard !transactionIDs.isEmpty else {
            return
        }

        let placeholders = Array(repeating: "?", count: transactionIDs.count).joined(separator: ", ")
        var arguments = StatementArguments([ReviewItemStatus.resolved.rawValue])
        _ = arguments.append(contentsOf: StatementArguments(transactionIDs))
        _ = arguments.append(contentsOf: StatementArguments([
            ReviewItemStatus.pending.rawValue,
            ReviewItemType.lowConfidenceCategory.rawValue,
        ]))
        try db.execute(
            sql: """
            UPDATE review_items
            SET status = ?
            WHERE transaction_id IN (\(placeholders))
              AND status = ?
              AND type = ?
            """,
            arguments: arguments
        )
    }

    public func fetchTransactionLedger(filter: TransactionLedgerFilter = .empty) throws -> [TransactionLedgerRow] {
        try databaseQueue.read { db in
            let query = transactionLedgerQuery(filter: filter, includeIDPredicate: false)
            let rows = try Row.fetchAll(db, sql: query.sql, arguments: query.arguments)
            return try rows.map(transactionLedgerRow(from:))
        }
    }

    public func fetchTransactionDetail(id: UUID) throws -> TransactionDetail? {
        try databaseQueue.read { db in
            var query = transactionLedgerQuery(filter: .empty, includeIDPredicate: true)
            appendArgument(id.uuidString, to: &query.arguments)
            guard let row = try Row.fetchOne(db, sql: query.sql, arguments: query.arguments) else {
                return nil
            }

            let ledgerRow = try transactionLedgerRow(from: row)
            return TransactionDetail(
                row: ledgerRow,
                notes: row["notes"],
                decisionSource: try classificationSource(from: row["decision_source"]),
                decisionSourceReference: row["decision_source_reference"],
                confidence: row["confidence"],
                duplicateStatus: row["duplicate_status"]
            )
        }
    }

    public func fetchTransactionImportOrigins() throws -> [TransactionImportOrigin] {
        try databaseQueue.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT DISTINCT
                    import_sessions.id AS import_session_id,
                    source_files.original_filename,
                    source_files.imported_at
                FROM transactions
                JOIN import_sessions ON import_sessions.id = transactions.import_session_id
                JOIN source_files ON source_files.id = import_sessions.source_file_id
                ORDER BY source_files.imported_at DESC, import_sessions.id DESC
                """
            )

            return rows.map { row in
                TransactionImportOrigin(
                    id: row["import_session_id"],
                    originalFilename: row["original_filename"],
                    importedAt: row["imported_at"]
                )
            }
        }
    }

    public func updateTransactionLedgerFields(id: UUID, draft: TransactionLedgerEditDraft) throws {
        try databaseQueue.write { db in
            guard let row = try Row.fetchOne(
                db,
                sql: """
                SELECT normalized_merchant_name, category_id, decision_source, review_status
                FROM transactions
                WHERE id = ?
                """,
                arguments: [id.uuidString]
            ) else {
                throw WorkspaceStoreError.transactionNotFound(id)
            }

            let merchantName = draft.merchantName.trimmingCharacters(in: .whitespacesAndNewlines)
            let notes = draft.notes?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            let currentMerchantName = try requireString(
                row["normalized_merchant_name"],
                field: "transactions.normalized_merchant_name"
            )
            let currentCategoryID = (row["category_id"] as String?).flatMap(UUID.init)
            let currentDecisionSource = ClassificationDecisionSource(
                rawValue: try requireString(row["decision_source"], field: "transactions.decision_source")
            )
            let currentReviewStatus = TransactionReviewStatus(
                rawValue: try requireString(row["review_status"], field: "transactions.review_status")
            )
            let promotesPendingTransactionToUser =
                draft.categoryID != nil && currentReviewStatus == .pending
            let promotesAcceptedStarterTransactionToUser =
                currentReviewStatus == .accepted
                && isAcceptedTransactionPromotableToUserOnEdit(currentDecisionSource)
                && (merchantName != currentMerchantName || draft.categoryID != currentCategoryID)

            if promotesPendingTransactionToUser || promotesAcceptedStarterTransactionToUser {
                try db.execute(
                    sql: """
                    UPDATE transactions
                    SET normalized_merchant_name = ?,
                        category_id = ?,
                        decision_source = ?,
                        decision_source_reference = NULL,
                        confidence = ?,
                        review_status = ?,
                        notes = ?
                    WHERE id = ?
                    """,
                    arguments: [
                        merchantName,
                        draft.categoryID?.uuidString,
                        ClassificationDecisionSource.user.rawValue,
                        1.0,
                        TransactionReviewStatus.accepted.rawValue,
                        notes,
                        id.uuidString,
                    ]
                )
                try resolvePendingLowConfidenceReviewItems(
                    db: db,
                    transactionIDs: [id.uuidString]
                )
            } else {
                try db.execute(
                    sql: """
                    UPDATE transactions
                    SET normalized_merchant_name = ?,
                        category_id = ?,
                        notes = ?
                    WHERE id = ?
                    """,
                    arguments: [
                        merchantName,
                        draft.categoryID?.uuidString,
                        notes,
                        id.uuidString,
                    ]
                )
            }
        }
    }

    public func fetchWorkspaceMetadata() throws -> WorkspaceMetadata {
        guard let databaseURL else {
            throw WorkspaceMaintenanceError.onDiskWorkspaceRequired
        }

        let attributes = try? FileManager.default.attributesOfItem(atPath: databaseURL.path)
        return WorkspaceMetadata(
            databaseURL: databaseURL,
            databaseExists: FileManager.default.fileExists(atPath: databaseURL.path),
            databaseSizeBytes: (attributes?[.size] as? NSNumber)?.int64Value ?? 0,
            modifiedAt: attributes?[.modificationDate] as? Date
        )
    }

    public func fetchWorkspacePreferences() throws -> WorkspacePreferences {
        try databaseQueue.read { db in
            let suggestionsEnabled = try String.fetchOne(
                db,
                sql: """
                SELECT value
                FROM workspace_preferences
                WHERE key = ?
                """,
                arguments: [workspacePreferenceSuggestionsEnabledKey]
            ) ?? "true"
            let seededHeuristicAutoAcceptEnabled = try String.fetchOne(
                db,
                sql: """
                SELECT value
                FROM workspace_preferences
                WHERE key = ?
                """,
                arguments: [workspacePreferenceSeededHeuristicAutoAcceptEnabledKey]
            ) ?? "false"

            return WorkspacePreferences(
                suggestionsEnabled: suggestionsEnabled == "true",
                seededHeuristicAutoAcceptEnabled: seededHeuristicAutoAcceptEnabled == "true"
            )
        }
    }

    public func updateWorkspacePreferences(_ preferences: WorkspacePreferences) throws {
        try databaseQueue.write { db in
            try db.execute(
                sql: """
                INSERT INTO workspace_preferences (key, value)
                VALUES (?, ?)
                ON CONFLICT(key) DO UPDATE SET value = excluded.value
                """,
                arguments: [
                    workspacePreferenceSuggestionsEnabledKey,
                    preferences.suggestionsEnabled ? "true" : "false",
                ]
            )
            try db.execute(
                sql: """
                INSERT INTO workspace_preferences (key, value)
                VALUES (?, ?)
                ON CONFLICT(key) DO UPDATE SET value = excluded.value
                """,
                arguments: [
                    workspacePreferenceSeededHeuristicAutoAcceptEnabledKey,
                    preferences.seededHeuristicAutoAcceptEnabled ? "true" : "false",
                ]
            )
        }
    }

    public func createWorkspaceBackup(in directory: URL?, now: Date) throws -> WorkspaceBackup {
        guard let databaseURL else {
            throw WorkspaceMaintenanceError.onDiskWorkspaceRequired
        }

        let backupDirectory = directory ?? databaseURL
            .deletingLastPathComponent()
            .appending(path: "Backups", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
        let backupURL = backupDirectory.appending(path: backupFilename(for: now))
        if FileManager.default.fileExists(atPath: backupURL.path) {
            try FileManager.default.removeItem(at: backupURL)
        }

        let destination = try DatabaseQueue(path: backupURL.path)
        try databaseQueue.backup(to: destination)
        let attributes = try FileManager.default.attributesOfItem(atPath: backupURL.path)
        return WorkspaceBackup(
            fileURL: backupURL,
            createdAt: now,
            sizeBytes: (attributes[.size] as? NSNumber)?.int64Value ?? 0
        )
    }

    public func restoreWorkspaceBackup(
        from backupURL: URL,
        safetyBackupDirectory: URL?,
        now: Date
    ) throws -> WorkspaceRestoreResult {
        guard let databaseURL else {
            throw WorkspaceMaintenanceError.onDiskWorkspaceRequired
        }
        guard backupURL.standardizedFileURL != databaseURL.standardizedFileURL else {
            throw WorkspaceMaintenanceError.restoreSourceIsCurrentWorkspace
        }

        try validateWorkspaceBackup(at: backupURL)
        try validateWorkspaceBackupCompatibility(at: backupURL)
        let safetyBackup = try createWorkspaceBackup(in: safetyBackupDirectory, now: now)
        let source = try DatabaseQueue(path: backupURL.path)
        try source.backup(to: databaseQueue)
        try bootstrap()
        return WorkspaceRestoreResult(
            restoredFromURL: backupURL,
            safetyBackup: safetyBackup,
            restoredAt: now
        )
    }

    public func resetWorkspace() throws -> WorkspaceResetResult {
        guard databaseURL != nil else {
            throw WorkspaceMaintenanceError.onDiskWorkspaceRequired
        }

        let preResetBackup = try createWorkspaceBackup()
        try withBootstrappedReplacementWorkspaceStore { replacementStore in
            try replacementStore.databaseQueue.backup(to: databaseQueue)
        }

        return WorkspaceResetResult(preResetBackupURL: preResetBackup.fileURL)
    }

    public func fetchMonthlyReport(referenceDate: Date) throws -> MonthlyReport {
        let interval = monthInterval(containing: referenceDate)
        let lastMonthStart = Calendar.alderwiseUTC.date(byAdding: .month, value: -1, to: interval.start) ?? interval.start
        let lastMonthInterval = DateInterval(start: lastMonthStart, end: interval.start)
        let paceRatio = monthElapsedRatio(referenceDate: referenceDate, interval: interval)
        let comparisonInterval = elapsedComparisonInterval(for: referenceDate, monthInterval: interval)
        let calendar = Calendar.alderwiseUTC
        let elapsedDay = calendar.component(.day, from: referenceDate)
        let totalDays = calendar.range(of: .day, in: .month, for: interval.start)?.count ?? 30

        return try databaseQueue.read { db in
            let currentSpend = try acceptedExpenseSpend(db: db, interval: interval)
            let lastMonthSpend = try acceptedExpenseSpend(db: db, interval: lastMonthInterval)
            let pendingReviewCount = try Int.fetchOne(
                db,
                sql: "SELECT COUNT(*) FROM review_items WHERE status = ?",
                arguments: [ReviewItemStatus.pending.rawValue]
            ) ?? 0
            let targetRows = try Row.fetchAll(
                db,
                sql: """
                SELECT
                    targets.id,
                    targets.category_id,
                    targets.category_group_id,
                    targets.monthly_limit,
                    categories.name AS category_name,
                    category_groups.name AS category_group_name
                FROM targets
                LEFT JOIN categories ON categories.id = targets.category_id
                LEFT JOIN category_groups ON category_groups.id = targets.category_group_id
                ORDER BY COALESCE(category_groups.name, categories.name) ASC, targets.id ASC
                """
            )
            let targets = try targetRows.map { row in
                try targetProgress(from: row, db: db, interval: interval, paceRatio: paceRatio)
            }
            let totalMonthlyTargetLimit = targets.reduce(Decimal.zero) { $0 + $1.monthlyLimit }
            let hasActiveTargets = targets.isEmpty == false
            let expectedPaceSpend = hasActiveTargets ? totalMonthlyTargetLimit * paceRatio : .zero
            let paceDelta = hasActiveTargets ? currentSpend - expectedPaceSpend : .zero
            let expectedDailySpend = hasActiveTargets
                ? totalMonthlyTargetLimit / Decimal(totalDays)
                : .zero
            let paceSeries = try monthlySpendSeries(
                db: db,
                interval: interval,
                elapsedDay: elapsedDay,
                expectedDailySpend: expectedDailySpend
            )
            let drivers = try spendingDrivers(
                db: db,
                currentInterval: interval,
                comparisonInterval: comparisonInterval
            )

            return MonthlyReport(
                monthStart: interval.start,
                currentMonthAcceptedSpend: currentSpend,
                lastMonthAcceptedSpend: lastMonthSpend,
                pendingReviewCount: pendingReviewCount,
                targets: targets,
                hasActiveTargets: hasActiveTargets,
                totalMonthlyTargetLimit: totalMonthlyTargetLimit,
                expectedPaceSpend: expectedPaceSpend,
                paceDelta: paceDelta,
                paceSeries: paceSeries,
                drivers: drivers,
                biggestShift: drivers.first
            )
        }
    }

    public func fetchManagedTargets(referenceDate: Date) throws -> [ManagedMonthlyTarget] {
        let interval = monthInterval(containing: referenceDate)
        let paceRatio = monthElapsedRatio(referenceDate: referenceDate, interval: interval)
        return try databaseQueue.read { db in
            try managedTargetRows(db: db).map { row in
                try managedMonthlyTarget(from: row, db: db, interval: interval, paceRatio: paceRatio)
            }
        }
    }

    public func createMonthlyTarget(_ draft: MonthlyTargetDraft, createdAt: Date) throws -> MonthlyTarget {
        let id = UUID()

        try databaseQueue.write { db in
            try validateMonthlyTargetDraft(draft, excluding: nil, db: db)
            let persistedScope = persistedTargetScope(from: draft.scope)
            try db.execute(
                sql: """
                INSERT INTO targets (id, category_id, category_group_id, monthly_limit, created_at)
                VALUES (?, ?, ?, ?, ?)
                """,
                arguments: [
                    id.uuidString,
                    persistedScope.categoryID?.uuidString,
                    persistedScope.categoryGroupID?.uuidString,
                    NSDecimalNumber(decimal: draft.monthlyLimit).doubleValue,
                    createdAt,
                ]
            )
        }

        return MonthlyTarget(
            id: id,
            scope: draft.scope,
            monthlyLimit: draft.monthlyLimit,
            createdAt: createdAt
        )
    }

    public func updateMonthlyTarget(id: UUID, _ draft: MonthlyTargetDraft) throws -> MonthlyTarget {
        try databaseQueue.write { db in
            let createdAt = try existingMonthlyTargetCreatedAt(id: id, db: db)
            try validateMonthlyTargetDraft(draft, excluding: id, db: db)
            let persistedScope = persistedTargetScope(from: draft.scope)
            try db.execute(
                sql: """
                UPDATE targets
                SET category_id = ?, category_group_id = ?, monthly_limit = ?
                WHERE id = ?
                """,
                arguments: [
                    persistedScope.categoryID?.uuidString,
                    persistedScope.categoryGroupID?.uuidString,
                    NSDecimalNumber(decimal: draft.monthlyLimit).doubleValue,
                    id.uuidString,
                ]
            )
            return MonthlyTarget(
                id: id,
                scope: draft.scope,
                monthlyLimit: draft.monthlyLimit,
                createdAt: createdAt
            )
        }
    }

    public func deleteMonthlyTarget(id: UUID) throws {
        try databaseQueue.write { db in
            guard try targetExists(id: id, db: db) else {
                throw MonthlyTargetManagementError.targetNotFound(id)
            }
            try db.execute(
                sql: "DELETE FROM targets WHERE id = ?",
                arguments: [id.uuidString]
            )
        }
    }

    public func createAccount(named: String, kind: AccountKind, institutionName: String?) throws -> Account {
        let account = Account(name: named, kind: kind, institutionName: institutionName)
        try databaseQueue.write { db in
            try db.execute(
                sql: """
                INSERT INTO accounts (id, name, kind, institution_name, created_at, archived_at)
                VALUES (?, ?, ?, ?, ?, ?)
                """,
                arguments: [
                    account.id.uuidString,
                    account.name,
                    account.kind.rawValue,
                    account.institutionName,
                    account.createdAt,
                    account.archivedAt,
                ]
            )
        }
        return account
    }

    public func updateAccount(id: UUID, named: String, kind: AccountKind, institutionName: String?) throws -> Account {
        try databaseQueue.write { db in
            let existing = try fetchAccount(id: id, db: db)
            guard let existing else {
                throw AccountManagementError.accountNotFound(id)
            }

            try db.execute(
                sql: """
                UPDATE accounts
                SET name = ?, kind = ?, institution_name = ?
                WHERE id = ?
                """,
                arguments: [named, kind.rawValue, institutionName, id.uuidString]
            )

            return Account(
                id: existing.id,
                name: named,
                kind: kind,
                institutionName: institutionName,
                createdAt: existing.createdAt,
                archivedAt: existing.archivedAt
            )
        }
    }

    public func archiveAccount(id: UUID, archivedAt: Date) throws -> Account {
        try databaseQueue.write { db in
            let existing = try fetchAccount(id: id, db: db)
            guard let existing else {
                throw AccountManagementError.accountNotFound(id)
            }

            try db.execute(
                sql: "UPDATE accounts SET archived_at = ? WHERE id = ?",
                arguments: [archivedAt, id.uuidString]
            )

            return Account(
                id: existing.id,
                name: existing.name,
                kind: existing.kind,
                institutionName: existing.institutionName,
                createdAt: existing.createdAt,
                archivedAt: archivedAt
            )
        }
    }

    public func restoreAccount(id: UUID) throws -> Account {
        try databaseQueue.write { db in
            let existing = try fetchAccount(id: id, db: db)
            guard let existing else {
                throw AccountManagementError.accountNotFound(id)
            }

            try db.execute(
                sql: "UPDATE accounts SET archived_at = NULL WHERE id = ?",
                arguments: [id.uuidString]
            )

            return Account(
                id: existing.id,
                name: existing.name,
                kind: existing.kind,
                institutionName: existing.institutionName,
                createdAt: existing.createdAt,
                archivedAt: nil
            )
        }
    }

    public func deleteAccountPermanently(id: UUID) throws {
        try databaseQueue.write { db in
            guard try fetchAccount(id: id, db: db) != nil else {
                throw AccountManagementError.accountNotFound(id)
            }
            guard try accountCanBeDeleted(id: id, db: db) else {
                throw AccountManagementError.deleteBlockedByDependencies(id)
            }
            try db.execute(
                sql: "DELETE FROM accounts WHERE id = ?",
                arguments: [id.uuidString]
            )
        }
    }

    public func createStagedImportSession(_ draft: StagedImportSessionDraft) throws -> StagedImportSession {
        let mappingJSON = try String(data: JSONEncoder().encode(draft.mapping), encoding: .utf8) ?? "{}"

        return try databaseQueue.write { db in
            try insertSourceFile(draft, db: db)
            let sourceFileID = db.lastInsertedRowID

            let insertSourceRow = try db.makeStatement(
                sql: """
                INSERT INTO source_rows (
                    source_file_id,
                    source_line_number,
                    row_hash,
                    raw_payload,
                    validation_status,
                    import_decision_kind,
                    decision_reason,
                    duplicate_transaction_id
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """
            )
            var insertedTransactionIDs: [UUID] = []
            for row in draft.rows {
                let transactionID: UUID?
                if case .imported = row.importDecision, let transaction = row.transaction {
                    transactionID = UUID()
                    insertedTransactionIDs.append(transactionID!)
                    try insertTransaction(
                        id: transactionID!,
                        accountID: draft.accountID,
                        importSessionID: nil,
                        transaction: transaction,
                        classification: row.classification,
                        db: db
                    )
                } else {
                    transactionID = nil
                }

                try insertSourceRow.execute(
                    arguments: [
                        sourceFileID,
                        row.sourceLineNumber,
                        row.rowHash,
                        row.rawPayload,
                        row.validationStatus.rawValue,
                        row.importDecision.storageKind,
                        row.importDecision.reason,
                        row.importDecision.duplicateTransactionID?.uuidString,
                    ]
                )
                let sourceRowID = db.lastInsertedRowID
                if case .flaggedLikelyDuplicate(let existingTransactionID, let reason) = row.importDecision {
                    try insertLikelyDuplicateReviewItem(
                        sourceRowID: sourceRowID,
                        existingTransactionID: existingTransactionID,
                        reason: reason,
                        createdAt: draft.importedAt,
                        db: db
                    )
                } else if case .imported = row.importDecision,
                          let classification = row.classification,
                          case .reviewRequired = classification {
                    try insertClassificationReviewItem(
                        transactionID: transactionID,
                        sourceRowID: sourceRowID,
                        decision: classification,
                        normalizedMerchantName: row.normalizedMerchantName,
                        createdAt: draft.importedAt,
                        db: db
                    )
                }
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
            if !insertedTransactionIDs.isEmpty {
                let placeholders = Array(repeating: "?", count: insertedTransactionIDs.count).joined(separator: ", ")
                var arguments = StatementArguments()
                appendArgument(sessionID, to: &arguments)
                for transactionID in insertedTransactionIDs {
                    appendArgument(transactionID.uuidString, to: &arguments)
                }
                try db.execute(
                    sql: """
                    UPDATE transactions
                    SET import_session_id = ?
                    WHERE id IN (\(placeholders))
                    """,
                    arguments: arguments
                )
            }
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

    public func fetchExistingSourceRowHashes(accountID: UUID, rowHashes: Set<String>) throws -> Set<String> {
        guard !rowHashes.isEmpty else {
            return []
        }

        return Set(try fetchExistingSourceRowHashCounts(accountID: accountID, rowHashes: rowHashes).keys)
    }

    public func fetchExistingSourceRowHashCounts(accountID: UUID, rowHashes: Set<String>) throws -> [String: Int] {
        guard !rowHashes.isEmpty else {
            return [:]
        }

        return try databaseQueue.read { db in
            let placeholders = Array(repeating: "?", count: rowHashes.count).joined(separator: ", ")
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT source_rows.row_hash, COUNT(*) AS row_count
                FROM source_rows
                JOIN source_files ON source_files.id = source_rows.source_file_id
                WHERE source_files.account_id = ?
                  AND source_rows.row_hash IN (\(placeholders))
                GROUP BY source_rows.row_hash
                """,
                arguments: StatementArguments([accountID.uuidString] + Array(rowHashes))
            )

            return Dictionary(uniqueKeysWithValues: rows.map { row in
                (row["row_hash"] as String, row["row_count"] as Int)
            })
        }
    }

    public func fetchLikelyDuplicateTransactions(
        accountID: UUID,
        candidates: [NormalizedImportCandidate]
    ) throws -> [LikelyDuplicateCandidate] {
        guard !candidates.isEmpty else {
            return []
        }

        return try databaseQueue.read { db in
            var matches: [LikelyDuplicateCandidate] = []
            for candidate in candidates {
                let existingRows = try Row.fetchAll(
                    db,
                    sql: """
                    SELECT id
                    FROM transactions
                    WHERE account_id = ?
                      AND ABS(amount - ?) < 0.000001
                      AND normalized_merchant_name = ?
                      AND transaction_date BETWEEN ? AND ?
                    ORDER BY transaction_date ASC, id ASC
                    LIMIT 1
                    """,
                    arguments: [
                        accountID.uuidString,
                        NSDecimalNumber(decimal: candidate.amount).doubleValue,
                        candidate.normalizedMerchantName,
                        Calendar.alderwiseUTC.date(byAdding: .day, value: -3, to: candidate.transactionDate) ?? candidate.transactionDate,
                        Calendar.alderwiseUTC.date(byAdding: .day, value: 3, to: candidate.transactionDate) ?? candidate.transactionDate,
                    ]
                )

                guard
                    let transactionIDText: String = existingRows.first?["id"],
                    let transactionID = UUID(uuidString: transactionIDText)
                else {
                    continue
                }

                matches.append(
                    LikelyDuplicateCandidate(
                        rowHash: candidate.rowHash,
                        existingTransactionID: transactionID,
                        reason: "Same account, amount, normalized merchant, and nearby date."
                    )
                )
            }
            return matches
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
            SELECT
                id,
                source_file_id,
                source_line_number,
                raw_payload,
                row_hash,
                validation_status,
                import_decision_kind,
                decision_reason,
                duplicate_transaction_id
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
                validationStatus: StagedSourceRowValidationStatus(rawValue: row["validation_status"]) ?? .invalid,
                importDecision: ImportRowDecision.fromStorage(
                    kind: row["import_decision_kind"],
                    reason: row["decision_reason"],
                    duplicateTransactionID: (row["duplicate_transaction_id"] as String?).flatMap(UUID.init(uuidString:))
                )
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

    private func insertSourceFile(_ draft: StagedImportSessionDraft, db: Database) throws {
        guard try accountIsImportEligible(id: draft.accountID, db: db) else {
            throw WorkspaceStoreError.accountNotImportEligible(draft.accountID)
        }

        let sourceFileColumns = try columnNames(in: "source_files", db: db)
        if sourceFileColumns.contains("filename") {
            try db.execute(
                sql: """
                INSERT INTO source_files (
                    account_id,
                    filename,
                    original_filename,
                    content_hash,
                    imported_at,
                    row_count
                )
                VALUES (?, ?, ?, ?, ?, ?)
                """,
                arguments: [
                    draft.accountID.uuidString,
                    draft.originalFilename,
                    draft.originalFilename,
                    draft.contentHash,
                    draft.importedAt,
                    draft.rows.count,
                ]
            )
        } else {
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
        }
    }

    private func insertLikelyDuplicateReviewItem(
        sourceRowID: Int64,
        existingTransactionID: UUID,
        reason: String,
        createdAt: Date,
        db: Database
    ) throws {
        let reviewItemColumns = try columnNames(in: "review_items", db: db)
        guard reviewItemColumns.contains("source_row_id"),
              reviewItemColumns.contains("duplicate_transaction_id"),
              reviewItemColumns.contains("reason")
        else {
            return
        }

        try db.execute(
            sql: """
            INSERT INTO review_items (
                id,
                transaction_id,
                source_row_id,
                duplicate_transaction_id,
                type,
                status,
                reason,
                created_at
            )
            VALUES (?, NULL, ?, ?, ?, ?, ?, ?)
            """,
            arguments: [
                UUID().uuidString,
                sourceRowID,
                existingTransactionID.uuidString,
                "likely_duplicate",
                "pending",
                reason,
                createdAt,
            ]
        )
    }

    private func insertTransaction(
        id: UUID,
        accountID: UUID,
        importSessionID: Int64?,
        transaction: StagedTransactionDraft,
        classification: TransactionClassificationDecision?,
        db: Database
    ) throws {
        let assignment = classification?.assignment
        let merchantName = assignment?.merchantName?.nilIfEmpty ?? transaction.normalizedMerchantName
        let categoryID = assignment?.categoryID
        let decisionSource = classification?.source ?? .user
        let sourceReference: String?
        let confidence: Double?
        let reviewStatus: TransactionReviewStatus
        switch classification {
        case .autoAccepted(_, _, let acceptedSourceReference, let acceptedConfidence, _):
            sourceReference = acceptedSourceReference
            confidence = acceptedConfidence
            reviewStatus = .accepted
        case .reviewRequired(_, _, let reviewSourceReference, let reviewConfidence, _):
            sourceReference = reviewSourceReference
            confidence = reviewConfidence
            reviewStatus = .pending
        case nil:
            sourceReference = nil
            confidence = nil
            reviewStatus = .pending
        }

        try db.execute(
            sql: """
            INSERT INTO transactions (
                id,
                account_id,
                import_session_id,
                category_id,
                raw_description,
                normalized_merchant_name,
                amount,
                transaction_date,
                direction,
                decision_source,
                decision_source_reference,
                confidence,
                review_status,
                duplicate_status
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            arguments: [
                id.uuidString,
                accountID.uuidString,
                importSessionID,
                categoryID?.uuidString,
                transaction.rawDescription,
                merchantName,
                NSDecimalNumber(decimal: transaction.amount).doubleValue,
                transaction.transactionDate,
                transaction.amount < 0 ? TransactionDirection.expense.rawValue : TransactionDirection.income.rawValue,
                decisionSource.rawValue,
                sourceReference,
                confidence,
                reviewStatus.rawValue,
                "none",
            ]
        )
    }

    private func insertClassificationReviewItem(
        transactionID: UUID?,
        sourceRowID: Int64,
        decision: TransactionClassificationDecision,
        normalizedMerchantName: String?,
        createdAt: Date,
        db: Database
    ) throws {
        guard case .reviewRequired(let prefill, let source, let sourceReference, let confidence, let reason) = decision else {
            return
        }

        let reviewItemColumns = try columnNames(in: "review_items", db: db)
        guard reviewItemColumns.contains("normalized_merchant_name"),
              reviewItemColumns.contains("suggested_category_id"),
              reviewItemColumns.contains("suggested_merchant_name"),
              reviewItemColumns.contains("classification_source"),
              reviewItemColumns.contains("classification_source_reference"),
              reviewItemColumns.contains("classification_confidence")
        else {
            return
        }

        try db.execute(
            sql: """
            INSERT INTO review_items (
                id,
                transaction_id,
                source_row_id,
                duplicate_transaction_id,
                type,
                status,
                reason,
                normalized_merchant_name,
                suggested_category_id,
                suggested_merchant_name,
                classification_source,
                classification_source_reference,
                classification_confidence,
                created_at
            )
            VALUES (?, ?, ?, NULL, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            arguments: [
                UUID().uuidString,
                transactionID?.uuidString,
                sourceRowID,
                ReviewItemType.lowConfidenceCategory.rawValue,
                ReviewItemStatus.pending.rawValue,
                reason,
                normalizedMerchantName,
                prefill?.categoryID.uuidString,
                prefill?.merchantName,
                source?.rawValue,
                sourceReference,
                confidence,
                createdAt,
            ]
        )
    }
}

private func stagedTransactionDraft(rawPayload: String, mappingJSON: String) throws -> StagedTransactionDraft {
    let decoder = JSONDecoder()
    let values: [String]
    do {
        values = try decoder.decode([String].self, from: Data(rawPayload.utf8))
    } catch {
        throw WorkspaceStoreError.invalidStoredReviewItem(field: "source_rows.raw_payload", value: rawPayload)
    }

    let mapping: CSVColumnMapping
    do {
        mapping = try decoder.decode(CSVColumnMapping.self, from: Data(mappingJSON.utf8))
    } catch {
        throw WorkspaceStoreError.invalidStoredMapping(error)
    }

    guard
        let transactionDate = legacyDateValue(in: values, at: mapping.dateColumnIndex),
        let rawDescription = legacyStringValue(in: values, at: mapping.descriptionColumnIndex),
        let amount = legacyAmountValue(in: values, mapping: mapping)
    else {
        throw WorkspaceStoreError.invalidStoredReviewItem(field: "source_rows.raw_payload", value: rawPayload)
    }

    return StagedTransactionDraft(
        transactionDate: transactionDate,
        rawDescription: rawDescription,
        normalizedMerchantName: MerchantNormalizer().normalize(rawDescription),
        amount: amount
    )
}

private func columnNames(in table: String, db: Database) throws -> Set<String> {
    Set(try db.columns(in: table).map(\.name))
}

private struct LedgerSQLQuery {
    var sql: String
    var arguments: StatementArguments
}

private func transactionLedgerQuery(
    filter: TransactionLedgerFilter,
    includeIDPredicate: Bool
) -> LedgerSQLQuery {
    var predicates: [String] = []
    var arguments = StatementArguments()

    let trimmedSearch = filter.searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    if !trimmedSearch.isEmpty {
        predicates.append(
            """
            (LOWER(transactions.raw_description) LIKE ?
             OR LOWER(COALESCE(transactions.normalized_merchant_name, '')) LIKE ?
             OR LOWER(COALESCE(categories.name, '')) LIKE ?)
            """
        )
        let pattern = "%\(trimmedSearch)%"
        appendArgument(pattern, to: &arguments)
        appendArgument(pattern, to: &arguments)
        appendArgument(pattern, to: &arguments)
    }

    if let startDate = filter.startDate {
        predicates.append("transactions.transaction_date >= ?")
        appendArgument(startDate, to: &arguments)
    }
    if let endDate = filter.endDate {
        predicates.append("transactions.transaction_date <= ?")
        appendArgument(endDate, to: &arguments)
    }
    if let accountID = filter.accountID {
        predicates.append("transactions.account_id = ?")
        appendArgument(accountID.uuidString, to: &arguments)
    }
    if let categoryID = filter.categoryID {
        predicates.append("transactions.category_id = ?")
        appendArgument(categoryID.uuidString, to: &arguments)
    }
    if let categoryGroupID = filter.categoryGroupID {
        predicates.append("categories.category_group_id = ?")
        appendArgument(categoryGroupID.uuidString, to: &arguments)
    }
    if let direction = filter.direction {
        predicates.append("transactions.direction = ?")
        appendArgument(direction.rawValue, to: &arguments)
    }
    if let reviewStatus = filter.reviewStatus {
        predicates.append("transactions.review_status = ?")
        appendArgument(reviewStatus.rawValue, to: &arguments)
    }
    if let importSessionID = filter.importSessionID {
        predicates.append("transactions.import_session_id = ?")
        appendArgument(importSessionID, to: &arguments)
    }
    if includeIDPredicate {
        predicates.append("transactions.id = ?")
    }

    let whereClause = predicates.isEmpty ? "" : "WHERE " + predicates.joined(separator: "\n  AND ")
    return LedgerSQLQuery(
        sql: """
        SELECT
            transactions.id,
            transactions.account_id,
            accounts.name AS account_name,
            transactions.category_id,
            categories.name AS category_name,
            transactions.raw_description,
            transactions.normalized_merchant_name,
            transactions.amount,
            transactions.transaction_date,
            transactions.posted_date,
            transactions.direction,
            transactions.review_status,
            transactions.notes,
            transactions.decision_source,
            transactions.decision_source_reference,
            transactions.confidence,
            transactions.duplicate_status,
            import_sessions.id AS import_session_id,
            source_files.original_filename,
            source_files.imported_at
        FROM transactions
        JOIN accounts ON accounts.id = transactions.account_id
        LEFT JOIN categories ON categories.id = transactions.category_id
        LEFT JOIN import_sessions ON import_sessions.id = transactions.import_session_id
        LEFT JOIN source_files ON source_files.id = import_sessions.source_file_id
        \(whereClause)
        ORDER BY transactions.transaction_date DESC, transactions.id ASC
        """,
        arguments: arguments
    )
}

private func appendArgument<Value: DatabaseValueConvertible>(
    _ value: Value,
    to arguments: inout StatementArguments
) {
    _ = arguments.append(contentsOf: StatementArguments([value]))
}

private func transactionLedgerRow(from row: Row) throws -> TransactionLedgerRow {
    let idText: String = row["id"]
    guard let id = UUID(uuidString: idText) else {
        throw WorkspaceStoreError.invalidStoredReviewItem(field: "transactions.id", value: idText)
    }

    let accountIDText: String = row["account_id"]
    guard let accountID = UUID(uuidString: accountIDText) else {
        throw WorkspaceStoreError.invalidStoredReviewItem(field: "transactions.account_id", value: accountIDText)
    }

    let categoryID: UUID?
    if let categoryIDText = row["category_id"] as String? {
        guard let parsedCategoryID = UUID(uuidString: categoryIDText) else {
            throw WorkspaceStoreError.invalidStoredReviewItem(field: "transactions.category_id", value: categoryIDText)
        }
        categoryID = parsedCategoryID
    } else {
        categoryID = nil
    }

    let directionText: String = row["direction"]
    guard let direction = TransactionDirection(rawValue: directionText) else {
        throw WorkspaceStoreError.invalidStoredReviewItem(field: "transactions.direction", value: directionText)
    }

    let reviewStatusText: String = row["review_status"]
    guard let reviewStatus = TransactionReviewStatus(rawValue: reviewStatusText) else {
        throw WorkspaceStoreError.invalidStoredReviewItem(field: "transactions.review_status", value: reviewStatusText)
    }

    let importOrigin: TransactionImportOrigin?
    if let importSessionID = row["import_session_id"] as Int64? {
        importOrigin = TransactionImportOrigin(
            id: importSessionID,
            originalFilename: row["original_filename"],
            importedAt: row["imported_at"]
        )
    } else {
        importOrigin = nil
    }

    let amountDouble: Double = row["amount"]
    let rawDescription: String = row["raw_description"]
    return TransactionLedgerRow(
        id: id,
        accountID: accountID,
        accountName: row["account_name"],
        categoryID: categoryID,
        categoryName: row["category_name"],
        rawDescription: rawDescription,
        merchantName: (row["normalized_merchant_name"] as String?) ?? rawDescription,
        amount: Decimal(amountDouble),
        transactionDate: row["transaction_date"],
        postedDate: row["posted_date"],
        direction: direction,
        reviewStatus: reviewStatus,
        importOrigin: importOrigin
    )
}

private func classificationSource(from sourceText: String?) throws -> ClassificationDecisionSource? {
    guard let sourceText else {
        return nil
    }
    guard let source = ClassificationDecisionSource(rawValue: sourceText) else {
        throw WorkspaceStoreError.invalidStoredReviewItem(field: "transactions.decision_source", value: sourceText)
    }
    return source
}

private func monthInterval(containing date: Date) -> DateInterval {
    let calendar = Calendar.alderwiseUTC
    let start = calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
    let end = calendar.date(byAdding: .month, value: 1, to: start) ?? date
    return DateInterval(start: start, end: end)
}

private func monthElapsedRatio(referenceDate: Date, interval: DateInterval) -> Decimal {
    let calendar = Calendar.alderwiseUTC
    let elapsedDay = calendar.component(.day, from: referenceDate)
    let dayRange = calendar.range(of: .day, in: .month, for: referenceDate)
    let totalDays = dayRange?.count ?? 30
    return Decimal(elapsedDay) / Decimal(totalDays)
}

private func elapsedComparisonInterval(for referenceDate: Date, monthInterval: DateInterval) -> DateInterval {
    let calendar = Calendar.alderwiseUTC
    let lastMonthStart = calendar.date(byAdding: .month, value: -1, to: monthInterval.start) ?? monthInterval.start
    let lastMonthEnd = monthInterval.start
    let day = min(
        calendar.component(.day, from: referenceDate),
        calendar.range(of: .day, in: .month, for: lastMonthStart)?.count ?? 28
    )
    let comparisonEnd = calendar.date(byAdding: .day, value: day, to: lastMonthStart) ?? lastMonthEnd
    return DateInterval(start: lastMonthStart, end: min(comparisonEnd, lastMonthEnd))
}

private func acceptedExpenseSpend(
    db: Database,
    interval: DateInterval,
    categoryID: UUID? = nil,
    categoryGroupID: UUID? = nil
) throws -> Decimal {
    var predicates = [
        "transactions.review_status = ?",
        "transactions.direction = ?",
        "transactions.amount < 0",
        "transactions.transaction_date >= ?",
        "transactions.transaction_date < ?",
    ]
    var arguments = StatementArguments()
    appendArgument(TransactionReviewStatus.accepted.rawValue, to: &arguments)
    appendArgument(TransactionDirection.expense.rawValue, to: &arguments)
    appendArgument(interval.start, to: &arguments)
    appendArgument(interval.end, to: &arguments)

    var joinClause = ""
    if let categoryID {
        predicates.append("transactions.category_id = ?")
        appendArgument(categoryID.uuidString, to: &arguments)
    }
    if let categoryGroupID {
        joinClause = "JOIN categories ON categories.id = transactions.category_id"
        predicates.append("categories.category_group_id = ?")
        appendArgument(categoryGroupID.uuidString, to: &arguments)
    }

    let sum = try Double.fetchOne(
        db,
        sql: """
        SELECT COALESCE(SUM(-transactions.amount), 0)
        FROM transactions
        \(joinClause)
        WHERE \(predicates.joined(separator: " AND "))
        """,
        arguments: arguments
    ) ?? 0
    return Decimal(sum)
}

private func monthlySpendSeries(
    db: Database,
    interval: DateInterval,
    elapsedDay: Int,
    expectedDailySpend: Decimal
) throws -> [MonthlySpendPoint] {
    guard elapsedDay > 0 else {
        return []
    }

    let rows = try Row.fetchAll(
        db,
        sql: """
        SELECT
            CAST(STRFTIME('%d', transactions.transaction_date) AS INTEGER) AS day,
            COALESCE(SUM(-transactions.amount), 0) AS spend
        FROM transactions
        WHERE transactions.review_status = ?
            AND transactions.direction = ?
            AND transactions.amount < 0
            AND transactions.transaction_date >= ?
            AND transactions.transaction_date < ?
        GROUP BY day
        ORDER BY day ASC
        """,
        arguments: [
            TransactionReviewStatus.accepted.rawValue,
            TransactionDirection.expense.rawValue,
            interval.start,
            interval.end,
        ]
    )

    let spendByDay = rows.reduce(into: [Int: Decimal]()) { partialResult, row in
        let day: Int = row["day"]
        partialResult[day] = Decimal(row["spend"] as Double)
    }

    var runningSpend = Decimal.zero
    return (1 ... elapsedDay).map { day in
        runningSpend += spendByDay[day] ?? .zero
        return MonthlySpendPoint(
            day: day,
            actualSpend: runningSpend,
            expectedSpend: expectedDailySpend * Decimal(day)
        )
    }
}

private func spendingDrivers(
    db: Database,
    currentInterval: DateInterval,
    comparisonInterval: DateInterval
) throws -> [MonthlySpendingDriver] {
    let currentRows = try Row.fetchAll(
        db,
        sql: """
        SELECT
            categories.id AS category_id,
            categories.name AS category_name,
            category_groups.id AS category_group_id,
            category_groups.name AS category_group_name,
            COALESCE(SUM(-transactions.amount), 0) AS spend
        FROM transactions
        JOIN categories ON categories.id = transactions.category_id
        LEFT JOIN category_groups ON category_groups.id = categories.category_group_id
        WHERE transactions.review_status = ?
            AND transactions.direction = ?
            AND transactions.amount < 0
            AND transactions.transaction_date >= ?
            AND transactions.transaction_date < ?
        GROUP BY
            categories.id,
            categories.name,
            category_groups.id,
            category_groups.name
        """,
        arguments: [
            TransactionReviewStatus.accepted.rawValue,
            TransactionDirection.expense.rawValue,
            currentInterval.start,
            currentInterval.end,
        ]
    )
    let comparisonRows = try Row.fetchAll(
        db,
        sql: """
        SELECT
            categories.id AS category_id,
            categories.name AS category_name,
            category_groups.id AS category_group_id,
            category_groups.name AS category_group_name,
            COALESCE(SUM(-transactions.amount), 0) AS spend
        FROM transactions
        JOIN categories ON categories.id = transactions.category_id
        LEFT JOIN category_groups ON category_groups.id = categories.category_group_id
        WHERE transactions.review_status = ?
            AND transactions.direction = ?
            AND transactions.amount < 0
            AND transactions.transaction_date >= ?
            AND transactions.transaction_date < ?
        GROUP BY
            categories.id,
            categories.name,
            category_groups.id,
            category_groups.name
        """,
        arguments: [
            TransactionReviewStatus.accepted.rawValue,
            TransactionDirection.expense.rawValue,
            comparisonInterval.start,
            comparisonInterval.end,
        ]
    )

    let currentSpendByRollup = try spendingDriverBuckets(from: currentRows)
    let comparisonSpendByRollup = try spendingDriverBuckets(from: comparisonRows)
    let rollups = Set(currentSpendByRollup.keys).union(comparisonSpendByRollup.keys)

    return rollups
        .map { rollup in
            let currentPeriodSpend = currentSpendByRollup[rollup] ?? .zero
            let comparisonPeriodSpend = comparisonSpendByRollup[rollup] ?? .zero
            let delta = currentPeriodSpend - comparisonPeriodSpend
            return MonthlySpendingDriver(
                title: rollup.title,
                scope: rollup.scope,
                currentPeriodSpend: currentPeriodSpend,
                comparisonPeriodSpend: comparisonPeriodSpend,
                delta: delta
            )
        }
        .sorted(by: compareMonthlySpendingDrivers)
}

private func spendingDriverBuckets(from rows: [Row]) throws -> DriverBuckets {
    var buckets: DriverBuckets = [:]
    for row in rows {
        let rollup = try spendingDriverRollup(from: row)
        let spend = Decimal(row["spend"] as Double)
        buckets[rollup, default: .zero] += spend
    }
    return buckets
}

private func spendingDriverRollup(from row: Row) throws -> SpendingDriverRollup {
    if let categoryGroupIDText = row["category_group_id"] as String? {
        guard let categoryGroupID = UUID(uuidString: categoryGroupIDText) else {
            throw WorkspaceStoreError.invalidStoredReviewItem(field: "category_groups.id", value: categoryGroupIDText)
        }
        return SpendingDriverRollup(
            title: (row["category_group_name"] as String?) ?? "Category Group",
            scope: .categoryGroup(categoryGroupID)
        )
    }

    let categoryIDText: String = row["category_id"]
    guard let categoryID = UUID(uuidString: categoryIDText) else {
        throw WorkspaceStoreError.invalidStoredReviewItem(field: "categories.id", value: categoryIDText)
    }
    return SpendingDriverRollup(
        title: (row["category_name"] as String?) ?? "Uncategorized",
        scope: .category(categoryID)
    )
}

private func compareMonthlySpendingDrivers(_ lhs: MonthlySpendingDriver, _ rhs: MonthlySpendingDriver) -> Bool {
    let lhsMagnitude = NSDecimalNumber(decimal: lhs.delta).doubleValue.magnitude
    let rhsMagnitude = NSDecimalNumber(decimal: rhs.delta).doubleValue.magnitude
    if lhsMagnitude != rhsMagnitude {
        return lhsMagnitude > rhsMagnitude
    }
    if lhs.delta != rhs.delta {
        return lhs.delta > rhs.delta
    }
    if lhs.currentPeriodSpend != rhs.currentPeriodSpend {
        return lhs.currentPeriodSpend > rhs.currentPeriodSpend
    }
    if lhs.comparisonPeriodSpend != rhs.comparisonPeriodSpend {
        return lhs.comparisonPeriodSpend > rhs.comparisonPeriodSpend
    }
    if lhs.title != rhs.title {
        return lhs.title < rhs.title
    }
    return spendingDriverScopeSortKey(lhs.scope) < spendingDriverScopeSortKey(rhs.scope)
}

private func spendingDriverScopeSortKey(_ scope: SpendingDriverScope) -> String {
    switch scope {
    case .category(let id):
        return "category:\(id.uuidString)"
    case .categoryGroup(let id):
        return "categoryGroup:\(id.uuidString)"
    }
}

private func targetProgress(
    from row: Row,
    db: Database,
    interval: DateInterval,
    paceRatio: Decimal
) throws -> TargetProgress {
    let idText: String = row["id"]
    guard let id = UUID(uuidString: idText) else {
        throw WorkspaceStoreError.invalidStoredReviewItem(field: "targets.id", value: idText)
    }

    let monthlyLimitDouble: Double = row["monthly_limit"]
    let monthlyLimit = Decimal(monthlyLimitDouble)
    let scope: TargetScope
    let name: String
    let spent: Decimal
    let categoryIDText = row["category_id"] as String?
    let categoryGroupIDText = row["category_group_id"] as String?
    if categoryIDText != nil && categoryGroupIDText != nil {
        throw WorkspaceStoreError.invalidStoredReviewItem(field: "targets.scope", value: "MULTIPLE")
    }

    if let categoryIDText {
        guard let categoryID = UUID(uuidString: categoryIDText) else {
            throw WorkspaceStoreError.invalidStoredReviewItem(field: "targets.category_id", value: categoryIDText)
        }
        scope = .category(categoryID)
        name = (row["category_name"] as String?) ?? "Uncategorized"
        spent = try acceptedExpenseSpend(db: db, interval: interval, categoryID: categoryID)
    } else if let categoryGroupIDText {
        guard let categoryGroupID = UUID(uuidString: categoryGroupIDText) else {
            throw WorkspaceStoreError.invalidStoredReviewItem(field: "targets.category_group_id", value: categoryGroupIDText)
        }
        scope = .categoryGroup(categoryGroupID)
        name = (row["category_group_name"] as String?) ?? "Category Group"
        spent = try acceptedExpenseSpend(db: db, interval: interval, categoryGroupID: categoryGroupID)
    } else {
        throw WorkspaceStoreError.invalidStoredReviewItem(field: "targets.scope", value: "NULL")
    }

    let expectedSpend = monthlyLimit * paceRatio
    return TargetProgress(
        id: id,
        name: name,
        scope: scope,
        monthlyLimit: monthlyLimit,
        spent: spent,
        remaining: monthlyLimit - spent,
        paceDelta: spent - expectedSpend
    )
}

private func installTargetScopeWriteGuards(db: Database) throws {
    guard try db.tableExists("targets") else {
        return
    }

    let targetColumns = try columnNames(in: "targets", db: db)
    guard targetColumns.contains("category_id"),
          targetColumns.contains("category_group_id"),
          targetColumns.contains("monthly_limit")
    else {
        return
    }

    try db.execute(
        sql: """
        CREATE TRIGGER IF NOT EXISTS validate_targets_before_insert
        BEFORE INSERT ON targets
        BEGIN
            SELECT CASE
                WHEN ((NEW.category_id IS NULL AND NEW.category_group_id IS NULL)
                   OR (NEW.category_id IS NOT NULL AND NEW.category_group_id IS NOT NULL))
                THEN RAISE(ABORT, 'invalid target scope')
            END;
            SELECT CASE
                WHEN NEW.monthly_limit <= 0
                THEN RAISE(ABORT, 'invalid target limit')
            END;
            SELECT CASE
                WHEN NEW.category_id IS NOT NULL
                 AND EXISTS(
                    SELECT 1
                    FROM targets
                    WHERE category_id = NEW.category_id
                      AND category_group_id IS NULL
                )
                THEN RAISE(ABORT, 'duplicate target category scope')
            END;
            SELECT CASE
                WHEN NEW.category_id IS NOT NULL
                 AND EXISTS(
                    SELECT 1
                    FROM categories
                    WHERE categories.id = NEW.category_id
                      AND categories.category_group_id IS NOT NULL
                      AND EXISTS(
                        SELECT 1
                        FROM targets
                        WHERE targets.category_group_id = categories.category_group_id
                          AND targets.category_id IS NULL
                      )
                )
                THEN RAISE(ABORT, 'overlapping target scope')
            END;
            SELECT CASE
                WHEN NEW.category_group_id IS NOT NULL
                 AND EXISTS(
                    SELECT 1
                    FROM targets
                    WHERE category_group_id = NEW.category_group_id
                      AND category_id IS NULL
                )
                THEN RAISE(ABORT, 'duplicate target group scope')
            END;
            SELECT CASE
                WHEN NEW.category_group_id IS NOT NULL
                 AND EXISTS(
                    SELECT 1
                    FROM categories
                    JOIN targets ON targets.category_id = categories.id
                    WHERE categories.category_group_id = NEW.category_group_id
                      AND targets.category_group_id IS NULL
                )
                THEN RAISE(ABORT, 'overlapping target scope')
            END;
        END
        """
    )
    try db.execute(
        sql: """
        CREATE TRIGGER IF NOT EXISTS validate_targets_before_update
        BEFORE UPDATE ON targets
        BEGIN
            SELECT CASE
                WHEN ((NEW.category_id IS NULL AND NEW.category_group_id IS NULL)
                   OR (NEW.category_id IS NOT NULL AND NEW.category_group_id IS NOT NULL))
                THEN RAISE(ABORT, 'invalid target scope')
            END;
            SELECT CASE
                WHEN NEW.monthly_limit <= 0
                THEN RAISE(ABORT, 'invalid target limit')
            END;
            SELECT CASE
                WHEN NEW.category_id IS NOT NULL
                 AND EXISTS(
                    SELECT 1
                    FROM targets
                    WHERE category_id = NEW.category_id
                      AND category_group_id IS NULL
                      AND id != NEW.id
                )
                THEN RAISE(ABORT, 'duplicate target category scope')
            END;
            SELECT CASE
                WHEN NEW.category_id IS NOT NULL
                 AND EXISTS(
                    SELECT 1
                    FROM categories
                    WHERE categories.id = NEW.category_id
                      AND categories.category_group_id IS NOT NULL
                      AND EXISTS(
                        SELECT 1
                        FROM targets
                        WHERE targets.category_group_id = categories.category_group_id
                          AND targets.category_id IS NULL
                          AND targets.id != NEW.id
                      )
                )
                THEN RAISE(ABORT, 'overlapping target scope')
            END;
            SELECT CASE
                WHEN NEW.category_group_id IS NOT NULL
                 AND EXISTS(
                    SELECT 1
                    FROM targets
                    WHERE category_group_id = NEW.category_group_id
                      AND category_id IS NULL
                      AND id != NEW.id
                )
                THEN RAISE(ABORT, 'duplicate target group scope')
            END;
            SELECT CASE
                WHEN NEW.category_group_id IS NOT NULL
                 AND EXISTS(
                    SELECT 1
                    FROM categories
                    JOIN targets ON targets.category_id = categories.id
                    WHERE categories.category_group_id = NEW.category_group_id
                      AND targets.category_group_id IS NULL
                      AND targets.id != NEW.id
                )
                THEN RAISE(ABORT, 'overlapping target scope')
            END;
        END
        """
    )

    if try canCreateUniqueCategoryScopeIndex(db: db) {
        try db.execute(
            sql: """
            CREATE UNIQUE INDEX IF NOT EXISTS targets_unique_category_scope
            ON targets(category_id)
            WHERE category_id IS NOT NULL AND category_group_id IS NULL
            """
        )
    }
    if try canCreateUniqueCategoryGroupScopeIndex(db: db) {
        try db.execute(
            sql: """
            CREATE UNIQUE INDEX IF NOT EXISTS targets_unique_category_group_scope
            ON targets(category_group_id)
            WHERE category_group_id IS NOT NULL AND category_id IS NULL
            """
        )
    }
}

private func canCreateUniqueCategoryScopeIndex(db: Database) throws -> Bool {
    try String.fetchOne(
        db,
        sql: """
        SELECT category_id
        FROM targets
        WHERE category_id IS NOT NULL AND category_group_id IS NULL
        GROUP BY category_id
        HAVING COUNT(*) > 1
        LIMIT 1
        """
    ) == nil
}

private func canCreateUniqueCategoryGroupScopeIndex(db: Database) throws -> Bool {
    try String.fetchOne(
        db,
        sql: """
        SELECT category_group_id
        FROM targets
        WHERE category_group_id IS NOT NULL AND category_id IS NULL
        GROUP BY category_group_id
        HAVING COUNT(*) > 1
        LIMIT 1
        """
    ) == nil
}

private func seededCategoryGroupIDPreservingTargetDisjointness(
    for category: DefaultBudgetCategoryDefinition,
    db: Database
) throws -> UUID? {
    guard let row = try Row.fetchOne(
        db,
        sql: "SELECT category_group_id FROM categories WHERE id = ?",
        arguments: [category.id.uuidString]
    ) else {
        return category.groupID
    }

    let currentGroupID: UUID?
    if let currentGroupIDText = row["category_group_id"] as String? {
        guard let parsedGroupID = UUID(uuidString: currentGroupIDText) else {
            throw WorkspaceStoreError.invalidStoredReviewItem(
                field: "categories.category_group_id",
                value: currentGroupIDText
            )
        }
        currentGroupID = parsedGroupID
    } else {
        currentGroupID = nil
    }

    if currentGroupID == category.groupID {
        return currentGroupID
    }

    // Bootstrap may normalize seeded memberships, but it must not implicitly create
    // an overlap between an existing category target and an existing group target.
    if try targetExists(categoryID: category.id, excluding: nil, db: db),
       try targetExists(categoryGroupID: category.groupID, excluding: nil, db: db) {
        return currentGroupID
    }

    return category.groupID
}

private struct PersistedTargetScope {
    let categoryID: UUID?
    let categoryGroupID: UUID?
}

private func managedTargetRows(db: Database) throws -> [Row] {
    try Row.fetchAll(
        db,
        sql: """
        SELECT
            targets.id,
            targets.category_id,
            targets.category_group_id,
            targets.monthly_limit,
            targets.created_at,
            categories.name AS category_name,
            category_groups.name AS category_group_name
        FROM targets
        LEFT JOIN categories ON categories.id = targets.category_id
        LEFT JOIN category_groups ON category_groups.id = targets.category_group_id
        ORDER BY COALESCE(category_groups.name, categories.name) ASC, targets.id ASC
        """
    )
}

private func managedMonthlyTarget(
    from row: Row,
    db: Database,
    interval: DateInterval,
    paceRatio: Decimal
) throws -> ManagedMonthlyTarget {
    let progress = try targetProgress(from: row, db: db, interval: interval, paceRatio: paceRatio)
    let createdAt: Date = row["created_at"]
    return ManagedMonthlyTarget(
        id: progress.id,
        name: progress.name,
        scope: progress.scope,
        monthlyLimit: progress.monthlyLimit,
        spent: progress.spent,
        remaining: progress.remaining,
        paceDelta: progress.paceDelta,
        createdAt: createdAt
    )
}

private func validateMonthlyTargetDraft(
    _ draft: MonthlyTargetDraft,
    excluding excludedID: UUID?,
    db: Database
) throws {
    guard draft.monthlyLimit > 0 else {
        throw MonthlyTargetManagementError.invalidLimit(draft.monthlyLimit)
    }

    let persistedScope = persistedTargetScope(from: draft.scope)
    switch draft.scope {
    case .category(let categoryID):
        if try targetExists(
            categoryID: categoryID,
            excluding: excludedID,
            db: db
        ) {
            throw MonthlyTargetManagementError.conflict(.duplicateScope(.category(categoryID)))
        }

        if let categoryGroupID = try categoryGroupID(for: categoryID, db: db),
           try targetExists(
               categoryGroupID: categoryGroupID,
               excluding: excludedID,
               db: db
           ) {
            throw MonthlyTargetManagementError.conflict(
                .categoryGroupOverlap(categoryID: categoryID, categoryGroupID: categoryGroupID)
            )
        }

    case .categoryGroup(let categoryGroupID):
        if try targetExists(
            categoryGroupID: categoryGroupID,
            excluding: excludedID,
            db: db
        ) {
            throw MonthlyTargetManagementError.conflict(.duplicateScope(.categoryGroup(categoryGroupID)))
        }

        // Scope edits are allowed as long as the resulting target does not overlap another target.
        if let overlappingCategoryID = try overlappingCategoryTargetID(
            in: categoryGroupID,
            excluding: excludedID,
            db: db
        ) {
            throw MonthlyTargetManagementError.conflict(
                .categoryGroupOverlap(categoryID: overlappingCategoryID, categoryGroupID: categoryGroupID)
            )
        }
    }

    if persistedScope.categoryID == nil && persistedScope.categoryGroupID == nil {
        throw WorkspaceStoreError.invalidStoredReviewItem(field: "targets.scope", value: "NULL")
    }
}

private func persistedTargetScope(from scope: TargetScope) -> PersistedTargetScope {
    switch scope {
    case .category(let categoryID):
        PersistedTargetScope(categoryID: categoryID, categoryGroupID: nil)
    case .categoryGroup(let categoryGroupID):
        PersistedTargetScope(categoryID: nil, categoryGroupID: categoryGroupID)
    }
}

private func existingMonthlyTargetCreatedAt(id: UUID, db: Database) throws -> Date {
    guard let createdAt = try Date.fetchOne(
        db,
        sql: "SELECT created_at FROM targets WHERE id = ?",
        arguments: [id.uuidString]
    ) else {
        throw MonthlyTargetManagementError.targetNotFound(id)
    }
    return createdAt
}

private func fetchAccountRows(db: Database, sql: String, arguments: StatementArguments = StatementArguments()) throws -> [Account] {
    let rows = try Row.fetchAll(db, sql: sql, arguments: arguments)
    return rows.map(account(from:))
}

private func account(from row: Row) -> Account {
    Account(
        id: UUID(uuidString: row["id"]) ?? UUID(),
        name: row["name"],
        kind: AccountKind(rawValue: row["kind"]) ?? .checking,
        institutionName: row["institution_name"],
        createdAt: row["created_at"],
        archivedAt: row["archived_at"]
    )
}

private func fetchAccount(id: UUID, db: Database) throws -> Account? {
    guard let row = try Row.fetchOne(
        db,
        sql: """
        SELECT id, name, kind, institution_name, created_at, archived_at
        FROM accounts
        WHERE id = ?
        """,
        arguments: [id.uuidString]
    ) else {
        return nil
    }
    return account(from: row)
}

private func accountCanBeDeleted(id: UUID, db: Database) throws -> Bool {
    let accountID = id.uuidString
    let hasSourceFiles = try Bool.fetchOne(
        db,
        sql: "SELECT EXISTS(SELECT 1 FROM source_files WHERE account_id = ?)",
        arguments: [accountID]
    ) ?? false
    if hasSourceFiles {
        return false
    }

    let hasImportSessions = try Bool.fetchOne(
        db,
        sql: "SELECT EXISTS(SELECT 1 FROM import_sessions WHERE account_id = ?)",
        arguments: [accountID]
    ) ?? false
    if hasImportSessions {
        return false
    }

    let hasTransactions = try Bool.fetchOne(
        db,
        sql: "SELECT EXISTS(SELECT 1 FROM transactions WHERE account_id = ?)",
        arguments: [accountID]
    ) ?? false
    return !hasTransactions
}

private func accountIsImportEligible(id: UUID, db: Database) throws -> Bool {
    try Bool.fetchOne(
        db,
        sql: """
        SELECT EXISTS(
            SELECT 1
            FROM accounts
            WHERE id = ?
              AND archived_at IS NULL
        )
        """,
        arguments: [id.uuidString]
    ) ?? false
}

private func targetExists(id: UUID, db: Database) throws -> Bool {
    try Bool.fetchOne(
        db,
        sql: "SELECT EXISTS(SELECT 1 FROM targets WHERE id = ?)",
        arguments: [id.uuidString]
    ) ?? false
}

private func targetExists(
    categoryID: UUID,
    excluding excludedID: UUID?,
    db: Database
) throws -> Bool {
    var arguments: StatementArguments = [categoryID.uuidString]
    var exclusionClause = ""
    if let excludedID {
        exclusionClause = " AND id != ?"
        appendArgument(excludedID.uuidString, to: &arguments)
    }

    return try Bool.fetchOne(
        db,
        sql: """
        SELECT EXISTS(
            SELECT 1
            FROM targets
            WHERE category_id = ?\(exclusionClause)
        )
        """,
        arguments: arguments
    ) ?? false
}

private func targetExists(
    categoryGroupID: UUID,
    excluding excludedID: UUID?,
    db: Database
) throws -> Bool {
    var arguments: StatementArguments = [categoryGroupID.uuidString]
    var exclusionClause = ""
    if let excludedID {
        exclusionClause = " AND id != ?"
        appendArgument(excludedID.uuidString, to: &arguments)
    }

    return try Bool.fetchOne(
        db,
        sql: """
        SELECT EXISTS(
            SELECT 1
            FROM targets
            WHERE category_group_id = ?\(exclusionClause)
        )
        """,
        arguments: arguments
    ) ?? false
}

private func categoryGroupID(for categoryID: UUID, db: Database) throws -> UUID? {
    guard let categoryGroupIDText = try String.fetchOne(
        db,
        sql: "SELECT category_group_id FROM categories WHERE id = ?",
        arguments: [categoryID.uuidString]
    ) else {
        return nil
    }

    guard let categoryGroupID = UUID(uuidString: categoryGroupIDText) else {
        throw WorkspaceStoreError.invalidStoredReviewItem(
            field: "categories.category_group_id",
            value: categoryGroupIDText
        )
    }
    return categoryGroupID
}

private func overlappingCategoryTargetID(
    in categoryGroupID: UUID,
    excluding excludedID: UUID?,
    db: Database
) throws -> UUID? {
    var arguments: StatementArguments = [categoryGroupID.uuidString]
    var exclusionClause = ""
    if let excludedID {
        exclusionClause = " AND targets.id != ?"
        appendArgument(excludedID.uuidString, to: &arguments)
    }

    guard let categoryIDText = try String.fetchOne(
        db,
        sql: """
        SELECT targets.category_id
        FROM targets
        JOIN categories ON categories.id = targets.category_id
        WHERE categories.category_group_id = ?\(exclusionClause)
        ORDER BY categories.name ASC, targets.id ASC
        LIMIT 1
        """,
        arguments: arguments
    ) else {
        return nil
    }

    guard let categoryID = UUID(uuidString: categoryIDText) else {
        throw WorkspaceStoreError.invalidStoredReviewItem(field: "targets.category_id", value: categoryIDText)
    }
    return categoryID
}

private func backfillLedgerTransactionsForLegacyStagedImports(db: Database) throws {
    guard
        try db.tableExists("source_rows"),
        try db.tableExists("source_files"),
        try db.tableExists("import_sessions"),
        try db.tableExists("transactions")
    else {
        return
    }

    let sourceRowColumns = try columnNames(in: "source_rows", db: db)
    let sourceFileColumns = try columnNames(in: "source_files", db: db)
    let sessionColumns = try columnNames(in: "import_sessions", db: db)
    let transactionColumns = try columnNames(in: "transactions", db: db)
    guard
        sourceRowColumns.contains("source_file_id"),
        sourceRowColumns.contains("raw_payload"),
        sourceRowColumns.contains("validation_status"),
        sourceFileColumns.contains("account_id"),
        sessionColumns.contains("source_file_id"),
        sessionColumns.contains("mapping_json"),
        transactionColumns.contains("account_id"),
        transactionColumns.contains("import_session_id"),
        transactionColumns.contains("raw_description"),
        transactionColumns.contains("normalized_merchant_name"),
        transactionColumns.contains("amount"),
        transactionColumns.contains("transaction_date"),
        transactionColumns.contains("direction"),
        transactionColumns.contains("decision_source"),
        transactionColumns.contains("review_status"),
        transactionColumns.contains("duplicate_status")
    else {
        return
    }

    let rows = try Row.fetchAll(
        db,
        sql: """
        SELECT
            import_sessions.id AS import_session_id,
            import_sessions.mapping_json,
            source_files.account_id,
            source_rows.raw_payload
        FROM import_sessions
        JOIN source_files ON source_files.id = import_sessions.source_file_id
        JOIN source_rows ON source_rows.source_file_id = source_files.id
        WHERE source_rows.validation_status = ?
          AND NOT EXISTS (
              SELECT 1
              FROM transactions
              WHERE transactions.import_session_id = import_sessions.id
          )
        ORDER BY import_sessions.id ASC, source_rows.id ASC
        """,
        arguments: [StagedSourceRowValidationStatus.valid.rawValue]
    )

    let decoder = JSONDecoder()
    let merchantNormalizer = MerchantNormalizer()
    for row in rows {
        let mappingJSON: String = row["mapping_json"]
        let rawPayload: String = row["raw_payload"]
        guard
            let mappingData = mappingJSON.data(using: .utf8),
            let rawPayloadData = rawPayload.data(using: .utf8)
        else {
            continue
        }

        let mapping = try decoder.decode(CSVColumnMapping.self, from: mappingData)
        let values = try decoder.decode([String].self, from: rawPayloadData)
        guard
            let transactionDate = legacyDateValue(in: values, at: mapping.dateColumnIndex),
            let rawDescription = legacyStringValue(in: values, at: mapping.descriptionColumnIndex),
            let amount = legacyAmountValue(in: values, mapping: mapping)
        else {
            continue
        }

        try db.execute(
            sql: """
            INSERT INTO transactions (
                id,
                account_id,
                import_session_id,
                raw_description,
                normalized_merchant_name,
                amount,
                transaction_date,
                direction,
                decision_source,
                review_status,
                duplicate_status
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            arguments: [
                UUID().uuidString,
                row["account_id"] as String,
                row["import_session_id"] as Int64,
                rawDescription,
                merchantNormalizer.normalize(rawDescription),
                NSDecimalNumber(decimal: amount).doubleValue,
                transactionDate,
                amount < 0 ? TransactionDirection.expense.rawValue : TransactionDirection.income.rawValue,
                ClassificationDecisionSource.user.rawValue,
                TransactionReviewStatus.pending.rawValue,
                "none",
            ]
        )
    }
}

private func backupFilename(for date: Date) -> String {
    "Alderwise Backup \(backupFilenameDateFormatter.string(from: date)).sqlite"
}

private let backupFilenameDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "yyyy-MM-dd HHmmss"
    return formatter
}()

private let defaultCategoryGroups = DefaultBudgetTaxonomy.categoryGroups

private let defaultBudgetCategories = DefaultBudgetTaxonomy.categories

private func withBootstrappedReplacementWorkspaceStore<R>(
    fileManager: FileManager = .default,
    perform body: (WorkspaceStore) throws -> R
) throws -> R {
    let replacementDirectory = fileManager.temporaryDirectory
        .appending(path: "AlderwiseWorkspaceReset-\(UUID().uuidString)", directoryHint: .isDirectory)
    let replacementURL = replacementDirectory.appending(path: "workspace.sqlite")
    try fileManager.createDirectory(at: replacementDirectory, withIntermediateDirectories: true)
    defer {
        try? fileManager.removeItem(at: replacementDirectory)
    }

    let store = try WorkspaceStore.at(databaseURL: replacementURL)
    try store.bootstrap()
    return try body(store)
}

private func pruneObsoleteDefaultTaxonomy(db: Database) throws {
    let currentCategoryIDs = Set(defaultBudgetCategories.map(\.id.uuidString))
    let currentGroupIDs = Set(defaultCategoryGroups.map(\.id.uuidString))

    try pruneObsoleteDefaultCategories(currentCategoryIDs: currentCategoryIDs, db: db)
    try pruneObsoleteDefaultGroups(currentGroupIDs: currentGroupIDs, db: db)
}

private func pruneObsoleteDefaultCategories(currentCategoryIDs: Set<String>, db: Database) throws {
    let placeholders = Array(repeating: "?", count: currentCategoryIDs.count).joined(separator: ", ")
    var arguments = StatementArguments()
    currentCategoryIDs.sorted().forEach { appendArgument($0, to: &arguments) }

    try db.execute(
        sql: """
        DELETE FROM categories
        WHERE id LIKE '20000000-0000-0000-0000-000000000%'
            AND id NOT IN (\(placeholders))
            AND NOT EXISTS (
                SELECT 1 FROM transactions
                WHERE transactions.category_id = categories.id
            )
            AND NOT EXISTS (
                SELECT 1 FROM rules
                WHERE rules.category_id = categories.id
            )
            AND NOT EXISTS (
                SELECT 1 FROM targets
                WHERE targets.category_id = categories.id
            )
            AND NOT EXISTS (
                SELECT 1 FROM review_items
                WHERE review_items.suggested_category_id = categories.id
            )
        """,
        arguments: arguments
    )
}

private func pruneObsoleteDefaultGroups(currentGroupIDs: Set<String>, db: Database) throws {
    let placeholders = Array(repeating: "?", count: currentGroupIDs.count).joined(separator: ", ")
    var arguments = StatementArguments()
    currentGroupIDs.sorted().forEach { appendArgument($0, to: &arguments) }

    try db.execute(
        sql: """
        DELETE FROM category_groups
        WHERE id LIKE '10000000-0000-0000-0000-000000000%'
            AND id NOT IN (\(placeholders))
            AND NOT EXISTS (
                SELECT 1 FROM categories
                WHERE categories.category_group_id = category_groups.id
            )
            AND NOT EXISTS (
                SELECT 1 FROM targets
                WHERE targets.category_group_id = category_groups.id
            )
        """,
        arguments: arguments
    )
}

private func defaultCategoryGroupOrderSQL(column: String) -> String {
    defaultOrderSQL(ids: defaultCategoryGroups.map(\.id), column: column)
}

private func defaultBudgetCategoryOrderSQL(column: String) -> String {
    defaultOrderSQL(ids: defaultBudgetCategories.map(\.id), column: column)
}

private func defaultOrderSQL(ids: [UUID], column: String) -> String {
    let cases = ids.enumerated().map { index, id in
        "WHEN '\(id.uuidString)' THEN \(index)"
    }
    .joined(separator: " ")
    return "CASE \(column) \(cases) ELSE \(ids.count) END"
}

private func validateWorkspaceBackup(at url: URL) throws {
    let unreadableSQLiteReason = "Selected file is not a readable SQLite database."
    let requiredTables = [
        "accounts",
        "source_files",
        "source_rows",
        "import_sessions",
        "merchants",
        "categories",
        "category_groups",
        "transactions",
        "rules",
        "review_items",
        "targets",
        "decision_events",
        "review_decision_events",
        "workspace_preferences",
        "grdb_migrations",
    ]

    guard FileManager.default.fileExists(atPath: url.path) else {
        throw WorkspaceMaintenanceError.invalidRestoreCandidate(unreadableSQLiteReason)
    }

    do {
        let source = try DatabaseQueue(path: url.path)
        try source.read { db in
            let missingTables = try requiredTables.filter { table in
                !(try db.tableExists(table))
            }
            guard missingTables.isEmpty else {
                let missingTablesDescription = missingTables.joined(separator: ", ")
                throw WorkspaceMaintenanceError.invalidRestoreCandidate(
                    "Missing required Alderwise tables: \(missingTablesDescription)."
                )
            }
        }
    } catch let error as WorkspaceMaintenanceError {
        throw error
    } catch {
        throw WorkspaceMaintenanceError.invalidRestoreCandidate(unreadableSQLiteReason)
    }
}

private func validateWorkspaceBackupCompatibility(at url: URL) throws {
    let fileManager = FileManager.default
    let validationDirectory = fileManager.temporaryDirectory
        .appending(path: "AlderwiseRestoreValidation-\(UUID().uuidString)", directoryHint: .isDirectory)
    let validationURL = validationDirectory.appending(path: "candidate.sqlite")
    let incompatibilityReason = "The selected backup is not compatible with the current Alderwise workspace schema."
    defer {
        try? fileManager.removeItem(at: validationDirectory)
    }

    do {
        try fileManager.createDirectory(at: validationDirectory, withIntermediateDirectories: true)
        if fileManager.fileExists(atPath: validationURL.path) {
            try fileManager.removeItem(at: validationURL)
        }
        try fileManager.copyItem(at: url, to: validationURL)

        let validationStore = try WorkspaceStore.at(databaseURL: validationURL)
        try validationStore.bootstrap()
        _ = try validationStore.fetchSummary()
        _ = try validationStore.fetchWorkspacePreferences()
    } catch let error as WorkspaceMaintenanceError {
        throw error
    } catch {
        throw WorkspaceMaintenanceError.invalidRestoreCandidate(incompatibilityReason)
    }
}

private func legacyAmountValue(in values: [String], mapping: CSVColumnMapping) -> Decimal? {
    guard let amount = mapping.amount else {
        return nil
    }

    switch amount {
    case .singleSignedAmount(let columnIndex):
        return legacyDecimalValue(in: values, at: columnIndex)
    case .debitCredit(let debitColumnIndex, let creditColumnIndex):
        if let debit = legacyDecimalValue(in: values, at: debitColumnIndex) {
            return -debit
        }
        return legacyDecimalValue(in: values, at: creditColumnIndex)
    }
}

private func legacyDateValue(in values: [String], at columnIndex: Int?) -> Date? {
    guard let value = legacyStringValue(in: values, at: columnIndex) else {
        return nil
    }

    for formatter in legacyDateFormatters {
        if let date = formatter.date(from: value) {
            return date
        }
    }
    return nil
}

private func legacyDecimalValue(in values: [String], at columnIndex: Int) -> Decimal? {
    guard let value = legacyStringValue(in: values, at: columnIndex) else {
        return nil
    }
    return Decimal(string: value, locale: Locale(identifier: "en_US_POSIX"))
}

private func legacyStringValue(in values: [String], at columnIndex: Int?) -> String? {
    guard
        let columnIndex,
        values.indices.contains(columnIndex)
    else {
        return nil
    }

    let trimmedValue = values[columnIndex].trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmedValue.isEmpty ? nil : trimmedValue
}

private let legacyDateFormatters: [DateFormatter] = [
    makeLegacyDateFormatter("yyyy-MM-dd"),
    makeLegacyDateFormatter("MM/dd/yyyy"),
    makeLegacyDateFormatter("M/d/yyyy"),
]

private func makeLegacyDateFormatter(_ format: String) -> DateFormatter {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = format
    return formatter
}

private func requireString(_ value: String?, field: String) throws -> String {
    if let value {
        return value
    }

    throw WorkspaceStoreError.invalidStoredReviewItem(field: field, value: "NULL")
}

private func pendingReviewClassification(from row: Row) throws -> PendingReviewClassification? {
    guard let normalizedMerchantName = row["normalized_merchant_name"] as String? else {
        return nil
    }

    let categoryID: UUID?
    if let categoryIDText = row["suggested_category_id"] as String? {
        guard let parsedCategoryID = UUID(uuidString: categoryIDText) else {
            throw WorkspaceStoreError.invalidStoredReviewItem(
                field: "review_items.suggested_category_id",
                value: categoryIDText
            )
        }
        categoryID = parsedCategoryID
    } else {
        categoryID = nil
    }

    let prefill = categoryID.map {
        ClassificationAssignment(categoryID: $0, merchantName: row["suggested_merchant_name"])
    }

    let source: ClassificationDecisionSource?
    if let sourceText = row["classification_source"] as String? {
        guard let parsedSource = ClassificationDecisionSource(rawValue: sourceText) else {
            throw WorkspaceStoreError.invalidStoredReviewItem(
                field: "review_items.classification_source",
                value: sourceText
            )
        }
        source = parsedSource
    } else {
        source = nil
    }

    return PendingReviewClassification(
        normalizedMerchantName: normalizedMerchantName,
        prefill: prefill,
        source: source,
        sourceReference: row["classification_source_reference"],
        confidence: row["classification_confidence"]
    )
}

private let learnedRuleBackfillDecisionSources: [ClassificationDecisionSource] = [
    .heuristic,
    .curatedPrefill,
]

private let acceptedTransactionPromotionDecisionSources: Set<ClassificationDecisionSource> = [
    .heuristic,
    .curatedPrefill,
    .suggestion,
]

private struct LearnedRuleBackfillCandidate {
    var transactionID: String
    var reviewStatus: String
}

private func isAcceptedTransactionPromotableToUserOnEdit(
    _ decisionSource: ClassificationDecisionSource?
) -> Bool {
    guard let decisionSource else {
        return false
    }
    return acceptedTransactionPromotionDecisionSources.contains(decisionSource)
}

private enum WorkspaceStoreError: Error {
    case insertedStagedSessionNotFound(Int64)
    case learnedRuleNotFound(UUID)
    case invalidLearnedRulePattern
    case accountNotImportEligible(UUID)
    case invalidStoredAccountID(String)
    case invalidStoredMapping(Error)
    case invalidStoredReviewItem(field: String, value: String)
    case reviewItemNotFound(UUID)
    case reviewItemNotPending(UUID)
    case transactionNotFound(UUID)
    case unsupportedReviewItemType(String)
}

extension WorkspaceStoreError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .accountNotImportEligible:
            "Archived accounts can't accept new imports."
        case .invalidLearnedRulePattern:
            "Learned rules require a non-empty merchant pattern."
        case .learnedRuleNotFound(let id):
            "Learned rule \(id.uuidString) was not found."
        default:
            nil
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

private extension Calendar {
    static var alderwiseUTC: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar
    }
}

private struct SpendingDriverRollup: Hashable {
    let title: String
    let scope: SpendingDriverScope
}

private typealias DriverBuckets = [SpendingDriverRollup: Decimal]
