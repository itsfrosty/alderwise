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
func liveWorkspaceLocationCreatesAlderwiseDirectoryInsideApplicationSupport() throws {
    let applicationSupportDirectory = try temporaryDirectoryURL().appending(path: "Application Support", directoryHint: .isDirectory)

    let location = try WorkspaceLocation.live(applicationSupportDirectory: applicationSupportDirectory)

    #expect(location.databaseURL == applicationSupportDirectory.appending(path: "Alderwise/workspace.sqlite"))
    #expect(location.databasePath.contains("Application Support/Alderwise/workspace.sqlite"))
    #expect(!location.databasePath.contains("%20"))
    #expect(FileManager.default.fileExists(atPath: location.databaseURL.deletingLastPathComponent().path))
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
func bootstrapSeedsDefaultBudgetCategories() throws {
    let store = try WorkspaceStore.inMemory()

    try store.bootstrap()
    try store.bootstrap()

    let categories = try store.fetchCategories()
    let groups = try store.fetchCategoryGroups()

    #expect(groups.isEmpty)
    #expect(categories.map(\.name) == [
        "Home & Utilities",
        "Groceries",
        "Dining",
        "Transportation",
        "Travel",
        "Shopping & Lifestyle",
        "Health",
        "Kids & Education",
        "Financial",
        "Income",
        "Transfers",
    ])
    #expect(Set(categories.map(\.id)) == DefaultBudgetTaxonomy.canonicalCategoryIDs)
    #expect(Set(categories.map(\.id)).isDisjoint(with: DefaultBudgetTaxonomy.removedLegacyCategoryIDs))
    #expect(categories.allSatisfy { $0.groupID == nil })
    #expect(categories.contains { $0.name == "Uncategorized" } == false)
    #expect(categories.first { $0.name == "Income" }?.kind == .income)
    #expect(categories.first { $0.name == "Transfers" }?.kind == .transfer)
}

@Test
func defaultBudgetTaxonomyDefinesSimplifiedCanonicalCategories() throws {
    let categoriesByName = Dictionary(
        uniqueKeysWithValues: DefaultBudgetTaxonomy.categories.map { ($0.name, $0) }
    )

    #expect(DefaultBudgetTaxonomy.categoryGroups.isEmpty)
    #expect(DefaultBudgetTaxonomy.categories.count == 11)
    #expect(categoriesByName["Travel"]?.id == DefaultBudgetTaxonomy.CategoryID.travel)
    #expect(categoriesByName["Travel"]?.kind == .expense)
    #expect(categoriesByName["Travel"]?.groupID == nil)
    #expect(categoriesByName["Financial"]?.id == DefaultBudgetTaxonomy.CategoryID.financial)
    #expect(categoriesByName["Financial"]?.kind == .expense)
    #expect(categoriesByName["Financial"]?.groupID == nil)
    #expect(DefaultBudgetTaxonomy.removedLegacyCategoryIDs.contains(DefaultBudgetTaxonomy.LegacyCategoryID.hotels.id))
    #expect(DefaultBudgetTaxonomy.removedLegacyCategoryIDs.contains(DefaultBudgetTaxonomy.LegacyCategoryID.coffeeShops.id))
    #expect(DefaultBudgetTaxonomy.categoryName(for: DefaultBudgetTaxonomy.LegacyCategoryID.coffeeShops.id) == "Dining")
}

@Test
func workspaceStoreBootstrapPreservesExpectedSimplifiedTaxonomyOrder() throws {
    let store = try WorkspaceStore.inMemory()

    try store.bootstrap()
    try store.bootstrap()

    let categories = try store.fetchCategories()
    let groups = try store.fetchCategoryGroups()

    #expect(groups.isEmpty)
    #expect(categories.map(\.name) == [
        "Home & Utilities",
        "Groceries",
        "Dining",
        "Transportation",
        "Travel",
        "Shopping & Lifestyle",
        "Health",
        "Kids & Education",
        "Financial",
        "Income",
        "Transfers",
    ])
}

@Test
func workspaceStoreSeedsSimplifiedCategoriesIntoFreshWorkspace() throws {
    let store = try WorkspaceStore.inMemory()

    try store.bootstrap()

    let categories = try store.fetchCategories()
    let groups = try store.fetchCategoryGroups()
    let travel = try #require(categories.first { $0.name == "Travel" })

    #expect(groups.isEmpty)
    #expect(categories.count == 11)
    #expect(Set(categories.map(\.id)) == DefaultBudgetTaxonomy.canonicalCategoryIDs)
    #expect(travel.id == DefaultBudgetTaxonomy.CategoryID.travel)
    #expect(travel.kind == .expense)
    #expect(travel.groupID == nil)
}

@Test
func legacyWorkspaceBootstrapDefersSimplifiedTaxonomyUntilReset() throws {
    let databaseURL = try temporaryDatabaseURL()
    try createWorkspaceAfterWorkspacePreferencesMigration(at: databaseURL)
    try insertLegacyDefaultTaxonomyWithoutTravel(databaseURL: databaseURL)
    let store = try WorkspaceStore.at(databaseURL: databaseURL)

    try store.bootstrap()

    let categories = try store.fetchCategories()
    let groups = try store.fetchCategoryGroups()
    let metadata = try store.fetchWorkspaceMetadata()

    #expect(metadata.requiresReset)
    #expect(categories.contains { $0.name == "Travel" } == false)
    #expect(categories.contains { $0.name == "Restaurants & Bars" })
    #expect(groups.contains { $0.name == "Food & Drink" })
}

@Test
func bootstrapPreservesCustomCategoriesWhileMaintainingDefaultTaxonomy() throws {
    let databaseURL = try temporaryDatabaseURL()
    var store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()
    let baselineCategoryNames = Set(try store.fetchCategories().map(\.name))
    try replaceSeededCategoriesWithCustomCategory(databaseURL: databaseURL)

    store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()

    let categories = try store.fetchCategories()

    #expect(categories.contains { $0.name == "Custom Food" && $0.kind == .expense })
    #expect(categories.filter { $0.name != "Custom Food" }.count == 11)
    #expect(Set(categories.filter { $0.name != "Custom Food" }.map(\.name)) == baselineCategoryNames)
    #expect(categories.filter { $0.kind == .income }.map(\.name) == ["Income"])
    #expect(categories.filter { $0.kind == .transfer }.map(\.name) == ["Transfers"])
}

@Test
func bootstrapPrunesUnreferencedObsoleteDefaultCategories() throws {
    let databaseURL = try temporaryDatabaseURL()
    var store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()

    let obsoleteDefaultCategoryID = UUID(uuidString: "20000000-0000-0000-0000-000000000024")!
    try insertCategory(
        databaseURL: databaseURL,
        id: obsoleteDefaultCategoryID,
        name: "Clothing",
        kind: "expense",
        categoryGroupID: nil
    )

    store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()

    #expect(try store.fetchCategories().contains { $0.id == obsoleteDefaultCategoryID } == false)
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
    #expect(try store.fetchImportEligibleAccounts().map(\.name) == ["Card", "Checking"])
    #expect(try store.fetchLedgerFilterAccounts().map(\.name) == ["Card", "Checking"])
    #expect(try store.fetchPermanentlyDeletableAccountIDs().count == 2)
}

@Test
func bootstrapAddsArchivedAccountStateToLegacyWorkspaces() throws {
    let databaseURL = try temporaryDatabaseURL()
    try createWorkspaceAfterWorkspacePreferencesMigration(at: databaseURL)
    let queue = try DatabaseQueue(path: databaseURL.path)
    let legacyAccountID = UUID(uuidString: "00000000-0000-0000-0000-000000000141")!
    try queue.write { db in
        try db.execute(
            sql: "INSERT INTO accounts (id, name, kind, institution_name, created_at) VALUES (?, ?, ?, ?, ?)",
            arguments: [
                legacyAccountID.uuidString,
                "Checking",
                "checking",
                "Local Bank",
                Date(timeIntervalSince1970: 1_775_171_200),
            ]
        )
    }

    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()

    let accountColumns = try queue.read { db in
        Set(try Row.fetchAll(db, sql: "PRAGMA table_info(accounts)").map { row in
            row["name"] as String
        })
    }
    let managementAccounts = try store.fetchManagementAccounts()
    let importEligibleAccounts = try store.fetchImportEligibleAccounts()

    #expect(accountColumns.contains("archived_at"))
    #expect(managementAccounts.map(\.id) == [legacyAccountID])
    #expect(managementAccounts.allSatisfy { $0.archivedAt == nil })
    #expect(importEligibleAccounts.map(\.id) == [legacyAccountID])
}

@Test
func archivingAndRestoringAccountsUpdatesVisibilityContracts() throws {
    let store = try WorkspaceStore.inMemory()
    try store.bootstrap()
    let account = try store.createAccount(named: "Checking", kind: .checking, institutionName: "Local Bank")

    _ = try store.archiveAccount(
        id: account.id,
        archivedAt: Date(timeIntervalSince1970: 1_775_171_260)
    )

    #expect(try store.fetchSummary().accountCount == 0)
    #expect(try store.fetchManagementAccounts().map(\.name) == ["Checking"])
    #expect(try store.fetchImportEligibleAccounts().isEmpty)
    #expect(try store.fetchLedgerFilterAccounts().map(\.name) == ["Checking"])
    #expect(try store.fetchPermanentlyDeletableAccountIDs() == Set([account.id]))

    _ = try store.restoreAccount(id: account.id)

    #expect(try store.fetchSummary().accountCount == 1)
    #expect(try store.fetchImportEligibleAccounts().map(\.name) == ["Checking"])
}

@Test
func updateAccountPersistsMetadataChanges() throws {
    let store = try WorkspaceStore.inMemory()
    try store.bootstrap()
    let account = try store.createAccount(named: "Checking", kind: .checking, institutionName: "Local Bank")

    let updated = try store.updateAccount(
        id: account.id,
        named: "Primary Checking",
        kind: .savings,
        institutionName: "Community Bank"
    )

    #expect(updated.name == "Primary Checking")
    #expect(updated.kind == .savings)
    #expect(updated.institutionName == "Community Bank")
    #expect(try store.fetchManagementAccounts().map(\.name) == ["Primary Checking"])
    #expect(try store.fetchPermanentlyDeletableAccountIDs() == Set([account.id]))
}

@Test
func deleteUnusedAccountPermanentlyRemovesIt() throws {
    let store = try WorkspaceStore.inMemory()
    try store.bootstrap()
    let account = try store.createAccount(named: "Checking", kind: .checking, institutionName: "Local Bank")

    try store.deleteAccountPermanently(id: account.id)

    #expect(try store.fetchManagementAccounts().isEmpty)
    #expect(try store.fetchSummary().accountCount == 0)
}

@Test
func deleteAccountPermanentlyRejectsDependentHistoryAndLeavesRowsIntact() throws {
    let databaseURL = try temporaryDatabaseURL()
    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()

    let stagedImportAccount = try store.createAccount(named: "Checking", kind: .checking, institutionName: "Local Bank")
    let transactionAccount = try store.createAccount(named: "Card", kind: .creditCard, institutionName: "Visa")
    let unusedAccount = try store.createAccount(named: "Savings", kind: .savings, institutionName: "Local Bank")
    try insertSourceFileAndImportSession(databaseURL: databaseURL, accountID: stagedImportAccount.id)
    try insertTransaction(
        databaseURL: databaseURL,
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000155")!,
        accountID: transactionAccount.id,
        normalizedMerchantName: "coffee shop",
        amount: Decimal(-4.75),
        transactionDate: Date(timeIntervalSince1970: 1_775_171_200)
    )

    #expect(throws: AccountManagementError.deleteBlockedByDependencies(stagedImportAccount.id)) {
        try store.deleteAccountPermanently(id: stagedImportAccount.id)
    }
    #expect(throws: AccountManagementError.deleteBlockedByDependencies(transactionAccount.id)) {
        try store.deleteAccountPermanently(id: transactionAccount.id)
    }
    #expect(try store.fetchPermanentlyDeletableAccountIDs() == Set([unusedAccount.id]))

    let counts = try DatabaseQueue(path: databaseURL.path).read { db in
        (
            accounts: try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM accounts") ?? 0,
            sourceFiles: try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM source_files WHERE account_id = ?", arguments: [stagedImportAccount.id.uuidString]) ?? 0,
            importSessions: try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM import_sessions WHERE account_id = ?", arguments: [stagedImportAccount.id.uuidString]) ?? 0,
            transactions: try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM transactions WHERE account_id IN (?, ?)", arguments: [stagedImportAccount.id.uuidString, transactionAccount.id.uuidString]) ?? 0
        )
    }

    #expect(counts.accounts == 3)
    #expect(counts.sourceFiles == 1)
    #expect(counts.importSessions == 1)
    #expect(counts.transactions == 1)
}

@Test
func workspaceMetadataReportsOnDiskLocationAndSize() throws {
    let databaseURL = try temporaryDatabaseURL()
    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()
    _ = try store.createAccount(named: "Checking", kind: .checking, institutionName: "Local Bank")

    let metadata = try store.fetchWorkspaceMetadata()

    #expect(metadata.databaseURL == databaseURL)
    #expect(metadata.databaseExists)
    #expect(metadata.databaseSizeBytes > 0)
    #expect(metadata.modifiedAt != nil)
    #expect(metadata.requiresReset == false)
    #expect(metadata.resetReason == nil)
}

@Test
func legacyWorkspaceMetadataRequiresResetBeforeNormalUse() throws {
    let databaseURL = try temporaryDatabaseURL()
    try createWorkspaceAfterWorkspacePreferencesMigration(at: databaseURL)
    try insertLegacyDefaultTaxonomyWithoutTravel(databaseURL: databaseURL)
    let store = try WorkspaceStore.at(databaseURL: databaseURL)

    try store.bootstrap()
    let metadata = try store.fetchWorkspaceMetadata()
    let categories = try store.fetchCategories()

    #expect(metadata.requiresReset)
    #expect(metadata.resetReason?.contains("reset") == true)
    #expect(categories.contains { $0.name == "Restaurants & Bars" })
    #expect(categories.contains { $0.name == "Home & Utilities" } == false)
}

@Test
func bootstrapDoesNotReseedLegacyWorkspaceBeforeReset() throws {
    let databaseURL = try temporaryDatabaseURL()
    try createWorkspaceAfterWorkspacePreferencesMigration(at: databaseURL)
    try insertLegacyDefaultTaxonomyWithoutTravel(databaseURL: databaseURL)
    let store = try WorkspaceStore.at(databaseURL: databaseURL)

    try store.bootstrap()

    let categories = try store.fetchCategories()
    let groups = try store.fetchCategoryGroups()

    #expect(categories.contains { $0.name == "Restaurants & Bars" })
    #expect(categories.contains { $0.name == "Travel" } == false)
    #expect(groups.contains { $0.name == "Food & Drink" })
}

@Test
func createWorkspaceBackupWritesReadableSQLiteCopy() throws {
    let databaseURL = try temporaryDatabaseURL()
    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()
    _ = try store.createAccount(named: "Checking", kind: .checking, institutionName: "Local Bank")
    let backupDirectory = databaseURL.deletingLastPathComponent().appending(path: "Backups", directoryHint: .isDirectory)

    let backup = try store.createWorkspaceBackup(
        in: backupDirectory,
        now: Date(timeIntervalSince1970: 1_775_171_200)
    )
    let backupStore = try WorkspaceStore.at(databaseURL: backup.fileURL)

    #expect(backup.fileURL.lastPathComponent == "Alderwise Backup 2026-04-02 230640.sqlite")
    #expect(backup.sizeBytes > 0)
    #expect(try backupStore.fetchSummary().accountCount == 1)
}

@Test
func restoreWorkspaceBackupRestoresValidBackupAndKeepsSafetyBackup() throws {
    let databaseURL = try temporaryDatabaseURL()
    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()
    _ = try store.createAccount(named: "Checking", kind: .checking, institutionName: "Local Bank")
    let backupDirectory = databaseURL.deletingLastPathComponent().appending(path: "Backups", directoryHint: .isDirectory)
    let backup = try store.createWorkspaceBackup(
        in: backupDirectory,
        now: Date(timeIntervalSince1970: 1_775_171_200)
    )
    _ = try store.createAccount(named: "Credit Card", kind: .creditCard, institutionName: "Local Bank")

    let result = try store.restoreWorkspaceBackup(
        from: backup.fileURL,
        safetyBackupDirectory: backupDirectory,
        now: Date(timeIntervalSince1970: 1_775_257_600)
    )

    #expect(result.restoredFromURL == backup.fileURL)
    #expect(result.safetyBackup?.fileURL.lastPathComponent == "Alderwise Backup 2026-04-03 230640.sqlite")
    #expect(try store.fetchSummary().accountCount == 1)
}

@Test
func restoreWorkspaceBackupRejectsLiveWorkspacePath() throws {
    let databaseURL = try temporaryDatabaseURL()
    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()

    #expect(throws: WorkspaceMaintenanceError.restoreSourceIsCurrentWorkspace) {
        try store.restoreWorkspaceBackup(from: databaseURL)
    }
}

@Test
func restoreWorkspaceBackupRejectsMalformedSQLiteCandidates() throws {
    let databaseURL = try temporaryDatabaseURL()
    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()
    let invalidURL = databaseURL.deletingLastPathComponent().appending(path: "not-a-workspace.sqlite")
    try Data("not sqlite".utf8).write(to: invalidURL)

    #expect(throws: WorkspaceMaintenanceError.invalidRestoreCandidate("Selected file is not a readable SQLite database.")) {
        try store.restoreWorkspaceBackup(from: invalidURL)
    }
}

@Test
func restoreWorkspaceBackupRejectsSchemaIncompatibleCandidatesMissingRequiredTables() throws {
    let databaseURL = try temporaryDatabaseURL()
    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()
    let backup = try createRestoreCandidateBackup(from: store, at: databaseURL)
    try dropRestoreCandidateTables(at: backup.fileURL, tables: [
        "rules",
        "review_decision_events",
        "workspace_preferences",
    ])

    do {
        _ = try store.restoreWorkspaceBackup(from: backup.fileURL)
        Issue.record("Expected restore to reject missing tables.")
    } catch let error as WorkspaceMaintenanceError {
        guard case .invalidRestoreCandidate(let reason) = error else {
            Issue.record("Expected invalidRestoreCandidate, got \(error).")
            return
        }

        #expect(reason.contains("Missing required Alderwise tables:"))
        #expect(reason.contains("rules"))
        #expect(reason.contains("review_decision_events"))
        #expect(reason.contains("workspace_preferences"))
    }
}

@Test
func restoreWorkspaceBackupRejectsSchemaIncompatibleCandidatesWithWrongWorkspacePreferencesShape() throws {
    let databaseURL = try temporaryDatabaseURL()
    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()
    let backup = try createRestoreCandidateBackup(from: store, at: databaseURL)
    try replaceWorkspacePreferencesTableWithIncompatibleShape(at: backup.fileURL)

    #expect(throws: WorkspaceMaintenanceError.invalidRestoreCandidate("The selected backup is not compatible with the current Alderwise workspace schema.")) {
        try store.restoreWorkspaceBackup(from: backup.fileURL)
    }
    #expect(try store.fetchSummary().accountCount == 0)
}

@Test
func restoreWorkspaceBackupLeavesLiveWorkspaceUnchangedWhenValidationFailsBeforeOverwrite() throws {
    let databaseURL = try temporaryDatabaseURL()
    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()
    _ = try store.createAccount(named: "Checking", kind: .checking, institutionName: "Local Bank")
    let invalidURL = databaseURL.deletingLastPathComponent().appending(path: "not-a-workspace.sqlite")
    try Data("not sqlite".utf8).write(to: invalidURL)

    #expect(throws: WorkspaceMaintenanceError.invalidRestoreCandidate("Selected file is not a readable SQLite database.")) {
        try store.restoreWorkspaceBackup(from: invalidURL)
    }
    #expect(try store.fetchSummary().accountCount == 1)
}

@Test
func resetWorkspaceCreatesMandatoryBackupAndLeavesBootstrappedEmptyWorkspace() throws {
    let databaseURL = try temporaryDatabaseURL()
    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()
    _ = try store.createAccount(named: "Checking", kind: .checking, institutionName: "Local Bank")

    let result = try store.resetWorkspace()
    let backupStore = try WorkspaceStore.at(databaseURL: result.preResetBackupURL)

    #expect(FileManager.default.fileExists(atPath: result.preResetBackupURL.path))
    #expect(try backupStore.fetchSummary().accountCount == 1)
    #expect(try store.fetchSummary() == .empty)
    #expect(try store.fetchAccounts().isEmpty)
    #expect(try store.fetchCategories().map(\.name) == DefaultBudgetTaxonomy.categories.map(\.name))
    #expect(try store.fetchCategoryGroups().isEmpty)
    #expect(try store.fetchWorkspaceMetadata().requiresReset == false)
}

@Test
func resetWorkspacePreservesLiveWorkspacePath() throws {
    let databaseURL = try temporaryDatabaseURL()
    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()
    _ = try store.createAccount(named: "Checking", kind: .checking, institutionName: "Local Bank")

    _ = try store.resetWorkspace()
    let metadata = try store.fetchWorkspaceMetadata()
    let reopenedStore = try WorkspaceStore.at(databaseURL: databaseURL)

    #expect(metadata.databaseURL == databaseURL)
    #expect(FileManager.default.fileExists(atPath: databaseURL.path))
    #expect(try reopenedStore.fetchSummary() == .empty)
}

@Test
func resetWorkspaceClearsWorkspacePreferencesBackToDefaults() throws {
    let databaseURL = try temporaryDatabaseURL()
    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()
    try store.updateWorkspacePreferences(
        WorkspacePreferences(
            suggestionsEnabled: false,
            seededHeuristicAutoAcceptEnabled: true
        )
    )

    _ = try store.resetWorkspace()

    #expect(try store.fetchWorkspacePreferences() == .default)
}

@Test
func resetWorkspaceLeavesExistingBackupFilesUntouched() throws {
    let databaseURL = try temporaryDatabaseURL()
    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()
    _ = try store.createAccount(named: "Checking", kind: .checking, institutionName: "Local Bank")
    let backupDirectory = databaseURL.deletingLastPathComponent().appending(path: "Backups", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
    let existingBackupURL = backupDirectory.appending(path: "Alderwise Backup 2000-01-01 000000.sqlite")
    let existingBackupContents = Data("existing backup".utf8)
    try existingBackupContents.write(to: existingBackupURL)

    let result = try store.resetWorkspace()

    #expect(result.preResetBackupURL != existingBackupURL)
    #expect(FileManager.default.fileExists(atPath: existingBackupURL.path))
    #expect(try Data(contentsOf: existingBackupURL) == existingBackupContents)
}

@Test
func resetWorkspaceIsBlockedWhenMandatoryBackupCannotComplete() throws {
    let databaseURL = try temporaryDatabaseURL()
    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()
    _ = try store.createAccount(named: "Checking", kind: .checking, institutionName: "Local Bank")
    let backupDirectory = databaseURL.deletingLastPathComponent().appending(path: "Backups", directoryHint: .isDirectory)
    try Data("not a directory".utf8).write(to: backupDirectory)

    #expect(throws: (any Error).self) {
        try store.resetWorkspace()
    }
    #expect(try store.fetchSummary().accountCount == 1)
}

@Test
func workspacePreferencesDefaultToSuggestionsEnabled() throws {
    let databaseURL = try temporaryDatabaseURL()
    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()

    let preferences = try store.fetchWorkspacePreferences()

    #expect(preferences == WorkspacePreferences(
        suggestionsEnabled: true,
        seededHeuristicAutoAcceptEnabled: false
    ))
}

@Test
func workspacePreferencesUpgradeExistingWorkspaceWithoutSeededHeuristicAutoAcceptOptIn() throws {
    let databaseURL = try temporaryDatabaseURL()
    try createWorkspaceAfterWorkspacePreferencesMigration(at: databaseURL)
    let store = try WorkspaceStore.at(databaseURL: databaseURL)

    try store.bootstrap()

    #expect(try store.fetchWorkspacePreferences() == WorkspacePreferences(
        suggestionsEnabled: true,
        seededHeuristicAutoAcceptEnabled: false
    ))
}

@Test
func bootstrapDoesNotCreateTargetOverlapWhenSeedingDefaultCategoryMembership() throws {
    let databaseURL = try temporaryDatabaseURL()
    try createWorkspaceAfterWorkspacePreferencesMigration(at: databaseURL)
    try insertLegacyTargetsForBootstrapOverlapRegression(databaseURL: databaseURL)
    let store = try WorkspaceStore.at(databaseURL: databaseURL)

    try store.bootstrap()

    let categories = try store.fetchCategories()
    let managedTargets = try store.fetchManagedTargets(referenceDate: Date(timeIntervalSince1970: 1_775_171_200))
    let groceries = try #require(categories.first { $0.id == DefaultBudgetTaxonomy.CategoryID.groceries })

    #expect(groceries.groupID == nil)
    #expect(managedTargets.map(\.name) == ["Category Group", "Groceries"])
    #expect(managedTargets.map(\.scope) == [
        .categoryGroup(DefaultBudgetTaxonomy.CategoryGroupID.foodAndDrink),
        .category(DefaultBudgetTaxonomy.CategoryID.groceries),
    ])
}

@Test
func travelTaxonomyDoesNotCreateTargetOverlapRegression() throws {
    let databaseURL = try temporaryDatabaseURL()
    try createWorkspaceAfterWorkspacePreferencesMigration(at: databaseURL)
    try insertLegacyTravelTargetsForBootstrapOverlapRegression(databaseURL: databaseURL)
    let store = try WorkspaceStore.at(databaseURL: databaseURL)

    try store.bootstrap()

    let categories = try store.fetchCategories()
    let managedTargets = try store.fetchManagedTargets(referenceDate: Date(timeIntervalSince1970: 1_775_171_200))

    #expect(categories.contains { $0.name == "Travel" } == false)
    #expect(managedTargets.map(\.name) == ["Category Group", "Flights"])
    #expect(managedTargets.map(\.scope) == [
        .categoryGroup(travelCategoryGroupID),
        .category(flightsCategoryID),
    ])
}

@Test
func bootstrapInstallsDatabaseGuardsForTargetScopeWrites() throws {
    let databaseURL = try temporaryDatabaseURL()
    try createWorkspaceAfterWorkspacePreferencesMigration(at: databaseURL)
    let store = try WorkspaceStore.at(databaseURL: databaseURL)

    try store.bootstrap()

    try insertTarget(
        databaseURL: databaseURL,
        id: UUID(uuidString: "00000000-0000-0000-0000-000000009011")!,
        categoryID: DefaultBudgetTaxonomy.CategoryID.groceries,
        categoryGroupID: nil,
        monthlyLimit: Decimal(125)
    )

    #expect(throws: (any Error).self) {
        try insertTarget(
            databaseURL: databaseURL,
            id: UUID(uuidString: "00000000-0000-0000-0000-000000009012")!,
            categoryID: DefaultBudgetTaxonomy.CategoryID.groceries,
            categoryGroupID: nil,
            monthlyLimit: Decimal(140)
        )
    }
    try insertTarget(
        databaseURL: databaseURL,
        id: UUID(uuidString: "00000000-0000-0000-0000-000000009013")!,
        categoryID: nil,
        categoryGroupID: DefaultBudgetTaxonomy.CategoryGroupID.foodAndDrink,
        monthlyLimit: Decimal(150)
    )

    try insertTarget(
        databaseURL: databaseURL,
        id: UUID(uuidString: "00000000-0000-0000-0000-000000009014")!,
        categoryID: nil,
        categoryGroupID: DefaultBudgetTaxonomy.CategoryGroupID.autoAndTransit,
        monthlyLimit: Decimal(90)
    )
    try insertTarget(
        databaseURL: databaseURL,
        id: UUID(uuidString: "00000000-0000-0000-0000-000000009015")!,
        categoryID: DefaultBudgetTaxonomy.CategoryID.publicTransitAndRideShare,
        categoryGroupID: nil,
        monthlyLimit: Decimal(90)
    )
}

@Test
func fetchManagedTargetsRejectsAmbiguousStoredTargetScopeRows() throws {
    let databaseURL = try temporaryDatabaseURL()
    try createWorkspaceAfterWorkspacePreferencesMigration(at: databaseURL)
    try insertAmbiguousLegacyTargetForReadRegression(databaseURL: databaseURL)
    let store = try WorkspaceStore.at(databaseURL: databaseURL)

    try store.bootstrap()

    #expect(throws: (any Error).self) {
        _ = try store.fetchManagedTargets(referenceDate: Date(timeIntervalSince1970: 1_775_171_200))
    }
}

