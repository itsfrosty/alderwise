import Domain
import Foundation
import GRDB

private let workspacePreferenceSuggestionsEnabledKey = "suggestions_enabled"
private let workspacePreferenceSeededHeuristicAutoAcceptEnabledKey = "seeded_heuristic_auto_accept_enabled"
private let workspacePreferenceDefaultTaxonomyVersionKey = "default_taxonomy_version"
private let simplifiedDefaultTaxonomyVersion = "simplified-default-taxonomy-2026-04-28"
private let simplifiedDefaultTaxonomyResetReason =
    "This workspace was created with an older default taxonomy. Back up if needed, then reset and reimport to continue with this version of Alderwise."

public final class WorkspaceStore: @unchecked Sendable, WorkspaceStoring, LearnedRuleManaging, LearnedRulePreviewReading, MerchantRecommendationEligibilityReading, StagedImportWriting, StagedImportReading, ImportDecisionReading, ImportAccountInferenceReading, ImportAccountInferenceWriting, ReviewQueueReading, ReviewQueueWriting, ReviewDecisionReading, ClassificationRuleReading, TransactionLedgerReading, TransactionLedgerWriting, ReportingReading, AnalysisReportReading, WorkspaceInsightReading, TargetManaging, WorkspaceMaintenanceManaging, WorkspacePreferencesManaging {
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
                table.column("is_hidden", .boolean).notNull().defaults(to: false)
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
        migrator.registerMigration("add-transaction-hidden-state") { db in
            try db.execute(sql: "PRAGMA foreign_keys = ON")

            guard try db.tableExists("transactions") else {
                return
            }

            let transactionColumns = try columnNames(in: "transactions", db: db)
            if !transactionColumns.contains("is_hidden") {
                try db.execute(sql: "ALTER TABLE transactions ADD COLUMN is_hidden BOOLEAN NOT NULL DEFAULT 0")
            }

            if transactionColumns.contains("review_status") {
                try db.execute(
                    sql: """
                    UPDATE transactions
                    SET review_status = ?
                    WHERE review_status = ?
                    """,
                    arguments: [
                        TransactionReviewStatus.pending.rawValue,
                        TransactionReviewStatus.rejected.rawValue,
                    ]
                )
            }
        }
        migrator.registerMigration("add-import-account-inference-evidence") { db in
            try db.execute(sql: "PRAGMA foreign_keys = ON")

            if try !db.tableExists("import_account_inference_evidence") {
                try db.create(table: "import_account_inference_evidence") { table in
                    table.column("staged_import_session_id", .integer)
                        .notNull()
                        .primaryKey()
                        .references("import_sessions", onDelete: .cascade)
                    table.column("feedback_kind", .text).notNull()
                    table.column("selected_account_id", .text)
                        .notNull()
                        .indexed()
                        .references("accounts", onDelete: .cascade)
                    table.column("losing_account_id", .text)
                        .indexed()
                        .references("accounts", onDelete: .cascade)
                    table.column("normalized_filename", .text).notNull().indexed()
                    table.column("profile", .text).notNull().indexed()
                    table.column("normalized_header_names_json", .text).notNull()
                    table.column("non_blank_column_indexes_by_row_json", .text).notNull()
                }
            }
        }

        try migrator.migrate(databaseQueue)
        try seedDefaultBudgetTaxonomyIfEligible()
    }

    public func fetchSummary() throws -> WorkspaceSummary {
        try databaseQueue.read { db in
            let accountCount = try Int.fetchOne(
                db,
                sql: "SELECT COUNT(*) FROM accounts WHERE archived_at IS NULL"
            ) ?? 0
            let transactionCount = try Int.fetchOne(
                db,
                sql: "SELECT COUNT(*) FROM transactions WHERE is_hidden = 0"
            ) ?? 0
            let hiddenTransactionCount = try Int.fetchOne(
                db,
                sql: "SELECT COUNT(*) FROM transactions WHERE is_hidden = 1"
            ) ?? 0
            let reviewCount = try Int.fetchOne(
                db,
                sql: """
                SELECT COUNT(*)
                FROM review_items
                LEFT JOIN transactions ON transactions.id = review_items.transaction_id
                WHERE review_items.status = ?
                  AND (
                    transactions.id IS NULL
                    OR transactions.is_hidden = 0
                  )
                """,
                arguments: [ReviewItemStatus.pending.rawValue]
            ) ?? 0
            let targetCount = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM targets") ?? 0

            return WorkspaceSummary(
                accountCount: accountCount,
                transactionCount: transactionCount,
                reviewCount: reviewCount,
                targetCount: targetCount,
                hiddenTransactionCount: hiddenTransactionCount
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

    private func seedDefaultBudgetTaxonomyIfEligible() throws {
        try databaseQueue.write { db in
            try db.execute(sql: "PRAGMA foreign_keys = ON")
            guard try db.tableExists("categories"),
                  try db.tableExists("category_groups"),
                  try columnNames(in: "categories", db: db).contains("category_group_id")
            else {
                return
            }

            guard try shouldSeedSimplifiedDefaultTaxonomy(db: db) else {
                return
            }

            let taxonomy = currentDefaultBudgetTaxonomy()

            for group in taxonomy.groups {
                try db.execute(
                    sql: """
                    INSERT INTO category_groups (id, name)
                    VALUES (?, ?)
                    ON CONFLICT(id) DO UPDATE SET name = excluded.name
                    """,
                    arguments: [group.id.uuidString, group.name]
                )
            }

            for category in taxonomy.categories {
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

            try pruneObsoleteDefaultTaxonomy(taxonomy: taxonomy, db: db)
            try writeSimplifiedDefaultTaxonomyVersion(db: db)
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
                    OR (
                        transactions.review_status = ?
                        AND transactions.is_hidden = 0
                    )
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

    public func fetchMerchantRecommendationEligibility(
        normalizedMerchantName: String
    ) throws -> MerchantRecommendationEligibility? {
        guard let normalizedMerchantName = LearnedRuleMatcher.normalizedPattern(normalizedMerchantName) else {
            return nil
        }

        return try databaseQueue.read { db in
            guard try hasActiveLearnedRuleMatchingMerchant(
                db: db,
                normalizedMerchantName: normalizedMerchantName
            ) == false else {
                return nil
            }

            let rows = try Row.fetchAll(
                db,
                sql: """
                WITH approved_decisions AS (
                    SELECT
                        transactions.category_id AS category_id,
                        CASE
                            WHEN source_rows.source_file_id IS NOT NULL THEN
                                CAST(source_rows.source_file_id AS TEXT) || ':' || source_rows.row_hash
                            ELSE CAST(source_rows.id AS TEXT)
                        END AS decision_key
                    FROM review_decision_events
                    JOIN review_items
                        ON review_items.id = review_decision_events.review_item_id
                    JOIN transactions
                        ON transactions.id = review_items.transaction_id
                    JOIN source_rows
                        ON source_rows.id = review_decision_events.source_row_id
                    WHERE review_decision_events.action = ?
                      AND review_items.type = ?
                      AND review_items.normalized_merchant_name = ?
                      AND transactions.review_status = ?
                      AND transactions.decision_source = ?
                      AND transactions.is_hidden = 0
                      AND transactions.category_id IS NOT NULL
                ),
                distinct_approved_decisions AS (
                    SELECT category_id, decision_key
                    FROM approved_decisions
                    GROUP BY category_id, decision_key
                )
                SELECT category_id, COUNT(*) AS approval_count
                FROM distinct_approved_decisions
                GROUP BY category_id
                ORDER BY approval_count DESC, category_id ASC
                """,
                arguments: [
                    ReviewDecisionAction.approveSuggestion.rawValue,
                    ReviewItemType.lowConfidenceCategory.rawValue,
                    normalizedMerchantName,
                    TransactionReviewStatus.accepted.rawValue,
                    ClassificationDecisionSource.user.rawValue,
                ]
            )

            guard rows.count == 1,
                  let categoryIDText = rows[0]["category_id"] as String?,
                  let categoryID = UUID(uuidString: categoryIDText)
            else {
                return nil
            }

            let approvalCount: Int = rows[0]["approval_count"]
            guard approvalCount >= 3 else {
                return nil
            }

            return MerchantRecommendationEligibility(
                normalizedMerchantName: normalizedMerchantName,
                categoryID: categoryID,
                approvedDecisionCount: approvalCount
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
            guard let categoryID = draft.categoryID else {
                throw WorkspaceStoreError.invalidLearnedRuleCategory
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
                    categoryID.uuidString,
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

    private func hasActiveLearnedRuleMatchingMerchant(
        db: Database,
        normalizedMerchantName: String
    ) throws -> Bool {
        let rows = try Row.fetchAll(
            db,
            sql: """
            SELECT rules.pattern, rules.match_kind
            FROM rules
            JOIN categories ON categories.id = rules.category_id
            WHERE rules.disabled_at IS NULL
            """
        )

        return try rows.contains { row in
            let matchKindRawValue: String = row["match_kind"]
            guard let matchKind = ClassificationRuleMatchKind(rawValue: matchKindRawValue) else {
                throw WorkspaceStoreError.invalidStoredReviewItem(
                    field: "rules.match_kind",
                    value: matchKindRawValue
                )
            }

            return LearnedRuleMatcher.matches(
                merchantPattern: row["pattern"],
                matchKind: matchKind,
                candidate: LearnedRuleMatchCandidate(
                    normalizedMerchantName: normalizedMerchantName,
                    rawDescription: normalizedMerchantName
                )
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
            var query = transactionLedgerQuery(
                filter: TransactionLedgerFilter(visibility: .all),
                includeIDPredicate: true
            )
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

    public func setTransactionHidden(id: UUID, isHidden: Bool) throws {
        try databaseQueue.write { db in
            try db.execute(
                sql: """
                UPDATE transactions
                SET is_hidden = ?
                WHERE id = ?
                """,
                arguments: [isHidden, id.uuidString]
            )

            if db.changesCount == 0 {
                throw WorkspaceStoreError.transactionNotFound(id)
            }
        }
    }

    public func fetchWorkspaceMetadata() throws -> WorkspaceMetadata {
        guard let databaseURL else {
            throw WorkspaceMaintenanceError.onDiskWorkspaceRequired
        }

        let attributes = try? FileManager.default.attributesOfItem(atPath: databaseURL.path)
        let requiresReset = try databaseQueue.read { db in
            try workspaceRequiresSimplifiedDefaultTaxonomyReset(db: db)
        }
        return WorkspaceMetadata(
            databaseURL: databaseURL,
            databaseExists: FileManager.default.fileExists(atPath: databaseURL.path),
            databaseSizeBytes: (attributes?[.size] as? NSNumber)?.int64Value ?? 0,
            modifiedAt: attributes?[.modificationDate] as? Date,
            requiresReset: requiresReset,
            resetReason: requiresReset ? simplifiedDefaultTaxonomyResetReason : nil
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
            let currentSpend = try includedVisibleExpenseSpend(db: db, interval: interval)
            let lastMonthSpend = try includedVisibleExpenseSpend(db: db, interval: lastMonthInterval)
            let pendingReviewCount = try Int.fetchOne(
                db,
                sql: """
                SELECT COUNT(*)
                FROM review_items
                LEFT JOIN transactions ON transactions.id = review_items.transaction_id
                WHERE review_items.status = ?
                  AND (
                    transactions.id IS NULL
                    OR transactions.is_hidden = 0
                  )
                """,
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
                expenseBasis: .includedVisibleExpenses,
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

    public func fetchWorkspaceInsightSummary(referenceDate: Date) throws -> WorkspaceInsightSummary {
        let cappedReferenceDate = Calendar.alderwiseUTC.startOfDay(for: referenceDate)
        let facts = try fetchWorkspaceInsightFacts(referenceDate: cappedReferenceDate)
        let recurringCandidates = recurringInsightCandidates(
            from: facts.recurringObservations,
            referenceDate: cappedReferenceDate
        ).map(workspaceInsightCandidate(from:))
        let driverCandidates = spendDriverChangeCandidates(
            from: facts.monthlyReport,
            referenceDate: cappedReferenceDate
        )
        let rankedInsights = WorkspaceInsightRanker.rankPhase1(recurringCandidates + driverCandidates)
        return WorkspaceInsightSummary(
            insights: rankedInsights,
            homeProjectedInsights: WorkspaceInsightProjectionPolicy.projectHome(from: rankedInsights)
        )
    }

    public func fetchOverviewReport(context: AnalysisContext) throws -> OverviewReport {
        let resolvedContext = resolvedAnalysisContext(from: context)
        let resolution = resolvedAnalysisInterval(from: resolvedContext)

        return try databaseQueue.read { db in
            OverviewReport(
                context: resolvedContext,
                currentSpend: try analysisExpenseSpend(
                    db: db,
                    interval: resolution.currentInterval,
                    context: resolvedContext
                ),
                comparisonSpend: try analysisComparisonSpend(
                    db: db,
                    comparison: resolution.comparison,
                    context: resolvedContext
                ),
                drivers: try analysisSpendRows(
                    db: db,
                    currentInterval: resolution.currentInterval,
                    comparison: resolution.comparison,
                    grouping: .categoryDrivers,
                    context: resolvedContext
                ),
                recurring: []
            )
        }
    }

    public func fetchCategoryAnalysisReport(context: AnalysisContext) throws -> CategoryAnalysisReport {
        let resolvedContext = resolvedAnalysisContext(from: context)
        let resolution = resolvedAnalysisInterval(from: resolvedContext)

        return try databaseQueue.read { db in
            CategoryAnalysisReport(
                context: resolvedContext,
                rows: try analysisSpendRows(
                    db: db,
                    currentInterval: resolution.currentInterval,
                    comparison: resolution.comparison,
                    grouping: .categoryDrivers,
                    context: resolvedContext
                )
            )
        }
    }

    public func fetchMerchantAnalysisReport(context: AnalysisContext) throws -> MerchantAnalysisReport {
        let resolvedContext = resolvedAnalysisContext(from: context)
        let resolution = resolvedAnalysisInterval(from: resolvedContext)

        return try databaseQueue.read { db in
            MerchantAnalysisReport(
                context: resolvedContext,
                merchants: try merchantAnalysisRows(
                    db: db,
                    currentInterval: resolution.currentInterval,
                    comparison: resolution.comparison,
                    context: resolvedContext
                ),
                recurring: []
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

    public func fetchImportAccountInferenceEvidence(
        for query: ImportAccountInferenceEvidenceQuery
    ) throws -> [UUID: ImportAccountInferenceAccountEvidence] {
        let normalizedFilename = normalizedInferenceFilename(query.originalFilename)
        let normalizedHeaderNamesJSON = try makeInferenceJSON(query.normalizedHeaderNames)
        let nonBlankColumnIndexesJSON = try makeInferenceJSON(query.nonBlankColumnIndexesByRow)

        return try databaseQueue.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT selected_account_id, losing_account_id
                FROM import_account_inference_evidence
                WHERE normalized_filename = ?
                  AND profile = ?
                  AND normalized_header_names_json = ?
                  AND non_blank_column_indexes_by_row_json = ?
                """,
                arguments: [
                    normalizedFilename,
                    query.profile.rawValue,
                    normalizedHeaderNamesJSON,
                    nonBlankColumnIndexesJSON,
                ]
            )

            var evidenceByAccountID: [UUID: ImportAccountInferenceAccountEvidence] = [:]
            for row in rows {
                let selectedAccountIDText: String = row["selected_account_id"]
                guard let selectedAccountID = UUID(uuidString: selectedAccountIDText) else {
                    throw WorkspaceStoreError.invalidStoredAccountID(selectedAccountIDText)
                }

                var selectedEvidence = evidenceByAccountID[selectedAccountID] ?? ImportAccountInferenceAccountEvidence()
                selectedEvidence.positiveMatchCount += 1
                evidenceByAccountID[selectedAccountID] = selectedEvidence

                if let losingAccountIDText: String = row["losing_account_id"] {
                    guard let losingAccountID = UUID(uuidString: losingAccountIDText) else {
                        throw WorkspaceStoreError.invalidStoredAccountID(losingAccountIDText)
                    }

                    var losingEvidence = evidenceByAccountID[losingAccountID] ?? ImportAccountInferenceAccountEvidence()
                    losingEvidence.overrideCount += 1
                    evidenceByAccountID[losingAccountID] = losingEvidence
                }
            }

            return evidenceByAccountID
        }
    }

    public func fetchBootstrapImportAccountInferenceEvidence(
        for query: ImportAccountInferenceEvidenceQuery
    ) throws -> [UUID: Int] {
        guard let bootstrapMapping = query.bootstrapMapping else {
            return [:]
        }

        let normalizedFilename = normalizedInferenceFilename(query.originalFilename)

        return try databaseQueue.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT
                    import_sessions.id AS import_session_id,
                    import_sessions.account_id,
                    source_files.original_filename,
                    import_sessions.mapping_json,
                    source_rows.raw_payload
                FROM import_sessions
                JOIN source_files ON source_files.id = import_sessions.source_file_id
                JOIN source_rows ON source_rows.source_file_id = source_files.id
                LEFT JOIN import_account_inference_evidence
                    ON import_account_inference_evidence.staged_import_session_id = import_sessions.id
                WHERE import_account_inference_evidence.staged_import_session_id IS NULL
                ORDER BY import_sessions.id ASC, source_rows.id ASC
                """
            )

            var countsByAccountID: [UUID: Int] = [:]
            var sessionRowsByID: [Int64: [Row]] = [:]
            for row in rows {
                let sessionID: Int64 = row["import_session_id"]
                sessionRowsByID[sessionID, default: []].append(row)
            }

            for rows in sessionRowsByID.values {
                guard let row = rows.first else {
                    continue
                }

                let accountIDText: String = row["account_id"]
                guard let accountID = UUID(uuidString: accountIDText) else {
                    throw WorkspaceStoreError.invalidStoredAccountID(accountIDText)
                }

                let originalFilename: String = row["original_filename"]
                guard normalizedInferenceFilename(originalFilename) == normalizedFilename else {
                    continue
                }

                let mappingJSON: String = row["mapping_json"]
                let storedMapping: CSVColumnMapping
                do {
                    storedMapping = try JSONDecoder().decode(CSVColumnMapping.self, from: Data(mappingJSON.utf8))
                } catch {
                    throw WorkspaceStoreError.invalidStoredMapping(error)
                }

                let rowShapeSummary = try inferenceRowShapeSummary(for: rows)
                guard rowShapeSummary == query.nonBlankColumnIndexesByRow else {
                    continue
                }

                if storedMapping.isEmptyInferenceBootstrapMapping {
                    guard query.profile == .generic else {
                        continue
                    }
                } else {
                    guard storedMapping.profile == query.profile else {
                        continue
                    }

                    guard storedMapping.canBootstrapInferenceEvidence(for: bootstrapMapping) else {
                        continue
                    }
                }

                countsByAccountID[accountID, default: 0] += 1
            }

            return countsByAccountID
        }
    }

    public func recordImportAccountInferenceFeedback(
        for query: ImportAccountInferenceEvidenceQuery,
        stagedImportSessionID: Int64?,
        selectedAccountID: UUID,
        suggestedAccountID: UUID?
    ) throws {
        try databaseQueue.write { db in
            try recordImportAccountInferenceFeedback(
                for: query,
                stagedImportSessionID: stagedImportSessionID,
                selectedAccountID: selectedAccountID,
                suggestedAccountID: suggestedAccountID,
                db: db
            )
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

    func recordImportAccountInferenceFeedback(
        for query: ImportAccountInferenceEvidenceQuery,
        stagedImportSessionID: Int64?,
        selectedAccountID: UUID,
        suggestedAccountID: UUID?,
        db: Database
    ) throws {
        guard let stagedImportSessionID else {
            return
        }

        let normalizedFilename = normalizedInferenceFilename(query.originalFilename)
        let normalizedHeaderNamesJSON = try makeInferenceJSON(query.normalizedHeaderNames)
        let nonBlankColumnIndexesJSON = try makeInferenceJSON(query.nonBlankColumnIndexesByRow)
        let losingAccountID = suggestedAccountID == selectedAccountID ? nil : suggestedAccountID

        try db.execute(
            sql: """
            INSERT INTO import_account_inference_evidence (
                staged_import_session_id,
                feedback_kind,
                selected_account_id,
                losing_account_id,
                normalized_filename,
                profile,
                normalized_header_names_json,
                non_blank_column_indexes_by_row_json
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(staged_import_session_id) DO UPDATE SET
                feedback_kind = excluded.feedback_kind,
                selected_account_id = excluded.selected_account_id,
                losing_account_id = excluded.losing_account_id,
                normalized_filename = excluded.normalized_filename,
                profile = excluded.profile,
                normalized_header_names_json = excluded.normalized_header_names_json,
                non_blank_column_indexes_by_row_json = excluded.non_blank_column_indexes_by_row_json
            """,
            arguments: [
                stagedImportSessionID,
                inferenceFeedbackKind(
                    selectedAccountID: selectedAccountID,
                    suggestedAccountID: suggestedAccountID
                ),
                selectedAccountID.uuidString,
                losingAccountID?.uuidString,
                normalizedFilename,
                query.profile.rawValue,
                normalizedHeaderNamesJSON,
                nonBlankColumnIndexesJSON,
            ]
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
        let amount = legacyAmountValue(in: values, mapping: mapping),
        let semantics = mapping.profile.semantics(for: values, mapping: mapping)
    else {
        throw WorkspaceStoreError.invalidStoredReviewItem(field: "source_rows.raw_payload", value: rawPayload)
    }

    return StagedTransactionDraft(
        transactionDate: transactionDate,
        rawDescription: semantics.rawDescription,
        normalizedMerchantName: MerchantNormalizer().normalize(semantics.derivedMerchant),
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
    if let normalizedMerchantName = filter.normalizedMerchantName?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
       !normalizedMerchantName.isEmpty {
        predicates.append("LOWER(COALESCE(transactions.normalized_merchant_name, '')) = ?")
        appendArgument(normalizedMerchantName, to: &arguments)
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
    if filter.uncategorizedOnly {
        predicates.append("transactions.category_id IS NULL")
    }
    if let direction = filter.direction {
        predicates.append("transactions.direction = ?")
        appendArgument(direction.rawValue, to: &arguments)
    }
    if let reviewStatuses = filter.reviewStatuses, reviewStatuses.isEmpty == false {
        let placeholders = Array(repeating: "?", count: reviewStatuses.count).joined(separator: ", ")
        predicates.append("transactions.review_status IN (\(placeholders))")
        for reviewStatus in reviewStatuses.sorted(by: { $0.rawValue < $1.rawValue }) {
            appendArgument(reviewStatus.rawValue, to: &arguments)
        }
    } else if let reviewStatus = filter.reviewStatus {
        predicates.append("transactions.review_status = ?")
        appendArgument(reviewStatus.rawValue, to: &arguments)
    }
    switch filter.visibility ?? .active {
    case .active:
        predicates.append("transactions.is_hidden = 0")
    case .hidden:
        predicates.append("transactions.is_hidden = 1")
    case .all:
        break
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
            transactions.is_hidden,
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
        isHidden: row["is_hidden"],
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

private func recurringInsightObservation(from row: Row) throws -> RecurringInsightObservation {
    let idText: String = row["id"]
    guard let id = UUID(uuidString: idText) else {
        throw WorkspaceStoreError.invalidStoredReviewItem(field: "transactions.id", value: idText)
    }

    let accountIDText: String = row["account_id"]
    guard let accountID = UUID(uuidString: accountIDText) else {
        throw WorkspaceStoreError.invalidStoredReviewItem(field: "transactions.account_id", value: accountIDText)
    }

    let rawDescription: String = row["raw_description"]
    let normalizedMerchantName = ((row["normalized_merchant_name"] as String?)?.nilIfEmpty)
        ?? MerchantNormalizer().normalize(rawDescription)
    let amount = Decimal(abs(row["amount"] as Double))

    return RecurringInsightObservation(
        transactionID: id,
        accountID: accountID,
        normalizedMerchantName: normalizedMerchantName,
        rawDescription: rawDescription,
        amount: amount,
        transactionDate: row["transaction_date"]
    )
}

private func recurringInsightCandidates(
    from observations: [RecurringInsightObservation],
    referenceDate: Date
) -> [RecurringInsightCandidate] {
    let groups = Dictionary(grouping: observations) { observation in
        RecurringInsightGroupKey(
            accountID: observation.accountID,
            normalizedMerchantName: observation.normalizedMerchantName
        )
    }

    return groups.values
        .compactMap { recurringInsightCandidate(from: $0, referenceDate: referenceDate) }
        .sorted(by: compareRecurringInsightCandidates)
}

private func workspaceInsightCandidate(
    from candidate: RecurringInsightCandidate
) -> WorkspaceInsightCandidate {
    let detail = candidate.detail
    let interval = DateInterval(
        start: Calendar.alderwiseUTC.startOfDay(for: detail.firstObservedDate ?? detail.lastObservedDate),
        end: Calendar.alderwiseUTC.date(
            byAdding: DateComponents(day: 1),
            to: Calendar.alderwiseUTC.startOfDay(for: detail.lastObservedDate)
        ) ?? detail.lastObservedDate
    )
    let merchantName = detail.normalizedMerchantName
    return WorkspaceInsightCandidate(
        kind: .recurringCharge(detail),
        confidence: candidate.confidence,
        score: candidate.score,
        suppressionKey: recurringSuppressionKey(detail: detail),
        evidence: InsightEvidence(
            metricBasis: .includedVisibleExpenses,
            resolvedInterval: interval,
            scope: .merchant(merchantName),
            reconciliationRule: .recurringObservationSet,
            destination: InsightEvidenceDestination(scope: .merchant(merchantName), direction: .expense)
        ),
        tieBreaker: WorkspaceInsightTieBreaker(
            primaryDate: detail.lastObservedDate,
            secondaryKey: String(format: "%05d:%@", 99_999 - detail.observationCount, merchantName),
            tertiaryKey: detail.accountID.uuidString
        )
    )
}

private func spendDriverChangeCandidates(
    from monthlyReport: MonthlyReport,
    referenceDate: Date
) -> [WorkspaceInsightCandidate] {
    guard let driver = monthlyReport.drivers.first(where: { $0.delta >= Decimal(50) }) else {
        return []
    }

    let monthInterval = monthInterval(containing: referenceDate)
    let detail = SpendDriverChangeInsightDetail(
        title: driver.title,
        scope: driver.scope,
        currentSpend: driver.currentPeriodSpend,
        comparisonSpend: driver.comparisonPeriodSpend,
        delta: driver.delta
    )

    return [
        WorkspaceInsightCandidate(
            kind: .spendDriverChange(detail),
            confidence: 1,
            score: min(70 + (decimalDouble(driver.delta) / 2), 125),
            suppressionKey: spendDriverSuppressionKey(for: driver.scope),
            evidence: InsightEvidence(
                metricBasis: .includedVisibleExpenses,
                resolvedInterval: monthInterval,
                scope: insightEvidenceScope(for: driver.scope),
                reconciliationRule: .exactTransactionSum,
                destination: InsightEvidenceDestination(
                    scope: insightEvidenceScope(for: driver.scope),
                    direction: .expense
                )
            ),
            tieBreaker: WorkspaceInsightTieBreaker(
                primaryDate: referenceDate,
                secondaryKey: driver.title,
                tertiaryKey: spendDriverStableIdentifier(for: driver.scope)
            )
        ),
    ]
}

private func recurringInsightCandidate(
    from observations: [RecurringInsightObservation],
    referenceDate: Date
) -> RecurringInsightCandidate? {
    let sortedObservations = observations.sorted {
        if $0.transactionDate != $1.transactionDate {
            return $0.transactionDate < $1.transactionDate
        }
        return $0.transactionID.uuidString < $1.transactionID.uuidString
    }
    guard sortedObservations.count >= 3 else {
        return nil
    }

    let merchantName = sortedObservations[0].normalizedMerchantName
    guard recurringMerchantLooksInstallmentLike(merchantName) == false else {
        return nil
    }

    let intervals = zip(sortedObservations, sortedObservations.dropFirst()).map {
        recurringDayDelta(from: $0.transactionDate, to: $1.transactionDate)
    }
    let cadenceMatches = intervals.compactMap(recurringChargeCadence(forIntervalDays:))
    guard cadenceMatches.count >= 2 else {
        return nil
    }

    let cadenceCounts = Dictionary(cadenceMatches.map { ($0, 1) }, uniquingKeysWith: +)
    guard let dominantCadence = cadenceCounts.max(by: { lhs, rhs in
        if lhs.value != rhs.value {
            return lhs.value < rhs.value
        }
        return recurringCadenceSortOrder(lhs.key) > recurringCadenceSortOrder(rhs.key)
    }) else {
        return nil
    }

    let confidence = Double(dominantCadence.value) / Double(intervals.count)
    guard confidence >= 2.0 / 3.0 else {
        return nil
    }

    let supportingObservations = recurringSupportingObservations(
        from: sortedObservations,
        cadence: dominantCadence.key
    )
    guard supportingObservations.count >= 3 else {
        return nil
    }

    let lastObservedDate = supportingObservations.last?.transactionDate ?? referenceDate
    let nextExpectedDateWindow = recurringNextExpectedDateWindow(
        after: lastObservedDate,
        cadence: dominantCadence.key
    )
    guard recurringInsightIsCurrent(
        referenceDate: referenceDate,
        nextExpectedDateWindow: nextExpectedDateWindow,
        cadence: dominantCadence.key
    ) else {
        return nil
    }

    let amounts = supportingObservations.map(\.amount)
    let detail = RecurringChargeInsightDetail(
        accountID: supportingObservations[0].accountID,
        normalizedMerchantName: merchantName,
        cadence: dominantCadence.key,
        observationCount: supportingObservations.count,
        amountRange: RecurringChargeAmountRange(
            minimum: amounts.min() ?? .zero,
            maximum: amounts.max() ?? .zero
        ),
        supportingTransactionIDs: supportingObservations.map(\.transactionID),
        firstObservedDate: supportingObservations.first?.transactionDate,
        lastObservedDate: lastObservedDate,
        nextExpectedDateWindow: nextExpectedDateWindow
    )

    let amountVariancePenalty = recurringAmountVariancePenalty(
        minimum: detail.amountRange.minimum,
        maximum: detail.amountRange.maximum
    )
    let merchantNoisePenalty = recurringMerchantNoisePenalty(merchantName)
    let score = max(0, (confidence - amountVariancePenalty - merchantNoisePenalty) * 100)

    return RecurringInsightCandidate(
        detail: detail,
        confidence: confidence,
        score: score
    )
}

private func compareRecurringInsightCandidates(
    _ lhs: RecurringInsightCandidate,
    _ rhs: RecurringInsightCandidate
) -> Bool {
    if lhs.score != rhs.score {
        return lhs.score > rhs.score
    }
    if lhs.confidence != rhs.confidence {
        return lhs.confidence > rhs.confidence
    }
    if lhs.detail.lastObservedDate != rhs.detail.lastObservedDate {
        return lhs.detail.lastObservedDate > rhs.detail.lastObservedDate
    }
    if lhs.detail.observationCount != rhs.detail.observationCount {
        return lhs.detail.observationCount > rhs.detail.observationCount
    }
    if lhs.detail.normalizedMerchantName != rhs.detail.normalizedMerchantName {
        return lhs.detail.normalizedMerchantName < rhs.detail.normalizedMerchantName
    }
    return lhs.detail.accountID.uuidString < rhs.detail.accountID.uuidString
}

private func recurringChargeCadence(forIntervalDays days: Int) -> RecurringChargeCadence? {
    switch days {
    case 26 ... 38:
        .monthly
    case 80 ... 100:
        .quarterly
    case 330 ... 390:
        .annual
    default:
        nil
    }
}

private func recurringCadenceSortOrder(_ cadence: RecurringChargeCadence) -> Int {
    switch cadence {
    case .monthly:
        0
    case .quarterly:
        1
    case .annual:
        2
    }
}

private func recurringDayDelta(from start: Date, to end: Date) -> Int {
    Calendar.alderwiseUTC.dateComponents(
        [.day],
        from: Calendar.alderwiseUTC.startOfDay(for: start),
        to: Calendar.alderwiseUTC.startOfDay(for: end)
    ).day ?? 0
}

private func recurringSupportingObservations(
    from observations: [RecurringInsightObservation],
    cadence: RecurringChargeCadence
) -> [RecurringInsightObservation] {
    guard observations.count >= 3 else {
        return observations
    }

    let intervalMatches = zip(observations, observations.dropFirst()).map {
        recurringChargeCadence(forIntervalDays: recurringDayDelta(from: $0.transactionDate, to: $1.transactionDate)) == cadence
    }

    var bestRange: ClosedRange<Int>?
    var currentStart: Int?

    for (index, isMatch) in intervalMatches.enumerated() {
        if isMatch {
            if currentStart == nil {
                currentStart = index
            }
            continue
        }

        if let runStart = currentStart {
            let candidateRange = runStart ... index
            if recurringObservationRangeIsBetter(candidateRange, than: bestRange) {
                bestRange = candidateRange
            }
            currentStart = nil
        }
    }

    if let runStart = currentStart {
        let candidateRange = runStart ... intervalMatches.count
        if recurringObservationRangeIsBetter(candidateRange, than: bestRange) {
            bestRange = candidateRange
        }
    }

    guard let bestRange else {
        return observations
    }
    return Array(observations[bestRange])
}

private func recurringObservationRangeIsBetter(
    _ candidate: ClosedRange<Int>,
    than currentBest: ClosedRange<Int>?
) -> Bool {
    guard let currentBest else {
        return true
    }
    let candidateCount = candidate.count
    let currentBestCount = currentBest.count
    if candidateCount != currentBestCount {
        return candidateCount > currentBestCount
    }
    return candidate.upperBound > currentBest.upperBound
}

private func recurringNextExpectedDateWindow(
    after lastObservedDate: Date,
    cadence: RecurringChargeCadence
) -> DateInterval? {
    let calendar = Calendar.alderwiseUTC
    let (expectedDays, toleranceDays) = recurringCadenceTiming(cadence)
    guard let start = calendar.date(byAdding: .day, value: expectedDays - toleranceDays, to: lastObservedDate),
          let end = calendar.date(byAdding: .day, value: expectedDays + toleranceDays, to: lastObservedDate)
    else {
        return nil
    }
    return DateInterval(start: start, end: end)
}

private func recurringInsightIsCurrent(
    referenceDate: Date,
    nextExpectedDateWindow: DateInterval?,
    cadence: RecurringChargeCadence
) -> Bool {
    guard let nextExpectedDateWindow else {
        return false
    }
    let calendar = Calendar.alderwiseUTC
    let graceDays = recurringCadenceTiming(cadence).expectedDays
    guard let staleCutoff = calendar.date(byAdding: .day, value: graceDays, to: nextExpectedDateWindow.end) else {
        return false
    }
    return referenceDate <= staleCutoff
}

private func recurringCadenceTiming(_ cadence: RecurringChargeCadence) -> (expectedDays: Int, toleranceDays: Int) {
    switch cadence {
    case .monthly:
        (30, 7)
    case .quarterly:
        (91, 14)
    case .annual:
        (365, 30)
    }
}

private func recurringMerchantLooksInstallmentLike(_ merchantName: String) -> Bool {
    let keywords = ["affirm", "afterpay", "klarna", "sezzle", "zip pay", "quadpay", "installment"]
    return keywords.contains { merchantName.contains($0) }
}

private func recurringMerchantNoisePenalty(_ merchantName: String) -> Double {
    var penalty = 0.0
    if merchantName.rangeOfCharacter(from: .decimalDigits) != nil {
        penalty += 0.12
    }
    if merchantName.split(separator: " ").count >= 3 {
        penalty += 0.03
    }
    return penalty
}

private func recurringAmountVariancePenalty(minimum: Decimal, maximum: Decimal) -> Double {
    let spread = max(decimalDouble(maximum - minimum), 0)
    let baseline = max(decimalDouble(maximum), 0.01)
    return min(spread / baseline * 0.1, 0.08)
}

private func decimalDouble(_ value: Decimal) -> Double {
    NSDecimalNumber(decimal: value).doubleValue
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

private enum AnalysisSpendGrouping {
    case categoryDrivers
}

private func resolvedAnalysisContext(from context: AnalysisContext) -> AnalysisContext {
    let referenceDate = context.referenceDate ?? Date()
    let resolution = AnalysisIntervalResolver.resolve(
        range: context.range,
        comparison: context.comparison,
        referenceDate: referenceDate
    )

    var resolvedContext = context
    resolvedContext.referenceDate = referenceDate
    resolvedContext.resolvedInterval = resolution.currentInterval
    return resolvedContext
}

private func resolvedAnalysisInterval(from context: AnalysisContext) -> AnalysisIntervalResolution {
    AnalysisIntervalResolver.resolve(
        range: context.range,
        comparison: context.comparison,
        referenceDate: context.referenceDate ?? Date()
    )
}

private func merchantRecurringRows(from summary: WorkspaceInsightSummary) -> [MerchantRecurringReportRow] {
    return summary.insights.compactMap { insight in
        guard case .recurringCharge(let detail) = insight.kind else {
            return nil
        }
        return MerchantRecurringReportRow(detail: detail, evidence: insight.evidence)
    }
}

private func analysisExpenseSpend(
    db: Database,
    interval: DateInterval,
    context: AnalysisContext
) throws -> Decimal {
    switch context.metricBasis {
    case .includedVisibleExpenses:
        return try includedVisibleExpenseSpend(
            db: db,
            interval: interval,
            categoryID: categoryID(for: context.scope),
            categoryGroupID: categoryGroupID(for: context.scope)
        )
    case .acceptedExpenses:
        return try acceptedExpenseSpend(
            db: db,
            interval: interval,
            categoryID: categoryID(for: context.scope),
            categoryGroupID: categoryGroupID(for: context.scope)
        )
    }
}

private func analysisComparisonSpend(
    db: Database,
    comparison: AnalysisResolvedComparison,
    context: AnalysisContext
) throws -> Decimal? {
    switch comparison {
    case .none, .unsupported:
        return nil
    case .interval(let interval, _):
        return try analysisExpenseSpend(db: db, interval: interval, context: context)
    case .rollingAverage(let intervals, _):
        guard intervals.isEmpty == false else {
            return nil
        }
        let totals = try intervals.map { interval in
            try analysisExpenseSpend(db: db, interval: interval, context: context)
        }
        return totals.reduce(Decimal.zero, +) / Decimal(intervals.count)
    }
}

private func analysisSpendRows(
    db: Database,
    currentInterval: DateInterval,
    comparison: AnalysisResolvedComparison,
    grouping: AnalysisSpendGrouping,
    context: AnalysisContext
) throws -> [AnalysisSpendRow] {
    let comparisonInterval: DateInterval
    switch comparison {
    case .interval(let interval, _):
        comparisonInterval = interval
    default:
        comparisonInterval = DateInterval(start: currentInterval.start, end: currentInterval.start)
    }

    switch grouping {
    case .categoryDrivers:
        return try spendingDrivers(
            db: db,
            currentInterval: currentInterval,
            comparisonInterval: comparisonInterval
        ).map { driver in
            let scope = insightEvidenceScope(for: driver.scope)
            return AnalysisSpendRow(
                title: driver.title,
                scope: scope,
                currentSpend: driver.currentPeriodSpend,
                comparisonSpend: driver.comparisonPeriodSpend,
                delta: driver.delta,
                evidence: InsightEvidence(
                    metricBasis: context.metricBasis,
                    resolvedInterval: currentInterval,
                    scope: scope,
                    reconciliationRule: .exactTransactionSum,
                    destination: InsightEvidenceDestination(scope: scope)
                )
            )
        }
    }
}

private func merchantAnalysisRows(
    db: Database,
    currentInterval: DateInterval,
    comparison: AnalysisResolvedComparison,
    context: AnalysisContext
) throws -> [MerchantAnalysisRow] {
    let comparisonInterval: DateInterval
    switch comparison {
    case .interval(let interval, _):
        comparisonInterval = interval
    default:
        comparisonInterval = DateInterval(start: currentInterval.start, end: currentInterval.start)
    }

    let currentRows = try merchantSpendRows(db: db, interval: currentInterval, context: context)
    let comparisonRows = try merchantSpendRows(db: db, interval: comparisonInterval, context: context)
    let comparisonByMerchant = Dictionary(uniqueKeysWithValues: comparisonRows.map { ($0.key, $0.currentSpend) })
    return currentRows.map { currentRow in
        let comparisonSpend = comparisonByMerchant[currentRow.key] ?? .zero
        return MerchantAnalysisRow(
            key: currentRow.key,
            title: currentRow.title,
            currentSpend: currentRow.currentSpend,
            comparisonSpend: comparisonSpend,
            delta: currentRow.currentSpend - comparisonSpend,
            evidence: currentRow.evidence
        )
    }
}

private func merchantSpendRows(
    db: Database,
    interval: DateInterval,
    context: AnalysisContext
) throws -> [MerchantAnalysisRow] {
    let rows = try Row.fetchAll(
        db,
        sql: """
        SELECT
            LOWER(COALESCE(transactions.normalized_merchant_name, '')) AS normalized_merchant_name,
            COALESCE(SUM(-transactions.amount), 0) AS spend
        FROM transactions
        WHERE transactions.is_hidden = 0
            AND transactions.direction = ?
            AND transactions.review_status IN (?, ?)
            AND transactions.amount < 0
            AND transactions.transaction_date >= ?
            AND transactions.transaction_date < ?
            AND COALESCE(transactions.normalized_merchant_name, '') != ''
        GROUP BY normalized_merchant_name
        ORDER BY spend DESC, normalized_merchant_name ASC
        """,
        arguments: [
            TransactionDirection.expense.rawValue,
            TransactionReviewStatus.accepted.rawValue,
            TransactionReviewStatus.pending.rawValue,
            interval.start,
            interval.end,
        ]
    )

    return rows.map { row in
        let merchantName: String = row["normalized_merchant_name"]
        let spend = Decimal(row["spend"] as Double)
        let scope = InsightEvidenceScope.merchant(merchantName)
        return MerchantAnalysisRow(
            key: MerchantReportKey(normalizedName: merchantName),
            title: merchantName,
            currentSpend: spend,
            comparisonSpend: .zero,
            delta: spend,
            evidence: InsightEvidence(
                metricBasis: context.metricBasis,
                resolvedInterval: interval,
                scope: scope,
                reconciliationRule: .exactTransactionSum,
                destination: InsightEvidenceDestination(scope: scope)
            )
        )
    }
}

private func insightEvidenceScope(for scope: SpendingDriverScope) -> InsightEvidenceScope {
    switch scope {
    case .category(let id):
        .category(id)
    case .categoryGroup(let id):
        .categoryGroup(id)
    case .uncategorized:
        .uncategorized
    }
}

private func recurringSuppressionKey(detail: RecurringChargeInsightDetail) -> String {
    "recurring:\(detail.accountID.uuidString):\(detail.normalizedMerchantName):\(detail.cadence.rawValue)"
}

private func spendDriverSuppressionKey(for scope: SpendingDriverScope) -> String {
    "driver:\(spendDriverStableIdentifier(for: scope))"
}

private func spendDriverStableIdentifier(for scope: SpendingDriverScope) -> String {
    switch scope {
    case .category(let id):
        "category:\(id.uuidString)"
    case .categoryGroup(let id):
        "category-group:\(id.uuidString)"
    case .uncategorized:
        "uncategorized"
    }
}

private func categoryID(for scope: AnalysisScope) -> UUID? {
    if case .category(let categoryID) = scope {
        return categoryID
    }
    return nil
}

private func categoryGroupID(for scope: AnalysisScope) -> UUID? {
    if case .categoryGroup(let categoryGroupID) = scope {
        return categoryGroupID
    }
    return nil
}

private func acceptedExpenseSpend(
    db: Database,
    interval: DateInterval,
    categoryID: UUID? = nil,
    categoryGroupID: UUID? = nil
) throws -> Decimal {
    var predicates = [
        "transactions.is_hidden = 0",
        "transactions.direction = ?",
        "transactions.review_status = ?",
        "transactions.amount < 0",
        "transactions.transaction_date >= ?",
        "transactions.transaction_date < ?",
    ]
    var arguments = StatementArguments()
    appendArgument(TransactionDirection.expense.rawValue, to: &arguments)
    appendArgument(TransactionReviewStatus.accepted.rawValue, to: &arguments)
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

private func includedVisibleExpenseSpend(
    db: Database,
    interval: DateInterval,
    categoryID: UUID? = nil,
    categoryGroupID: UUID? = nil
) throws -> Decimal {
    var predicates = [
        "transactions.is_hidden = 0",
        "transactions.direction = ?",
        "transactions.review_status IN (?, ?)",
        "transactions.amount < 0",
        "transactions.transaction_date >= ?",
        "transactions.transaction_date < ?",
    ]
    var arguments = StatementArguments()
    appendArgument(TransactionDirection.expense.rawValue, to: &arguments)
    appendArgument(TransactionReviewStatus.accepted.rawValue, to: &arguments)
    appendArgument(TransactionReviewStatus.pending.rawValue, to: &arguments)
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
        WHERE transactions.is_hidden = 0
            AND transactions.direction = ?
            AND transactions.review_status IN (?, ?)
            AND transactions.amount < 0
            AND transactions.transaction_date >= ?
            AND transactions.transaction_date < ?
        GROUP BY day
        ORDER BY day ASC
        """,
        arguments: [
            TransactionDirection.expense.rawValue,
            TransactionReviewStatus.accepted.rawValue,
            TransactionReviewStatus.pending.rawValue,
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
        LEFT JOIN categories ON categories.id = transactions.category_id
        LEFT JOIN category_groups ON category_groups.id = categories.category_group_id
        WHERE transactions.is_hidden = 0
            AND transactions.direction = ?
            AND transactions.review_status IN (?, ?)
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
            TransactionDirection.expense.rawValue,
            TransactionReviewStatus.accepted.rawValue,
            TransactionReviewStatus.pending.rawValue,
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
        LEFT JOIN categories ON categories.id = transactions.category_id
        LEFT JOIN category_groups ON category_groups.id = categories.category_group_id
        WHERE transactions.is_hidden = 0
            AND transactions.direction = ?
            AND transactions.review_status IN (?, ?)
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
            TransactionDirection.expense.rawValue,
            TransactionReviewStatus.accepted.rawValue,
            TransactionReviewStatus.pending.rawValue,
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
    if let categoryIDText = row["category_id"] as String? {
        guard let categoryID = UUID(uuidString: categoryIDText) else {
            throw WorkspaceStoreError.invalidStoredReviewItem(field: "categories.id", value: categoryIDText)
        }
        return SpendingDriverRollup(
            title: (row["category_name"] as String?) ?? "Uncategorized",
            scope: .category(categoryID)
        )
    }
    return SpendingDriverRollup(
        title: "Uncategorized",
        scope: .uncategorized
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
        case .uncategorized:
            return "uncategorized"
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
        spent = try includedVisibleExpenseSpend(db: db, interval: interval, categoryID: categoryID)
    } else if let categoryGroupIDText {
        guard let categoryGroupID = UUID(uuidString: categoryGroupIDText) else {
            throw WorkspaceStoreError.invalidStoredReviewItem(field: "targets.category_group_id", value: categoryGroupIDText)
        }
        scope = .categoryGroup(categoryGroupID)
        name = (row["category_group_name"] as String?) ?? "Category Group"
        spent = try includedVisibleExpenseSpend(db: db, interval: interval, categoryGroupID: categoryGroupID)
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
    if let targetGroupID = category.groupID,
       try targetExists(categoryID: category.id, excluding: nil, db: db),
       try targetExists(categoryGroupID: targetGroupID, excluding: nil, db: db) {
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
    let history = try targetHistorySummary(
        scope: progress.scope,
        monthlyLimit: progress.monthlyLimit,
        createdAt: createdAt,
        currentMonthStart: interval.start,
        db: db
    )
    return ManagedMonthlyTarget(
        id: progress.id,
        name: progress.name,
        scope: progress.scope,
        monthlyLimit: progress.monthlyLimit,
        spent: progress.spent,
        remaining: progress.remaining,
        paceDelta: progress.paceDelta,
        history: history,
        calibrationSuggestion: targetCalibrationSuggestion(
            monthlyLimit: progress.monthlyLimit,
            history: history
        ),
        createdAt: createdAt
    )
}

private func targetHistorySummary(
    scope: TargetScope,
    monthlyLimit: Decimal,
    createdAt: Date,
    currentMonthStart: Date,
    db: Database
) throws -> TargetHistorySummary {
    let calendar = Calendar.alderwiseUTC
    let createdMonthInterval = monthInterval(containing: createdAt)
    let firstFullHistoryMonthStart: Date
    if createdAt == createdMonthInterval.start {
        firstFullHistoryMonthStart = createdMonthInterval.start
    } else {
        firstFullHistoryMonthStart = calendar.date(byAdding: .month, value: 1, to: createdMonthInterval.start)
            ?? createdMonthInterval.end
    }
    var monthStart = calendar.date(byAdding: .month, value: -1, to: currentMonthStart)
    var months: [TargetHistoryMonth] = []

    while let historyMonthStart = monthStart, months.count < 6 {
        guard historyMonthStart >= firstFullHistoryMonthStart else {
            break
        }

        let interval = monthInterval(containing: historyMonthStart)
        let spent = try targetScopeSpend(db: db, interval: interval, scope: scope)
        months.append(
            TargetHistoryMonth(
                monthStart: interval.start,
                spent: spent,
                monthlyLimit: monthlyLimit
            )
        )
        if let previousMonth = calendar.date(byAdding: .month, value: -1, to: historyMonthStart) {
            monthStart = previousMonth
        } else {
            break
        }
    }

    let orderedMonths = months.reversed()
    guard orderedMonths.isEmpty == false else {
        return .empty
    }

    let totalCount = Decimal(orderedMonths.count)
    let hitCount = Decimal(orderedMonths.filter(\.hit).count)
    let overshootMonths = orderedMonths.filter { $0.overshoot > .zero }
    let overshootCount = Decimal(overshootMonths.count)
    let averageSpend = orderedMonths.reduce(.zero) { $0 + $1.spent } / totalCount
    let averageOvershoot: Decimal
    if overshootMonths.isEmpty {
        averageOvershoot = .zero
    } else {
        averageOvershoot = overshootMonths.reduce(.zero) { $0 + $1.overshoot } / Decimal(overshootMonths.count)
    }

    return TargetHistorySummary(
        months: Array(orderedMonths),
        hitRate: hitCount / totalCount,
        overshootRate: overshootCount / totalCount,
        averageSpend: averageSpend,
        averageOvershoot: averageOvershoot
    )
}

private func targetCalibrationSuggestion(
    monthlyLimit: Decimal,
    history: TargetHistorySummary
) -> TargetCalibrationSuggestion? {
    guard history.months.count >= 3 else {
        return nil
    }

    let recommendedLimit = roundedTargetCalibrationLimit(history.averageSpend)
    let delta = recommendedLimit - monthlyLimit
    let threshold = max(Decimal(25), monthlyLimit * Decimal(string: "0.10")!)
    guard abs(delta) >= threshold else {
        return nil
    }

    return TargetCalibrationSuggestion(
        recommendedMonthlyLimit: recommendedLimit,
        direction: delta >= .zero ? .increase : .decrease,
        delta: abs(delta)
    )
}

private func roundedTargetCalibrationLimit(_ value: Decimal) -> Decimal {
    let rounded = ceil((NSDecimalNumber(decimal: value).doubleValue / 10.0)) * 10.0
    return Decimal(rounded)
}

private func targetScopeSpend(
    db: Database,
    interval: DateInterval,
    scope: TargetScope
) throws -> Decimal {
    switch scope {
    case .category(let categoryID):
        return try includedVisibleExpenseSpend(db: db, interval: interval, categoryID: categoryID)
    case .categoryGroup(let categoryGroupID):
        return try includedVisibleExpenseSpend(db: db, interval: interval, categoryGroupID: categoryGroupID)
    }
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

private func normalizedInferenceFilename(_ originalFilename: String) -> String {
    inferenceFilenameIdentityTokens(
        originalFilename
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: #"\.[a-z0-9]+$"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"[^a-z0-9]+"#, with: " ", options: .regularExpression)
            .split(separator: " ")
            .joined(separator: " ")
    ).joined(separator: " ")
}

private func inferenceFilenameIdentityTokens(_ normalizedValue: String) -> [String] {
    let tokens = normalizedValue
        .split(separator: " ")
        .map(String.init)

    return tokens.enumerated().compactMap { index, token in
        guard token.count > 1 else {
            return nil
        }
        if Int(token) != nil, shouldDropNumericInferenceFilenameToken(tokens, index: index) {
            return nil
        }
        return token
    }
}

private func shouldDropNumericInferenceFilenameToken(_ tokens: [String], index: Int) -> Bool {
    let token = tokens[index]
    guard let value = Int(token) else {
        return false
    }
    if (1900...2100).contains(value) {
        return true
    }
    guard token.count <= 2 else {
        return false
    }

    let neighbors = [index - 1, index + 1]
        .filter { tokens.indices.contains($0) }
        .map { tokens[$0] }

    return neighbors.contains(where: { monthInferenceFilenameTokens.contains($0) }) ||
        neighbors.contains(where: isYearInferenceFilenameToken)
}

private func isYearInferenceFilenameToken(_ token: String) -> Bool {
    guard let value = Int(token) else {
        return false
    }
    return (1900...2100).contains(value)
}

private func inferenceRowShapeSummary(for rows: [Row]) throws -> [[Int]] {
    let decoder = JSONDecoder()

    return try rows.map { row in
        let rawPayload: String = row["raw_payload"]
        guard let rawPayloadData = rawPayload.data(using: .utf8) else {
            throw WorkspaceStoreError.invalidStoredInferenceEncoding
        }

        let values = try decoder.decode([String].self, from: rawPayloadData)
        return values.enumerated().compactMap { index, value in
            value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : index
        }
    }
}

private let monthInferenceFilenameTokens: Set<String> = [
    "apr",
    "april",
    "aug",
    "august",
    "dec",
    "december",
    "feb",
    "february",
    "jan",
    "january",
    "jul",
    "july",
    "jun",
    "june",
    "mar",
    "march",
    "may",
    "nov",
    "november",
    "oct",
    "october",
    "sep",
    "sept",
    "september",
]

private func makeInferenceJSON<T: Encodable>(_ value: T) throws -> String {
    guard let json = String(data: try JSONEncoder().encode(value), encoding: .utf8) else {
        throw WorkspaceStoreError.invalidStoredInferenceEncoding
    }
    return json
}

private func inferenceFeedbackKind(
    selectedAccountID: UUID,
    suggestedAccountID: UUID?
) -> String {
    guard let suggestedAccountID else {
        return "manualAssignment"
    }

    if selectedAccountID == suggestedAccountID {
        return "acceptedSuggestion"
    }

    return "overrodeSuggestion"
}

private extension CSVColumnMapping {
    var isEmptyInferenceBootstrapMapping: Bool {
        dateColumnIndex == nil &&
        descriptionColumnIndex == nil &&
        amount == nil
    }

    func canBootstrapInferenceEvidence(for queryMapping: CSVColumnMapping) -> Bool {
        self == queryMapping || isEmptyInferenceBootstrapMapping
    }
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
            let amount = legacyAmountValue(in: values, mapping: mapping),
            let semantics = mapping.profile.semantics(for: values, mapping: mapping)
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
                semantics.rawDescription,
                merchantNormalizer.normalize(semantics.derivedMerchant),
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

private struct DefaultBudgetTaxonomySnapshot {
    var groups: [DefaultCategoryGroupDefinition]
    var categories: [DefaultBudgetCategoryDefinition]
}

private func currentDefaultBudgetTaxonomy() -> DefaultBudgetTaxonomySnapshot {
    DefaultBudgetTaxonomySnapshot(
        groups: DefaultBudgetTaxonomy.categoryGroups,
        categories: DefaultBudgetTaxonomy.categories
    )
}

private func shouldSeedSimplifiedDefaultTaxonomy(db: Database) throws -> Bool {
    if try currentDefaultTaxonomyVersion(db: db) == simplifiedDefaultTaxonomyVersion {
        return true
    }

    return try workspaceIsEmptyForSimplifiedDefaultTaxonomyBootstrap(db: db)
}

private func workspaceRequiresSimplifiedDefaultTaxonomyReset(db: Database) throws -> Bool {
    guard try currentDefaultTaxonomyVersion(db: db) != simplifiedDefaultTaxonomyVersion else {
        return false
    }

    return try workspaceIsEmptyForSimplifiedDefaultTaxonomyBootstrap(db: db) == false
}

private func currentDefaultTaxonomyVersion(db: Database) throws -> String? {
    guard try db.tableExists("workspace_preferences") else {
        return nil
    }

    return try String.fetchOne(
        db,
        sql: """
        SELECT value
        FROM workspace_preferences
        WHERE key = ?
        """,
        arguments: [workspacePreferenceDefaultTaxonomyVersionKey]
    )
}

private func writeSimplifiedDefaultTaxonomyVersion(db: Database) throws {
    guard try db.tableExists("workspace_preferences") else {
        return
    }

    try db.execute(
        sql: """
        INSERT INTO workspace_preferences (key, value)
        VALUES (?, ?)
        ON CONFLICT(key) DO UPDATE SET value = excluded.value
        """,
        arguments: [
            workspacePreferenceDefaultTaxonomyVersionKey,
            simplifiedDefaultTaxonomyVersion,
        ]
    )
}

private func workspaceIsEmptyForSimplifiedDefaultTaxonomyBootstrap(db: Database) throws -> Bool {
    let occupiedTableNames = [
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
    ]

    for tableName in occupiedTableNames {
        guard try db.tableExists(tableName) else {
            continue
        }

        let rowCount = try Int.fetchOne(
            db,
            sql: "SELECT COUNT(*) FROM \(tableName)"
        ) ?? 0
        if rowCount > 0 {
            return false
        }
    }

    return true
}

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

private func pruneObsoleteDefaultTaxonomy(
    taxonomy: DefaultBudgetTaxonomySnapshot = currentDefaultBudgetTaxonomy(),
    db: Database
) throws {
    let currentCategoryIDs = Set(taxonomy.categories.map(\.id.uuidString))
    let currentGroupIDs = Set(taxonomy.groups.map(\.id.uuidString))

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
    guard currentGroupIDs.isEmpty == false else {
        try db.execute(
            sql: """
            DELETE FROM category_groups
            WHERE id LIKE '10000000-0000-0000-0000-000000000%'
                AND NOT EXISTS (
                    SELECT 1 FROM categories
                    WHERE categories.category_group_id = category_groups.id
                )
                AND NOT EXISTS (
                    SELECT 1 FROM targets
                    WHERE targets.category_group_id = category_groups.id
                )
            """
        )
        return
    }

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
    defaultOrderSQL(ids: currentDefaultBudgetTaxonomy().groups.map(\.id), column: column)
}

private func defaultBudgetCategoryOrderSQL(column: String) -> String {
    defaultOrderSQL(ids: currentDefaultBudgetTaxonomy().categories.map(\.id), column: column)
}

private func defaultOrderSQL(ids: [UUID], column: String) -> String {
    guard ids.isEmpty == false else {
        return column
    }

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

    return CSVImportValueParser.date(from: value)
}

private func legacyDecimalValue(in values: [String], at columnIndex: Int) -> Decimal? {
    guard let value = legacyStringValue(in: values, at: columnIndex) else {
        return nil
    }
    return CSVImportValueParser.decimal(from: value)
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
    case invalidLearnedRuleCategory
    case invalidLearnedRulePattern
    case accountNotImportEligible(UUID)
    case invalidStoredAccountID(String)
    case invalidStoredMapping(Error)
    case invalidStoredInferenceEncoding
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
        case .invalidLearnedRuleCategory:
            "Learned rules require a category before saving."
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

private struct RecurringInsightObservation {
    let transactionID: UUID
    let accountID: UUID
    let normalizedMerchantName: String
    let rawDescription: String
    let amount: Decimal
    let transactionDate: Date
}

private struct RecurringInsightGroupKey: Hashable {
    let accountID: UUID
    let normalizedMerchantName: String
}

private struct WorkspaceInsightFactBundle {
    let monthlyReport: MonthlyReport
    let recurringObservations: [RecurringInsightObservation]
}

private struct RecurringInsightCandidate {
    let detail: RecurringChargeInsightDetail
    let confidence: Double
    let score: Double
}

private struct SpendingDriverRollup: Hashable {
    let title: String
    let scope: SpendingDriverScope
}

private typealias DriverBuckets = [SpendingDriverRollup: Decimal]

private extension WorkspaceStore {
    func fetchWorkspaceInsightFacts(referenceDate: Date) throws -> WorkspaceInsightFactBundle {
        let monthlyReport = try fetchMonthlyReport(referenceDate: referenceDate)
        let recurringObservations = try databaseQueue.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                SELECT
                    id,
                    account_id,
                    raw_description,
                    normalized_merchant_name,
                    amount,
                    transaction_date
                FROM transactions
                WHERE is_hidden = 0
                    AND direction = ?
                    AND review_status IN (?, ?)
                    AND amount < 0
                    AND transaction_date <= ?
                ORDER BY transaction_date ASC, id ASC
                """,
                arguments: [
                    TransactionDirection.expense.rawValue,
                    TransactionReviewStatus.accepted.rawValue,
                    TransactionReviewStatus.pending.rawValue,
                    referenceDate,
                ]
            )
            return try rows.map(recurringInsightObservation(from:))
        }

        return WorkspaceInsightFactBundle(
            monthlyReport: monthlyReport,
            recurringObservations: recurringObservations
        )
    }
}