@Test
func workspacePreferencesRoundTripThroughSQLite() throws {
    let databaseURL = try temporaryDatabaseURL()
    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()

    try store.updateWorkspacePreferences(
        WorkspacePreferences(
            suggestionsEnabled: false,
            seededHeuristicAutoAcceptEnabled: false
        )
    )
    #expect(try store.fetchWorkspacePreferences() == WorkspacePreferences(
        suggestionsEnabled: false,
        seededHeuristicAutoAcceptEnabled: false
    ))

    let reopenedStore = try WorkspaceStore.at(databaseURL: databaseURL)
    try reopenedStore.bootstrap()
    #expect(try reopenedStore.fetchWorkspacePreferences() == WorkspacePreferences(
        suggestionsEnabled: false,
        seededHeuristicAutoAcceptEnabled: false
    ))

    try reopenedStore.updateWorkspacePreferences(
        WorkspacePreferences(
            suggestionsEnabled: true,
            seededHeuristicAutoAcceptEnabled: true
        )
    )
    #expect(try store.fetchWorkspacePreferences() == WorkspacePreferences(
        suggestionsEnabled: true,
        seededHeuristicAutoAcceptEnabled: true
    ))
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
func createStagedImportSessionRejectsArchivedAccounts() throws {
    let store = try WorkspaceStore.inMemory()
    try store.bootstrap()
    let archivedAccount = try store.createAccount(named: "Travel Card", kind: .creditCard, institutionName: "Visa")
    _ = try store.archiveAccount(
        id: archivedAccount.id,
        archivedAt: Date(timeIntervalSince1970: 1_775_171_260)
    )

    #expect(throws: (any Error).self) {
        _ = try store.createStagedImportSession(
            StagedImportSessionDraft(
                accountID: archivedAccount.id,
                originalFilename: "travel-card.csv",
                contentHash: "content-hash",
                importedAt: Date(timeIntervalSince1970: 1_775_171_200),
                rows: [
                    StagedSourceRowDraft(
                        sourceLineNumber: 2,
                        rawPayload: "[\"2026-04-01\",\"Coffee Shop\",\"-4.75\"]",
                        rowHash: "row-hash",
                        validationStatus: .valid,
                        importDecision: .imported(reason: "New source row.")
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
    }
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
func stagedImportedRowsCreateLedgerTransactions() throws {
    let databaseURL = try temporaryDatabaseURL()
    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()

    let account = try store.createAccount(named: "Checking", kind: .checking, institutionName: "Local Bank")
    let categoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000111")!
    try insertCategory(databaseURL: databaseURL, id: categoryID, name: "Coffee", kind: "expense")

    let session = try store.createStagedImportSession(
        StagedImportSessionDraft(
            accountID: account.id,
            originalFilename: "checking-april.csv",
            contentHash: "file-sha256",
            importedAt: Date(timeIntervalSince1970: 1_775_171_200),
            rows: [
                StagedSourceRowDraft(
                    sourceLineNumber: 2,
                    rawPayload: #"["2026-04-01","SQ *Coffee Shop","-4.75"]"#,
                    rowHash: "row-1-sha256",
                    validationStatus: .valid,
                    importDecision: .imported(reason: "New source row."),
                    classification: .autoAccepted(
                        assignment: ClassificationAssignment(categoryID: categoryID, merchantName: "Coffee Shop"),
                        source: .rule,
                        sourceReference: "rule-123",
                        confidence: 1.0,
                        reason: "Matched explicit merchant rule."
                    ),
                    normalizedMerchantName: "coffee shop",
                    transaction: StagedTransactionDraft(
                        transactionDate: Date(timeIntervalSince1970: 1_775_171_200),
                        rawDescription: "SQ *Coffee Shop",
                        normalizedMerchantName: "coffee shop",
                        amount: Decimal(-4.75)
                    )
                ),
                StagedSourceRowDraft(
                    sourceLineNumber: 3,
                    rawPayload: #"["2026-04-02","Unknown Store","-8.25"]"#,
                    rowHash: "row-2-sha256",
                    validationStatus: .valid,
                    importDecision: .imported(reason: "New source row."),
                    classification: .reviewRequired(
                        prefill: nil,
                        source: nil,
                        sourceReference: nil,
                        confidence: nil,
                        reason: "No classification matched."
                    ),
                    normalizedMerchantName: "unknown store",
                    transaction: StagedTransactionDraft(
                        transactionDate: Date(timeIntervalSince1970: 1_775_257_600),
                        rawDescription: "Unknown Store",
                        normalizedMerchantName: "unknown store",
                        amount: Decimal(-8.25)
                    )
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

    let rows = try store.fetchTransactionLedger(filter: .empty)

    #expect(session.id == rows[0].importOrigin?.id)
    #expect(rows.map(\.rawDescription) == ["Unknown Store", "SQ *Coffee Shop"])
    #expect(rows.map(\.reviewStatus) == [.pending, .accepted])
    #expect(rows[1].categoryID == categoryID)
    #expect(rows[1].categoryName == "Coffee")
    #expect(rows[1].merchantName == "Coffee Shop")
}

@Test
func bootstrapBackfillsLedgerTransactionsForLegacyStagedImports() throws {
    let databaseURL = try temporaryDatabaseURL()
    let accountID = UUID(uuidString: "00000000-0000-0000-0000-000000000801")!
    try createWorkspaceWithLegacyStagedImportMissingDecisionColumns(at: databaseURL, accountID: accountID)
    let store = try WorkspaceStore.at(databaseURL: databaseURL)

    try store.bootstrap()
    let rows = try store.fetchTransactionLedger(filter: .empty)

    #expect(rows.map(\.rawDescription) == [
        "SRI ANANDABHAVAN SUNNYVALE CA null XXXXXXXXXXXX3969",
        "WALMART.COM WALMART.COM AR",
    ])
    let amounts = rows.map { NSDecimalNumber(decimal: $0.amount).doubleValue }
    #expect(abs(amounts[0] - -34.48) < 0.000001)
    #expect(abs(amounts[1] - -2.53) < 0.000001)
    #expect(rows.map(\.reviewStatus) == [.pending, .pending])
    #expect(rows.allSatisfy { $0.importOrigin?.id == 1 })
}

@Test
func bootstrapBackfillsLegacyVenmoStagedImportsUsingStoredProfileSemantics() throws {
    let databaseURL = try temporaryDatabaseURL()
    let accountID = UUID(uuidString: "00000000-0000-0000-0000-000000000802")!
    try createWorkspaceWithLegacyVenmoStagedImportMissingDecisionColumns(at: databaseURL, accountID: accountID)
    let store = try WorkspaceStore.at(databaseURL: databaseURL)

    try store.bootstrap()
    let row = try #require(try store.fetchTransactionLedger(filter: .empty).first)

    #expect(row.rawDescription == "Groceries")
    #expect(row.merchantName == "jordan example")
    #expect(row.amount == Decimal(-135))
    #expect(row.reviewStatus == .pending)
    #expect(row.importOrigin?.id == 1)
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
func fetchPendingReviewItemsExcludesAcceptedLowConfidenceRowsEvenIfReviewItemStatusIsStillPending() throws {
    let databaseURL = try temporaryDatabaseURL()
    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()

    let account = try store.createAccount(named: "Checking", kind: .checking, institutionName: "Local Bank")
    let categoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000111")!
    try insertCategory(databaseURL: databaseURL, id: categoryID, name: "Groceries", kind: "expense")

    _ = try store.createStagedImportSession(
        StagedImportSessionDraft(
            accountID: account.id,
            originalFilename: "checking-april.csv",
            contentHash: "file-sha256",
            importedAt: Date(timeIntervalSince1970: 1_775_171_200),
            rows: [
                StagedSourceRowDraft(
                    sourceLineNumber: 2,
                    rawPayload: #"["2026-04-01","99PLEDG*ONIR BAWEJA","-25.00"]"#,
                    rowHash: "row-1-sha256",
                    validationStatus: .valid,
                    importDecision: .imported(reason: "New source row."),
                    classification: .reviewRequired(
                        prefill: nil,
                        source: nil,
                        sourceReference: nil,
                        confidence: nil,
                        reason: "No classification matched."
                    ),
                    normalizedMerchantName: "99pledg onir baweja",
                    transaction: StagedTransactionDraft(
                        transactionDate: Date(timeIntervalSince1970: 1_775_171_200),
                        rawDescription: "99PLEDG*ONIR BAWEJA",
                        normalizedMerchantName: "99pledg onir baweja",
                        amount: Decimal(-25)
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

    let reviewItem = try #require(try store.fetchPendingReviewItems().first)
    let transactionID = try #require(try reviewItemTransactionID(databaseURL: databaseURL, reviewItemID: reviewItem.id))
    try setTransactionAcceptedWithoutResolvingReviewItem(
        databaseURL: databaseURL,
        transactionID: transactionID,
        categoryID: categoryID
    )

    #expect(try store.fetchPendingReviewItems().isEmpty)
}

@Test
func fetchPendingReviewItemsExcludesHiddenLinkedTransactionsButKeepsTransactionlessItems() throws {
    let databaseURL = try temporaryDatabaseURL()
    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()

    let account = try store.createAccount(named: "Checking", kind: .checking, institutionName: "Local Bank")
    let duplicateTransactionID = UUID(uuidString: "00000000-0000-0000-0000-000000000421")!
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
                    rowHash: "row-duplicate-sha256",
                    validationStatus: .valid,
                    importDecision: .flaggedLikelyDuplicate(
                        existingTransactionID: duplicateTransactionID,
                        reason: "Same account, amount, normalized merchant, and nearby date."
                    )
                ),
                StagedSourceRowDraft(
                    sourceLineNumber: 3,
                    rawPayload: #"["2026-04-02","Neighborhood Market","-19.50"]"#,
                    rowHash: "row-review-sha256",
                    validationStatus: .valid,
                    importDecision: .imported(reason: "New source row."),
                    classification: .reviewRequired(
                        prefill: nil,
                        source: nil,
                        sourceReference: nil,
                        confidence: nil,
                        reason: "No classification matched."
                    ),
                    normalizedMerchantName: "neighborhood market",
                    transaction: StagedTransactionDraft(
                        transactionDate: Date(timeIntervalSince1970: 1_775_257_600),
                        rawDescription: "Neighborhood Market",
                        normalizedMerchantName: "neighborhood market",
                        amount: Decimal(-19.50)
                    )
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

    let pendingItems = try store.fetchPendingReviewItems()
    let linkedItem = try #require(pendingItems.first { $0.type == .lowConfidenceCategory })
    let linkedTransactionID = try #require(try reviewItemTransactionID(databaseURL: databaseURL, reviewItemID: linkedItem.id))
    try setTransactionHidden(
        databaseURL: databaseURL,
        transactionID: linkedTransactionID,
        isHidden: true
    )

    let remainingItems = try store.fetchPendingReviewItems()

    #expect(remainingItems.count == 1)
    #expect(remainingItems[0].type == .likelyDuplicate)
}

@Test
func fetchTransactionLedgerAppliesCoreFilters() throws {
    let databaseURL = try temporaryDatabaseURL()
    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()

    let checking = try store.createAccount(named: "Checking", kind: .checking, institutionName: "Local Bank")
    let card = try store.createAccount(named: "Card", kind: .creditCard, institutionName: "Visa")
    let groceries = UUID(uuidString: "00000000-0000-0000-0000-000000000111")!
    let travel = UUID(uuidString: "00000000-0000-0000-0000-000000000222")!
    try insertCategory(databaseURL: databaseURL, id: groceries, name: "Groceries", kind: "expense")
    try insertCategory(databaseURL: databaseURL, id: travel, name: "Travel", kind: "expense")
    let session = try store.createStagedImportSession(
        StagedImportSessionDraft(
            accountID: checking.id,
            originalFilename: "checking-april.csv",
            contentHash: "file-sha256",
            importedAt: Date(timeIntervalSince1970: 1_775_171_200),
            rows: [
                StagedSourceRowDraft(
                    sourceLineNumber: 2,
                    rawPayload: #"["2026-04-01","Berkeley Bowl","-42.20"]"#,
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

    let matchingID = UUID(uuidString: "00000000-0000-0000-0000-000000000301")!
    try insertLedgerTransaction(
        databaseURL: databaseURL,
        id: matchingID,
        accountID: checking.id,
        categoryID: groceries,
        importSessionID: session.id,
        rawDescription: "BERKELEY BOWL MARKET",
        normalizedMerchantName: "berkeley bowl",
        amount: Decimal(-42.20),
        transactionDate: Date(timeIntervalSince1970: 1_775_171_200),
        reviewStatus: "accepted"
    )
    try insertLedgerTransaction(
        databaseURL: databaseURL,
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000302")!,
        accountID: checking.id,
        categoryID: travel,
        importSessionID: session.id,
        rawDescription: "BART",
        normalizedMerchantName: "bart",
        amount: Decimal(-6.40),
        transactionDate: Date(timeIntervalSince1970: 1_775_257_600),
        reviewStatus: "accepted"
    )
    try insertLedgerTransaction(
        databaseURL: databaseURL,
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000303")!,
        accountID: card.id,
        categoryID: groceries,
        importSessionID: nil,
        rawDescription: "BERKELEY BOWL CARD",
        normalizedMerchantName: "berkeley bowl",
        amount: Decimal(-18.00),
        transactionDate: Date(timeIntervalSince1970: 1_775_171_200),
        reviewStatus: "pending"
    )

    let rows = try store.fetchTransactionLedger(
        filter: TransactionLedgerFilter(
            searchText: "bowl",
            startDate: Date(timeIntervalSince1970: 1_775_000_000),
            endDate: Date(timeIntervalSince1970: 1_775_200_000),
            accountID: checking.id,
            categoryID: groceries,
            reviewStatus: .accepted,
            importSessionID: session.id
        )
    )

    #expect(rows.map(\.id) == [matchingID])
    #expect(rows[0].accountName == "Checking")
    #expect(rows[0].categoryName == "Groceries")
    #expect(rows[0].importOrigin?.originalFilename == "checking-april.csv")
}

@Test
func fetchTransactionImportOriginsIsIndependentOfCurrentLedgerFilters() throws {
    let databaseURL = try temporaryDatabaseURL()
    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()

    let account = try store.createAccount(named: "Checking", kind: .checking, institutionName: "Local Bank")
    let dining = UUID(uuidString: "00000000-0000-0000-0000-000000000111")!
    try insertCategory(databaseURL: databaseURL, id: dining, name: "Dining", kind: "expense")
    let aprilSession = try store.createStagedImportSession(
        StagedImportSessionDraft(
            accountID: account.id,
            originalFilename: "checking-april.csv",
            contentHash: "april-file-sha256",
            importedAt: Date(timeIntervalSince1970: 1_775_171_200),
            rows: [],
            mapping: CSVColumnMapping(
                dateColumnIndex: 0,
                descriptionColumnIndex: 1,
                amount: .singleSignedAmount(columnIndex: 2)
            ),
            validRowCount: 0,
            invalidRowCount: 0,
            status: .staged
        )
    )
    let maySession = try store.createStagedImportSession(
        StagedImportSessionDraft(
            accountID: account.id,
            originalFilename: "checking-may.csv",
            contentHash: "may-file-sha256",
            importedAt: Date(timeIntervalSince1970: 1_777_849_600),
            rows: [],
            mapping: CSVColumnMapping(
                dateColumnIndex: 0,
                descriptionColumnIndex: 1,
                amount: .singleSignedAmount(columnIndex: 2)
            ),
            validRowCount: 0,
            invalidRowCount: 0,
            status: .staged
        )
    )
    try insertLedgerTransaction(
        databaseURL: databaseURL,
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000501")!,
        accountID: account.id,
        categoryID: dining,
        importSessionID: aprilSession.id,
        rawDescription: "APRIL TACO SHOP",
        normalizedMerchantName: "taco shop",
        amount: Decimal(-12.50),
        transactionDate: Date(timeIntervalSince1970: 1_775_171_200),
        reviewStatus: "accepted"
    )
    try insertLedgerTransaction(
        databaseURL: databaseURL,
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000502")!,
        accountID: account.id,
        categoryID: dining,
        importSessionID: maySession.id,
        rawDescription: "MAY TACO SHOP",
        normalizedMerchantName: "taco shop",
        amount: Decimal(-15.00),
        transactionDate: Date(timeIntervalSince1970: 1_777_849_600),
        reviewStatus: "accepted"
    )

    let aprilRows = try store.fetchTransactionLedger(
        filter: TransactionLedgerFilter(importSessionID: aprilSession.id)
    )
    let origins = try store.fetchTransactionImportOrigins()

    #expect(aprilRows.map(\.importOrigin?.id) == [aprilSession.id])
    #expect(origins.map(\.id) == [maySession.id, aprilSession.id])
    #expect(origins.map(\.originalFilename) == ["checking-may.csv", "checking-april.csv"])
}

@Test
func fetchTransactionLedgerFiltersByDirectionAndCategoryGroup() throws {
    let databaseURL = try temporaryDatabaseURL()
    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()

    let checking = try store.createAccount(named: "Checking", kind: .checking, institutionName: "Local Bank")
    let food = UUID(uuidString: "00000000-0000-0000-0000-000000000201")!
    let travel = UUID(uuidString: "00000000-0000-0000-0000-000000000202")!
    let groceries = UUID(uuidString: "00000000-0000-0000-0000-000000000211")!
    let parking = UUID(uuidString: "00000000-0000-0000-0000-000000000212")!
    let incomeGroup = UUID(uuidString: "00000000-0000-0000-0000-000000000203")!
    let salary = UUID(uuidString: "00000000-0000-0000-0000-000000000213")!
    try insertCategoryGroup(databaseURL: databaseURL, id: food, name: "Food")
    try insertCategoryGroup(databaseURL: databaseURL, id: travel, name: "Travel")
    try insertCategoryGroup(databaseURL: databaseURL, id: incomeGroup, name: "Income Group")
    try insertCategory(databaseURL: databaseURL, id: groceries, name: "Groceries", kind: "expense", categoryGroupID: food)
    try insertCategory(databaseURL: databaseURL, id: parking, name: "Parking", kind: "expense", categoryGroupID: travel)
    try insertCategory(databaseURL: databaseURL, id: salary, name: "Salary", kind: "income", categoryGroupID: incomeGroup)

    let groceryID = UUID(uuidString: "00000000-0000-0000-0000-000000000401")!
    let paycheckID = UUID(uuidString: "00000000-0000-0000-0000-000000000402")!
    let parkingID = UUID(uuidString: "00000000-0000-0000-0000-000000000403")!
    let bonusID = UUID(uuidString: "00000000-0000-0000-0000-000000000404")!
    try insertLedgerTransaction(
        databaseURL: databaseURL,
        id: groceryID,
        accountID: checking.id,
        categoryID: groceries,
        importSessionID: nil,
        rawDescription: "Groceries",
        normalizedMerchantName: "groceries",
        amount: Decimal(-48),
        transactionDate: Date(timeIntervalSince1970: 1_775_171_200),
        reviewStatus: "accepted"
    )
    try insertLedgerTransaction(
        databaseURL: databaseURL,
        id: paycheckID,
        accountID: checking.id,
        categoryID: salary,
        importSessionID: nil,
        rawDescription: "Payroll",
        normalizedMerchantName: "payroll",
        amount: Decimal(1800),
        transactionDate: Date(timeIntervalSince1970: 1_775_171_200),
        reviewStatus: "accepted",
        direction: "income"
    )
    try insertLedgerTransaction(
        databaseURL: databaseURL,
        id: parkingID,
        accountID: checking.id,
        categoryID: parking,
        importSessionID: nil,
        rawDescription: "Parking",
        normalizedMerchantName: "parking",
        amount: Decimal(-12),
        transactionDate: Date(timeIntervalSince1970: 1_775_171_200),
        reviewStatus: "accepted"
    )
    try insertLedgerTransaction(
        databaseURL: databaseURL,
        id: bonusID,
        accountID: checking.id,
        categoryID: salary,
        importSessionID: nil,
        rawDescription: "Bonus",
        normalizedMerchantName: "bonus",
        amount: Decimal(200),
        transactionDate: Date(timeIntervalSince1970: 1_775_171_200),
        reviewStatus: "accepted",
        direction: "income"
    )

    let rows = try store.fetchTransactionLedger(
        filter: TransactionLedgerFilter(
            categoryGroupID: food,
            direction: .expense
        )
    )

    #expect(rows.map(\.id) == [groceryID])
}

@Test
func transactionDetailIncludesExplanationFieldsAndEditableValuesRoundTrip() throws {
    let databaseURL = try temporaryDatabaseURL()
    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()

    let account = try store.createAccount(named: "Checking", kind: .checking, institutionName: "Local Bank")
    let dining = UUID(uuidString: "00000000-0000-0000-0000-000000000111")!
    let groceries = UUID(uuidString: "00000000-0000-0000-0000-000000000222")!
    try insertCategory(databaseURL: databaseURL, id: dining, name: "Dining", kind: "expense")
    try insertCategory(databaseURL: databaseURL, id: groceries, name: "Groceries", kind: "expense")
    let session = try store.createStagedImportSession(
        StagedImportSessionDraft(
            accountID: account.id,
            originalFilename: "checking-april.csv",
            contentHash: "file-sha256",
            importedAt: Date(timeIntervalSince1970: 1_775_171_200),
            rows: [],
            mapping: CSVColumnMapping(
                dateColumnIndex: 0,
                descriptionColumnIndex: 1,
                amount: .singleSignedAmount(columnIndex: 2)
            ),
            validRowCount: 0,
            invalidRowCount: 0,
            status: .staged
        )
    )
    let transactionID = UUID(uuidString: "00000000-0000-0000-0000-000000000401")!
    try insertLedgerTransaction(
        databaseURL: databaseURL,
        id: transactionID,
        accountID: account.id,
        categoryID: dining,
        importSessionID: session.id,
        rawDescription: "SQ *TACO SHOP",
        normalizedMerchantName: "taco shop",
        amount: Decimal(-12.50),
        transactionDate: Date(timeIntervalSince1970: 1_775_171_200),
        reviewStatus: "accepted",
        decisionSource: "rule",
        decisionSourceReference: "rule-123",
        confidence: 0.98,
        notes: "old note"
    )

    try store.updateTransactionLedgerFields(
        id: transactionID,
        draft: TransactionLedgerEditDraft(
            merchantName: "Neighborhood Tacos",
            categoryID: groceries,
            notes: "weekly lunch"
        )
    )
    let detail = try #require(try store.fetchTransactionDetail(id: transactionID))

    #expect(detail.row.merchantName == "Neighborhood Tacos")
    #expect(detail.row.categoryID == groceries)
    #expect(detail.row.categoryName == "Groceries")
    #expect(detail.notes == "weekly lunch")
    #expect(detail.decisionSource == .rule)
    #expect(detail.decisionSourceReference == "rule-123")
    #expect(detail.confidence == 0.98)
    #expect(detail.importOrigin?.id == session.id)
    #expect(detail.importOrigin?.originalFilename == "checking-april.csv")
}

@Test
func updateTransactionLedgerFieldsAcceptsPendingTransactionWithCategory() throws {
    let databaseURL = try temporaryDatabaseURL()
    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()

    let account = try store.createAccount(named: "Checking", kind: .checking, institutionName: "Local Bank")
    let categoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000111")!
    try insertCategory(databaseURL: databaseURL, id: categoryID, name: "Groceries", kind: "expense")
    let transactionID = UUID(uuidString: "00000000-0000-0000-0000-000000000412")!
    try insertLedgerTransaction(
        databaseURL: databaseURL,
        id: transactionID,
        accountID: account.id,
        categoryID: nil,
        importSessionID: nil,
        rawDescription: "Market",
        normalizedMerchantName: "market",
        amount: Decimal(-31.25),
        transactionDate: Date(timeIntervalSince1970: 1_775_171_200),
        reviewStatus: "pending"
    )

    try store.updateTransactionLedgerFields(
        id: transactionID,
        draft: TransactionLedgerEditDraft(
            merchantName: "Market",
            categoryID: categoryID,
            notes: nil
        )
    )

    let detail = try #require(try store.fetchTransactionDetail(id: transactionID))
    let report = try store.fetchMonthlyReport(referenceDate: Date(timeIntervalSince1970: 1_775_171_200))

    #expect(detail.row.reviewStatus == .accepted)
    #expect(report.currentMonthAcceptedSpend == Decimal(31.25))
}

@Test
func fetchTransactionDetailAcceptsCuratedPrefillDecisionSource() throws {
    let databaseURL = try temporaryDatabaseURL()
    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()

    let account = try store.createAccount(named: "Checking", kind: .checking, institutionName: "Local Bank")
    let categoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000111")!
    try insertCategory(databaseURL: databaseURL, id: categoryID, name: "Groceries", kind: "expense")
    let transactionID = UUID(uuidString: "00000000-0000-0000-0000-000000000414")!
    try insertLedgerTransaction(
        databaseURL: databaseURL,
        id: transactionID,
        accountID: account.id,
        categoryID: categoryID,
        importSessionID: nil,
        rawDescription: "Market",
        normalizedMerchantName: "market",
        amount: Decimal(-31.25),
        transactionDate: Date(timeIntervalSince1970: 1_775_171_200),
        reviewStatus: "accepted",
        decisionSource: ClassificationDecisionSource.curatedPrefill.rawValue,
        decisionSourceReference: "starter:market",
        confidence: nil
    )

    let detail = try #require(try store.fetchTransactionDetail(id: transactionID))

    #expect(detail.decisionSource == .curatedPrefill)
    #expect(detail.decisionSourceReference == "starter:market")
    #expect(detail.confidence == nil)
}

@Test
func updateTransactionLedgerFieldsAcceptingPendingTransactionResolvesLinkedReviewItem() throws {
    let databaseURL = try temporaryDatabaseURL()
    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()

    let account = try store.createAccount(named: "Checking", kind: .checking, institutionName: "Local Bank")
    let categoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000111")!
    try insertCategory(databaseURL: databaseURL, id: categoryID, name: "Groceries", kind: "expense")

    _ = try store.createStagedImportSession(
        StagedImportSessionDraft(
            accountID: account.id,
            originalFilename: "checking-april.csv",
            contentHash: "file-sha256",
            importedAt: Date(timeIntervalSince1970: 1_775_171_200),
            rows: [
                StagedSourceRowDraft(
                    sourceLineNumber: 2,
                    rawPayload: #"["2026-04-01","99PLEDG*ONIR BAWEJA","-25.00"]"#,
                    rowHash: "row-1-sha256",
                    validationStatus: .valid,
                    importDecision: .imported(reason: "New source row."),
                    classification: .reviewRequired(
                        prefill: nil,
                        source: nil,
                        sourceReference: nil,
                        confidence: nil,
                        reason: "No classification matched."
                    ),
                    normalizedMerchantName: "99pledg onir baweja",
                    transaction: StagedTransactionDraft(
                        transactionDate: Date(timeIntervalSince1970: 1_775_171_200),
                        rawDescription: "99PLEDG*ONIR BAWEJA",
                        normalizedMerchantName: "99pledg onir baweja",
                        amount: Decimal(-25)
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

    let reviewItem = try #require(try store.fetchPendingReviewItems().first)
    let transactionID = try #require(try reviewItemTransactionID(databaseURL: databaseURL, reviewItemID: reviewItem.id))

    try store.updateTransactionLedgerFields(
        id: transactionID,
        draft: TransactionLedgerEditDraft(
            merchantName: "99PLEDG",
            categoryID: categoryID,
            notes: nil
        )
    )

    #expect(try fetchReviewItemStatus(databaseURL: databaseURL, reviewItemID: reviewItem.id) == .resolved)
    #expect(try store.fetchPendingReviewItems().isEmpty)
}


@Test
func updateTransactionLedgerFieldsClearsDecisionSourceReferenceWhenPendingTransactionPromotedToUser() throws {
    let databaseURL = try temporaryDatabaseURL()
    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()

    let account = try store.createAccount(named: "Checking", kind: .checking, institutionName: "Local Bank")
    let categoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000111")!
    try insertCategory(databaseURL: databaseURL, id: categoryID, name: "Groceries", kind: "expense")
    let transactionID = UUID(uuidString: "00000000-0000-0000-0000-000000000414")!
    try insertLedgerTransaction(
        databaseURL: databaseURL,
        id: transactionID,
        accountID: account.id,
        categoryID: nil,
        importSessionID: nil,
        rawDescription: "Market",
        normalizedMerchantName: "market",
        amount: Decimal(-31.25),
        transactionDate: Date(timeIntervalSince1970: 1_775_171_200),
        reviewStatus: "pending",
        decisionSource: ClassificationDecisionSource.curatedPrefill.rawValue,
        decisionSourceReference: "starter:market",
        confidence: nil
    )

    try store.updateTransactionLedgerFields(
        id: transactionID,
        draft: TransactionLedgerEditDraft(
            merchantName: "Market",
            categoryID: categoryID,
            notes: nil
        )
    )

    let detail = try #require(try store.fetchTransactionDetail(id: transactionID))

    #expect(detail.decisionSource == .user)
    #expect(detail.decisionSourceReference == nil)
    #expect(detail.confidence == 1.0)
    #expect(detail.row.reviewStatus == .accepted)
}

@Test
func updateTransactionLedgerFieldsPromotesAcceptedStarterDerivedTransactionToUserWhenEdited() throws {
    let databaseURL = try temporaryDatabaseURL()
    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()

    let account = try store.createAccount(named: "Checking", kind: .checking, institutionName: "Local Bank")
    let categoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000111")!
    try insertCategory(databaseURL: databaseURL, id: categoryID, name: "Groceries", kind: "expense")
    let transactionID = UUID(uuidString: "00000000-0000-0000-0000-000000000415")!
    try insertLedgerTransaction(
        databaseURL: databaseURL,
        id: transactionID,
        accountID: account.id,
        categoryID: categoryID,
        importSessionID: nil,
        rawDescription: "Market",
        normalizedMerchantName: "market",
        amount: Decimal(-31.25),
        transactionDate: Date(timeIntervalSince1970: 1_775_171_200),
        reviewStatus: "accepted",
        decisionSource: ClassificationDecisionSource.curatedPrefill.rawValue,
        decisionSourceReference: "starter:market",
        confidence: nil
    )

    try store.updateTransactionLedgerFields(
        id: transactionID,
        draft: TransactionLedgerEditDraft(
            merchantName: "Neighborhood Market",
            categoryID: categoryID,
            notes: nil
        )
    )

    let detail = try #require(try store.fetchTransactionDetail(id: transactionID))

    #expect(detail.row.merchantName == "Neighborhood Market")
    #expect(detail.decisionSource == .user)
    #expect(detail.decisionSourceReference == nil)
    #expect(detail.confidence == 1.0)
    #expect(detail.row.reviewStatus == .accepted)
}

@Test
func updateTransactionLedgerFieldsPromotesAcceptedSuggestionTransactionToUserWhenEdited() throws {
    let databaseURL = try temporaryDatabaseURL()
    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()

    let account = try store.createAccount(named: "Checking", kind: .checking, institutionName: "Local Bank")
    let categoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000111")!
    try insertCategory(databaseURL: databaseURL, id: categoryID, name: "Groceries", kind: "expense")
    let transactionID = UUID(uuidString: "00000000-0000-0000-0000-000000000416")!
    try insertLedgerTransaction(
        databaseURL: databaseURL,
        id: transactionID,
        accountID: account.id,
        categoryID: categoryID,
        importSessionID: nil,
        rawDescription: "Market",
        normalizedMerchantName: "market",
        amount: Decimal(-31.25),
        transactionDate: Date(timeIntervalSince1970: 1_775_171_200),
        reviewStatus: "accepted",
        decisionSource: ClassificationDecisionSource.suggestion.rawValue,
        decisionSourceReference: "suggestion:market",
        confidence: 0.91
    )

    try store.updateTransactionLedgerFields(
        id: transactionID,
        draft: TransactionLedgerEditDraft(
            merchantName: "Neighborhood Market",
            categoryID: categoryID,
            notes: nil
        )
    )

    let detail = try #require(try store.fetchTransactionDetail(id: transactionID))

    #expect(detail.row.merchantName == "Neighborhood Market")
    #expect(detail.decisionSource == .user)
    #expect(detail.decisionSourceReference == nil)
    #expect(detail.confidence == 1.0)
    #expect(detail.row.reviewStatus == .accepted)
}

@Test
func bootstrapAcceptsPreviouslyUserCategorizedPendingTransactions() throws {
    let databaseURL = try temporaryDatabaseURL()
    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()

    let account = try store.createAccount(named: "Checking", kind: .checking, institutionName: "Local Bank")
    let categoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000111")!
    try insertCategory(databaseURL: databaseURL, id: categoryID, name: "Groceries", kind: "expense")
    let transactionID = UUID(uuidString: "00000000-0000-0000-0000-000000000413")!
    try insertLedgerTransaction(
        databaseURL: databaseURL,
        id: transactionID,
        accountID: account.id,
        categoryID: categoryID,
        importSessionID: nil,
        rawDescription: "Market",
        normalizedMerchantName: "market",
        amount: Decimal(-28.40),
        transactionDate: Date(timeIntervalSince1970: 1_775_171_200),
        reviewStatus: "pending",
        decisionSource: "user",
        decisionSourceReference: "starter:market",
        confidence: 1.0
    )
    let queue = try DatabaseQueue(path: databaseURL.path)
    try queue.write { db in
        try db.execute(
            sql: "DELETE FROM grdb_migrations WHERE identifier = ?",
            arguments: ["accept-user-categorized-pending-transactions"]
        )
    }

    try store.bootstrap()

    let detail = try #require(try store.fetchTransactionDetail(id: transactionID))
    let report = try store.fetchMonthlyReport(referenceDate: Date(timeIntervalSince1970: 1_775_171_200))

    #expect(detail.row.reviewStatus == .accepted)
    #expect(detail.decisionSourceReference == nil)
    #expect(report.currentMonthAcceptedSpend == Decimal(28.40))
}

@Test
func bootstrapAddsHiddenFlagAndDefaultsLegacyTransactionsToIncluded() throws {
    let databaseURL = try temporaryDatabaseURL()
    try createWorkspaceAfterWorkspacePreferencesMigration(at: databaseURL)
    let accountID = UUID(uuidString: "00000000-0000-0000-0000-000000000417")!
    let transactionID = UUID(uuidString: "00000000-0000-0000-0000-000000000418")!
    let queue = try DatabaseQueue(path: databaseURL.path)
    try queue.write { db in
        try db.execute(
            sql: """
            INSERT INTO accounts (id, name, kind, institution_name, created_at)
            VALUES (?, ?, ?, ?, ?)
            """,
            arguments: [
                accountID.uuidString,
                "Checking",
                "checking",
                "Local Bank",
                Date(timeIntervalSince1970: 1_775_171_200),
            ]
        )
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
                transactionID.uuidString,
                accountID.uuidString,
                "Legacy grocery",
                "legacy grocery",
                -12.50,
                Date(timeIntervalSince1970: 1_775_171_200),
                "expense",
                "user",
                "accepted",
                "none",
            ]
        )
    }

    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()

    let rows = try store.fetchTransactionLedger(filter: .empty)
    let row = try #require(rows.first)
    let hiddenColumn = try queue.read { db in
        try Bool.fetchOne(
            db,
            sql: "SELECT is_hidden FROM transactions WHERE id = ?",
            arguments: [transactionID.uuidString]
        )
    }

    #expect(row.id == transactionID)
    #expect(row.isHidden == false)
    #expect(hiddenColumn == false)
}

@Test
func bootstrapRewritesLegacyRejectedTransactionsToPendingAndKeepsThemReadable() throws {
    let databaseURL = try temporaryDatabaseURL()
    try createWorkspaceAfterWorkspacePreferencesMigration(at: databaseURL)
    let accountID = UUID(uuidString: "00000000-0000-0000-0000-000000000419")!
    let transactionID = UUID(uuidString: "00000000-0000-0000-0000-000000000420")!
    let queue = try DatabaseQueue(path: databaseURL.path)
    try queue.write { db in
        try db.execute(
            sql: """
            INSERT INTO accounts (id, name, kind, institution_name, created_at)
            VALUES (?, ?, ?, ?, ?)
            """,
            arguments: [
                accountID.uuidString,
                "Checking",
                "checking",
                "Local Bank",
                Date(timeIntervalSince1970: 1_775_171_200),
            ]
        )
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
                transactionID.uuidString,
                accountID.uuidString,
                "Legacy rejected row",
                "legacy rejected row",
                -18.00,
                Date(timeIntervalSince1970: 1_775_171_200),
                "expense",
                "user",
                "rejected",
                "none",
            ]
        )
    }

    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()

    let detail = try #require(try store.fetchTransactionDetail(id: transactionID))
    let storedStatus = try queue.read { db in
        try String.fetchOne(
            db,
            sql: "SELECT review_status FROM transactions WHERE id = ?",
            arguments: [transactionID.uuidString]
        )
    }

    #expect(detail.row.reviewStatus == .pending)
    #expect(detail.row.isHidden == false)
    #expect(storedStatus == TransactionReviewStatus.pending.rawValue)
}

@Test
func monthlyReportCountsIncludedCurrentMonthExpensesExcludingHiddenRows() throws {
    let databaseURL = try temporaryDatabaseURL()
    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()

    let account = try store.createAccount(named: "Checking", kind: .checking, institutionName: "Local Bank")
    let groceries = UUID(uuidString: "00000000-0000-0000-0000-000000000111")!
    try insertCategory(databaseURL: databaseURL, id: groceries, name: "Groceries", kind: "expense")
    try insertLedgerTransaction(
        databaseURL: databaseURL,
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000601")!,
        accountID: account.id,
        categoryID: groceries,
        importSessionID: nil,
        rawDescription: "Current accepted expense",
        normalizedMerchantName: "current accepted expense",
        amount: Decimal(-42.50),
        transactionDate: Date(timeIntervalSince1970: 1_775_171_200),
        reviewStatus: "accepted"
    )
    try insertLedgerTransaction(
        databaseURL: databaseURL,
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000602")!,
        accountID: account.id,
        categoryID: groceries,
        importSessionID: nil,
        rawDescription: "Pending expense",
        normalizedMerchantName: "pending expense",
        amount: Decimal(-100.00),
        transactionDate: Date(timeIntervalSince1970: 1_775_257_600),
        reviewStatus: "pending"
    )
    try insertLedgerTransaction(
        databaseURL: databaseURL,
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000603")!,
        accountID: account.id,
        categoryID: groceries,
        importSessionID: nil,
        rawDescription: "Income",
        normalizedMerchantName: "income",
        amount: Decimal(500.00),
        transactionDate: Date(timeIntervalSince1970: 1_775_257_600),
        reviewStatus: "accepted"
    )
    try insertLedgerTransaction(
        databaseURL: databaseURL,
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000604")!,
        accountID: account.id,
        categoryID: groceries,
        importSessionID: nil,
        rawDescription: "Last month accepted expense",
        normalizedMerchantName: "last month accepted expense",
        amount: Decimal(-25.00),
        transactionDate: Date(timeIntervalSince1970: 1_772_492_400),
        reviewStatus: "accepted"
    )

    let report = try store.fetchMonthlyReport(referenceDate: Date(timeIntervalSince1970: 1_775_171_200))

    #expect(report.currentMonthAcceptedSpend == Decimal(142.50))
    #expect(report.lastMonthAcceptedSpend == Decimal(25.00))
    #expect(report.pendingReviewCount == 0)
}

@Test
func targetProgressSupportsCategoryAndCategoryGroupTargets() throws {
    let databaseURL = try temporaryDatabaseURL()
    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()

    let account = try store.createAccount(named: "Checking", kind: .checking, institutionName: "Local Bank")
    let foodGroupID = UUID(uuidString: "00000000-0000-0000-0000-000000000701")!
    let travelGroupID = UUID(uuidString: "00000000-0000-0000-0000-000000000702")!
    let groceries = UUID(uuidString: "00000000-0000-0000-0000-000000000711")!
    let dining = UUID(uuidString: "00000000-0000-0000-0000-000000000712")!
    let travel = UUID(uuidString: "00000000-0000-0000-0000-000000000713")!
    let groceryTarget = UUID(uuidString: "00000000-0000-0000-0000-000000000721")!
    let travelTarget = UUID(uuidString: "00000000-0000-0000-0000-000000000722")!
    try insertCategoryGroup(databaseURL: databaseURL, id: foodGroupID, name: "Food")
    try insertCategoryGroup(databaseURL: databaseURL, id: travelGroupID, name: "Travel")
    try insertCategory(databaseURL: databaseURL, id: groceries, name: "Groceries", kind: "expense", categoryGroupID: foodGroupID)
    try insertCategory(databaseURL: databaseURL, id: dining, name: "Dining", kind: "expense", categoryGroupID: foodGroupID)
    try insertCategory(databaseURL: databaseURL, id: travel, name: "Flights", kind: "expense", categoryGroupID: travelGroupID)
    try insertTarget(databaseURL: databaseURL, id: groceryTarget, categoryID: groceries, categoryGroupID: nil, monthlyLimit: Decimal(100))
    try insertTarget(databaseURL: databaseURL, id: travelTarget, categoryID: nil, categoryGroupID: travelGroupID, monthlyLimit: Decimal(250))
    try insertLedgerTransaction(
        databaseURL: databaseURL,
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000731")!,
        accountID: account.id,
        categoryID: groceries,
        importSessionID: nil,
        rawDescription: "Groceries",
        normalizedMerchantName: "groceries",
        amount: Decimal(-40),
        transactionDate: Date(timeIntervalSince1970: 1_775_171_200),
        reviewStatus: "accepted"
    )
    try insertLedgerTransaction(
        databaseURL: databaseURL,
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000732")!,
        accountID: account.id,
        categoryID: dining,
        importSessionID: nil,
        rawDescription: "Dining",
        normalizedMerchantName: "dining",
        amount: Decimal(-60),
        transactionDate: Date(timeIntervalSince1970: 1_775_257_600),
        reviewStatus: "accepted"
    )
    try insertLedgerTransaction(
        databaseURL: databaseURL,
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000733")!,
        accountID: account.id,
        categoryID: travel,
        importSessionID: nil,
        rawDescription: "Travel",
        normalizedMerchantName: "travel",
        amount: Decimal(-200),
        transactionDate: Date(timeIntervalSince1970: 1_775_257_600),
        reviewStatus: "accepted"
    )

    let report = try store.fetchMonthlyReport(referenceDate: Date(timeIntervalSince1970: 1_775_171_200))

    #expect(report.targets.map(\.name) == ["Groceries", "Travel"])
    #expect(report.targets.map(\.spent) == [Decimal(40), Decimal(200)])
    #expect(report.targets.map(\.remaining) == [Decimal(60), Decimal(50)])
    #expect(report.targets.map(\.monthlyLimit) == [Decimal(100), Decimal(250)])
}

@Test
func stagedImportCreatesClassificationReviewItemsForRowsNeedingReview() throws {
    let databaseURL = try temporaryDatabaseURL()
    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()

    let account = try store.createAccount(named: "Checking", kind: .checking, institutionName: "Local Bank")
    let categoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000111")!

    _ = try store.createStagedImportSession(
        StagedImportSessionDraft(
            accountID: account.id,
            originalFilename: "checking-april.csv",
            contentHash: "file-sha256",
            importedAt: Date(timeIntervalSince1970: 1_775_171_200),
            rows: [
                StagedSourceRowDraft(
                    sourceLineNumber: 2,
                    rawPayload: #"["2026-04-01","SQ *Coffee Shop","-4.75"]"#,
                    rowHash: "row-1-sha256",
                    validationStatus: .valid,
                    importDecision: .imported(reason: "New source row."),
                    classification: .reviewRequired(
                        prefill: ClassificationAssignment(
                            categoryID: categoryID,
                            merchantName: "Coffee Shop"
                        ),
                        source: .heuristic,
                        sourceReference: nil,
                        confidence: 0.65,
                        reason: "Deterministic heuristic requires review."
                    ),
                    normalizedMerchantName: "coffee shop"
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
    #expect(reviewItems[0].type == .lowConfidenceCategory)
    #expect(reviewItems[0].sourceRow.rowHash == "row-1-sha256")
    #expect(reviewItems[0].classification?.normalizedMerchantName == "coffee shop")
    #expect(reviewItems[0].classification?.prefill?.categoryID == categoryID)
    #expect(reviewItems[0].classification?.prefill?.merchantName == "Coffee Shop")
    #expect(reviewItems[0].reason == "Deterministic heuristic requires review.")
}

@Test
func fetchPendingReviewItemsAcceptsCuratedPrefillClassificationSource() throws {
    let databaseURL = try temporaryDatabaseURL()
    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()

    let account = try store.createAccount(named: "Checking", kind: .checking, institutionName: "Local Bank")
    let categoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000111")!

    _ = try store.createStagedImportSession(
        StagedImportSessionDraft(
            accountID: account.id,
            originalFilename: "checking-april.csv",
            contentHash: "file-sha256",
            importedAt: Date(timeIntervalSince1970: 1_775_171_200),
            rows: [
                StagedSourceRowDraft(
                    sourceLineNumber: 2,
                    rawPayload: #"["2026-04-01","SQ *Coffee Shop","-4.75"]"#,
                    rowHash: "row-1-sha256",
                    validationStatus: .valid,
                    importDecision: .imported(reason: "New source row."),
                    classification: .reviewRequired(
                        prefill: ClassificationAssignment(
                            categoryID: categoryID,
                            merchantName: "Coffee Shop"
                        ),
                        source: .curatedPrefill,
                        sourceReference: "starter:coffee-shop",
                        confidence: nil,
                        reason: "Curated starter match requires review before acceptance."
                    ),
                    normalizedMerchantName: "coffee shop"
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

    let reviewItem = try #require(try store.fetchPendingReviewItems().first)

    #expect(reviewItem.classification?.source == .curatedPrefill)
    #expect(reviewItem.classification?.sourceReference == "starter:coffee-shop")
    #expect(reviewItem.classification?.confidence == nil)
}

@Test
func approveClassificationReviewItemResolvesReviewAndPersistsLearnedRule() throws {
    let databaseURL = try temporaryDatabaseURL()
    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()

    let account = try store.createAccount(named: "Checking", kind: .checking, institutionName: "Local Bank")
    let categoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000111")!
    try insertCategory(databaseURL: databaseURL, id: categoryID, name: "Coffee", kind: "expense")
    _ = try store.createStagedImportSession(
        StagedImportSessionDraft(
            accountID: account.id,
            originalFilename: "checking-april.csv",
            contentHash: "file-sha256",
            importedAt: Date(timeIntervalSince1970: 1_775_171_200),
            rows: [
                StagedSourceRowDraft(
                    sourceLineNumber: 2,
                    rawPayload: #"["2026-04-01","SQ *Coffee Shop","-4.75"]"#,
                    rowHash: "row-1-sha256",
                    validationStatus: .valid,
                    importDecision: .imported(reason: "New source row."),
                    classification: .reviewRequired(
                        prefill: nil,
                        source: nil,
                        sourceReference: nil,
                        confidence: nil,
                        reason: "No classification matched."
                    ),
                    normalizedMerchantName: "coffee shop"
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
    let reviewItemID = try #require(try store.fetchPendingReviewItems().first?.id)
    let resolvedAt = Date(timeIntervalSince1970: 1_775_171_260)

    let event = try store.approveClassificationReviewItem(
        id: reviewItemID,
        assignment: ClassificationAssignment(
            categoryID: categoryID,
            merchantName: "Coffee Shop"
        ),
        ruleLearning: .exactNormalizedMerchant(pattern: "coffee shop"),
        resolvedAt: resolvedAt
    )

    #expect(try store.fetchPendingReviewItems().isEmpty)
    #expect(event.reviewItemID == reviewItemID)
    #expect(event.action == .approveSuggestion)
    #expect(event.createdAt == resolvedAt)
    let rules = try store.fetchClassificationRules()
    #expect(rules.count == 1)
    #expect(rules[0].merchantPattern == "coffee shop")
    #expect(rules[0].categoryID == categoryID)
    #expect(rules[0].merchantName == "Coffee Shop")
    #expect(rules[0].matchKind == .exactNormalizedMerchant)
}

@Test
func approveClassificationReviewItemUpdatesLinkedTransaction() throws {
    let databaseURL = try temporaryDatabaseURL()
    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()

    let account = try store.createAccount(named: "Checking", kind: .checking, institutionName: "Local Bank")
    let categoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000111")!
    try insertCategory(databaseURL: databaseURL, id: categoryID, name: "Coffee", kind: "expense")
    _ = try store.createStagedImportSession(
        StagedImportSessionDraft(
            accountID: account.id,
            originalFilename: "checking-april.csv",
            contentHash: "file-sha256",
            importedAt: Date(timeIntervalSince1970: 1_775_171_200),
            rows: [
                StagedSourceRowDraft(
                    sourceLineNumber: 2,
                    rawPayload: #"["2026-04-01","SQ *Coffee Shop","-4.75"]"#,
                    rowHash: "row-1-sha256",
                    validationStatus: .valid,
                    importDecision: .imported(reason: "New source row."),
                    classification: .reviewRequired(
                        prefill: nil,
                        source: nil,
                        sourceReference: nil,
                        confidence: nil,
                        reason: "No classification matched."
                    ),
                    normalizedMerchantName: "coffee shop",
                    transaction: StagedTransactionDraft(
                        transactionDate: Date(timeIntervalSince1970: 1_775_171_200),
                        rawDescription: "SQ *Coffee Shop",
                        normalizedMerchantName: "coffee shop",
                        amount: Decimal(-4.75)
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
    let reviewItem = try #require(try store.fetchPendingReviewItems().first)

    _ = try store.approveClassificationReviewItem(
        id: reviewItem.id,
        assignment: ClassificationAssignment(categoryID: categoryID, merchantName: "Coffee Shop"),
        ruleLearning: nil,
        resolvedAt: Date(timeIntervalSince1970: 1_775_200_000)
    )
    let row = try #require(try store.fetchTransactionLedger(filter: .empty).first)

    #expect(row.reviewStatus == .accepted)
    #expect(row.categoryID == categoryID)
    #expect(row.categoryName == "Coffee")
    #expect(row.merchantName == "Coffee Shop")
}

@Test
func approveClassificationReviewItemClearsDecisionSourceReferenceWhenPromotingTransactionToUser() throws {
    let databaseURL = try temporaryDatabaseURL()
    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()

    let account = try store.createAccount(named: "Checking", kind: .checking, institutionName: "Local Bank")
    let categoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000111")!
    try insertCategory(databaseURL: databaseURL, id: categoryID, name: "Coffee", kind: "expense")
    _ = try store.createStagedImportSession(
        StagedImportSessionDraft(
            accountID: account.id,
            originalFilename: "checking-april.csv",
            contentHash: "file-sha256",
            importedAt: Date(timeIntervalSince1970: 1_775_171_200),
            rows: [
                StagedSourceRowDraft(
                    sourceLineNumber: 2,
                    rawPayload: #"["2026-04-01","SQ *Coffee Shop","-4.75"]"#,
                    rowHash: "row-1-sha256",
                    validationStatus: .valid,
                    importDecision: .imported(reason: "New source row."),
                    classification: .reviewRequired(
                        prefill: ClassificationAssignment(
                            categoryID: categoryID,
                            merchantName: "Coffee Shop"
                        ),
                        source: .curatedPrefill,
                        sourceReference: "starter:coffee-shop",
                        confidence: nil,
                        reason: "Curated starter match requires review before acceptance."
                    ),
                    normalizedMerchantName: "coffee shop",
                    transaction: StagedTransactionDraft(
                        transactionDate: Date(timeIntervalSince1970: 1_775_171_200),
                        rawDescription: "SQ *Coffee Shop",
                        normalizedMerchantName: "coffee shop",
                        amount: Decimal(-4.75)
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
    let reviewItem = try #require(try store.fetchPendingReviewItems().first)

    _ = try store.approveClassificationReviewItem(
        id: reviewItem.id,
        assignment: ClassificationAssignment(categoryID: categoryID, merchantName: "Coffee Shop"),
        ruleLearning: nil,
        resolvedAt: Date(timeIntervalSince1970: 1_775_200_000)
    )

    let row = try #require(try store.fetchTransactionLedger(filter: .empty).first)
    let detail = try #require(try store.fetchTransactionDetail(id: row.id))

    #expect(detail.decisionSource == .user)
    #expect(detail.decisionSourceReference == nil)
    #expect(detail.confidence == 1.0)
    #expect(detail.row.reviewStatus == .accepted)
}

@Test
func approveClassificationReviewItemCanPersistPrefixRule() throws {
    let databaseURL = try temporaryDatabaseURL()
    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()

    let account = try store.createAccount(named: "Checking", kind: .checking, institutionName: "Local Bank")
    let categoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000111")!
    try insertCategory(databaseURL: databaseURL, id: categoryID, name: "Charity", kind: "expense")
    _ = try store.createStagedImportSession(
        StagedImportSessionDraft(
            accountID: account.id,
            originalFilename: "checking-april.csv",
            contentHash: "file-sha256",
            importedAt: Date(timeIntervalSince1970: 1_775_171_200),
            rows: [
                StagedSourceRowDraft(
                    sourceLineNumber: 2,
                    rawPayload: #"["2026-04-01","99PLEDG*ONIR BAWEJA","-25.00"]"#,
                    rowHash: "row-1-sha256",
                    validationStatus: .valid,
                    importDecision: .imported(reason: "New source row."),
                    classification: .reviewRequired(
                        prefill: nil,
                        source: nil,
                        sourceReference: nil,
                        confidence: nil,
                        reason: "No classification matched."
                    ),
                    normalizedMerchantName: "99pledg onir baweja"
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
    let reviewItemID = try #require(try store.fetchPendingReviewItems().first?.id)

    _ = try store.approveClassificationReviewItem(
        id: reviewItemID,
        assignment: ClassificationAssignment(categoryID: categoryID, merchantName: "99Pledg"),
        ruleLearning: .prefixNormalizedMerchant(pattern: "99pledg"),
        resolvedAt: Date(timeIntervalSince1970: 1_775_171_260)
    )

    let rules = try store.fetchClassificationRules()
    #expect(rules.count == 1)
    #expect(rules[0].merchantPattern == "99pledg")
    #expect(rules[0].matchKind == .prefixNormalizedMerchant)
    #expect(rules[0].merchantName == "99Pledg")
}

@Test
func approveClassificationReviewItemWithExactLearnedRuleBackfillsMatchingExistingTransactions() throws {
    let databaseURL = try temporaryDatabaseURL()
    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()

    let account = try store.createAccount(named: "Checking", kind: .checking, institutionName: "Local Bank")
    let categoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000111")!
    let previousCategoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000222")!
    try insertCategory(databaseURL: databaseURL, id: categoryID, name: "Coffee", kind: "expense")
    try insertCategory(databaseURL: databaseURL, id: previousCategoryID, name: "Misc", kind: "expense")

    let matchingTransactionID = UUID(uuidString: "10000000-0000-0000-0000-000000000001")!
    let nonMatchingTransactionID = UUID(uuidString: "10000000-0000-0000-0000-000000000002")!
    try insertLedgerTransaction(
        databaseURL: databaseURL,
        id: matchingTransactionID,
        accountID: account.id,
        categoryID: previousCategoryID,
        importSessionID: nil,
        rawDescription: "SQ *Coffee Shop",
        normalizedMerchantName: "Coffee Shop",
        amount: Decimal(-8.75),
        transactionDate: Date(timeIntervalSince1970: 1_775_084_800),
        reviewStatus: "accepted",
        decisionSource: "heuristic",
        decisionSourceReference: "seeded:coffee"
    )
    try insertLedgerTransaction(
        databaseURL: databaseURL,
        id: nonMatchingTransactionID,
        accountID: account.id,
        categoryID: previousCategoryID,
        importSessionID: nil,
        rawDescription: "SQ *Coffee Shop Downtown",
        normalizedMerchantName: "coffee shop downtown",
        amount: Decimal(-9.25),
        transactionDate: Date(timeIntervalSince1970: 1_775_171_200),
        reviewStatus: "accepted",
        decisionSource: "heuristic",
        decisionSourceReference: "seeded:coffee"
    )

    _ = try store.createStagedImportSession(
        StagedImportSessionDraft(
            accountID: account.id,
            originalFilename: "checking-april.csv",
            contentHash: "file-sha256",
            importedAt: Date(timeIntervalSince1970: 1_775_257_600),
            rows: [
                StagedSourceRowDraft(
                    sourceLineNumber: 2,
                    rawPayload: #"["2026-04-03","SQ *Coffee Shop","-4.75"]"#,
                    rowHash: "row-1-sha256",
                    validationStatus: .valid,
                    importDecision: .imported(reason: "New source row."),
                    classification: .reviewRequired(
                        prefill: nil,
                        source: nil,
                        sourceReference: nil,
                        confidence: nil,
                        reason: "No classification matched."
                    ),
                    normalizedMerchantName: "coffee shop",
                    transaction: StagedTransactionDraft(
                        transactionDate: Date(timeIntervalSince1970: 1_775_257_600),
                        rawDescription: "SQ *Coffee Shop",
                        normalizedMerchantName: "coffee shop",
                        amount: Decimal(-4.75)
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

    let reviewItemID = try #require(try store.fetchPendingReviewItems().first?.id)
    _ = try store.approveClassificationReviewItem(
        id: reviewItemID,
        assignment: ClassificationAssignment(categoryID: categoryID, merchantName: "Coffee Shop"),
        ruleLearning: .exactNormalizedMerchant(pattern: "coffee shop"),
        resolvedAt: Date(timeIntervalSince1970: 1_775_257_660)
    )
    let learnedRule = try #require(try store.fetchClassificationRules().first)

    let matchingDetail = try #require(try store.fetchTransactionDetail(id: matchingTransactionID))
    #expect(matchingDetail.row.categoryID == categoryID)
    #expect(matchingDetail.row.categoryName == "Coffee")
    #expect(matchingDetail.row.merchantName == "Coffee Shop")
    #expect(matchingDetail.decisionSource == .rule)
    #expect(matchingDetail.decisionSourceReference == learnedRule.id.uuidString)
    #expect(matchingDetail.confidence == 1.0)
    #expect(matchingDetail.row.reviewStatus == .accepted)

    let nonMatchingDetail = try #require(try store.fetchTransactionDetail(id: nonMatchingTransactionID))
    #expect(nonMatchingDetail.row.categoryID == previousCategoryID)
    #expect(nonMatchingDetail.row.categoryName == "Misc")
    #expect(nonMatchingDetail.row.merchantName == "coffee shop downtown")
    #expect(nonMatchingDetail.decisionSource == .heuristic)
    #expect(nonMatchingDetail.decisionSourceReference == "seeded:coffee")
    #expect(nonMatchingDetail.confidence == nil)
}

@Test
func approveClassificationReviewItemWithPrefixLearnedRuleBackfillsMatchingExistingTransactions() throws {
    let databaseURL = try temporaryDatabaseURL()
    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()

    let account = try store.createAccount(named: "Checking", kind: .checking, institutionName: "Local Bank")
    let categoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000111")!
    let previousCategoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000222")!
    try insertCategory(databaseURL: databaseURL, id: categoryID, name: "Donations", kind: "expense")
    try insertCategory(databaseURL: databaseURL, id: previousCategoryID, name: "Misc", kind: "expense")

    let exactMatchTransactionID = UUID(uuidString: "10000000-0000-0000-0000-000000000011")!
    let prefixMatchTransactionID = UUID(uuidString: "10000000-0000-0000-0000-000000000012")!
    let nonMatchingTransactionID = UUID(uuidString: "10000000-0000-0000-0000-000000000013")!
    try insertLedgerTransaction(
        databaseURL: databaseURL,
        id: exactMatchTransactionID,
        accountID: account.id,
        categoryID: previousCategoryID,
        importSessionID: nil,
        rawDescription: "99PLEDG",
        normalizedMerchantName: "99Pledg",
        amount: Decimal(-10),
        transactionDate: Date(timeIntervalSince1970: 1_775_084_800),
        reviewStatus: "accepted",
        decisionSource: "heuristic",
        decisionSourceReference: "starter:donations"
    )
    try insertLedgerTransaction(
        databaseURL: databaseURL,
        id: prefixMatchTransactionID,
        accountID: account.id,
        categoryID: previousCategoryID,
        importSessionID: nil,
        rawDescription: "99PLEDG*ONIR BAWEJA",
        normalizedMerchantName: "99Pledg Onir Baweja",
        amount: Decimal(-25),
        transactionDate: Date(timeIntervalSince1970: 1_775_171_200),
        reviewStatus: "accepted",
        decisionSource: ClassificationDecisionSource.curatedPrefill.rawValue,
        decisionSourceReference: "starter:donations"
    )
    try insertLedgerTransaction(
        databaseURL: databaseURL,
        id: nonMatchingTransactionID,
        accountID: account.id,
        categoryID: previousCategoryID,
        importSessionID: nil,
        rawDescription: "PLEDG99",
        normalizedMerchantName: "pledg99",
        amount: Decimal(-15),
        transactionDate: Date(timeIntervalSince1970: 1_775_257_600),
        reviewStatus: "accepted",
        decisionSource: "heuristic",
        decisionSourceReference: "starter:donations"
    )

    _ = try store.createStagedImportSession(
        StagedImportSessionDraft(
            accountID: account.id,
            originalFilename: "checking-april.csv",
            contentHash: "file-sha256",
            importedAt: Date(timeIntervalSince1970: 1_775_344_000),
            rows: [
                StagedSourceRowDraft(
                    sourceLineNumber: 2,
                    rawPayload: #"["2026-04-04","99PLEDG*ANOTHER DONOR","-18.00"]"#,
                    rowHash: "row-1-sha256",
                    validationStatus: .valid,
                    importDecision: .imported(reason: "New source row."),
                    classification: .reviewRequired(
                        prefill: nil,
                        source: nil,
                        sourceReference: nil,
                        confidence: nil,
                        reason: "No classification matched."
                    ),
                    normalizedMerchantName: "99pledg another donor",
                    transaction: StagedTransactionDraft(
                        transactionDate: Date(timeIntervalSince1970: 1_775_344_000),
                        rawDescription: "99PLEDG*ANOTHER DONOR",
                        normalizedMerchantName: "99pledg another donor",
                        amount: Decimal(-18)
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

    let reviewItemID = try #require(try store.fetchPendingReviewItems().first?.id)
    _ = try store.approveClassificationReviewItem(
        id: reviewItemID,
        assignment: ClassificationAssignment(categoryID: categoryID, merchantName: "99Pledg"),
        ruleLearning: .prefixNormalizedMerchant(pattern: "99pledg"),
        resolvedAt: Date(timeIntervalSince1970: 1_775_344_060)
    )
    let learnedRule = try #require(try store.fetchClassificationRules().first)

    let exactMatchDetail = try #require(try store.fetchTransactionDetail(id: exactMatchTransactionID))
    #expect(exactMatchDetail.row.categoryID == categoryID)
    #expect(exactMatchDetail.row.merchantName == "99Pledg")
    #expect(exactMatchDetail.decisionSource == .rule)
    #expect(exactMatchDetail.decisionSourceReference == learnedRule.id.uuidString)
    #expect(exactMatchDetail.confidence == 1.0)

    let prefixMatchDetail = try #require(try store.fetchTransactionDetail(id: prefixMatchTransactionID))
    #expect(prefixMatchDetail.row.categoryID == categoryID)
    #expect(prefixMatchDetail.row.merchantName == "99Pledg Onir Baweja")
    #expect(prefixMatchDetail.decisionSource == .rule)
    #expect(prefixMatchDetail.decisionSourceReference == learnedRule.id.uuidString)
    #expect(prefixMatchDetail.confidence == 1.0)

    let nonMatchingDetail = try #require(try store.fetchTransactionDetail(id: nonMatchingTransactionID))
    #expect(nonMatchingDetail.row.categoryID == previousCategoryID)
    #expect(nonMatchingDetail.row.categoryName == "Misc")
    #expect(nonMatchingDetail.row.merchantName == "pledg99")
    #expect(nonMatchingDetail.decisionSource == .heuristic)
    #expect(nonMatchingDetail.decisionSourceReference == "starter:donations")
    #expect(nonMatchingDetail.confidence == nil)
}

@Test
func approveClassificationReviewItemBackfillMatchesRawDescriptionWithoutOverwritingMerchantName() throws {
    let databaseURL = try temporaryDatabaseURL()
    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()

    let account = try store.createAccount(named: "Checking", kind: .checking, institutionName: "Local Bank")
    let categoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000111")!
    let previousCategoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000222")!
    try insertCategory(databaseURL: databaseURL, id: categoryID, name: "Groceries", kind: "expense")
    try insertCategory(databaseURL: databaseURL, id: previousCategoryID, name: "Misc", kind: "expense")

    let matchingTransactionID = UUID(uuidString: "10000000-0000-0000-0000-000000000014")!
    try insertLedgerTransaction(
        databaseURL: databaseURL,
        id: matchingTransactionID,
        accountID: account.id,
        categoryID: previousCategoryID,
        importSessionID: nil,
        rawDescription: "COSTCO WHSE #1234",
        normalizedMerchantName: "Costco Wholesale",
        amount: Decimal(-82.10),
        transactionDate: Date(timeIntervalSince1970: 1_775_257_600),
        reviewStatus: "accepted",
        decisionSource: ClassificationDecisionSource.heuristic.rawValue,
        decisionSourceReference: nil
    )

    _ = try store.createStagedImportSession(
        StagedImportSessionDraft(
            accountID: account.id,
            originalFilename: "checking-april.csv",
            contentHash: "file-sha256",
            importedAt: Date(timeIntervalSince1970: 1_775_344_000),
            rows: [
                StagedSourceRowDraft(
                    sourceLineNumber: 2,
                    rawPayload: #"["2026-04-04","COSTCO WHSE #1234","-82.10"]"#,
                    rowHash: "row-1-sha256",
                    validationStatus: .valid,
                    importDecision: .imported(reason: "New source row."),
                    classification: .reviewRequired(
                        prefill: nil,
                        source: nil,
                        sourceReference: nil,
                        confidence: nil,
                        reason: "No classification matched."
                    ),
                    normalizedMerchantName: "costco whse 1234",
                    transaction: StagedTransactionDraft(
                        transactionDate: Date(timeIntervalSince1970: 1_775_344_000),
                        rawDescription: "COSTCO WHSE #1234",
                        normalizedMerchantName: "costco whse 1234",
                        amount: Decimal(-82.10)
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

    let reviewItemID = try #require(try store.fetchPendingReviewItems().first?.id)
    _ = try store.approveClassificationReviewItem(
        id: reviewItemID,
        assignment: ClassificationAssignment(categoryID: categoryID, merchantName: "Costco"),
        ruleLearning: .prefixNormalizedMerchant(pattern: "costco whse"),
        resolvedAt: Date(timeIntervalSince1970: 1_775_344_060)
    )
    let learnedRule = try #require(try store.fetchClassificationRules().first)

    let matchingDetail = try #require(try store.fetchTransactionDetail(id: matchingTransactionID))
    #expect(matchingDetail.row.categoryID == categoryID)
    #expect(matchingDetail.row.categoryName == "Groceries")
    #expect(matchingDetail.row.merchantName == "Costco Wholesale")
    #expect(matchingDetail.decisionSource == .rule)
    #expect(matchingDetail.decisionSourceReference == learnedRule.id.uuidString)
    #expect(matchingDetail.confidence == 1.0)
}

@Test
func approveClassificationReviewItemResolvesMatchingPendingSiblingReviewItemsDuringBackfill() throws {
    let databaseURL = try temporaryDatabaseURL()
    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()

    let account = try store.createAccount(named: "Checking", kind: .checking, institutionName: "Local Bank")
    let categoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000111")!
    try insertCategory(databaseURL: databaseURL, id: categoryID, name: "Donations", kind: "expense")

    _ = try store.createStagedImportSession(
        StagedImportSessionDraft(
            accountID: account.id,
            originalFilename: "checking-april.csv",
            contentHash: "file-sha256",
            importedAt: Date(timeIntervalSince1970: 1_775_344_000),
            rows: [
                StagedSourceRowDraft(
                    sourceLineNumber: 2,
                    rawPayload: #"["2026-04-04","99PLEDG*ANOTHER DONOR","-18.00"]"#,
                    rowHash: "row-1-sha256",
                    validationStatus: .valid,
                    importDecision: .imported(reason: "New source row."),
                    classification: .reviewRequired(
                        prefill: ClassificationAssignment(categoryID: categoryID, merchantName: "99PLEDG"),
                        source: .curatedPrefill,
                        sourceReference: "starter.99pledg.family",
                        confidence: nil,
                        reason: "Curated starter match requires review before acceptance."
                    ),
                    normalizedMerchantName: "99pledg another donor",
                    transaction: StagedTransactionDraft(
                        transactionDate: Date(timeIntervalSince1970: 1_775_344_000),
                        rawDescription: "99PLEDG*ANOTHER DONOR",
                        normalizedMerchantName: "99pledg another donor",
                        amount: Decimal(-18)
                    )
                ),
                StagedSourceRowDraft(
                    sourceLineNumber: 3,
                    rawPayload: #"["2026-04-05","99PLEDG*ONIR BAWEJA","-25.00"]"#,
                    rowHash: "row-2-sha256",
                    validationStatus: .valid,
                    importDecision: .imported(reason: "New source row."),
                    classification: .reviewRequired(
                        prefill: ClassificationAssignment(categoryID: categoryID, merchantName: "99PLEDG"),
                        source: .curatedPrefill,
                        sourceReference: "starter.99pledg.family",
                        confidence: nil,
                        reason: "Curated starter match requires review before acceptance."
                    ),
                    normalizedMerchantName: "99pledg onir baweja",
                    transaction: StagedTransactionDraft(
                        transactionDate: Date(timeIntervalSince1970: 1_775_344_060),
                        rawDescription: "99PLEDG*ONIR BAWEJA",
                        normalizedMerchantName: "99pledg onir baweja",
                        amount: Decimal(-25)
                    )
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

    let reviewItems = try store.fetchPendingReviewItems().sorted { $0.sourceRow.sourceLineNumber < $1.sourceRow.sourceLineNumber }
    let currentReviewItem = try #require(reviewItems.first)
    let siblingReviewItem = try #require(reviewItems.last)
    let resolvedAt = Date(timeIntervalSince1970: 1_775_344_120)

    _ = try store.approveClassificationReviewItem(
        id: currentReviewItem.id,
        assignment: ClassificationAssignment(categoryID: categoryID, merchantName: "99Pledg"),
        ruleLearning: .prefixNormalizedMerchant(pattern: "99pledg"),
        resolvedAt: resolvedAt
    )

    #expect(try store.fetchPendingReviewItems().isEmpty)
    #expect(try fetchReviewItemStatus(databaseURL: databaseURL, reviewItemID: siblingReviewItem.id) == .resolved)

    let siblingEvents = try store.fetchReviewDecisionEvents(reviewItemID: siblingReviewItem.id)
    #expect(siblingEvents.count == 1)
    #expect(siblingEvents[0].reviewItemID == siblingReviewItem.id)
    #expect(siblingEvents[0].sourceRowID == siblingReviewItem.sourceRow.id)
    #expect(siblingEvents[0].action == .autoResolvedByLearnedRuleBackfill)
    #expect(siblingEvents[0].details == "Automatically resolved after learned-rule backfill.")
    #expect(siblingEvents[0].createdAt == resolvedAt)
}

@Test
func approveClassificationReviewItemBackfillsMatchingPendingUnclassifiedSiblings() throws {
    let databaseURL = try temporaryDatabaseURL()
    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()

    let account = try store.createAccount(named: "Checking", kind: .checking, institutionName: "Local Bank")
    let categoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000111")!
    try insertCategory(databaseURL: databaseURL, id: categoryID, name: "Donations", kind: "expense")

    _ = try store.createStagedImportSession(
        StagedImportSessionDraft(
            accountID: account.id,
            originalFilename: "checking-april.csv",
            contentHash: "file-sha256",
            importedAt: Date(timeIntervalSince1970: 1_775_344_000),
            rows: [
                StagedSourceRowDraft(
                    sourceLineNumber: 2,
                    rawPayload: #"["2026-04-04","99PLEDG*ANOTHER DONOR","-18.00"]"#,
                    rowHash: "row-1-sha256",
                    validationStatus: .valid,
                    importDecision: .imported(reason: "New source row."),
                    classification: .reviewRequired(
                        prefill: nil,
                        source: nil,
                        sourceReference: nil,
                        confidence: nil,
                        reason: "No classification matched."
                    ),
                    normalizedMerchantName: "99pledg another donor",
                    transaction: StagedTransactionDraft(
                        transactionDate: Date(timeIntervalSince1970: 1_775_344_000),
                        rawDescription: "99PLEDG*ANOTHER DONOR",
                        normalizedMerchantName: "99pledg another donor",
                        amount: Decimal(-18)
                    )
                ),
                StagedSourceRowDraft(
                    sourceLineNumber: 3,
                    rawPayload: #"["2026-04-05","99PLEDG*ONIR BAWEJA","-25.00"]"#,
                    rowHash: "row-2-sha256",
                    validationStatus: .valid,
                    importDecision: .imported(reason: "New source row."),
                    classification: .reviewRequired(
                        prefill: nil,
                        source: nil,
                        sourceReference: nil,
                        confidence: nil,
                        reason: "No classification matched."
                    ),
                    normalizedMerchantName: "99pledg onir baweja",
                    transaction: StagedTransactionDraft(
                        transactionDate: Date(timeIntervalSince1970: 1_775_344_060),
                        rawDescription: "99PLEDG*ONIR BAWEJA",
                        normalizedMerchantName: "99pledg onir baweja",
                        amount: Decimal(-25)
                    )
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

    let reviewItems = try store.fetchPendingReviewItems().sorted { $0.sourceRow.sourceLineNumber < $1.sourceRow.sourceLineNumber }
    let currentReviewItem = try #require(reviewItems.first)
    let siblingReviewItem = try #require(reviewItems.last)

    _ = try store.approveClassificationReviewItem(
        id: currentReviewItem.id,
        assignment: ClassificationAssignment(categoryID: categoryID, merchantName: "99Pledg"),
        ruleLearning: .prefixNormalizedMerchant(pattern: "99pledg"),
        resolvedAt: Date(timeIntervalSince1970: 1_775_344_120)
    )

    #expect(try fetchReviewItemStatus(databaseURL: databaseURL, reviewItemID: siblingReviewItem.id) == .resolved)
    #expect(try store.fetchPendingReviewItems().isEmpty)
}

@Test
func approveClassificationReviewItemWithoutRuleLearningDoesNotBackfillMatchingExistingTransactions() throws {
    let databaseURL = try temporaryDatabaseURL()
    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()

    let account = try store.createAccount(named: "Checking", kind: .checking, institutionName: "Local Bank")
    let categoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000111")!
    let previousCategoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000222")!
    try insertCategory(databaseURL: databaseURL, id: categoryID, name: "Coffee", kind: "expense")
    try insertCategory(databaseURL: databaseURL, id: previousCategoryID, name: "Misc", kind: "expense")

    let matchingTransactionID = UUID(uuidString: "10000000-0000-0000-0000-000000000021")!
    try insertLedgerTransaction(
        databaseURL: databaseURL,
        id: matchingTransactionID,
        accountID: account.id,
        categoryID: previousCategoryID,
        importSessionID: nil,
        rawDescription: "SQ *Coffee Shop",
        normalizedMerchantName: "Coffee Shop",
        amount: Decimal(-8.75),
        transactionDate: Date(timeIntervalSince1970: 1_775_084_800),
        reviewStatus: "accepted",
        decisionSource: ClassificationDecisionSource.heuristic.rawValue,
        decisionSourceReference: "seeded:coffee"
    )

    _ = try store.createStagedImportSession(
        StagedImportSessionDraft(
            accountID: account.id,
            originalFilename: "checking-april.csv",
            contentHash: "file-sha256",
            importedAt: Date(timeIntervalSince1970: 1_775_257_600),
            rows: [
                StagedSourceRowDraft(
                    sourceLineNumber: 2,
                    rawPayload: #"["2026-04-03","SQ *Coffee Shop","-4.75"]"#,
                    rowHash: "row-1-sha256",
                    validationStatus: .valid,
                    importDecision: .imported(reason: "New source row."),
                    classification: .reviewRequired(
                        prefill: nil,
                        source: nil,
                        sourceReference: nil,
                        confidence: nil,
                        reason: "No classification matched."
                    ),
                    normalizedMerchantName: "coffee shop",
                    transaction: StagedTransactionDraft(
                        transactionDate: Date(timeIntervalSince1970: 1_775_257_600),
                        rawDescription: "SQ *Coffee Shop",
                        normalizedMerchantName: "coffee shop",
                        amount: Decimal(-4.75)
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

    let reviewItemID = try #require(try store.fetchPendingReviewItems().first?.id)
    _ = try store.approveClassificationReviewItem(
        id: reviewItemID,
        assignment: ClassificationAssignment(categoryID: categoryID, merchantName: "Coffee Shop"),
        ruleLearning: nil,
        resolvedAt: Date(timeIntervalSince1970: 1_775_257_660)
    )

    let matchingDetail = try #require(try store.fetchTransactionDetail(id: matchingTransactionID))
    #expect(matchingDetail.row.categoryID == previousCategoryID)
    #expect(matchingDetail.row.categoryName == "Misc")
    #expect(matchingDetail.row.merchantName == "Coffee Shop")
    #expect(matchingDetail.decisionSource == .heuristic)
    #expect(matchingDetail.decisionSourceReference == "seeded:coffee")
    #expect(matchingDetail.confidence == nil)
    #expect(try store.fetchClassificationRules().isEmpty)
}

@Test
func approveClassificationReviewItemBackfillSkipsTransactionsAlreadyFinalizedByUserOrRule() throws {
    let databaseURL = try temporaryDatabaseURL()
    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()

    let account = try store.createAccount(named: "Checking", kind: .checking, institutionName: "Local Bank")
    let categoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000111")!
    let previousCategoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000222")!
    try insertCategory(databaseURL: databaseURL, id: categoryID, name: "Coffee", kind: "expense")
    try insertCategory(databaseURL: databaseURL, id: previousCategoryID, name: "Misc", kind: "expense")

    let userTransactionID = UUID(uuidString: "10000000-0000-0000-0000-000000000031")!
    let ruleTransactionID = UUID(uuidString: "10000000-0000-0000-0000-000000000032")!
    try insertLedgerTransaction(
        databaseURL: databaseURL,
        id: userTransactionID,
        accountID: account.id,
        categoryID: previousCategoryID,
        importSessionID: nil,
        rawDescription: "SQ *Coffee Shop",
        normalizedMerchantName: "coffee shop",
        amount: Decimal(-8.75),
        transactionDate: Date(timeIntervalSince1970: 1_775_084_800),
        reviewStatus: "accepted",
        decisionSource: ClassificationDecisionSource.user.rawValue,
        decisionSourceReference: nil,
        confidence: 1.0
    )
    try insertLedgerTransaction(
        databaseURL: databaseURL,
        id: ruleTransactionID,
        accountID: account.id,
        categoryID: previousCategoryID,
        importSessionID: nil,
        rawDescription: "SQ *Coffee Shop",
        normalizedMerchantName: "coffee shop",
        amount: Decimal(-6.25),
        transactionDate: Date(timeIntervalSince1970: 1_775_171_200),
        reviewStatus: "accepted",
        decisionSource: ClassificationDecisionSource.rule.rawValue,
        decisionSourceReference: "00000000-0000-0000-0000-000000000999",
        confidence: 1.0
    )

    _ = try store.createStagedImportSession(
        StagedImportSessionDraft(
            accountID: account.id,
            originalFilename: "checking-april.csv",
            contentHash: "file-sha256",
            importedAt: Date(timeIntervalSince1970: 1_775_257_600),
            rows: [
                StagedSourceRowDraft(
                    sourceLineNumber: 2,
                    rawPayload: #"["2026-04-03","SQ *Coffee Shop","-4.75"]"#,
                    rowHash: "row-1-sha256",
                    validationStatus: .valid,
                    importDecision: .imported(reason: "New source row."),
                    classification: .reviewRequired(
                        prefill: nil,
                        source: nil,
                        sourceReference: nil,
                        confidence: nil,
                        reason: "No classification matched."
                    ),
                    normalizedMerchantName: "coffee shop",
                    transaction: StagedTransactionDraft(
                        transactionDate: Date(timeIntervalSince1970: 1_775_257_600),
                        rawDescription: "SQ *Coffee Shop",
                        normalizedMerchantName: "coffee shop",
                        amount: Decimal(-4.75)
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

    let reviewItemID = try #require(try store.fetchPendingReviewItems().first?.id)
    _ = try store.approveClassificationReviewItem(
        id: reviewItemID,
        assignment: ClassificationAssignment(categoryID: categoryID, merchantName: "Coffee Shop"),
        ruleLearning: .exactNormalizedMerchant(pattern: "coffee shop"),
        resolvedAt: Date(timeIntervalSince1970: 1_775_257_660)
    )

    let userDetail = try #require(try store.fetchTransactionDetail(id: userTransactionID))
    #expect(userDetail.row.categoryID == previousCategoryID)
    #expect(userDetail.row.categoryName == "Misc")
    #expect(userDetail.row.merchantName == "coffee shop")
    #expect(userDetail.decisionSource == .user)
    #expect(userDetail.decisionSourceReference == nil)
    #expect(userDetail.confidence == 1.0)

    let ruleDetail = try #require(try store.fetchTransactionDetail(id: ruleTransactionID))
    #expect(ruleDetail.row.categoryID == previousCategoryID)
    #expect(ruleDetail.row.categoryName == "Misc")
    #expect(ruleDetail.row.merchantName == "coffee shop")
    #expect(ruleDetail.decisionSource == .rule)
    #expect(ruleDetail.decisionSourceReference == "00000000-0000-0000-0000-000000000999")
    #expect(ruleDetail.confidence == 1.0)
}

@Test
func approveClassificationReviewItemBackfillsStarterDerivedAcceptedExactMatches() throws {
    let databaseURL = try temporaryDatabaseURL()
    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()

    let account = try store.createAccount(named: "Checking", kind: .checking, institutionName: "Local Bank")
    let coffeeCategoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000111")!
    let protectedCategoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000222")!
    try insertCategory(databaseURL: databaseURL, id: coffeeCategoryID, name: "Coffee", kind: "expense")
    try insertCategory(databaseURL: databaseURL, id: protectedCategoryID, name: "Protected", kind: "expense")

    _ = try store.createStagedImportSession(
        StagedImportSessionDraft(
            accountID: account.id,
            originalFilename: "checking-april.csv",
            contentHash: "file-sha256",
            importedAt: Date(timeIntervalSince1970: 1_775_171_200),
            rows: [
                StagedSourceRowDraft(
                    sourceLineNumber: 2,
                    rawPayload: #"["2026-04-01","SQ *Coffee Shop","-4.75"]"#,
                    rowHash: "row-1-sha256",
                    validationStatus: .valid,
                    importDecision: .imported(reason: "New source row."),
                    classification: .reviewRequired(
                        prefill: nil,
                        source: nil,
                        sourceReference: nil,
                        confidence: nil,
                        reason: "No classification matched."
                    ),
                    normalizedMerchantName: "coffee shop",
                    transaction: StagedTransactionDraft(
                        transactionDate: Date(timeIntervalSince1970: 1_775_171_200),
                        rawDescription: "SQ *Coffee Shop",
                        normalizedMerchantName: "coffee shop",
                        amount: Decimal(-4.75)
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

    let reviewItemID = try #require(try store.fetchPendingReviewItems().first?.id)
    let directTransactionID = try #require(try store.fetchTransactionLedger(filter: .empty).first?.id)
    let heuristicSiblingID = UUID(uuidString: "00000000-0000-0000-0000-000000000301")!
    let curatedSiblingID = UUID(uuidString: "00000000-0000-0000-0000-000000000302")!
    let userSiblingID = UUID(uuidString: "00000000-0000-0000-0000-000000000303")!
    let ruleSiblingID = UUID(uuidString: "00000000-0000-0000-0000-000000000304")!
    let untouchedSiblingID = UUID(uuidString: "00000000-0000-0000-0000-000000000305")!

    try insertLedgerTransaction(
        databaseURL: databaseURL,
        id: heuristicSiblingID,
        accountID: account.id,
        categoryID: nil,
        importSessionID: nil,
        rawDescription: "SQ *Coffee Shop",
        normalizedMerchantName: "Coffee Shop",
        amount: Decimal(-5.25),
        transactionDate: Date(timeIntervalSince1970: 1_775_257_600),
        reviewStatus: "accepted",
        decisionSource: ClassificationDecisionSource.heuristic.rawValue,
        decisionSourceReference: "starter-heuristic",
        confidence: 0.65
    )
    try insertLedgerTransaction(
        databaseURL: databaseURL,
        id: curatedSiblingID,
        accountID: account.id,
        categoryID: nil,
        importSessionID: nil,
        rawDescription: "Coffee Shop",
        normalizedMerchantName: "COFFEE SHOP",
        amount: Decimal(-6.25),
        transactionDate: Date(timeIntervalSince1970: 1_775_344_000),
        reviewStatus: "accepted",
        decisionSource: ClassificationDecisionSource.curatedPrefill.rawValue,
        decisionSourceReference: "starter-curated",
        confidence: nil
    )
    try insertLedgerTransaction(
        databaseURL: databaseURL,
        id: userSiblingID,
        accountID: account.id,
        categoryID: protectedCategoryID,
        importSessionID: nil,
        rawDescription: "Coffee Shop",
        normalizedMerchantName: "coffee shop",
        amount: Decimal(-7.25),
        transactionDate: Date(timeIntervalSince1970: 1_775_430_400),
        reviewStatus: "accepted",
        decisionSource: ClassificationDecisionSource.user.rawValue,
        decisionSourceReference: nil,
        confidence: 1.0
    )
    try insertLedgerTransaction(
        databaseURL: databaseURL,
        id: ruleSiblingID,
        accountID: account.id,
        categoryID: protectedCategoryID,
        importSessionID: nil,
        rawDescription: "Coffee Shop",
        normalizedMerchantName: "coffee shop",
        amount: Decimal(-8.25),
        transactionDate: Date(timeIntervalSince1970: 1_775_516_800),
        reviewStatus: "accepted",
        decisionSource: ClassificationDecisionSource.rule.rawValue,
        decisionSourceReference: "existing-rule-id",
        confidence: 1.0
    )
    try insertLedgerTransaction(
        databaseURL: databaseURL,
        id: untouchedSiblingID,
        accountID: account.id,
        categoryID: nil,
        importSessionID: nil,
        rawDescription: "Tea Shop",
        normalizedMerchantName: "tea shop",
        amount: Decimal(-3.25),
        transactionDate: Date(timeIntervalSince1970: 1_775_603_200),
        reviewStatus: "accepted",
        decisionSource: ClassificationDecisionSource.heuristic.rawValue,
        decisionSourceReference: "starter-tea",
        confidence: 0.33
    )

    _ = try store.approveClassificationReviewItem(
        id: reviewItemID,
        assignment: ClassificationAssignment(categoryID: coffeeCategoryID, merchantName: "Coffee Shop"),
        ruleLearning: .exactNormalizedMerchant(pattern: "coffee shop"),
        resolvedAt: Date(timeIntervalSince1970: 1_775_171_260)
    )

    let learnedRule = try #require(try store.fetchClassificationRules().first)
    let directDetail = try #require(try store.fetchTransactionDetail(id: directTransactionID))
    let heuristicDetail = try #require(try store.fetchTransactionDetail(id: heuristicSiblingID))
    let curatedDetail = try #require(try store.fetchTransactionDetail(id: curatedSiblingID))
    let userDetail = try #require(try store.fetchTransactionDetail(id: userSiblingID))
    let ruleDetail = try #require(try store.fetchTransactionDetail(id: ruleSiblingID))
    let untouchedDetail = try #require(try store.fetchTransactionDetail(id: untouchedSiblingID))

    #expect(directDetail.row.categoryID == coffeeCategoryID)
    #expect(directDetail.decisionSource == .user)

    #expect(heuristicDetail.row.categoryID == coffeeCategoryID)
    #expect(heuristicDetail.decisionSource == .rule)
    #expect(heuristicDetail.decisionSourceReference == learnedRule.id.uuidString)
    #expect(heuristicDetail.confidence == 1.0)

    #expect(curatedDetail.row.categoryID == coffeeCategoryID)
    #expect(curatedDetail.decisionSource == .rule)
    #expect(curatedDetail.decisionSourceReference == learnedRule.id.uuidString)
    #expect(curatedDetail.confidence == 1.0)

    #expect(userDetail.row.categoryID == protectedCategoryID)
    #expect(userDetail.decisionSource == .user)
    #expect(userDetail.decisionSourceReference == nil)
    #expect(userDetail.confidence == 1.0)

    #expect(ruleDetail.row.categoryID == protectedCategoryID)
    #expect(ruleDetail.decisionSource == .rule)
    #expect(ruleDetail.decisionSourceReference == "existing-rule-id")
    #expect(ruleDetail.confidence == 1.0)

    #expect(untouchedDetail.row.categoryID == nil)
    #expect(untouchedDetail.decisionSource == .heuristic)
    #expect(untouchedDetail.decisionSourceReference == "starter-tea")
    #expect(untouchedDetail.confidence == 0.33)
}

@Test
func approveClassificationReviewItemBackfillsPrefixMatchesUsingSharedMerchantNormalization() throws {
    let databaseURL = try temporaryDatabaseURL()
    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()

    let account = try store.createAccount(named: "Checking", kind: .checking, institutionName: "Local Bank")
    let charityCategoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000111")!
    try insertCategory(databaseURL: databaseURL, id: charityCategoryID, name: "Charity", kind: "expense")

    _ = try store.createStagedImportSession(
        StagedImportSessionDraft(
            accountID: account.id,
            originalFilename: "checking-april.csv",
            contentHash: "file-sha256",
            importedAt: Date(timeIntervalSince1970: 1_775_171_200),
            rows: [
                StagedSourceRowDraft(
                    sourceLineNumber: 2,
                    rawPayload: #"["2026-04-01","99PLEDG*ONIR BAWEJA","-25.00"]"#,
                    rowHash: "row-1-sha256",
                    validationStatus: .valid,
                    importDecision: .imported(reason: "New source row."),
                    classification: .reviewRequired(
                        prefill: nil,
                        source: nil,
                        sourceReference: nil,
                        confidence: nil,
                        reason: "No classification matched."
                    ),
                    normalizedMerchantName: "99pledg onir baweja",
                    transaction: StagedTransactionDraft(
                        transactionDate: Date(timeIntervalSince1970: 1_775_171_200),
                        rawDescription: "99PLEDG*ONIR BAWEJA",
                        normalizedMerchantName: "99pledg onir baweja",
                        amount: Decimal(-25.00)
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

    let reviewItemID = try #require(try store.fetchPendingReviewItems().first?.id)
    let exactRootSiblingID = UUID(uuidString: "00000000-0000-0000-0000-000000000401")!
    let spacedPrefixSiblingID = UUID(uuidString: "00000000-0000-0000-0000-000000000402")!
    let unmatchedSiblingID = UUID(uuidString: "00000000-0000-0000-0000-000000000403")!

    try insertLedgerTransaction(
        databaseURL: databaseURL,
        id: exactRootSiblingID,
        accountID: account.id,
        categoryID: nil,
        importSessionID: nil,
        rawDescription: "99PLEDG",
        normalizedMerchantName: "99PLEDG",
        amount: Decimal(-11.00),
        transactionDate: Date(timeIntervalSince1970: 1_775_257_600),
        reviewStatus: "accepted",
        decisionSource: ClassificationDecisionSource.heuristic.rawValue,
        decisionSourceReference: "starter-root",
        confidence: 0.65
    )
    try insertLedgerTransaction(
        databaseURL: databaseURL,
        id: spacedPrefixSiblingID,
        accountID: account.id,
        categoryID: nil,
        importSessionID: nil,
        rawDescription: "99PLEDG*ANOTHER DONATION",
        normalizedMerchantName: "99PLEDG*ANOTHER DONATION",
        amount: Decimal(-12.00),
        transactionDate: Date(timeIntervalSince1970: 1_775_344_000),
        reviewStatus: "accepted",
        decisionSource: ClassificationDecisionSource.curatedPrefill.rawValue,
        decisionSourceReference: "starter-spaced-prefix",
        confidence: nil
    )
    try insertLedgerTransaction(
        databaseURL: databaseURL,
        id: unmatchedSiblingID,
        accountID: account.id,
        categoryID: nil,
        importSessionID: nil,
        rawDescription: "99PLEDGX OTHER",
        normalizedMerchantName: "99PLEDGX OTHER",
        amount: Decimal(-13.00),
        transactionDate: Date(timeIntervalSince1970: 1_775_430_400),
        reviewStatus: "accepted",
        decisionSource: ClassificationDecisionSource.heuristic.rawValue,
        decisionSourceReference: "starter-unmatched",
        confidence: 0.5
    )

    _ = try store.approveClassificationReviewItem(
        id: reviewItemID,
        assignment: ClassificationAssignment(categoryID: charityCategoryID, merchantName: "99Pledg"),
        ruleLearning: .prefixNormalizedMerchant(pattern: "99pledg"),
        resolvedAt: Date(timeIntervalSince1970: 1_775_171_260)
    )

    let learnedRule = try #require(try store.fetchClassificationRules().first)
    let exactRootDetail = try #require(try store.fetchTransactionDetail(id: exactRootSiblingID))
    let spacedPrefixDetail = try #require(try store.fetchTransactionDetail(id: spacedPrefixSiblingID))
    let unmatchedDetail = try #require(try store.fetchTransactionDetail(id: unmatchedSiblingID))

    #expect(exactRootDetail.decisionSource == .rule)
    #expect(exactRootDetail.decisionSourceReference == learnedRule.id.uuidString)
    #expect(spacedPrefixDetail.decisionSource == .rule)
    #expect(spacedPrefixDetail.decisionSourceReference == learnedRule.id.uuidString)
    #expect(unmatchedDetail.decisionSource == .heuristic)
    #expect(unmatchedDetail.decisionSourceReference == "starter-unmatched")
    #expect(unmatchedDetail.confidence == 0.5)
}

@Test
func previewLearnedRuleImpactCountsExactMatchesWithoutMutatingTransactionsOrReviewItems() throws {
    let databaseURL = try temporaryDatabaseURL()
    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()

    let account = try store.createAccount(named: "Checking", kind: .checking, institutionName: "Local Bank")
    let categoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000041")!
    let previousCategoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000042")!
    try insertCategory(databaseURL: databaseURL, id: categoryID, name: "Coffee", kind: "expense")
    try insertCategory(databaseURL: databaseURL, id: previousCategoryID, name: "Misc", kind: "expense")

    let matchingAcceptedTransactionID = UUID(uuidString: "10000000-0000-0000-0000-000000000041")!
    let ignoredUserTransactionID = UUID(uuidString: "10000000-0000-0000-0000-000000000042")!
    try insertLedgerTransaction(
        databaseURL: databaseURL,
        id: matchingAcceptedTransactionID,
        accountID: account.id,
        categoryID: previousCategoryID,
        importSessionID: nil,
        rawDescription: "Coffee Shop",
        normalizedMerchantName: "coffee shop alias",
        amount: Decimal(-8.75),
        transactionDate: Date(timeIntervalSince1970: 1_775_084_800),
        reviewStatus: "accepted",
        decisionSource: ClassificationDecisionSource.heuristic.rawValue,
        decisionSourceReference: "seeded:coffee"
    )
    try insertLedgerTransaction(
        databaseURL: databaseURL,
        id: ignoredUserTransactionID,
        accountID: account.id,
        categoryID: previousCategoryID,
        importSessionID: nil,
        rawDescription: "Coffee Shop",
        normalizedMerchantName: "coffee shop",
        amount: Decimal(-6.25),
        transactionDate: Date(timeIntervalSince1970: 1_775_171_200),
        reviewStatus: "accepted",
        decisionSource: ClassificationDecisionSource.user.rawValue,
        decisionSourceReference: nil,
        confidence: 1.0
    )

    _ = try store.createStagedImportSession(
        StagedImportSessionDraft(
            accountID: account.id,
            originalFilename: "checking-april.csv",
            contentHash: "file-sha256",
            importedAt: Date(timeIntervalSince1970: 1_775_257_600),
            rows: [
                StagedSourceRowDraft(
                    sourceLineNumber: 2,
                    rawPayload: #"["2026-04-03","Coffee Shop","-4.75"]"#,
                    rowHash: "row-1-sha256",
                    validationStatus: .valid,
                    importDecision: .imported(reason: "New source row."),
                    classification: .reviewRequired(
                        prefill: nil,
                        source: nil,
                        sourceReference: nil,
                        confidence: nil,
                        reason: "No classification matched."
                    ),
                    normalizedMerchantName: "coffee shop",
                    transaction: StagedTransactionDraft(
                        transactionDate: Date(timeIntervalSince1970: 1_775_257_600),
                        rawDescription: "Coffee Shop",
                        normalizedMerchantName: "coffee shop",
                        amount: Decimal(-4.75)
                    )
                ),
                StagedSourceRowDraft(
                    sourceLineNumber: 3,
                    rawPayload: #"["2026-04-04","Coffee Shop","-5.25"]"#,
                    rowHash: "row-2-sha256",
                    validationStatus: .valid,
                    importDecision: .imported(reason: "New source row."),
                    classification: .reviewRequired(
                        prefill: nil,
                        source: nil,
                        sourceReference: nil,
                        confidence: nil,
                        reason: "No classification matched."
                    ),
                    normalizedMerchantName: "coffee shop",
                    transaction: StagedTransactionDraft(
                        transactionDate: Date(timeIntervalSince1970: 1_775_257_660),
                        rawDescription: "Coffee Shop",
                        normalizedMerchantName: "coffee shop",
                        amount: Decimal(-5.25)
                    )
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

    let reviewItems = try store.fetchPendingReviewItems().sorted { $0.sourceRow.sourceLineNumber < $1.sourceRow.sourceLineNumber }
    let currentReviewItem = try #require(reviewItems.first)
    let siblingReviewItem = try #require(reviewItems.last)

    let preview = try store.previewLearnedRuleImpact(
        merchantPattern: "coffee shop",
        matchKind: .exactNormalizedMerchant,
        excludingReviewItemID: currentReviewItem.id
    )

    #expect(preview == LearnedRuleImpactPreview(
        matchedAcceptedTransactionCount: 1,
        matchedPendingReviewItemCount: 1
    ))
    let unfilteredPreview = try store.previewLearnedRuleImpact(
        merchantPattern: "coffee shop",
        matchKind: .exactNormalizedMerchant,
        excludingReviewItemID: nil
    )
    #expect(unfilteredPreview == LearnedRuleImpactPreview(
        matchedAcceptedTransactionCount: 1,
        matchedPendingReviewItemCount: 2
    ))
    #expect(Set(try store.fetchPendingReviewItems().map(\.id)) == Set([currentReviewItem.id, siblingReviewItem.id]))

    let matchingDetail = try #require(try store.fetchTransactionDetail(id: matchingAcceptedTransactionID))
    #expect(matchingDetail.row.categoryID == previousCategoryID)
    #expect(matchingDetail.row.categoryName == "Misc")
    #expect(matchingDetail.decisionSource == .heuristic)
    #expect(matchingDetail.decisionSourceReference == "seeded:coffee")
}

@Test
func previewLearnedRuleImpactCountsPrefixMatchesAcrossAcceptedTransactionsAndSiblingReviewItems() throws {
    let databaseURL = try temporaryDatabaseURL()
    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()

    let account = try store.createAccount(named: "Checking", kind: .checking, institutionName: "Local Bank")
    let categoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000051")!
    let previousCategoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000052")!
    try insertCategory(databaseURL: databaseURL, id: categoryID, name: "Donations", kind: "expense")
    try insertCategory(databaseURL: databaseURL, id: previousCategoryID, name: "Misc", kind: "expense")

    try insertLedgerTransaction(
        databaseURL: databaseURL,
        id: UUID(uuidString: "10000000-0000-0000-0000-000000000051")!,
        accountID: account.id,
        categoryID: previousCategoryID,
        importSessionID: nil,
        rawDescription: "99PLEDG",
        normalizedMerchantName: "99pledg",
        amount: Decimal(-10),
        transactionDate: Date(timeIntervalSince1970: 1_775_084_800),
        reviewStatus: "accepted",
        decisionSource: ClassificationDecisionSource.heuristic.rawValue,
        decisionSourceReference: "starter:donations"
    )
    try insertLedgerTransaction(
        databaseURL: databaseURL,
        id: UUID(uuidString: "10000000-0000-0000-0000-000000000052")!,
        accountID: account.id,
        categoryID: previousCategoryID,
        importSessionID: nil,
        rawDescription: "99PLEDG*ONIR BAWEJA",
        normalizedMerchantName: "99pledg onir baweja",
        amount: Decimal(-25),
        transactionDate: Date(timeIntervalSince1970: 1_775_171_200),
        reviewStatus: "accepted",
        decisionSource: ClassificationDecisionSource.curatedPrefill.rawValue,
        decisionSourceReference: "starter:donations"
    )
    try insertLedgerTransaction(
        databaseURL: databaseURL,
        id: UUID(uuidString: "10000000-0000-0000-0000-000000000053")!,
        accountID: account.id,
        categoryID: previousCategoryID,
        importSessionID: nil,
        rawDescription: "PLEDG99",
        normalizedMerchantName: "pledg99",
        amount: Decimal(-15),
        transactionDate: Date(timeIntervalSince1970: 1_775_257_600),
        reviewStatus: "accepted",
        decisionSource: ClassificationDecisionSource.heuristic.rawValue,
        decisionSourceReference: "starter:donations"
    )

    _ = try store.createStagedImportSession(
        StagedImportSessionDraft(
            accountID: account.id,
            originalFilename: "checking-april.csv",
            contentHash: "file-sha256",
            importedAt: Date(timeIntervalSince1970: 1_775_344_000),
            rows: [
                StagedSourceRowDraft(
                    sourceLineNumber: 2,
                    rawPayload: #"["2026-04-04","99PLEDG*ANOTHER DONOR","-18.00"]"#,
                    rowHash: "row-1-sha256",
                    validationStatus: .valid,
                    importDecision: .imported(reason: "New source row."),
                    classification: .reviewRequired(
                        prefill: nil,
                        source: nil,
                        sourceReference: nil,
                        confidence: nil,
                        reason: "No classification matched."
                    ),
                    normalizedMerchantName: "99pledg another donor",
                    transaction: StagedTransactionDraft(
                        transactionDate: Date(timeIntervalSince1970: 1_775_344_000),
                        rawDescription: "99PLEDG*ANOTHER DONOR",
                        normalizedMerchantName: "99pledg another donor",
                        amount: Decimal(-18)
                    )
                ),
                StagedSourceRowDraft(
                    sourceLineNumber: 3,
                    rawPayload: #"["2026-04-05","99PLEDG*ONIR BAWEJA","-25.00"]"#,
                    rowHash: "row-2-sha256",
                    validationStatus: .valid,
                    importDecision: .imported(reason: "New source row."),
                    classification: .reviewRequired(
                        prefill: nil,
                        source: nil,
                        sourceReference: nil,
                        confidence: nil,
                        reason: "No classification matched."
                    ),
                    normalizedMerchantName: "99pledg onir baweja",
                    transaction: StagedTransactionDraft(
                        transactionDate: Date(timeIntervalSince1970: 1_775_344_060),
                        rawDescription: "99PLEDG*ONIR BAWEJA",
                        normalizedMerchantName: "99pledg onir baweja",
                        amount: Decimal(-25)
                    )
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

    let reviewItems = try store.fetchPendingReviewItems().sorted { $0.sourceRow.sourceLineNumber < $1.sourceRow.sourceLineNumber }
    let currentReviewItem = try #require(reviewItems.first)

    let preview = try store.previewLearnedRuleImpact(
        merchantPattern: "99pledg",
        matchKind: .prefixNormalizedMerchant,
        excludingReviewItemID: currentReviewItem.id
    )

    #expect(preview == LearnedRuleImpactPreview(
        matchedAcceptedTransactionCount: 2,
        matchedPendingReviewItemCount: 1
    ))
}

@Test
func previewLearnedRuleImpactCountsContainsMatchesAcrossAcceptedTransactionsAndSiblingReviewItems() throws {
    let databaseURL = try temporaryDatabaseURL()
    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()

    let account = try store.createAccount(named: "Checking", kind: .checking, institutionName: "Local Bank")
    let categoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000061")!
    let previousCategoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000062")!
    try insertCategory(databaseURL: databaseURL, id: categoryID, name: "Coffee", kind: "expense")
    try insertCategory(databaseURL: databaseURL, id: previousCategoryID, name: "Misc", kind: "expense")

    try insertLedgerTransaction(
        databaseURL: databaseURL,
        id: UUID(uuidString: "10000000-0000-0000-0000-000000000061")!,
        accountID: account.id,
        categoryID: previousCategoryID,
        importSessionID: nil,
        rawDescription: "Daily Coffee Roasters",
        normalizedMerchantName: "daily coffee roasters",
        amount: Decimal(-8.75),
        transactionDate: Date(timeIntervalSince1970: 1_775_084_800),
        reviewStatus: "accepted",
        decisionSource: ClassificationDecisionSource.heuristic.rawValue,
        decisionSourceReference: "seeded:coffee"
    )
    try insertLedgerTransaction(
        databaseURL: databaseURL,
        id: UUID(uuidString: "10000000-0000-0000-0000-000000000062")!,
        accountID: account.id,
        categoryID: previousCategoryID,
        importSessionID: nil,
        rawDescription: "Iced Coffee",
        normalizedMerchantName: "iced coffee",
        amount: Decimal(-6.25),
        transactionDate: Date(timeIntervalSince1970: 1_775_171_200),
        reviewStatus: "accepted",
        decisionSource: ClassificationDecisionSource.curatedPrefill.rawValue,
        decisionSourceReference: "starter:coffee"
    )
    try insertLedgerTransaction(
        databaseURL: databaseURL,
        id: UUID(uuidString: "10000000-0000-0000-0000-000000000063")!,
        accountID: account.id,
        categoryID: previousCategoryID,
        importSessionID: nil,
        rawDescription: "Tea House",
        normalizedMerchantName: "tea house",
        amount: Decimal(-7.25),
        transactionDate: Date(timeIntervalSince1970: 1_775_257_600),
        reviewStatus: "accepted",
        decisionSource: ClassificationDecisionSource.heuristic.rawValue,
        decisionSourceReference: "seeded:tea"
    )

    _ = try store.createStagedImportSession(
        StagedImportSessionDraft(
            accountID: account.id,
            originalFilename: "checking-april.csv",
            contentHash: "file-sha256",
            importedAt: Date(timeIntervalSince1970: 1_775_344_000),
            rows: [
                StagedSourceRowDraft(
                    sourceLineNumber: 2,
                    rawPayload: #"["2026-04-04","Coffee Shop","-18.00"]"#,
                    rowHash: "row-1-sha256",
                    validationStatus: .valid,
                    importDecision: .imported(reason: "New source row."),
                    classification: .reviewRequired(
                        prefill: nil,
                        source: nil,
                        sourceReference: nil,
                        confidence: nil,
                        reason: "No classification matched."
                    ),
                    normalizedMerchantName: "coffee shop",
                    transaction: StagedTransactionDraft(
                        transactionDate: Date(timeIntervalSince1970: 1_775_344_000),
                        rawDescription: "Coffee Shop",
                        normalizedMerchantName: "coffee shop",
                        amount: Decimal(-18)
                    )
                ),
                StagedSourceRowDraft(
                    sourceLineNumber: 3,
                    rawPayload: #"["2026-04-05","Daily Coffee Subscription","-25.00"]"#,
                    rowHash: "row-2-sha256",
                    validationStatus: .valid,
                    importDecision: .imported(reason: "New source row."),
                    classification: .reviewRequired(
                        prefill: nil,
                        source: nil,
                        sourceReference: nil,
                        confidence: nil,
                        reason: "No classification matched."
                    ),
                    normalizedMerchantName: "daily coffee subscription",
                    transaction: StagedTransactionDraft(
                        transactionDate: Date(timeIntervalSince1970: 1_775_344_060),
                        rawDescription: "Daily Coffee Subscription",
                        normalizedMerchantName: "daily coffee subscription",
                        amount: Decimal(-25)
                    )
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

    let reviewItems = try store.fetchPendingReviewItems().sorted { $0.sourceRow.sourceLineNumber < $1.sourceRow.sourceLineNumber }
    let currentReviewItem = try #require(reviewItems.first)

    let preview = try store.previewLearnedRuleImpact(
        merchantPattern: "coffee",
        matchKind: .contains,
        excludingReviewItemID: currentReviewItem.id
    )

    #expect(preview == LearnedRuleImpactPreview(
        matchedAcceptedTransactionCount: 2,
        matchedPendingReviewItemCount: 1
    ))
}

@Test
func merchantHistoryDerivedFromAcceptedUserDecisionsBecomesEligibleForRecommendation() throws {
    let databaseURL = try temporaryDatabaseURL()
    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()

    let account = try store.createAccount(named: "Checking", kind: .checking, institutionName: "Local Bank")
    let categoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000111")!
    try insertCategory(databaseURL: databaseURL, id: categoryID, name: "Coffee Shops", kind: "expense")

    _ = try approveMerchantRecommendationHistory(
        store: store,
        accountID: account.id,
        categoryID: categoryID,
        normalizedMerchantName: "coffee shop",
        rawDescriptions: [
            "Coffee Shop Downtown",
            "Coffee Shop Uptown",
            "Coffee Shop Midtown",
        ]
    )

    let eligibility = try store.fetchMerchantRecommendationEligibility(normalizedMerchantName: "coffee shop")

    #expect(eligibility == MerchantRecommendationEligibility(
        normalizedMerchantName: "coffee shop",
        categoryID: categoryID,
        approvedDecisionCount: 3
    ))
}

@Test
func twoDistinctAcceptedUserApprovalsRemainBelowRecommendationThreshold() throws {
    let databaseURL = try temporaryDatabaseURL()
    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()

    let account = try store.createAccount(named: "Checking", kind: .checking, institutionName: "Local Bank")
    let categoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000111")!
    try insertCategory(databaseURL: databaseURL, id: categoryID, name: "Coffee Shops", kind: "expense")

    _ = try approveMerchantRecommendationHistory(
        store: store,
        accountID: account.id,
        categoryID: categoryID,
        normalizedMerchantName: "coffee shop",
        rawDescriptions: [
            "Coffee Shop Downtown",
            "Coffee Shop Uptown",
        ]
    )

    let eligibility = try store.fetchMerchantRecommendationEligibility(normalizedMerchantName: "coffee shop")

    #expect(eligibility == nil)
}

@Test
func conflictingUserHistorySuppressesMerchantRecommendationEligibility() throws {
    let databaseURL = try temporaryDatabaseURL()
    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()

    let account = try store.createAccount(named: "Checking", kind: .checking, institutionName: "Local Bank")
    let coffeeCategoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000111")!
    let groceriesCategoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000112")!
    try insertCategory(databaseURL: databaseURL, id: coffeeCategoryID, name: "Coffee Shops", kind: "expense")
    try insertCategory(databaseURL: databaseURL, id: groceriesCategoryID, name: "Groceries", kind: "expense")

    _ = try approveMerchantRecommendationHistory(
        store: store,
        accountID: account.id,
        categoryID: coffeeCategoryID,
        normalizedMerchantName: "coffee shop",
        rawDescriptions: [
            "Coffee Shop Downtown",
            "Coffee Shop Uptown",
            "Coffee Shop Midtown",
        ]
    )
    _ = try approveMerchantRecommendationHistory(
        store: store,
        accountID: account.id,
        categoryID: groceriesCategoryID,
        normalizedMerchantName: "coffee shop",
        rawDescriptions: [
            "Coffee Shop Grocery Counter",
        ],
        startingSequence: 100
    )

    let eligibility = try store.fetchMerchantRecommendationEligibility(normalizedMerchantName: "coffee shop")

    #expect(eligibility == nil)
}

@Test
func sameImportDuplicatesDoNotCountAsRepeatedApprovals() throws {
    let databaseURL = try temporaryDatabaseURL()
    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()

    let account = try store.createAccount(named: "Checking", kind: .checking, institutionName: "Local Bank")
    let categoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000111")!
    try insertCategory(databaseURL: databaseURL, id: categoryID, name: "Coffee Shops", kind: "expense")

    _ = try approveMerchantRecommendationHistory(
        store: store,
        accountID: account.id,
        categoryID: categoryID,
        normalizedMerchantName: "coffee shop",
        rawDescriptions: [
            "Coffee Shop Downtown",
        ]
    )
    _ = try approveMerchantRecommendationHistory(
        store: store,
        accountID: account.id,
        categoryID: categoryID,
        normalizedMerchantName: "coffee shop",
        rawDescriptions: [
            "Coffee Shop Repeated",
            "Coffee Shop Repeated",
        ],
        rowHashes: [
            "duplicate-row",
            "duplicate-row",
        ],
        originalFilename: "checking-duplicate-import.csv",
        startingSequence: 100
    )

    let eligibility = try store.fetchMerchantRecommendationEligibility(normalizedMerchantName: "coffee shop")

    #expect(eligibility == nil)
}

@Test
func nonUserSourcesDoNotCountTowardMerchantRecommendationEligibility() throws {
    let databaseURL = try temporaryDatabaseURL()
    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()

    let account = try store.createAccount(named: "Checking", kind: .checking, institutionName: "Local Bank")
    let categoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000111")!
    try insertCategory(databaseURL: databaseURL, id: categoryID, name: "Coffee Shops", kind: "expense")

    _ = try approveMerchantRecommendationHistory(
        store: store,
        accountID: account.id,
        categoryID: categoryID,
        normalizedMerchantName: "coffee shop",
        rawDescriptions: [
            "Coffee Shop Downtown",
            "Coffee Shop Uptown",
        ]
    )
    let hiddenTransactionIDs = try approveMerchantRecommendationHistory(
        store: store,
        accountID: account.id,
        categoryID: categoryID,
        normalizedMerchantName: "coffee shop",
        rawDescriptions: [
            "Coffee Shop Hidden",
        ],
        originalFilename: "checking-hidden.csv",
        startingSequence: 100
    )
    try store.setTransactionHidden(id: try #require(hiddenTransactionIDs.first), isHidden: true)

    try insertLedgerTransaction(
        databaseURL: databaseURL,
        id: UUID(uuidString: "10000000-0000-0000-0000-000000000071")!,
        accountID: account.id,
        categoryID: categoryID,
        importSessionID: nil,
        rawDescription: "Coffee Shop Rule",
        normalizedMerchantName: "coffee shop",
        amount: Decimal(-5.25),
        transactionDate: Date(timeIntervalSince1970: 1_776_355_360),
        reviewStatus: TransactionReviewStatus.accepted.rawValue,
        decisionSource: ClassificationDecisionSource.rule.rawValue,
        decisionSourceReference: "00000000-0000-0000-0000-000000009999"
    )
    try insertLedgerTransaction(
        databaseURL: databaseURL,
        id: UUID(uuidString: "10000000-0000-0000-0000-000000000072")!,
        accountID: account.id,
        categoryID: categoryID,
        importSessionID: nil,
        rawDescription: "Coffee Shop Heuristic",
        normalizedMerchantName: "coffee shop",
        amount: Decimal(-5.75),
        transactionDate: Date(timeIntervalSince1970: 1_776_441_760),
        reviewStatus: TransactionReviewStatus.accepted.rawValue,
        decisionSource: ClassificationDecisionSource.heuristic.rawValue,
        decisionSourceReference: "seeded:coffee"
    )
    try insertLedgerTransaction(
        databaseURL: databaseURL,
        id: UUID(uuidString: "10000000-0000-0000-0000-000000000073")!,
        accountID: account.id,
        categoryID: categoryID,
        importSessionID: nil,
        rawDescription: "Coffee Shop Curated",
        normalizedMerchantName: "coffee shop",
        amount: Decimal(-6.25),
        transactionDate: Date(timeIntervalSince1970: 1_776_528_160),
        reviewStatus: TransactionReviewStatus.accepted.rawValue,
        decisionSource: ClassificationDecisionSource.curatedPrefill.rawValue,
        decisionSourceReference: "starter:coffee"
    )
    try insertLedgerTransaction(
        databaseURL: databaseURL,
        id: UUID(uuidString: "10000000-0000-0000-0000-000000000074")!,
        accountID: account.id,
        categoryID: categoryID,
        importSessionID: nil,
        rawDescription: "Coffee Shop Suggestion",
        normalizedMerchantName: "coffee shop",
        amount: Decimal(-6.75),
        transactionDate: Date(timeIntervalSince1970: 1_776_614_560),
        reviewStatus: TransactionReviewStatus.accepted.rawValue,
        decisionSource: ClassificationDecisionSource.suggestion.rawValue,
        decisionSourceReference: "suggestion:coffee"
    )

    let eligibility = try store.fetchMerchantRecommendationEligibility(normalizedMerchantName: "coffee shop")

    #expect(eligibility == nil)
}

@Test
func existingLearnedRuleSuppressesMerchantRecommendationEligibility() throws {
    let databaseURL = try temporaryDatabaseURL()
    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()

    let account = try store.createAccount(named: "Checking", kind: .checking, institutionName: "Local Bank")
    let categoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000111")!
    try insertCategory(databaseURL: databaseURL, id: categoryID, name: "Coffee Shops", kind: "expense")

    _ = try approveMerchantRecommendationHistory(
        store: store,
        accountID: account.id,
        categoryID: categoryID,
        normalizedMerchantName: "coffee shop",
        rawDescriptions: [
            "Coffee Shop Downtown",
            "Coffee Shop Uptown",
            "Coffee Shop Midtown",
        ]
    )
    try insertRule(
        databaseURL: databaseURL,
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000222")!,
        pattern: "coffee shop",
        categoryID: categoryID,
        merchantName: "Coffee Shop",
        matchKind: .exactNormalizedMerchant,
        createdAt: Date(timeIntervalSince1970: 1_776_700_960)
    )

    let eligibility = try store.fetchMerchantRecommendationEligibility(normalizedMerchantName: "coffee shop")

    #expect(eligibility == nil)
}

@Test
func classifierInvisibleLearnedRulesDoNotSuppressMerchantRecommendationEligibility() throws {
    let databaseURL = try temporaryDatabaseURL()
    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()

    let account = try store.createAccount(named: "Checking", kind: .checking, institutionName: "Local Bank")
    let categoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000111")!
    try insertCategory(databaseURL: databaseURL, id: categoryID, name: "Coffee Shops", kind: "expense")

    _ = try approveMerchantRecommendationHistory(
        store: store,
        accountID: account.id,
        categoryID: categoryID,
        normalizedMerchantName: "coffee shop",
        rawDescriptions: [
            "Coffee Shop Downtown",
            "Coffee Shop Uptown",
            "Coffee Shop Midtown",
        ]
    )
    try insertRule(
        databaseURL: databaseURL,
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000223")!,
        pattern: "coffee shop",
        categoryID: nil,
        merchantName: "Coffee Shop",
        matchKind: .exactNormalizedMerchant,
        createdAt: Date(timeIntervalSince1970: 1_776_700_961)
    )
    try insertOrphanedRule(
        databaseURL: databaseURL,
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000224")!,
        pattern: "coffee shop",
        missingCategoryID: UUID(uuidString: "00000000-0000-0000-0000-000000000999")!,
        merchantName: "Coffee Shop",
        matchKind: .exactNormalizedMerchant,
        createdAt: Date(timeIntervalSince1970: 1_776_700_962)
    )

    let eligibility = try store.fetchMerchantRecommendationEligibility(normalizedMerchantName: "coffee shop")

    #expect(eligibility == MerchantRecommendationEligibility(
        normalizedMerchantName: "coffee shop",
        categoryID: categoryID,
        approvedDecisionCount: 3
    ))
}

@Test
func fetchClassificationRulesIgnoresRulesWithoutCategory() throws {
    let databaseURL = try temporaryDatabaseURL()
    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()

    try insertRule(
        databaseURL: databaseURL,
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000222")!,
        pattern: "coffee shop",
        categoryID: nil,
        merchantName: "Coffee Shop",
        createdAt: Date(timeIntervalSince1970: 1_775_171_260)
    )

    let rules = try store.fetchClassificationRules()

    #expect(rules.isEmpty)
}

@Test
func fetchClassificationRulesDefaultsLegacyRulesToContainsMatchKind() throws {
    let databaseURL = try temporaryDatabaseURL()
    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()

    let categoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000111")!
    try insertCategory(databaseURL: databaseURL, id: categoryID, name: "Coffee", kind: "expense")
    try insertRule(
        databaseURL: databaseURL,
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000222")!,
        pattern: "coffee",
        categoryID: categoryID,
        merchantName: "Coffee Shop",
        createdAt: Date(timeIntervalSince1970: 1_775_171_260)
    )

    let rules = try store.fetchClassificationRules()

    #expect(rules.count == 1)
    #expect(rules[0].matchKind == .contains)
}

@Test
func fetchClassificationRulesExcludesDisabledLearnedRules() throws {
    let databaseURL = try temporaryDatabaseURL()
    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()

    let categoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000111")!
    let learnedRuleID = UUID(uuidString: "00000000-0000-0000-0000-000000000222")!
    try insertCategory(databaseURL: databaseURL, id: categoryID, name: "Coffee", kind: "expense")
    try insertRule(
        databaseURL: databaseURL,
        id: learnedRuleID,
        pattern: "coffee shop",
        categoryID: categoryID,
        merchantName: "Coffee Shop",
        matchKind: .contains,
        createdAt: Date(timeIntervalSince1970: 1_775_171_260),
        disabledAt: Date(timeIntervalSince1970: 1_775_171_320)
    )

    let rules = try store.fetchClassificationRules()

    #expect(rules.isEmpty)
}

@Test
func fetchManagedLearnedRulesIncludesDisabledRows() throws {
    let databaseURL = try temporaryDatabaseURL()
    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()

    let categoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000111")!
    let learnedRuleID = UUID(uuidString: "00000000-0000-0000-0000-000000000222")!
    let disabledAt = Date(timeIntervalSince1970: 1_775_171_320)
    try insertCategory(databaseURL: databaseURL, id: categoryID, name: "Coffee", kind: "expense")
    try insertRule(
        databaseURL: databaseURL,
        id: learnedRuleID,
        pattern: "coffee shop",
        categoryID: categoryID,
        merchantName: "Coffee Shop",
        matchKind: .prefixNormalizedMerchant,
        createdAt: Date(timeIntervalSince1970: 1_775_171_260),
        disabledAt: disabledAt
    )

    let rules = try store.fetchLearnedRuleSummaries()

    #expect(rules.count == 1)
    #expect(rules[0].id == learnedRuleID)
    #expect(rules[0].merchantPattern == "coffee shop")
    #expect(rules[0].categoryID == categoryID)
    #expect(rules[0].merchantName == "Coffee Shop")
    #expect(rules[0].matchKind == .prefixNormalizedMerchant)
    #expect(rules[0].createdAt == Date(timeIntervalSince1970: 1_775_171_260))
    #expect(rules[0].disabledAt == disabledAt)
}

@Test
func fetchLearnedRuleSummaryAndDetailResolveDisabledRulesByID() throws {
    let databaseURL = try temporaryDatabaseURL()
    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()

    let categoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000111")!
    let learnedRuleID = UUID(uuidString: "00000000-0000-0000-0000-000000000222")!
    let disabledAt = Date(timeIntervalSince1970: 1_775_171_320)
    let createdAt = Date(timeIntervalSince1970: 1_775_171_260)
    try insertCategory(databaseURL: databaseURL, id: categoryID, name: "Coffee", kind: "expense")
    try insertRule(
        databaseURL: databaseURL,
        id: learnedRuleID,
        pattern: "coffee shop",
        categoryID: categoryID,
        merchantName: "Coffee Shop",
        matchKind: .exactNormalizedMerchant,
        createdAt: createdAt,
        disabledAt: disabledAt
    )

    let summary = try #require(try store.fetchLearnedRuleSummary(id: learnedRuleID))
    let detail = try #require(try store.fetchLearnedRuleDetail(id: learnedRuleID))

    #expect(summary.id == learnedRuleID)
    #expect(summary.merchantPattern == "coffee shop")
    #expect(summary.categoryID == categoryID)
    #expect(summary.merchantName == "Coffee Shop")
    #expect(summary.matchKind == .exactNormalizedMerchant)

    #expect(detail.id == learnedRuleID)
    #expect(detail.merchantPattern == "coffee shop")
    #expect(detail.categoryID == categoryID)
    #expect(detail.merchantName == "Coffee Shop")
    #expect(detail.matchKind == .exactNormalizedMerchant)
    #expect(detail.createdAt == createdAt)
    #expect(detail.disabledAt == disabledAt)
}

@Test
func createLearnedRulePersistsManualRulesUsingReviewAlignedNormalizationAndOrdering() throws {
    let databaseURL = try temporaryDatabaseURL()
    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()

    let categoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000119")!
    try insertCategory(databaseURL: databaseURL, id: categoryID, name: "Coffee", kind: "expense")

    _ = try store.createLearnedRule(
        LearnedRuleDraft(
            merchantPattern: "  coffee  ",
            categoryID: categoryID,
            merchantName: "Coffee",
            matchKind: .contains
        ),
        createdAt: Date(timeIntervalSince1970: 1_775_171_260)
    )
    _ = try store.createLearnedRule(
        LearnedRuleDraft(
            merchantPattern: " 99PLEDG ",
            categoryID: categoryID,
            merchantName: "99Pledg",
            matchKind: .prefixNormalizedMerchant
        ),
        createdAt: Date(timeIntervalSince1970: 1_775_171_320)
    )
    let exactRule = try store.createLearnedRule(
        LearnedRuleDraft(
            merchantPattern: "  COFFEE SHOP  ",
            categoryID: categoryID,
            merchantName: "Coffee Shop",
            matchKind: .exactNormalizedMerchant
        ),
        createdAt: Date(timeIntervalSince1970: 1_775_171_380)
    )

    let classifierRules = try store.fetchClassificationRules()
    let managedRules = try store.fetchLearnedRuleSummaries()

    #expect(classifierRules.map(\.matchKind) == [
        .exactNormalizedMerchant,
        .prefixNormalizedMerchant,
        .contains,
    ])
    #expect(classifierRules.map(\.merchantPattern) == [
        "coffee shop",
        "99pledg",
        "coffee",
    ])
    #expect(managedRules.map(\.matchKind) == [
        .exactNormalizedMerchant,
        .prefixNormalizedMerchant,
        .contains,
    ])
    #expect(managedRules.map(\.merchantPattern) == [
        "coffee shop",
        "99pledg",
        "coffee",
    ])
    #expect(exactRule.merchantPattern == "coffee shop")
    #expect(exactRule.matchKind == .exactNormalizedMerchant)
    #expect(exactRule.createdAt == Date(timeIntervalSince1970: 1_775_171_380))
    #expect(exactRule.disabledAt == nil)
}

@Test
func createLearnedRuleRejectsDraftsWithoutCategory() throws {
    let databaseURL = try temporaryDatabaseURL()
    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()

    do {
        _ = try store.createLearnedRule(
            LearnedRuleDraft(
                merchantPattern: "coffee shop",
                categoryID: nil,
                merchantName: "Coffee Shop",
                matchKind: .exactNormalizedMerchant
            ),
            createdAt: Date(timeIntervalSince1970: 1_775_171_440)
        )
        Issue.record("Expected createLearnedRule to reject drafts without a category.")
    } catch {
        #expect(error.localizedDescription == "Learned rules require a category before saving.")
    }
}

@Test
func disableAndEnableLearnedRuleRoundTripsClassifierVisibility() throws {
    let databaseURL = try temporaryDatabaseURL()
    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()

    let categoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000111")!
    let learnedRuleID = UUID(uuidString: "00000000-0000-0000-0000-000000000222")!
    let disabledAt = Date(timeIntervalSince1970: 1_775_171_320)
    try insertCategory(databaseURL: databaseURL, id: categoryID, name: "Coffee", kind: "expense")
    try insertRule(
        databaseURL: databaseURL,
        id: learnedRuleID,
        pattern: "coffee shop",
        categoryID: categoryID,
        merchantName: "Coffee Shop",
        createdAt: Date(timeIntervalSince1970: 1_775_171_260)
    )

    #expect(try store.fetchClassificationRules().map(\.id) == [learnedRuleID])

    let disabledRule = try store.disableLearnedRule(id: learnedRuleID, disabledAt: disabledAt)
    #expect(disabledRule.id == learnedRuleID)
    #expect(disabledRule.disabledAt == disabledAt)
    #expect(try store.fetchClassificationRules().isEmpty)
    #expect(try #require(try store.fetchLearnedRuleDetail(id: learnedRuleID)).disabledAt == disabledAt)

    let enabledRule = try store.enableLearnedRule(id: learnedRuleID)
    #expect(enabledRule.id == learnedRuleID)
    #expect(enabledRule.disabledAt == nil)
    #expect(try store.fetchClassificationRules().map(\.id) == [learnedRuleID])
    #expect(try #require(try store.fetchLearnedRuleSummary(id: learnedRuleID)).disabledAt == nil)
}

@Test
func fetchClassificationRulesKeepsContainsLearnedRulesVisible() throws {
    let databaseURL = try temporaryDatabaseURL()
    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()

    let categoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000111")!
    let learnedRuleID = UUID(uuidString: "00000000-0000-0000-0000-000000000222")!
    let createdAt = Date(timeIntervalSince1970: 1_775_171_260)
    try insertCategory(databaseURL: databaseURL, id: categoryID, name: "Coffee", kind: "expense")
    try insertRule(
        databaseURL: databaseURL,
        id: learnedRuleID,
        pattern: "coffee",
        categoryID: categoryID,
        merchantName: "Coffee Shop",
        createdAt: createdAt
    )

    let classifierRules = try store.fetchClassificationRules()
    let managedRules = try store.fetchLearnedRuleSummaries()

    #expect(classifierRules.count == 1)
    #expect(classifierRules[0].id == learnedRuleID)
    #expect(classifierRules[0].merchantPattern == "coffee")
    #expect(classifierRules[0].categoryID == categoryID)
    #expect(classifierRules[0].merchantName == "Coffee Shop")
    #expect(classifierRules[0].matchKind == .contains)

    #expect(managedRules.count == 1)
    #expect(managedRules[0].id == learnedRuleID)
    #expect(managedRules[0].merchantPattern == "coffee")
    #expect(managedRules[0].categoryID == categoryID)
    #expect(managedRules[0].merchantName == "Coffee Shop")
    #expect(managedRules[0].matchKind == .contains)
    #expect(managedRules[0].disabledAt == nil)
}

@Test
func bootstrapAddsDisabledAtToLegacyRulesTableWithoutDeletingRows() throws {
    let databaseURL = try temporaryDatabaseURL()
    try createWorkspaceAfterWorkspacePreferencesMigration(at: databaseURL)
    let legacyRuleID = UUID(uuidString: "00000000-0000-0000-0000-000000000333")!
    let categoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000111")!
    try insertCategory(databaseURL: databaseURL, id: categoryID, name: "Coffee", kind: "expense")
    try insertLegacyRuleWithoutDisabledAt(
        databaseURL: databaseURL,
        id: legacyRuleID,
        pattern: "coffee shop",
        categoryID: categoryID,
        merchantName: "Coffee Shop",
        createdAt: Date(timeIntervalSince1970: 1_775_171_260)
    )

    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()

    let ruleColumns = try DatabaseQueue(path: databaseURL.path).read { db in
        Set(try Row.fetchAll(db, sql: "PRAGMA table_info(rules)").map { row in
            row["name"] as String
        })
    }
    let managedRules = try store.fetchLearnedRuleSummaries()
    let classifierRules = try store.fetchClassificationRules()

    #expect(ruleColumns.contains("disabled_at"))
    #expect(managedRules.map(\.id) == [legacyRuleID])
    #expect(managedRules.first?.disabledAt == nil)
    #expect(classifierRules.map(\.id) == [legacyRuleID])
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
func keepBothLikelyDuplicateResolvesReviewItemUpdatesSourceRowDecisionAndRecordsEvent() throws {
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
    let reviewItemID = try #require(try store.fetchPendingReviewItems().first?.id)
    let resolvedAt = Date(timeIntervalSince1970: 1_775_171_260)
    let sourceRow = try #require(session.rows.first)

    let event = try store.keepBothForLikelyDuplicateReviewItem(id: reviewItemID, resolvedAt: resolvedAt)

    #expect(try store.fetchPendingReviewItems().isEmpty)
    #expect(try fetchReviewItemStatus(databaseURL: databaseURL, reviewItemID: reviewItemID) == .resolved)
    #expect(event.reviewItemID == reviewItemID)
    #expect(event.sourceRowID == sourceRow.id)
    #expect(event.action == .keepBoth)
    #expect(event.createdAt == resolvedAt)
    #expect(event.details == "User kept both the staged row and existing transaction after duplicate review.")
    #expect(try store.fetchReviewDecisionEvents(reviewItemID: reviewItemID) == [event])
    #expect(try store.fetchSummary().transactionCount == 2)

    let resolvedSession = try #require(try store.fetchStagedImportSession(id: session.id))
    #expect(resolvedSession.rows == [
        StagedSourceRow(
            id: sourceRow.id,
            sourceFileID: sourceRow.sourceFileID,
            sourceLineNumber: 2,
            rawPayload: #"["2026-04-01","Coffee Shop","-4.75"]"#,
            rowHash: "row-1-sha256",
            validationStatus: .valid,
            importDecision: .keptBothAfterLikelyDuplicateReview(
                existingTransactionID: duplicateTransactionID,
                reason: "User kept both the staged row and existing transaction after duplicate review."
            )
        ),
    ])

    let ledgerRows = try store.fetchTransactionLedger(filter: .empty)
    let createdRow = try #require(ledgerRows.first { $0.id != duplicateTransactionID })
    #expect(createdRow.importOrigin?.originalFilename == "checking-april.csv")
    #expect(createdRow.reviewStatus == .pending)
    #expect(createdRow.categoryID == nil)
    #expect(createdRow.rawDescription == "Coffee Shop")
    #expect(createdRow.amount == Decimal(-4.75))
}

@Test
func keepBothLikelyDuplicatePreservesVenmoSemanticsFromStoredMappingProfile() throws {
    let databaseURL = try temporaryDatabaseURL()
    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()

    let account = try store.createAccount(named: "Checking", kind: .checking, institutionName: "Local Bank")
    let duplicateTransactionID = UUID(uuidString: "00000000-0000-0000-0000-000000000998")!
    try insertTransaction(
        databaseURL: databaseURL,
        id: duplicateTransactionID,
        accountID: account.id,
        normalizedMerchantName: "jordan example",
        amount: Decimal(-135),
        transactionDate: Date(timeIntervalSince1970: 1_743_811_200)
    )

    let session = try store.createStagedImportSession(
        StagedImportSessionDraft(
            accountID: account.id,
            originalFilename: "venmo-april.csv",
            contentHash: "file-sha256",
            importedAt: Date(timeIntervalSince1970: 1_775_171_200),
            rows: [
                StagedSourceRowDraft(
                    sourceLineNumber: 5,
                    rawPayload: venmoOutgoingRawPayload(),
                    rowHash: "venmo-row-1-sha256",
                    validationStatus: .valid,
                    importDecision: .flaggedLikelyDuplicate(
                        existingTransactionID: duplicateTransactionID,
                        reason: "Same account, amount, normalized merchant, and nearby date."
                    )
                ),
            ],
            mapping: CSVColumnMapping(
                dateColumnIndex: 2,
                descriptionColumnIndex: 6,
                amount: .singleSignedAmount(columnIndex: 8),
                profile: .venmoStatement
            ),
            validRowCount: 1,
            invalidRowCount: 0,
            status: .staged
        )
    )
    let reviewItemID = try #require(try store.fetchPendingReviewItems().first?.id)

    _ = try store.keepBothForLikelyDuplicateReviewItem(
        id: reviewItemID,
        resolvedAt: Date(timeIntervalSince1970: 1_775_171_260)
    )

    let ledgerRows = try store.fetchTransactionLedger(filter: .empty)
    let createdRow = try #require(ledgerRows.first { $0.id != duplicateTransactionID })
    #expect(createdRow.importOrigin?.id == session.id)
    #expect(createdRow.rawDescription == "Groceries")
    #expect(createdRow.merchantName == "jordan example")
    #expect(createdRow.amount == Decimal(-135))
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

@Test
func fetchWorkspaceInsightSummarySurfacesSupportedCadencesAndFiltersInvalidSeries() throws {
    let databaseURL = try temporaryDatabaseURL()
    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()

    let primaryAccount = try store.createAccount(named: "Checking", kind: .checking, institutionName: "Local Bank")

    let monthlyTransactionIDs = try insertRecurringTransactions(
        databaseURL: databaseURL,
        accountID: primaryAccount.id,
        normalizedMerchantName: "video streaming",
        observations: [
            (UUID(uuidString: "00000000-0000-0000-0000-00000000a101")!, Decimal(-12.99), recurringUTCDate(year: 2026, month: 1, day: 9), "accepted", false),
            (UUID(uuidString: "00000000-0000-0000-0000-00000000a102")!, Decimal(-12.99), recurringUTCDate(year: 2026, month: 2, day: 9), "accepted", false),
            (UUID(uuidString: "00000000-0000-0000-0000-00000000a103")!, Decimal(-13.49), recurringUTCDate(year: 2026, month: 3, day: 9), "accepted", false),
        ]
    )
    let quarterlyTransactionIDs = try insertRecurringTransactions(
        databaseURL: databaseURL,
        accountID: primaryAccount.id,
        normalizedMerchantName: "car insurance",
        observations: [
            (UUID(uuidString: "00000000-0000-0000-0000-00000000b101")!, Decimal(-90), recurringUTCDate(year: 2025, month: 10, day: 14), "accepted", false),
            (UUID(uuidString: "00000000-0000-0000-0000-00000000b102")!, Decimal(-90), recurringUTCDate(year: 2026, month: 1, day: 14), "accepted", false),
            (UUID(uuidString: "00000000-0000-0000-0000-00000000b103")!, Decimal(-95), recurringUTCDate(year: 2026, month: 4, day: 14), "accepted", false),
        ]
    )
    let annualTransactionIDs = try insertRecurringTransactions(
        databaseURL: databaseURL,
        accountID: primaryAccount.id,
        normalizedMerchantName: "domain renewal",
        observations: [
            (UUID(uuidString: "00000000-0000-0000-0000-00000000c101")!, Decimal(-72), recurringUTCDate(year: 2023, month: 6, day: 2), "accepted", false),
            (UUID(uuidString: "00000000-0000-0000-0000-00000000c102")!, Decimal(-72), recurringUTCDate(year: 2024, month: 6, day: 2), "accepted", false),
            (UUID(uuidString: "00000000-0000-0000-0000-00000000c103")!, Decimal(-75), recurringUTCDate(year: 2025, month: 6, day: 2), "accepted", false),
        ]
    )

    _ = try insertRecurringTransactions(
        databaseURL: databaseURL,
        accountID: primaryAccount.id,
        normalizedMerchantName: "hidden gym",
        observations: [
            (UUID(uuidString: "00000000-0000-0000-0000-00000000d101")!, Decimal(-40), recurringUTCDate(year: 2026, month: 1, day: 3), "accepted", false),
            (UUID(uuidString: "00000000-0000-0000-0000-00000000d102")!, Decimal(-40), recurringUTCDate(year: 2026, month: 2, day: 3), "accepted", true),
            (UUID(uuidString: "00000000-0000-0000-0000-00000000d103")!, Decimal(-40), recurringUTCDate(year: 2026, month: 3, day: 3), "accepted", false),
        ]
    )
    _ = try insertRecurringTransactions(
        databaseURL: databaseURL,
        accountID: primaryAccount.id,
        normalizedMerchantName: "stale backup",
        observations: [
            (UUID(uuidString: "00000000-0000-0000-0000-00000000e101")!, Decimal(-9.99), recurringUTCDate(year: 2025, month: 1, day: 5), "accepted", false),
            (UUID(uuidString: "00000000-0000-0000-0000-00000000e102")!, Decimal(-9.99), recurringUTCDate(year: 2025, month: 2, day: 5), "accepted", false),
            (UUID(uuidString: "00000000-0000-0000-0000-00000000e103")!, Decimal(-9.99), recurringUTCDate(year: 2025, month: 3, day: 5), "accepted", false),
        ]
    )
    _ = try insertRecurringTransactions(
        databaseURL: databaseURL,
        accountID: primaryAccount.id,
        normalizedMerchantName: "music svc",
        observations: [
            (UUID(uuidString: "00000000-0000-0000-0000-00000000f101")!, Decimal(-8.99), recurringUTCDate(year: 2026, month: 1, day: 12), "accepted", false),
            (UUID(uuidString: "00000000-0000-0000-0000-00000000f102")!, Decimal(-8.99), recurringUTCDate(year: 2026, month: 2, day: 12), "accepted", false),
            (UUID(uuidString: "00000000-0000-0000-0000-00000000f103")!, Decimal(-8.99), recurringUTCDate(year: 2026, month: 3, day: 12), "accepted", false),
        ]
    )
    _ = try insertRecurringTransactions(
        databaseURL: databaseURL,
        accountID: primaryAccount.id,
        normalizedMerchantName: "music service",
        observations: [
            (UUID(uuidString: "00000000-0000-0000-0000-00000000f104")!, Decimal(-8.99), recurringUTCDate(year: 2026, month: 4, day: 12), "accepted", false),
        ]
    )
    _ = try insertRecurringTransactions(
        databaseURL: databaseURL,
        accountID: primaryAccount.id,
        normalizedMerchantName: "weekend coffee",
        observations: [
            (UUID(uuidString: "00000000-0000-0000-0000-000000001101")!, Decimal(-6), recurringUTCDate(year: 2026, month: 2, day: 2), "accepted", false),
            (UUID(uuidString: "00000000-0000-0000-0000-000000001102")!, Decimal(-6), recurringUTCDate(year: 2026, month: 3, day: 2), "accepted", false),
        ]
    )
    _ = try insertRecurringTransactions(
        databaseURL: databaseURL,
        accountID: primaryAccount.id,
        normalizedMerchantName: "affirm installment",
        observations: [
            (UUID(uuidString: "00000000-0000-0000-0000-000000001201")!, Decimal(-120), recurringUTCDate(year: 2026, month: 1, day: 18), "accepted", false),
            (UUID(uuidString: "00000000-0000-0000-0000-000000001202")!, Decimal(-120), recurringUTCDate(year: 2026, month: 2, day: 18), "accepted", false),
            (UUID(uuidString: "00000000-0000-0000-0000-000000001203")!, Decimal(-120), recurringUTCDate(year: 2026, month: 3, day: 18), "accepted", false),
        ]
    )

    let summary = try store.fetchWorkspaceInsightSummary(referenceDate: recurringUTCDate(year: 2026, month: 4, day: 23))
    let recurringDetails: [RecurringChargeInsightDetail] = summary.insights.compactMap(recurringDetail(from:))
    let recurringDetailsByMerchant = Dictionary(uniqueKeysWithValues: recurringDetails.map { ($0.normalizedMerchantName, $0) })

    #expect(Set(recurringDetails.map(\.normalizedMerchantName)) == Set([
        "car insurance",
        "video streaming",
        "music svc",
        "domain renewal",
    ]))
    #expect(recurringDetailsByMerchant["car insurance"]?.cadence == .quarterly)
    #expect(recurringDetailsByMerchant["video streaming"]?.cadence == .monthly)
    #expect(recurringDetailsByMerchant["music svc"]?.cadence == .monthly)
    #expect(recurringDetailsByMerchant["domain renewal"]?.cadence == .annual)
    #expect(recurringDetailsByMerchant["car insurance"]?.observationCount == 3)
    #expect(recurringDetailsByMerchant["video streaming"]?.observationCount == 3)
    #expect(recurringDetailsByMerchant["music svc"]?.observationCount == 3)
    #expect(recurringDetailsByMerchant["domain renewal"]?.observationCount == 3)
    #expect(recurringDetailsByMerchant["car insurance"]?.supportingTransactionIDs == quarterlyTransactionIDs)
    #expect(recurringDetailsByMerchant["video streaming"]?.supportingTransactionIDs == monthlyTransactionIDs)
    #expect(recurringDetailsByMerchant["music svc"]?.supportingTransactionIDs == [
        UUID(uuidString: "00000000-0000-0000-0000-00000000f101")!,
        UUID(uuidString: "00000000-0000-0000-0000-00000000f102")!,
        UUID(uuidString: "00000000-0000-0000-0000-00000000f103")!,
    ])
    #expect(recurringDetailsByMerchant["domain renewal"]?.supportingTransactionIDs == annualTransactionIDs)
    #expect(recurringDetailsByMerchant["video streaming"]?.amountRange == RecurringChargeAmountRange(minimum: Decimal(12.99), maximum: Decimal(13.49)))
    #expect(recurringDetailsByMerchant["video streaming"]?.lastObservedDate == recurringUTCDate(year: 2026, month: 3, day: 9))
    #expect(recurringDetailsByMerchant["car insurance"]?.lastObservedDate == recurringUTCDate(year: 2026, month: 4, day: 14))
    #expect(recurringDetailsByMerchant["domain renewal"]?.lastObservedDate == recurringUTCDate(year: 2025, month: 6, day: 2))
    #expect(recurringDetails.contains { $0.normalizedMerchantName == "hidden gym" } == false)
    #expect(recurringDetails.contains { $0.normalizedMerchantName == "stale backup" } == false)
    #expect(recurringDetails.contains { $0.normalizedMerchantName == "music service" } == false)
    #expect(recurringDetails.contains { $0.normalizedMerchantName == "weekend coffee" } == false)
    #expect(recurringDetails.contains { $0.normalizedMerchantName == "affirm installment" } == false)
}

@Test
func fetchWorkspaceInsightSummaryKeepsOnlyCadenceSupportingEvidenceForNoisySeries() throws {
    let databaseURL = try temporaryDatabaseURL()
    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()

    let account = try store.createAccount(named: "Checking", kind: .checking, institutionName: "Local Bank")
    let supportingIDs = [
        UUID(uuidString: "00000000-0000-0000-0000-000000008901")!,
        UUID(uuidString: "00000000-0000-0000-0000-000000008902")!,
        UUID(uuidString: "00000000-0000-0000-0000-000000008903")!,
    ]
    let outlierID = UUID(uuidString: "00000000-0000-0000-0000-000000008904")!

    _ = try insertRecurringTransactions(
        databaseURL: databaseURL,
        accountID: account.id,
        normalizedMerchantName: "cell service",
        observations: [
            (supportingIDs[0], Decimal(-55), recurringUTCDate(year: 2026, month: 1, day: 15), "accepted", false),
            (supportingIDs[1], Decimal(-55), recurringUTCDate(year: 2026, month: 2, day: 15), "accepted", false),
            (supportingIDs[2], Decimal(-55), recurringUTCDate(year: 2026, month: 3, day: 15), "accepted", false),
            (outlierID, Decimal(-55), recurringUTCDate(year: 2026, month: 5, day: 15), "accepted", false),
        ]
    )

    let summary = try store.fetchWorkspaceInsightSummary(referenceDate: recurringUTCDate(year: 2026, month: 5, day: 17))
    let detail = try #require(summary.insights.compactMap(recurringDetail(from:)).first)

    #expect(detail.normalizedMerchantName == "cell service")
    #expect(detail.observationCount == 3)
    #expect(detail.supportingTransactionIDs == supportingIDs)
    #expect(detail.supportingTransactionIDs.contains(outlierID) == false)
    #expect(detail.lastObservedDate == recurringUTCDate(year: 2026, month: 3, day: 15))
}

@Test
func fetchWorkspaceInsightSummaryRanksRecurringCandidatesDeterministically() throws {
    let databaseURL = try temporaryDatabaseURL()
    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()

    let accountA = try store.createAccount(named: "Checking", kind: .checking, institutionName: "Local Bank")
    let accountB = try store.createAccount(named: "Savings", kind: .savings, institutionName: "Local Bank")

    _ = try insertRecurringTransactions(
        databaseURL: databaseURL,
        accountID: accountA.id,
        normalizedMerchantName: "camera club",
        observations: [
            (UUID(uuidString: "00000000-0000-0000-0000-000000009101")!, Decimal(-25), recurringUTCDate(year: 2026, month: 2, day: 22), "accepted", false),
            (UUID(uuidString: "00000000-0000-0000-0000-000000009102")!, Decimal(-25), recurringUTCDate(year: 2026, month: 3, day: 22), "accepted", false),
            (UUID(uuidString: "00000000-0000-0000-0000-000000009103")!, Decimal(-25), recurringUTCDate(year: 2026, month: 4, day: 22), "accepted", false),
        ]
    )
    _ = try insertRecurringTransactions(
        databaseURL: databaseURL,
        accountID: accountA.id,
        normalizedMerchantName: "aardvark care",
        observations: [
            (UUID(uuidString: "00000000-0000-0000-0000-000000009201")!, Decimal(-25), recurringUTCDate(year: 2026, month: 1, day: 21), "accepted", false),
            (UUID(uuidString: "00000000-0000-0000-0000-000000009202")!, Decimal(-25), recurringUTCDate(year: 2026, month: 2, day: 21), "accepted", false),
            (UUID(uuidString: "00000000-0000-0000-0000-000000009203")!, Decimal(-25), recurringUTCDate(year: 2026, month: 3, day: 21), "accepted", false),
            (UUID(uuidString: "00000000-0000-0000-0000-000000009204")!, Decimal(-25), recurringUTCDate(year: 2026, month: 4, day: 21), "accepted", false),
        ]
    )
    _ = try insertRecurringTransactions(
        databaseURL: databaseURL,
        accountID: accountB.id,
        normalizedMerchantName: "aardvark care",
        observations: [
            (UUID(uuidString: "00000000-0000-0000-0000-000000009301")!, Decimal(-25), recurringUTCDate(year: 2026, month: 1, day: 21), "accepted", false),
            (UUID(uuidString: "00000000-0000-0000-0000-000000009302")!, Decimal(-25), recurringUTCDate(year: 2026, month: 2, day: 21), "accepted", false),
            (UUID(uuidString: "00000000-0000-0000-0000-000000009303")!, Decimal(-25), recurringUTCDate(year: 2026, month: 3, day: 21), "accepted", false),
            (UUID(uuidString: "00000000-0000-0000-0000-000000009304")!, Decimal(-25), recurringUTCDate(year: 2026, month: 4, day: 21), "accepted", false),
        ]
    )
    _ = try insertRecurringTransactions(
        databaseURL: databaseURL,
        accountID: accountA.id,
        normalizedMerchantName: "zeta care",
        observations: [
            (UUID(uuidString: "00000000-0000-0000-0000-000000009401")!, Decimal(-25), recurringUTCDate(year: 2026, month: 1, day: 21), "accepted", false),
            (UUID(uuidString: "00000000-0000-0000-0000-000000009402")!, Decimal(-25), recurringUTCDate(year: 2026, month: 2, day: 21), "accepted", false),
            (UUID(uuidString: "00000000-0000-0000-0000-000000009403")!, Decimal(-25), recurringUTCDate(year: 2026, month: 3, day: 21), "accepted", false),
            (UUID(uuidString: "00000000-0000-0000-0000-000000009404")!, Decimal(-25), recurringUTCDate(year: 2026, month: 4, day: 21), "accepted", false),
        ]
    )
    _ = try insertRecurringTransactions(
        databaseURL: databaseURL,
        accountID: accountA.id,
        normalizedMerchantName: "alpha lite",
        observations: [
            (UUID(uuidString: "00000000-0000-0000-0000-000000009601")!, Decimal(-25), recurringUTCDate(year: 2026, month: 2, day: 21), "accepted", false),
            (UUID(uuidString: "00000000-0000-0000-0000-000000009602")!, Decimal(-25), recurringUTCDate(year: 2026, month: 3, day: 21), "accepted", false),
            (UUID(uuidString: "00000000-0000-0000-0000-000000009603")!, Decimal(-25), recurringUTCDate(year: 2026, month: 4, day: 21), "accepted", false),
        ]
    )
    _ = try insertRecurringTransactions(
        databaseURL: databaseURL,
        accountID: accountA.id,
        normalizedMerchantName: "noisy cable 1234",
        observations: [
            (UUID(uuidString: "00000000-0000-0000-0000-000000009501")!, Decimal(-60), recurringUTCDate(year: 2026, month: 1, day: 24), "accepted", false),
            (UUID(uuidString: "00000000-0000-0000-0000-000000009502")!, Decimal(-60), recurringUTCDate(year: 2026, month: 2, day: 24), "accepted", false),
            (UUID(uuidString: "00000000-0000-0000-0000-000000009503")!, Decimal(-60), recurringUTCDate(year: 2026, month: 3, day: 24), "accepted", false),
            (UUID(uuidString: "00000000-0000-0000-0000-000000009504")!, Decimal(-60), recurringUTCDate(year: 2026, month: 5, day: 24), "accepted", false),
        ]
    )

    let summary = try store.fetchWorkspaceInsightSummary(referenceDate: recurringUTCDate(year: 2026, month: 5, day: 26))
    let recurringDetails: [RecurringChargeInsightDetail] = summary.insights.compactMap(recurringDetail(from:))
    let expectedAardvarkAccountOrder = [accountA.id, accountB.id].sorted { $0.uuidString < $1.uuidString }

    #expect(recurringDetails.map(\.normalizedMerchantName) == [
        "camera club",
        "aardvark care",
        "aardvark care",
        "zeta care",
        "alpha lite",
        "noisy cable 1234",
    ])
    #expect(recurringDetails[0].accountID == accountA.id)
    #expect(recurringDetails[1].accountID == expectedAardvarkAccountOrder[0])
    #expect(recurringDetails[2].accountID == expectedAardvarkAccountOrder[1])
    #expect(recurringDetails[3].accountID == accountA.id)
    #expect(recurringDetails[4].accountID == accountA.id)
    #expect(recurringDetails[5].accountID == accountA.id)
    #expect(summary.insights.map(\.rank) == [1, 2, 3, 4, 5, 6])
    #expect(summary.insights[0].score == summary.insights[1].score)
    #expect(summary.insights[1].score == summary.insights[2].score)
    #expect(summary.insights[2].score == summary.insights[3].score)
    #expect(summary.insights[3].score == summary.insights[4].score)
    #expect(summary.insights[4].score > summary.insights[5].score)
    #expect(summary.insights[0].confidence == summary.insights[1].confidence)
    #expect(summary.insights[1].confidence == summary.insights[2].confidence)
    #expect(summary.insights[2].confidence == summary.insights[3].confidence)
    #expect(summary.insights[3].confidence == summary.insights[4].confidence)
    #expect(summary.insights[4].confidence > summary.insights[5].confidence)
}

@Test
func fetchWorkspaceInsightSummaryAddsSpendDriverChangeInsightWithEvidence() throws {
    let databaseURL = try temporaryDatabaseURL()
    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()

    let account = try store.createAccount(named: "Checking", kind: .checking, institutionName: "Local Bank")
    let foodGroupID = UUID(uuidString: "00000000-0000-0000-0000-00000000aa01")!
    let diningID = UUID(uuidString: "00000000-0000-0000-0000-00000000aa02")!
    try insertCategoryGroup(databaseURL: databaseURL, id: foodGroupID, name: "Food")
    try insertCategory(databaseURL: databaseURL, id: diningID, name: "Dining", kind: "expense", categoryGroupID: foodGroupID)
    try insertLedgerTransaction(
        databaseURL: databaseURL,
        id: UUID(uuidString: "00000000-0000-0000-0000-00000000aa11")!,
        accountID: account.id,
        categoryID: diningID,
        importSessionID: nil,
        rawDescription: "Dining April",
        normalizedMerchantName: "dining april",
        amount: Decimal(-180),
        transactionDate: recurringUTCDate(year: 2026, month: 4, day: 10),
        reviewStatus: "accepted"
    )
    try insertLedgerTransaction(
        databaseURL: databaseURL,
        id: UUID(uuidString: "00000000-0000-0000-0000-00000000aa12")!,
        accountID: account.id,
        categoryID: diningID,
        importSessionID: nil,
        rawDescription: "Dining March",
        normalizedMerchantName: "dining march",
        amount: Decimal(-40),
        transactionDate: recurringUTCDate(year: 2026, month: 3, day: 10),
        reviewStatus: "accepted"
    )

    let summary = try store.fetchWorkspaceInsightSummary(referenceDate: recurringUTCDate(year: 2026, month: 4, day: 15))
    let insight = try #require(summary.insights.first(where: { spendDriverChangeDetail(from: $0) != nil }))
    let detail = try #require(spendDriverChangeDetail(from: insight))

    #expect(detail.title == "Dining")
    #expect(detail.scope == .category(diningID))
    #expect(detail.currentSpend == Decimal(180))
    #expect(detail.comparisonSpend == Decimal(40))
    #expect(detail.delta == Decimal(140))
    #expect(insight.family == .spendDriverChange)
    #expect(insight.evidence.scope == .category(diningID))
    #expect(insight.evidence.destination == InsightEvidenceDestination(
        scope: .category(diningID),
        direction: .expense
    ))
    #expect(summary.homeProjectedInsights.contains(where: { candidate in
        spendDriverChangeDetail(from: candidate) != nil
    }))
}

@Test
func fetchWorkspaceInsightSummaryRanksSpendDriverChangeAgainstRecurringInsights() throws {
    let databaseURL = try temporaryDatabaseURL()
    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()

    let account = try store.createAccount(named: "Checking", kind: .checking, institutionName: "Local Bank")
    let foodGroupID = UUID(uuidString: "00000000-0000-0000-0000-00000000ab01")!
    let diningID = UUID(uuidString: "00000000-0000-0000-0000-00000000ab02")!
    try insertCategoryGroup(databaseURL: databaseURL, id: foodGroupID, name: "Food")
    try insertCategory(databaseURL: databaseURL, id: diningID, name: "Dining", kind: "expense", categoryGroupID: foodGroupID)
    _ = try insertRecurringTransactions(
        databaseURL: databaseURL,
        accountID: account.id,
        normalizedMerchantName: "video streaming",
        observations: [
            (UUID(uuidString: "00000000-0000-0000-0000-00000000ab11")!, Decimal(-12.99), recurringUTCDate(year: 2026, month: 1, day: 9), "accepted", false),
            (UUID(uuidString: "00000000-0000-0000-0000-00000000ab12")!, Decimal(-12.99), recurringUTCDate(year: 2026, month: 2, day: 9), "accepted", false),
            (UUID(uuidString: "00000000-0000-0000-0000-00000000ab13")!, Decimal(-13.49), recurringUTCDate(year: 2026, month: 3, day: 9), "accepted", false),
        ]
    )
    try insertLedgerTransaction(
        databaseURL: databaseURL,
        id: UUID(uuidString: "00000000-0000-0000-0000-00000000ab21")!,
        accountID: account.id,
        categoryID: diningID,
        importSessionID: nil,
        rawDescription: "Dining April",
        normalizedMerchantName: "dining april",
        amount: Decimal(-240),
        transactionDate: recurringUTCDate(year: 2026, month: 4, day: 10),
        reviewStatus: "accepted"
    )
    try insertLedgerTransaction(
        databaseURL: databaseURL,
        id: UUID(uuidString: "00000000-0000-0000-0000-00000000ab22")!,
        accountID: account.id,
        categoryID: diningID,
        importSessionID: nil,
        rawDescription: "Dining March",
        normalizedMerchantName: "dining march",
        amount: Decimal(-30),
        transactionDate: recurringUTCDate(year: 2026, month: 3, day: 10),
        reviewStatus: "accepted"
    )

    let summary = try store.fetchWorkspaceInsightSummary(referenceDate: recurringUTCDate(year: 2026, month: 4, day: 15))

    #expect(summary.insights.prefix(2).map(\.family) == [.spendDriverChange, .recurringCharge])
    #expect(summary.homeProjectedInsights.map(\.family) == [.spendDriverChange, .recurringCharge])
}

func temporaryDatabaseURL() throws -> URL {
    let directory = try temporaryDirectoryURL()
    return directory.appending(path: "workspace.sqlite")
}

func temporaryDirectoryURL() throws -> URL {
    let directory = FileManager.default.temporaryDirectory
        .appending(path: "AlderwisePersistenceTests-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
}

private func replaceSeededCategoriesWithCustomCategory(databaseURL: URL) throws {
    let groupID = UUID(uuidString: "00000000-0000-0000-0000-00000000c001")!
    let categoryID = UUID(uuidString: "00000000-0000-0000-0000-00000000c002")!
    let queue = try DatabaseQueue(path: databaseURL.path)
    try queue.write { db in
        try db.execute(sql: "DELETE FROM categories")
        try db.execute(sql: "DELETE FROM category_groups")
        try db.execute(
            sql: "INSERT INTO category_groups (id, name) VALUES (?, ?)",
            arguments: [groupID.uuidString, "Custom"]
        )
        try db.execute(
            sql: "INSERT INTO categories (id, name, kind, category_group_id) VALUES (?, ?, ?, ?)",
            arguments: [categoryID.uuidString, "Custom Food", "expense", groupID.uuidString]
        )
    }
}

private func fetchReviewItemStatus(databaseURL: URL, reviewItemID: UUID) throws -> ReviewItemStatus? {
    let queue = try DatabaseQueue(path: databaseURL.path)
    return try queue.read { db in
        guard let statusText = try String.fetchOne(
            db,
            sql: "SELECT status FROM review_items WHERE id = ?",
            arguments: [reviewItemID.uuidString]
        ) else {
            return nil
        }

        return ReviewItemStatus(rawValue: statusText)
    }
}

private func reviewItemTransactionID(databaseURL: URL, reviewItemID: UUID) throws -> UUID? {
    let queue = try DatabaseQueue(path: databaseURL.path)
    return try queue.read { db in
        guard let transactionIDText = try String.fetchOne(
            db,
            sql: "SELECT transaction_id FROM review_items WHERE id = ?",
            arguments: [reviewItemID.uuidString]
        ) else {
            return nil
        }

        return UUID(uuidString: transactionIDText)
    }
}

private func setTransactionAcceptedWithoutResolvingReviewItem(
    databaseURL: URL,
    transactionID: UUID,
    categoryID: UUID
) throws {
    let queue = try DatabaseQueue(path: databaseURL.path)
    try queue.write { db in
        try db.execute(
            sql: """
            UPDATE transactions
            SET category_id = ?,
                decision_source = ?,
                decision_source_reference = NULL,
                confidence = ?,
                review_status = ?
            WHERE id = ?
            """,
            arguments: [
                categoryID.uuidString,
                ClassificationDecisionSource.user.rawValue,
                1.0,
                TransactionReviewStatus.accepted.rawValue,
                transactionID.uuidString,
            ]
        )
    }
}

private func setTransactionHidden(
    databaseURL: URL,
    transactionID: UUID,
    isHidden: Bool
) throws {
    let queue = try DatabaseQueue(path: databaseURL.path)
    try queue.write { db in
        try db.execute(
            sql: """
            UPDATE transactions
            SET is_hidden = ?
            WHERE id = ?
            """,
            arguments: [isHidden, transactionID.uuidString]
        )
    }
}

func createWorkspaceAfterWorkspacePreferencesMigration(at databaseURL: URL) throws {
    let queue = try DatabaseQueue(path: databaseURL.path)
    try queue.write { db in
        try db.execute(sql: "PRAGMA foreign_keys = ON")
        try db.execute(sql: "CREATE TABLE grdb_migrations (identifier TEXT NOT NULL PRIMARY KEY)")
        for identifier in [
            "create-v1-schema",
            "expand-staged-import-schema",
            "add-review-decision-events",
            "add-classification-review-context",
            "add-category-group-membership",
            "repair-staged-import-ledger-materialization",
            "add-workspace-preferences",
        ] {
            try db.execute(sql: "INSERT INTO grdb_migrations (identifier) VALUES (?)", arguments: [identifier])
        }

        try db.execute(sql: "CREATE TABLE accounts (id TEXT PRIMARY KEY, name TEXT NOT NULL, kind TEXT NOT NULL, institution_name TEXT, created_at DATETIME NOT NULL)")
        try db.execute(sql: "CREATE TABLE source_files (id INTEGER PRIMARY KEY AUTOINCREMENT, account_id TEXT NOT NULL, original_filename TEXT NOT NULL, content_hash TEXT NOT NULL, imported_at DATETIME NOT NULL, row_count INTEGER NOT NULL)")
        try db.execute(sql: "CREATE TABLE source_rows (id INTEGER PRIMARY KEY AUTOINCREMENT, source_file_id INTEGER NOT NULL, row_hash TEXT NOT NULL, raw_payload TEXT NOT NULL, source_line_number INTEGER NOT NULL DEFAULT 0, validation_status TEXT NOT NULL DEFAULT 'valid', import_decision_kind TEXT NOT NULL DEFAULT 'imported', decision_reason TEXT NOT NULL DEFAULT 'New source row.', duplicate_transaction_id TEXT)")
        try db.execute(sql: "CREATE TABLE import_sessions (id INTEGER PRIMARY KEY AUTOINCREMENT, account_id TEXT NOT NULL, source_file_id INTEGER, mapping_json TEXT NOT NULL, valid_row_count INTEGER NOT NULL, invalid_row_count INTEGER NOT NULL, status TEXT NOT NULL, created_at DATETIME NOT NULL)")
        try db.execute(
            sql: """
            CREATE TABLE transactions (
                id TEXT PRIMARY KEY,
                account_id TEXT,
                import_session_id INTEGER,
                merchant_id TEXT,
                category_id TEXT,
                raw_description TEXT NOT NULL DEFAULT '',
                normalized_merchant_name TEXT,
                amount DOUBLE NOT NULL DEFAULT 0,
                transaction_date DATE NOT NULL DEFAULT CURRENT_DATE,
                posted_date DATE,
                direction TEXT NOT NULL DEFAULT 'expense',
                decision_source TEXT NOT NULL DEFAULT 'user',
                decision_source_reference TEXT,
                confidence DOUBLE,
                review_status TEXT NOT NULL DEFAULT 'accepted',
                duplicate_status TEXT NOT NULL DEFAULT 'none',
                notes TEXT
            )
            """
        )
        try db.execute(sql: "CREATE TABLE review_items (id TEXT PRIMARY KEY, transaction_id TEXT, source_row_id INTEGER, duplicate_transaction_id TEXT, type TEXT NOT NULL, status TEXT NOT NULL, reason TEXT, normalized_merchant_name TEXT, suggested_category_id TEXT, suggested_merchant_name TEXT, classification_source TEXT, classification_source_reference TEXT, classification_confidence DOUBLE, created_at DATETIME NOT NULL)")
        try db.execute(sql: "CREATE TABLE categories (id TEXT PRIMARY KEY, name TEXT NOT NULL, kind TEXT NOT NULL, category_group_id TEXT)")
        try db.execute(sql: "CREATE TABLE category_groups (id TEXT PRIMARY KEY, name TEXT NOT NULL)")
        try db.execute(sql: "CREATE TABLE targets (id TEXT PRIMARY KEY, category_id TEXT, category_group_id TEXT, monthly_limit DOUBLE NOT NULL, created_at DATETIME NOT NULL)")
        try db.execute(sql: "CREATE TABLE rules (id TEXT PRIMARY KEY, pattern TEXT NOT NULL, category_id TEXT, merchant_name TEXT, created_at DATETIME NOT NULL)")
        try db.execute(sql: "CREATE TABLE review_decision_events (id TEXT PRIMARY KEY, review_item_id TEXT NOT NULL, source_row_id INTEGER NOT NULL, action TEXT NOT NULL, details TEXT NOT NULL, created_at DATETIME NOT NULL)")
        try db.execute(sql: "CREATE TABLE decision_events (id TEXT PRIMARY KEY, transaction_id TEXT NOT NULL, source TEXT NOT NULL, details TEXT NOT NULL, created_at DATETIME NOT NULL)")
        try db.execute(sql: "CREATE TABLE workspace_preferences (key TEXT PRIMARY KEY, value TEXT NOT NULL)")
        try db.execute(
            sql: "INSERT INTO workspace_preferences (key, value) VALUES (?, ?)",
            arguments: ["suggestions_enabled", "true"]
        )
    }
}

func createWorkspaceAtLatestPreInferenceSchema(at databaseURL: URL) throws {
    try createWorkspaceAfterWorkspacePreferencesMigration(at: databaseURL)

    let queue = try DatabaseQueue(path: databaseURL.path)
    try queue.write { db in
        for identifier in [
            "add-rule-match-kind",
            "add-rule-lifecycle",
            "add-seeded-heuristic-auto-accept-preference",
            "accept-user-categorized-pending-transactions",
            "enforce-target-scope-invariants",
            "add-account-archive-state",
            "add-transaction-hidden-state",
        ] {
            try db.execute(
                sql: "INSERT INTO grdb_migrations (identifier) VALUES (?)",
                arguments: [identifier]
            )
        }

        try db.execute(
            sql: """
            ALTER TABLE rules
            ADD COLUMN match_kind TEXT NOT NULL DEFAULT 'contains'
            """
        )
        try db.execute(
            sql: """
            ALTER TABLE rules
            ADD COLUMN disabled_at DATETIME
            """
        )
        try db.execute(
            sql: """
            INSERT INTO workspace_preferences (key, value)
            VALUES (?, ?)
            """,
            arguments: ["seeded_heuristic_auto_accept_enabled", "false"]
        )
        try db.execute(sql: "ALTER TABLE accounts ADD COLUMN archived_at DATETIME")
        try db.execute(
            sql: """
            ALTER TABLE transactions
            ADD COLUMN is_hidden BOOLEAN NOT NULL DEFAULT 0
            """
        )
    }
}

private func insertLegacyTargetsForBootstrapOverlapRegression(databaseURL: URL) throws {
    let queue = try DatabaseQueue(path: databaseURL.path)
    try queue.write { db in
        try db.execute(
            sql: "INSERT INTO categories (id, name, kind, category_group_id) VALUES (?, ?, ?, ?)",
            arguments: [
                DefaultBudgetTaxonomy.CategoryID.groceries.uuidString,
                "Groceries",
                "expense",
                nil as String?,
            ]
        )
        try db.execute(
            sql: """
            INSERT INTO targets (id, category_id, category_group_id, monthly_limit, created_at)
            VALUES (?, ?, ?, ?, ?), (?, ?, ?, ?, ?)
            """,
            arguments: [
                UUID(uuidString: "00000000-0000-0000-0000-000000009001")!.uuidString,
                DefaultBudgetTaxonomy.CategoryID.groceries.uuidString,
                nil as String?,
                125.0,
                Date(timeIntervalSince1970: 1_775_171_200),
                UUID(uuidString: "00000000-0000-0000-0000-000000009002")!.uuidString,
                nil as String?,
                DefaultBudgetTaxonomy.CategoryGroupID.foodAndDrink.uuidString,
                250.0,
                Date(timeIntervalSince1970: 1_775_171_201),
            ]
        )
    }
}

private func insertLegacyTravelTargetsForBootstrapOverlapRegression(databaseURL: URL) throws {
    let queue = try DatabaseQueue(path: databaseURL.path)
    try queue.write { db in
        try db.execute(
            sql: "INSERT INTO categories (id, name, kind, category_group_id) VALUES (?, ?, ?, ?)",
            arguments: [
                flightsCategoryID.uuidString,
                "Flights",
                "expense",
                nil as String?,
            ]
        )
        try db.execute(
            sql: """
            INSERT INTO targets (id, category_id, category_group_id, monthly_limit, created_at)
            VALUES (?, ?, ?, ?, ?), (?, ?, ?, ?, ?)
            """,
            arguments: [
                UUID(uuidString: "00000000-0000-0000-0000-000000009031")!.uuidString,
                flightsCategoryID.uuidString,
                nil as String?,
                400.0,
                Date(timeIntervalSince1970: 1_775_171_200),
                UUID(uuidString: "00000000-0000-0000-0000-000000009032")!.uuidString,
                nil as String?,
                travelCategoryGroupID.uuidString,
                750.0,
                Date(timeIntervalSince1970: 1_775_171_201),
            ]
        )
    }
}

private func insertAmbiguousLegacyTargetForReadRegression(databaseURL: URL) throws {
    let queue = try DatabaseQueue(path: databaseURL.path)
    try queue.write { db in
        try db.execute(
            sql: """
            INSERT INTO categories (id, name, kind, category_group_id)
            VALUES (?, ?, ?, ?)
            """,
            arguments: [
                DefaultBudgetTaxonomy.CategoryID.groceries.uuidString,
                "Groceries",
                "expense",
                nil as String?,
            ]
        )
        try db.execute(
            sql: """
            INSERT INTO targets (id, category_id, category_group_id, monthly_limit, created_at)
            VALUES (?, ?, ?, ?, ?)
            """,
            arguments: [
                UUID(uuidString: "00000000-0000-0000-0000-000000009021")!.uuidString,
                DefaultBudgetTaxonomy.CategoryID.groceries.uuidString,
                DefaultBudgetTaxonomy.CategoryGroupID.foodAndDrink.uuidString,
                125.0,
                Date(timeIntervalSince1970: 1_775_171_200),
            ]
        )
    }
}

func createLegacyWorkspaceWithFilenameSourceFiles(at databaseURL: URL) throws {
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

private func createWorkspaceWithLegacyStagedImportMissingDecisionColumns(
    at databaseURL: URL,
    accountID: UUID
) throws {
    let queue = try DatabaseQueue(path: databaseURL.path)
    try queue.write { db in
        try db.execute(sql: "PRAGMA foreign_keys = ON")
        try db.execute(sql: "CREATE TABLE grdb_migrations (identifier TEXT NOT NULL PRIMARY KEY)")
        for identifier in [
            "create-v1-schema",
            "expand-staged-import-schema",
            "add-review-decision-events",
            "add-classification-review-context",
            "add-category-group-membership",
        ] {
            try db.execute(sql: "INSERT INTO grdb_migrations (identifier) VALUES (?)", arguments: [identifier])
        }

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
                original_filename TEXT NOT NULL,
                content_hash TEXT NOT NULL,
                imported_at DATETIME NOT NULL,
                row_count INTEGER NOT NULL
            )
            """
        )
        try db.execute(
            sql: """
            CREATE TABLE source_rows (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                source_file_id INTEGER NOT NULL REFERENCES source_files(id) ON DELETE CASCADE,
                row_hash TEXT NOT NULL,
                raw_payload TEXT NOT NULL,
                source_line_number INTEGER NOT NULL DEFAULT 0,
                validation_status TEXT NOT NULL DEFAULT 'valid'
            )
            """
        )
        try db.execute(
            sql: """
            CREATE TABLE import_sessions (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                account_id TEXT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
                source_file_id INTEGER NOT NULL REFERENCES source_files(id) ON DELETE CASCADE,
                mapping_json TEXT NOT NULL,
                valid_row_count INTEGER NOT NULL,
                invalid_row_count INTEGER NOT NULL,
                status TEXT NOT NULL,
                created_at DATETIME NOT NULL
            )
            """
        )
        try db.execute(
            sql: """
            CREATE TABLE transactions (
                id TEXT PRIMARY KEY,
                account_id TEXT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
                import_session_id INTEGER REFERENCES import_sessions(id) ON DELETE SET NULL,
                merchant_id TEXT,
                category_id TEXT,
                raw_description TEXT NOT NULL,
                normalized_merchant_name TEXT,
                amount DOUBLE NOT NULL,
                transaction_date DATE NOT NULL,
                posted_date DATE,
                direction TEXT NOT NULL,
                decision_source TEXT NOT NULL,
                decision_source_reference TEXT,
                confidence DOUBLE,
                review_status TEXT NOT NULL,
                duplicate_status TEXT NOT NULL,
                notes TEXT
            )
            """
        )
        try db.execute(
            sql: """
            CREATE TABLE review_items (
                id TEXT PRIMARY KEY,
                transaction_id TEXT REFERENCES transactions(id) ON DELETE CASCADE,
                type TEXT NOT NULL,
                status TEXT NOT NULL,
                created_at DATETIME NOT NULL,
                normalized_merchant_name TEXT,
                suggested_category_id TEXT,
                suggested_merchant_name TEXT,
                classification_source TEXT,
                classification_source_reference TEXT,
                classification_confidence DOUBLE
            )
            """
        )
        try db.execute(sql: "CREATE TABLE categories (id TEXT PRIMARY KEY, name TEXT NOT NULL, kind TEXT NOT NULL, category_group_id TEXT)")
        try db.execute(sql: "CREATE TABLE category_groups (id TEXT PRIMARY KEY, name TEXT NOT NULL)")
        try db.execute(sql: "CREATE TABLE targets (id TEXT PRIMARY KEY, category_id TEXT, category_group_id TEXT, monthly_limit DOUBLE NOT NULL, created_at DATETIME NOT NULL)")
        try db.execute(sql: "CREATE TABLE rules (id TEXT PRIMARY KEY, pattern TEXT NOT NULL, category_id TEXT, merchant_name TEXT, created_at DATETIME NOT NULL)")
        try db.execute(sql: "CREATE TABLE review_decision_events (id TEXT PRIMARY KEY, review_item_id TEXT NOT NULL, source_row_id INTEGER NOT NULL, action TEXT NOT NULL, details TEXT NOT NULL, created_at DATETIME NOT NULL)")
        try db.execute(sql: "CREATE TABLE decision_events (id TEXT PRIMARY KEY, transaction_id TEXT NOT NULL, source TEXT NOT NULL, details TEXT NOT NULL, created_at DATETIME NOT NULL)")

        try db.execute(
            sql: "INSERT INTO accounts (id, name, kind, institution_name, created_at) VALUES (?, ?, ?, ?, ?)",
            arguments: [accountID.uuidString, "Checking", "checking", "Local Bank", Date(timeIntervalSince1970: 1_775_171_200)]
        )
        try db.execute(
            sql: "INSERT INTO source_files (id, account_id, original_filename, content_hash, imported_at, row_count) VALUES (?, ?, ?, ?, ?, ?)",
            arguments: [1, accountID.uuidString, "checking-april.csv", "file-sha256", Date(timeIntervalSince1970: 1_775_171_200), 2]
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
                #"{"amount":{"debitCredit":{"creditColumnIndex":4,"debitColumnIndex":3}},"dateColumnIndex":1,"descriptionColumnIndex":2}"#,
                2,
                0,
                "staged",
                Date(timeIntervalSince1970: 1_775_171_200),
            ]
        )
        try db.execute(
            sql: "INSERT INTO source_rows (source_file_id, row_hash, raw_payload, source_line_number, validation_status) VALUES (?, ?, ?, ?, ?)",
            arguments: [
                1,
                "row-1-sha256",
                #"["Cleared","04\/15\/2026","SRI ANANDABHAVAN SUNNYVALE CA null XXXXXXXXXXXX3969","34.48",""]"#,
                2,
                "valid",
            ]
        )
        try db.execute(
            sql: "INSERT INTO source_rows (source_file_id, row_hash, raw_payload, source_line_number, validation_status) VALUES (?, ?, ?, ?, ?)",
            arguments: [
                1,
                "row-2-sha256",
                #"["Cleared","04\/14\/2026","WALMART.COM WALMART.COM AR","2.53",""]"#,
                3,
                "valid",
            ]
        )
    }
}

private func createWorkspaceWithLegacyVenmoStagedImportMissingDecisionColumns(
    at databaseURL: URL,
    accountID: UUID
) throws {
    let queue = try DatabaseQueue(path: databaseURL.path)
    try queue.write { db in
        try db.execute(sql: "PRAGMA foreign_keys = ON")
        try db.execute(sql: "CREATE TABLE grdb_migrations (identifier TEXT NOT NULL PRIMARY KEY)")
        for identifier in [
            "create-v1-schema",
            "expand-staged-import-schema",
            "add-review-decision-events",
            "add-classification-review-context",
            "add-category-group-membership",
        ] {
            try db.execute(sql: "INSERT INTO grdb_migrations (identifier) VALUES (?)", arguments: [identifier])
        }

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
                original_filename TEXT NOT NULL,
                content_hash TEXT NOT NULL,
                imported_at DATETIME NOT NULL,
                row_count INTEGER NOT NULL
            )
            """
        )
        try db.execute(
            sql: """
            CREATE TABLE source_rows (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                source_file_id INTEGER NOT NULL REFERENCES source_files(id) ON DELETE CASCADE,
                row_hash TEXT NOT NULL,
                raw_payload TEXT NOT NULL,
                source_line_number INTEGER NOT NULL DEFAULT 0,
                validation_status TEXT NOT NULL DEFAULT 'valid'
            )
            """
        )
        try db.execute(
            sql: """
            CREATE TABLE import_sessions (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                account_id TEXT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
                source_file_id INTEGER NOT NULL REFERENCES source_files(id) ON DELETE CASCADE,
                mapping_json TEXT NOT NULL,
                valid_row_count INTEGER NOT NULL,
                invalid_row_count INTEGER NOT NULL,
                status TEXT NOT NULL,
                created_at DATETIME NOT NULL
            )
            """
        )
        try db.execute(
            sql: """
            CREATE TABLE transactions (
                id TEXT PRIMARY KEY,
                account_id TEXT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
                import_session_id INTEGER REFERENCES import_sessions(id) ON DELETE SET NULL,
                merchant_id TEXT,
                category_id TEXT,
                raw_description TEXT NOT NULL,
                normalized_merchant_name TEXT,
                amount DOUBLE NOT NULL,
                transaction_date DATE NOT NULL,
                posted_date DATE,
                direction TEXT NOT NULL,
                decision_source TEXT NOT NULL,
                decision_source_reference TEXT,
                confidence DOUBLE,
                review_status TEXT NOT NULL,
                duplicate_status TEXT NOT NULL,
                notes TEXT
            )
            """
        )
        try db.execute(
            sql: """
            CREATE TABLE review_items (
                id TEXT PRIMARY KEY,
                transaction_id TEXT REFERENCES transactions(id) ON DELETE CASCADE,
                type TEXT NOT NULL,
                status TEXT NOT NULL,
                created_at DATETIME NOT NULL,
                normalized_merchant_name TEXT,
                suggested_category_id TEXT,
                suggested_merchant_name TEXT,
                classification_source TEXT,
                classification_source_reference TEXT,
                classification_confidence DOUBLE
            )
            """
        )
        try db.execute(sql: "CREATE TABLE categories (id TEXT PRIMARY KEY, name TEXT NOT NULL, kind TEXT NOT NULL, category_group_id TEXT)")
        try db.execute(sql: "CREATE TABLE category_groups (id TEXT PRIMARY KEY, name TEXT NOT NULL)")
        try db.execute(sql: "CREATE TABLE targets (id TEXT PRIMARY KEY, category_id TEXT, category_group_id TEXT, monthly_limit DOUBLE NOT NULL, created_at DATETIME NOT NULL)")
        try db.execute(sql: "CREATE TABLE rules (id TEXT PRIMARY KEY, pattern TEXT NOT NULL, category_id TEXT, merchant_name TEXT, created_at DATETIME NOT NULL)")
        try db.execute(sql: "CREATE TABLE review_decision_events (id TEXT PRIMARY KEY, review_item_id TEXT NOT NULL, source_row_id INTEGER NOT NULL, action TEXT NOT NULL, details TEXT NOT NULL, created_at DATETIME NOT NULL)")
        try db.execute(sql: "CREATE TABLE decision_events (id TEXT PRIMARY KEY, transaction_id TEXT NOT NULL, source TEXT NOT NULL, details TEXT NOT NULL, created_at DATETIME NOT NULL)")

        try db.execute(
            sql: "INSERT INTO accounts (id, name, kind, institution_name, created_at) VALUES (?, ?, ?, ?, ?)",
            arguments: [accountID.uuidString, "Checking", "checking", "Venmo", Date(timeIntervalSince1970: 1_775_171_200)]
        )
        try db.execute(
            sql: "INSERT INTO source_files (id, account_id, original_filename, content_hash, imported_at, row_count) VALUES (?, ?, ?, ?, ?, ?)",
            arguments: [1, accountID.uuidString, "venmo-april.csv", "file-sha256", Date(timeIntervalSince1970: 1_775_171_200), 1]
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
                #"{"amount":{"singleSignedAmount":{"columnIndex":8}},"dateColumnIndex":2,"descriptionColumnIndex":6,"profile":"venmoStatement"}"#,
                1,
                0,
                "staged",
                Date(timeIntervalSince1970: 1_775_171_200),
            ]
        )
        try db.execute(
            sql: "INSERT INTO source_rows (source_file_id, row_hash, raw_payload, source_line_number, validation_status) VALUES (?, ?, ?, ?, ?)",
            arguments: [
                1,
                "venmo-row-1-sha256",
                venmoOutgoingRawPayload(),
                5,
                "valid",
            ]
        )
    }
}

private func dropRestoreCandidateTables(at databaseURL: URL, tables: [String]) throws {
    let queue = try DatabaseQueue(path: databaseURL.path)
    try queue.write { db in
        for table in tables {
            try db.execute(sql: "DROP TABLE \(table)")
        }
    }
}

private func createRestoreCandidateBackup(from store: WorkspaceStore, at databaseURL: URL) throws -> WorkspaceBackup {
    let backupDirectory = databaseURL.deletingLastPathComponent().appending(path: "Backups", directoryHint: .isDirectory)
    return try store.createWorkspaceBackup(
        in: backupDirectory,
        now: Date(timeIntervalSince1970: 1_775_171_200)
    )
}

private func replaceWorkspacePreferencesTableWithIncompatibleShape(at databaseURL: URL) throws {
    let queue = try DatabaseQueue(path: databaseURL.path)
    try queue.write { db in
        try db.execute(sql: "ALTER TABLE workspace_preferences RENAME TO workspace_preferences_old")
        try db.execute(sql: "CREATE TABLE workspace_preferences (key TEXT PRIMARY KEY, stored_value TEXT NOT NULL)")
        try db.execute(
            sql: "INSERT INTO workspace_preferences (key, stored_value) SELECT key, value FROM workspace_preferences_old"
        )
        try db.execute(sql: "DROP TABLE workspace_preferences_old")
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

private func insertSourceFileAndImportSession(databaseURL: URL, accountID: UUID) throws {
    let queue = try DatabaseQueue(path: databaseURL.path)
    try queue.write { db in
        try db.execute(
            sql: """
            INSERT INTO source_files (id, account_id, original_filename, content_hash, imported_at, row_count)
            VALUES (?, ?, ?, ?, ?, ?)
            """,
            arguments: [
                1,
                accountID.uuidString,
                "checking-april.csv",
                "source-file-hash",
                Date(timeIntervalSince1970: 1_775_171_200),
                2,
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
                #"{"dateColumnIndex":0,"descriptionColumnIndex":1}"#,
                2,
                0,
                "staged",
                Date(timeIntervalSince1970: 1_775_171_200),
            ]
        )
    }
}

private func insertLedgerTransaction(
    databaseURL: URL,
    id: UUID,
    accountID: UUID,
    categoryID: UUID?,
    importSessionID: Int64?,
    rawDescription: String,
    normalizedMerchantName: String,
    amount: Decimal,
    transactionDate: Date,
    reviewStatus: String,
    direction: String = "expense",
    decisionSource: String = "heuristic",
    decisionSourceReference: String? = nil,
    confidence: Double? = nil,
    notes: String? = nil
) throws {
    let queue = try DatabaseQueue(path: databaseURL.path)
    try queue.write { db in
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
                duplicate_status,
                notes
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            arguments: [
                id.uuidString,
                accountID.uuidString,
                importSessionID,
                categoryID?.uuidString,
                rawDescription,
                normalizedMerchantName,
                NSDecimalNumber(decimal: amount).doubleValue,
                transactionDate,
                direction,
                decisionSource,
                decisionSourceReference,
                confidence,
                reviewStatus,
                "none",
                notes,
            ]
        )
    }
}

private func venmoOutgoingRawPayload() -> String {
    #"["","4303787187085607348","2025-04-05T02:16:52","Payment","Complete","Groceries","Alex Example","Jordan Example","- $135.00","","0","","0","","Bank Checking *1234","","","","","Venmo","",""]"#
}

private func insertCategory(
    databaseURL: URL,
    id: UUID,
    name: String,
    kind: String,
    categoryGroupID: UUID? = nil
) throws {
    let queue = try DatabaseQueue(path: databaseURL.path)
    try queue.write { db in
        try db.execute(
            sql: """
            INSERT INTO categories (id, name, kind, category_group_id)
            VALUES (?, ?, ?, ?)
            """,
            arguments: [
                id.uuidString,
                name,
                kind,
                categoryGroupID?.uuidString,
            ]
        )
    }
}

private func insertRecurringTransactions(
    databaseURL: URL,
    accountID: UUID,
    normalizedMerchantName: String,
    observations: [(id: UUID, amount: Decimal, transactionDate: Date, reviewStatus: String, isHidden: Bool)]
) throws -> [UUID] {
    let queue = try DatabaseQueue(path: databaseURL.path)
    try queue.write { db in
        for observation in observations {
            try db.execute(
                sql: """
                INSERT INTO transactions (
                    id,
                    account_id,
                    is_hidden,
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
                    observation.id.uuidString,
                    accountID.uuidString,
                    observation.isHidden,
                    normalizedMerchantName,
                    normalizedMerchantName,
                    NSDecimalNumber(decimal: observation.amount).doubleValue,
                    observation.transactionDate,
                    TransactionDirection.expense.rawValue,
                    "heuristic",
                    observation.reviewStatus,
                    "none",
                ]
            )
        }
    }
    return observations.map(\.id)
}

private func recurringDetail(from insight: WorkspaceInsight) -> RecurringChargeInsightDetail? {
    switch insight.kind {
    case let .recurringCharge(detail):
        detail
    case .spendDriverChange:
        nil
    }
}

private func spendDriverChangeDetail(from insight: WorkspaceInsight) -> SpendDriverChangeInsightDetail? {
    switch insight.kind {
    case .recurringCharge:
        nil
    case let .spendDriverChange(detail):
        detail
    }
}

private func recurringUTCDate(year: Int, month: Int, day: Int) -> Date {
    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = day
    components.calendar = recurringUTCCalendar
    return components.date!
}

private let recurringUTCCalendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
    return calendar
}()

private func insertCategoryGroup(
    databaseURL: URL,
    id: UUID,
    name: String
) throws {
    let queue = try DatabaseQueue(path: databaseURL.path)
    try queue.write { db in
        try db.execute(
            sql: """
            INSERT INTO category_groups (id, name)
            VALUES (?, ?)
            """,
            arguments: [
                id.uuidString,
                name,
            ]
        )
    }
}

private func insertTarget(
    databaseURL: URL,
    id: UUID,
    categoryID: UUID?,
    categoryGroupID: UUID?,
    monthlyLimit: Decimal
) throws {
    let queue = try DatabaseQueue(path: databaseURL.path)
    try queue.write { db in
        try db.execute(
            sql: """
            INSERT INTO targets (id, category_id, category_group_id, monthly_limit, created_at)
            VALUES (?, ?, ?, ?, ?)
            """,
            arguments: [
                id.uuidString,
                categoryID?.uuidString,
                categoryGroupID?.uuidString,
                NSDecimalNumber(decimal: monthlyLimit).doubleValue,
                Date(timeIntervalSince1970: 1_775_171_200),
            ]
        )
    }
}

private func insertRule(
    databaseURL: URL,
    id: UUID,
    pattern: String,
    categoryID: UUID?,
    merchantName: String?,
    matchKind: ClassificationRuleMatchKind = .contains,
    createdAt: Date,
    disabledAt: Date? = nil
) throws {
    let queue = try DatabaseQueue(path: databaseURL.path)
    try queue.write { db in
        try db.execute(
            sql: """
            INSERT INTO rules (id, pattern, category_id, merchant_name, match_kind, created_at, disabled_at)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            arguments: [
                id.uuidString,
                pattern,
                categoryID?.uuidString,
                merchantName,
                matchKind.rawValue,
                createdAt,
                disabledAt,
            ]
        )
    }
}

private func insertLegacyRuleWithoutDisabledAt(
    databaseURL: URL,
    id: UUID,
    pattern: String,
    categoryID: UUID?,
    merchantName: String?,
    createdAt: Date
) throws {
    let queue = try DatabaseQueue(path: databaseURL.path)
    try queue.write { db in
        try db.execute(
            sql: """
            INSERT INTO rules (id, pattern, category_id, merchant_name, created_at)
            VALUES (?, ?, ?, ?, ?)
            """,
            arguments: [
                id.uuidString,
                pattern,
                categoryID?.uuidString,
                merchantName,
                createdAt,
            ]
        )
    }
}

private func insertOrphanedRule(
    databaseURL: URL,
    id: UUID,
    pattern: String,
    missingCategoryID: UUID,
    merchantName: String?,
    matchKind: ClassificationRuleMatchKind = .contains,
    createdAt: Date
) throws {
    var configuration = Configuration()
    configuration.foreignKeysEnabled = false
    let queue = try DatabaseQueue(path: databaseURL.path, configuration: configuration)
    try queue.write { db in
        try db.execute(
            sql: """
            INSERT INTO rules (id, pattern, category_id, merchant_name, match_kind, created_at, disabled_at)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            arguments: [
                id.uuidString,
                pattern,
                missingCategoryID.uuidString,
                merchantName,
                matchKind.rawValue,
                createdAt,
                nil,
            ]
        )
    }
}

private func approveMerchantRecommendationHistory(
    store: WorkspaceStore,
    accountID: UUID,
    categoryID: UUID,
    normalizedMerchantName: String,
    rawDescriptions: [String],
    rowHashes: [String]? = nil,
    originalFilename: String = "checking-history.csv",
    startingSequence: Int = 0
) throws -> [UUID] {
    let hashes = rowHashes ?? rawDescriptions.enumerated().map { index, _ in
        "history-row-\(startingSequence + index)"
    }
    #expect(hashes.count == rawDescriptions.count)

    let rows = rawDescriptions.enumerated().map { index, rawDescription in
        StagedSourceRowDraft(
            sourceLineNumber: index + 2,
            rawPayload: #"["2026-04-03","\#(rawDescription)","-4.75"]"#,
            rowHash: hashes[index],
            validationStatus: .valid,
            importDecision: .imported(reason: "New source row."),
            classification: .reviewRequired(
                prefill: nil,
                source: nil,
                sourceReference: nil,
                confidence: nil,
                reason: "No classification matched."
            ),
            normalizedMerchantName: normalizedMerchantName,
            transaction: StagedTransactionDraft(
                transactionDate: Date(timeIntervalSince1970: TimeInterval(1_776_355_360 + startingSequence + index)),
                rawDescription: rawDescription,
                normalizedMerchantName: normalizedMerchantName,
                amount: Decimal(-4.75)
            )
        )
    }

    _ = try store.createStagedImportSession(
        StagedImportSessionDraft(
            accountID: accountID,
            originalFilename: originalFilename,
            contentHash: "history-file-\(startingSequence)",
            importedAt: Date(timeIntervalSince1970: TimeInterval(1_776_355_360 + startingSequence)),
            rows: rows,
            mapping: CSVColumnMapping(
                dateColumnIndex: 0,
                descriptionColumnIndex: 1,
                amount: .singleSignedAmount(columnIndex: 2)
            ),
            validRowCount: rows.count,
            invalidRowCount: 0,
            status: .staged
        )
    )

    let reviewItems = try store.fetchPendingReviewItems()
        .filter { $0.classification?.normalizedMerchantName == normalizedMerchantName }
        .sorted { lhs, rhs in
            lhs.sourceRow.sourceLineNumber < rhs.sourceRow.sourceLineNumber
        }

    #expect(reviewItems.count == rawDescriptions.count)

    for reviewItem in reviewItems {
        _ = try store.approveClassificationReviewItem(
            id: reviewItem.id,
            assignment: ClassificationAssignment(categoryID: categoryID, merchantName: nil),
            ruleLearning: nil,
            resolvedAt: Date(timeIntervalSince1970: 1_776_355_860)
        )
    }

    return try fetchTransactionIDs(
        store: store,
        normalizedMerchantName: normalizedMerchantName,
        rawDescriptions: rawDescriptions
    )
}

private func fetchTransactionIDs(
    store: WorkspaceStore,
    normalizedMerchantName: String,
    rawDescriptions: [String]
) throws -> [UUID] {
    try store.fetchTransactionLedger(filter: .empty)
        .filter {
            $0.merchantName == normalizedMerchantName
            && rawDescriptions.contains($0.rawDescription)
        }
        .map(\.id)
}

private func categoryNamesByGroup(
    categories: [BudgetCategory],
    groups: [BudgetCategoryGroup]
) -> [String: [String]] {
    let groupNameByID = Dictionary(uniqueKeysWithValues: groups.map { ($0.id, $0.name) })
    let pairs = categories.compactMap { category -> (String, String)? in
        guard let groupID = category.groupID,
              let groupName = groupNameByID[groupID]
        else {
            return nil
        }
        return (groupName, category.name)
    }
    return Dictionary(grouping: pairs, by: \.0).mapValues { pairs in
        pairs.map(\.1)
    }
}

private func insertLegacyDefaultTaxonomyWithoutTravel(databaseURL: URL) throws {
    let queue = try DatabaseQueue(path: databaseURL.path)
    try queue.write { db in
        for group in DefaultBudgetTaxonomy.legacyCategoryGroups where group.name != "Travel" {
            try db.execute(
                sql: "INSERT INTO category_groups (id, name) VALUES (?, ?)",
                arguments: [group.id.uuidString, group.name]
            )
        }

        for category in DefaultBudgetTaxonomy.legacyCategories where category.name != "Flights" && category.name != "Hotels" {
            try db.execute(
                sql: """
                INSERT INTO categories (id, name, kind, category_group_id)
                VALUES (?, ?, ?, ?)
                """,
                arguments: [
                    category.id.uuidString,
                    category.name,
                    category.kind.rawValue,
                    category.groupID?.uuidString,
                ]
            )
        }
    }
}

private let travelCategoryGroupID = UUID(uuidString: "10000000-0000-0000-0000-000000000005")!
private let flightsCategoryID = UUID(uuidString: "20000000-0000-0000-0000-000000000014")!

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
