import Application
import Domain
import Foundation
import Testing

private struct StubWorkspaceStore: WorkspaceStoring, StagedImportWriting, ImportDecisionReading, ReviewQueueReading {
    var summary: WorkspaceSummary
    var accounts: [Account]
    var pendingReviewItems: [PendingReviewItem] = []

    func fetchSummary() throws -> WorkspaceSummary {
        summary
    }

    func fetchAccounts() throws -> [Account] {
        accounts
    }

    func fetchCategories() throws -> [BudgetCategory] {
        []
    }

    func fetchCategoryGroups() throws -> [BudgetCategoryGroup] {
        []
    }

    func fetchPendingReviewItems() throws -> [PendingReviewItem] {
        pendingReviewItems
    }

    func createAccount(named: String, kind: AccountKind, institutionName: String?) throws -> Account {
        Account(
            name: named,
            kind: kind,
            institutionName: institutionName
        )
    }

    func createStagedImportSession(_ draft: StagedImportSessionDraft) throws -> StagedImportSession {
        StagedImportSession(
            id: 1,
            sourceFile: StagedSourceFile(
                id: 1,
                accountID: draft.accountID,
                originalFilename: draft.originalFilename,
                contentHash: draft.contentHash,
                importedAt: draft.importedAt,
                rowCount: draft.rows.count
            ),
            mapping: draft.mapping,
            validRowCount: draft.validRowCount,
            invalidRowCount: draft.invalidRowCount,
            status: draft.status,
            rows: draft.rows.enumerated().map { index, row in
                StagedSourceRow(
                    id: Int64(index + 1),
                    sourceFileID: 1,
                    sourceLineNumber: row.sourceLineNumber,
                    rawPayload: row.rawPayload,
                    rowHash: row.rowHash,
                    validationStatus: row.validationStatus
                )
            }
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
}

private final class MutableWorkspaceStore: WorkspaceStoring, StagedImportWriting, ImportDecisionReading, ReviewQueueReading, ClassificationRuleReading, TargetManaging, ReportingReading, WorkspacePreferencesManaging, @unchecked Sendable {
    var summary: WorkspaceSummary
    var accounts: [Account]
    var categories: [BudgetCategory] = []
    var categoryGroups: [BudgetCategoryGroup] = []
    var pendingReviewItems: [PendingReviewItem] = []
    var stagedImportDrafts: [StagedImportSessionDraft] = []
    var likelyDuplicateCandidates: [LikelyDuplicateCandidate] = []
    var existingSourceRowHashes: Set<String> = []
    var classificationRules: [ClassificationRule] = []
    var createdTargets: [MonthlyTarget] = []
    var monthlyReport = MonthlyReport.empty
    var managedTargets: [ManagedMonthlyTarget] = []
    var preferences = WorkspacePreferences()
    var createMonthlyTargetError: (any Error)?
    var updateMonthlyTargetError: (any Error)?
    var deleteMonthlyTargetError: (any Error)?

    init(summary: WorkspaceSummary = .empty, accounts: [Account] = []) {
        self.summary = summary
        self.accounts = accounts
    }

    func fetchSummary() throws -> WorkspaceSummary {
        summary
    }

    func fetchAccounts() throws -> [Account] {
        accounts.sorted { $0.name < $1.name }
    }

    func fetchCategories() throws -> [BudgetCategory] {
        categories.sorted { $0.name < $1.name }
    }

    func fetchCategoryGroups() throws -> [BudgetCategoryGroup] {
        categoryGroups.sorted { $0.name < $1.name }
    }

    func fetchPendingReviewItems() throws -> [PendingReviewItem] {
        pendingReviewItems
    }

    func createAccount(named: String, kind: AccountKind, institutionName: String?) throws -> Account {
        let account = Account(
            name: named,
            kind: kind,
            institutionName: institutionName
        )
        accounts.append(account)
        summary.accountCount = accounts.count
        return account
    }

    func createStagedImportSession(_ draft: StagedImportSessionDraft) throws -> StagedImportSession {
        stagedImportDrafts.append(draft)
        return StagedImportSession(
            id: Int64(stagedImportDrafts.count),
            sourceFile: StagedSourceFile(
                id: Int64(stagedImportDrafts.count),
                accountID: draft.accountID,
                originalFilename: draft.originalFilename,
                contentHash: draft.contentHash,
                importedAt: draft.importedAt,
                rowCount: draft.rows.count
            ),
            mapping: draft.mapping,
            validRowCount: draft.validRowCount,
            invalidRowCount: draft.invalidRowCount,
            status: draft.status,
            rows: draft.rows.enumerated().map { index, row in
                StagedSourceRow(
                    id: Int64(index + 1),
                    sourceFileID: Int64(stagedImportDrafts.count),
                    sourceLineNumber: row.sourceLineNumber,
                    rawPayload: row.rawPayload,
                    rowHash: row.rowHash,
                    validationStatus: row.validationStatus,
                    importDecision: row.importDecision
                )
            }
        )
    }

    func fetchExistingSourceRowHashes(accountID: UUID, rowHashes: Set<String>) throws -> Set<String> {
        existingSourceRowHashes.union(
            stagedImportDrafts
                .filter { $0.accountID == accountID }
                .flatMap(\.rows)
                .map(\.rowHash)
                .filter { rowHashes.contains($0) }
        )
    }

    func fetchExistingSourceRowHashCounts(accountID: UUID, rowHashes: Set<String>) throws -> [String: Int] {
        let storedHashes = stagedImportDrafts
            .filter { $0.accountID == accountID }
            .flatMap(\.rows)
            .map(\.rowHash)
            .filter { rowHashes.contains($0) }
        let explicitHashes = existingSourceRowHashes.filter { rowHashes.contains($0) }
        return Dictionary((storedHashes + explicitHashes).map { ($0, 1) }, uniquingKeysWith: +)
    }

    func fetchLikelyDuplicateTransactions(
        accountID: UUID,
        candidates: [NormalizedImportCandidate]
    ) throws -> [LikelyDuplicateCandidate] {
        let candidateHashes = Set(candidates.map(\.rowHash))
        return likelyDuplicateCandidates.filter { candidateHashes.contains($0.rowHash) }
    }

    func fetchClassificationRules() throws -> [ClassificationRule] {
        classificationRules
    }

    func fetchWorkspacePreferences() throws -> WorkspacePreferences {
        preferences
    }

    func updateWorkspacePreferences(_ preferences: WorkspacePreferences) throws {
        self.preferences = preferences
    }

    func fetchManagedTargets(referenceDate: Date) throws -> [ManagedMonthlyTarget] {
        managedTargets
    }

    func createMonthlyTarget(_ draft: MonthlyTargetDraft, createdAt: Date) throws -> MonthlyTarget {
        if let createMonthlyTargetError {
            throw createMonthlyTargetError
        }
        let target = MonthlyTarget(id: UUID(), scope: draft.scope, monthlyLimit: draft.monthlyLimit, createdAt: createdAt)
        createdTargets.append(target)
        summary.targetCount = createdTargets.count
        managedTargets.append(
            ManagedMonthlyTarget(
                id: target.id,
                name: "Groceries",
                scope: target.scope,
                monthlyLimit: target.monthlyLimit,
                spent: Decimal(40),
                remaining: target.monthlyLimit - Decimal(40),
                paceDelta: Decimal(0),
                createdAt: createdAt
            )
        )
        monthlyReport.targets.append(
            TargetProgress(
                id: target.id,
                name: "Groceries",
                scope: target.scope,
                monthlyLimit: target.monthlyLimit,
                spent: Decimal(40),
                remaining: target.monthlyLimit - Decimal(40),
                paceDelta: Decimal(0)
            )
        )
        return target
    }

    func updateMonthlyTarget(id: UUID, _ draft: MonthlyTargetDraft) throws -> MonthlyTarget {
        if let updateMonthlyTargetError {
            throw updateMonthlyTargetError
        }

        let existingIndex = try #require(createdTargets.firstIndex { $0.id == id })
        let existingTarget = createdTargets[existingIndex]
        let updatedTarget = MonthlyTarget(
            id: id,
            scope: draft.scope,
            monthlyLimit: draft.monthlyLimit,
            createdAt: existingTarget.createdAt
        )
        createdTargets[existingIndex] = updatedTarget

        if let managedIndex = managedTargets.firstIndex(where: { $0.id == id }) {
            managedTargets[managedIndex] = ManagedMonthlyTarget(
                id: id,
                name: "Groceries",
                scope: draft.scope,
                monthlyLimit: draft.monthlyLimit,
                spent: Decimal(40),
                remaining: draft.monthlyLimit - Decimal(40),
                paceDelta: Decimal(0),
                createdAt: existingTarget.createdAt
            )
        }
        if let reportIndex = monthlyReport.targets.firstIndex(where: { $0.id == id }) {
            monthlyReport.targets[reportIndex] = TargetProgress(
                id: id,
                name: "Groceries",
                scope: draft.scope,
                monthlyLimit: draft.monthlyLimit,
                spent: Decimal(40),
                remaining: draft.monthlyLimit - Decimal(40),
                paceDelta: Decimal(0)
            )
        }

        return updatedTarget
    }

    func deleteMonthlyTarget(id: UUID) throws {
        if let deleteMonthlyTargetError {
            throw deleteMonthlyTargetError
        }
        guard createdTargets.contains(where: { $0.id == id }) else {
            throw MonthlyTargetManagementError.targetNotFound(id)
        }
        createdTargets.removeAll { $0.id == id }
        managedTargets.removeAll { $0.id == id }
        monthlyReport.targets.removeAll { $0.id == id }
        summary.targetCount = createdTargets.count
    }

    func fetchMonthlyReport(referenceDate: Date) throws -> MonthlyReport {
        monthlyReport
    }
}

@Test
func loadSnapshotReturnsSummaryAndAccountsFromStore() throws {
    let reviewItem = PendingReviewItem(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000222")!,
        type: .lowConfidenceCategory,
        status: .pending,
        reason: "Needs a category.",
        createdAt: Date(timeIntervalSince1970: 1_775_000_000),
        sourceFile: PendingReviewSourceFile(
            accountID: UUID(uuidString: "00000000-0000-0000-0000-000000000123")!,
            originalFilename: "checking.csv"
        ),
        sourceRow: PendingReviewSourceRow(
            id: 1,
            sourceLineNumber: 2,
            rowHash: "row-hash",
            rawPayload: "[\"2026-04-01\",\"Coffee Shop\",\"-4.75\"]"
        ),
        duplicateTransactionID: nil
    )
    let store = StubWorkspaceStore(
        summary: WorkspaceSummary(
            accountCount: 1,
            transactionCount: 24,
            reviewCount: 3,
            targetCount: 2
        ),
        accounts: [
            Account(name: "Checking", kind: .checking, institutionName: "Local Bank"),
        ],
        pendingReviewItems: [reviewItem]
    )

    let service = WorkspaceService(store: store)
    let snapshot = try service.loadSnapshot()

    #expect(snapshot.summary.accountCount == 1)
    #expect(snapshot.summary.reviewCount == 3)
    #expect(snapshot.accounts.map(\.name) == ["Checking"])
    #expect(snapshot.pendingReviewItems == [reviewItem])
}

@Test
func createAccountReturnsCreatedAccountAndUpdatedSnapshot() throws {
    let store = MutableWorkspaceStore()
    let service = WorkspaceService(store: store)

    let created = try service.createAccount(
        named: "Travel Card",
        kind: .creditCard,
        institutionName: "Visa"
    )
    let snapshot = try service.loadSnapshot()

    #expect(created.name == "Travel Card")
    #expect(snapshot.summary.accountCount == 1)
    #expect(snapshot.accounts.map(\.name) == ["Travel Card"])
}

@Test
func seedSampleDataCreatesStarterAccountsOnlyOnce() throws {
    let store = MutableWorkspaceStore()
    let service = WorkspaceService(store: store)

    try service.seedSampleDataIfNeeded()
    try service.seedSampleDataIfNeeded()

    let snapshot = try service.loadSnapshot()

    #expect(snapshot.summary.accountCount == 2)
    #expect(snapshot.accounts.map(\.name) == ["Checking", "Daily Card"])
}

@Test
func createMonthlyTargetReturnsTargetAndReloadsSnapshot() throws {
    let store = MutableWorkspaceStore()
    let categoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000111")!
    store.categories = [BudgetCategory(id: categoryID, name: "Groceries", kind: .expense)]
    let service = WorkspaceService(store: store)

    let target = try service.createMonthlyTarget(
        MonthlyTargetDraft(scope: .category(categoryID), monthlyLimit: Decimal(125)),
        createdAt: Date(timeIntervalSince1970: 1_775_171_260)
    )
    let snapshot = try service.loadSnapshot()

    #expect(target.scope == .category(categoryID))
    #expect(snapshot.summary.targetCount == 1)
    #expect(snapshot.monthlyReport.targets.map(\.id) == [target.id])
    #expect(snapshot.monthlyReport.targets.map(\.remaining) == [Decimal(85)])
}

@Test
func createMonthlyTargetSurfacesTypedConflictErrors() throws {
    let store = MutableWorkspaceStore()
    let categoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000911")!
    store.createMonthlyTargetError = MonthlyTargetManagementError.conflict(.duplicateScope(.category(categoryID)))
    let service = WorkspaceService(store: store)

    #expect(throws: WorkspaceServiceError.monthlyTargetConflict(.duplicateScope(.category(categoryID)))) {
        try service.createMonthlyTarget(
            MonthlyTargetDraft(scope: .category(categoryID), monthlyLimit: Decimal(125)),
            createdAt: Date(timeIntervalSince1970: 1_775_171_260)
        )
    }
}

@Test
func updateMonthlyTargetSurfacesTypedConflictErrors() throws {
    let store = MutableWorkspaceStore()
    let categoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000912")!
    let groupID = UUID(uuidString: "00000000-0000-0000-0000-000000000913")!
    store.updateMonthlyTargetError = MonthlyTargetManagementError.conflict(
        .categoryGroupOverlap(categoryID: categoryID, categoryGroupID: groupID)
    )
    let service = WorkspaceService(store: store)

    #expect(
        throws: WorkspaceServiceError.monthlyTargetConflict(
            .categoryGroupOverlap(categoryID: categoryID, categoryGroupID: groupID)
        )
    ) {
        try service.updateMonthlyTarget(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000914")!,
            MonthlyTargetDraft(scope: .categoryGroup(groupID), monthlyLimit: Decimal(250))
        )
    }
}

@Test
func fetchManagedTargetsReturnsManagedTargets() throws {
    let store = MutableWorkspaceStore()
    let categoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000915")!
    store.managedTargets = [
        ManagedMonthlyTarget(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000916")!,
            name: "Groceries",
            scope: .category(categoryID),
            monthlyLimit: Decimal(125),
            spent: Decimal(40),
            remaining: Decimal(85),
            paceDelta: Decimal(5),
            createdAt: Date(timeIntervalSince1970: 1_775_171_260)
        ),
    ]
    let service = WorkspaceService(store: store)

    let managedTargets = try service.fetchManagedTargets(referenceDate: Date(timeIntervalSince1970: 1_775_171_200))

    #expect(managedTargets == store.managedTargets)
}

@Test
func deleteMonthlyTargetRemovesTargetAndReloadsSnapshot() throws {
    let store = MutableWorkspaceStore()
    let categoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000917")!
    store.categories = [BudgetCategory(id: categoryID, name: "Groceries", kind: .expense)]
    let service = WorkspaceService(store: store)
    let target = try service.createMonthlyTarget(
        MonthlyTargetDraft(scope: .category(categoryID), monthlyLimit: Decimal(125)),
        createdAt: Date(timeIntervalSince1970: 1_775_171_260)
    )

    try service.deleteMonthlyTarget(id: target.id)
    let snapshot = try service.loadSnapshot()

    #expect(snapshot.summary.targetCount == 0)
    #expect(snapshot.monthlyReport.targets.isEmpty)
    #expect(try service.fetchManagedTargets(referenceDate: Date(timeIntervalSince1970: 1_775_171_200)).isEmpty)
}

@Test
func deleteMonthlyTargetPropagatesStaleIDError() throws {
    let store = MutableWorkspaceStore()
    let service = WorkspaceService(store: store)
    let missingID = UUID(uuidString: "00000000-0000-0000-0000-000000000918")!

    #expect(throws: MonthlyTargetManagementError.targetNotFound(missingID)) {
        try service.deleteMonthlyTarget(id: missingID)
    }
}

@Test
func stageCSVImportCreatesStagedSessionFromValidPreview() throws {
    let account = Account(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000123")!,
        name: "Checking",
        kind: .checking,
        institutionName: "Local Bank"
    )
    let store = MutableWorkspaceStore(accounts: [account])
    let service = WorkspaceService(store: store)
    let csv = """
    Date,Description,Amount
    2026-04-01,Coffee Shop,-4.75
    2026-04-02,Payroll,1250.00
    """
    let preview = try CSVImportPreviewService().makePreview(from: csv)
    let importedAt = Date(timeIntervalSince1970: 1_777_000_000)

    let result = try service.stageCSVImport(
        preview: preview,
        account: account,
        originalFilename: "checking-april.csv",
        csvText: csv,
        importedAt: importedAt
    )
    let session = try #require(result.session)

    let draft = try #require(store.stagedImportDrafts.first)
    #expect(result.outcome == .staged)
    #expect(result.summary.importedRowCount == 2)
    #expect(result.summary.skippedRowCount == 0)
    #expect(result.summary.flaggedDuplicateRowCount == 0)
    #expect(store.stagedImportDrafts.count == 1)
    #expect(session.status == .staged)
    #expect(draft.accountID == account.id)
    #expect(draft.originalFilename == "checking-april.csv")
    #expect(draft.importedAt == importedAt)
    #expect(draft.mapping == preview.mapping)
    #expect(draft.validRowCount == 2)
    #expect(draft.invalidRowCount == 0)
    #expect(draft.status == .staged)
    #expect(draft.rows.map(\.sourceLineNumber) == [2, 3])
    #expect(draft.rows.map(\.validationStatus) == [.valid, .valid])
    #expect(draft.rows.map(\.importDecision) == [
        .imported(reason: "New source row."),
        .imported(reason: "New source row."),
    ])
    #expect(draft.rows.map(\.rawPayload) == [
        #"["2026-04-01","Coffee Shop","-4.75"]"#,
        #"["2026-04-02","Payroll","1250.00"]"#,
    ])
    #expect(draft.contentHash.isEmpty == false)
    #expect(draft.rows.allSatisfy { !$0.rowHash.isEmpty })
}

@Test
func stageCSVImportReturnsClassificationResultsForImportedRows() throws {
    let account = Account(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000123")!,
        name: "Checking",
        kind: .checking,
        institutionName: "Local Bank"
    )
    let categoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000111")!
    let ruleID = UUID(uuidString: "00000000-0000-0000-0000-000000000222")!
    let store = MutableWorkspaceStore(accounts: [account])
    let classifier = ClassificationEngine(
        explicitRules: [
            ClassificationRule(
                id: ruleID,
                merchantPattern: "coffee shop",
                categoryID: categoryID,
                merchantName: "Coffee Shop"
            ),
        ]
    )
    let service = WorkspaceService(store: store, classifier: classifier)
    let csv = """
    Date,Description,Amount
    2026-04-01,SQ *Coffee Shop,-4.75
    """
    let preview = try CSVImportPreviewService().makePreview(from: csv)

    let result = try service.stageCSVImport(
        preview: preview,
        account: account,
        originalFilename: "checking-april.csv",
        csvText: csv
    )

    #expect(result.classifications == [
        ImportRowClassification(
            rowHash: try WorkspaceService.rowHash(for: preview.sourceRows[0]),
            sourceLineNumber: 2,
            decision: .autoAccepted(
                assignment: ClassificationAssignment(
                    categoryID: categoryID,
                    merchantName: "Coffee Shop"
                ),
                source: .rule,
                sourceReference: ruleID.uuidString,
                confidence: 1.0,
                reason: "Matched explicit merchant rule."
            )
        ),
    ])
}

@Test
func stageCSVImportUsesPersistedClassificationRulesToAvoidReview() throws {
    let account = Account(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000123")!,
        name: "Checking",
        kind: .checking,
        institutionName: "Local Bank"
    )
    let categoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000111")!
    let store = MutableWorkspaceStore(accounts: [account])
    store.classificationRules = [
        ClassificationRule(
            merchantPattern: "coffee shop",
            categoryID: categoryID,
            merchantName: "Coffee Shop"
        ),
    ]
    let service = WorkspaceService(store: store)
    let csv = """
    Date,Description,Amount
    2026-04-02,SQ *Coffee Shop,-5.25
    """
    let preview = try CSVImportPreviewService().makePreview(from: csv)

    let result = try service.stageCSVImport(
        preview: preview,
        account: account,
        originalFilename: "checking-april.csv",
        csvText: csv
    )

    #expect(result.classifications.count == 1)
    #expect(result.classifications[0].decision.isAutoAccepted)
    #expect(result.classifications[0].decision.source == .rule)
    #expect(try #require(store.stagedImportDrafts.first).rows.first?.classification?.isAutoAccepted == true)
}

@Test
func stageCSVImportHonorsPersistedSuggestionPreference() throws {
    let account = Account(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000123")!,
        name: "Checking",
        kind: .checking,
        institutionName: "Local Bank"
    )
    let categoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000111")!
    let store = MutableWorkspaceStore(accounts: [account])
    store.preferences = WorkspacePreferences(suggestionsEnabled: false)
    let classifier = ClassificationEngine(
        suggestionProvider: FixedSuggestionProvider(
            suggestion: ClassificationSuggestion(
                assignment: ClassificationAssignment(categoryID: categoryID, merchantName: "Coffee Shop"),
                confidence: 0.80,
                sourceReference: "fixture"
            )
        )
    )
    let service = WorkspaceService(store: store, classifier: classifier)
    let csv = """
    Date,Description,Amount
    2026-04-02,SQ *Coffee Shop,-5.25
    """
    let preview = try CSVImportPreviewService().makePreview(from: csv)

    let result = try service.stageCSVImport(
        preview: preview,
        account: account,
        originalFilename: "checking-april.csv",
        csvText: csv
    )

    #expect(result.classifications.count == 1)
    #expect(result.classifications[0].decision.source == nil)
    #expect(result.classifications[0].decision.assignment == nil)
}

@Test
func stageCSVImportHonorsSeededHeuristicAutoAcceptPreference() throws {
    let account = Account(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000123")!,
        name: "Checking",
        kind: .checking,
        institutionName: "Local Bank"
    )
    let categoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000111")!
    let classifier = ClassificationEngine(
        heuristics: [
            ClassificationHeuristic(
                merchantPattern: "coffee",
                categoryID: categoryID,
                merchantName: "Coffee Shop"
            ),
        ]
    )
    let csv = """
    Date,Description,Amount
    2026-04-02,SQ *Coffee Shop,-5.25
    """
    let preview = try CSVImportPreviewService().makePreview(from: csv)
    let aggressiveStore = MutableWorkspaceStore(accounts: [account])
    aggressiveStore.preferences = WorkspacePreferences(
        suggestionsEnabled: true,
        seededHeuristicAutoAcceptEnabled: true
    )
    let aggressiveService = WorkspaceService(store: aggressiveStore, classifier: classifier)

    let aggressiveResult = try aggressiveService.stageCSVImport(
        preview: preview,
        account: account,
        originalFilename: "checking-april.csv",
        csvText: csv
    )

    let conservativeStore = MutableWorkspaceStore(accounts: [account])
    conservativeStore.preferences = WorkspacePreferences(
        suggestionsEnabled: true,
        seededHeuristicAutoAcceptEnabled: false
    )
    let conservativeService = WorkspaceService(store: conservativeStore, classifier: classifier)

    let reviewResult = try conservativeService.stageCSVImport(
        preview: preview,
        account: account,
        originalFilename: "checking-april-review.csv",
        csvText: csv
    )

    #expect(aggressiveResult.classifications.count == 1)
    #expect(aggressiveResult.classifications[0].decision.isAutoAccepted)
    #expect(aggressiveResult.classifications[0].decision.source == .heuristic)
    #expect(reviewResult.classifications.count == 1)
    #expect(reviewResult.classifications[0].decision.isAutoAccepted == false)
    #expect(reviewResult.classifications[0].decision.source == .heuristic)
}

@Test
func stageCSVImportTreatsRenamedExactReimportAsNoOp() throws {
    let account = Account(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000123")!,
        name: "Checking",
        kind: .checking,
        institutionName: "Local Bank"
    )
    let store = MutableWorkspaceStore(accounts: [account])
    let service = WorkspaceService(store: store)
    let csv = """
    Date,Description,Amount
    2026-04-01,Coffee Shop,-4.75
    2026-04-02,Payroll,1250.00
    """
    let preview = try CSVImportPreviewService().makePreview(from: csv)

    let firstResult = try service.stageCSVImport(
        preview: preview,
        account: account,
        originalFilename: "checking-april.csv",
        csvText: csv
    )
    let renamedResult = try service.stageCSVImport(
        preview: preview,
        account: account,
        originalFilename: "renamed-export.csv",
        csvText: csv
    )

    #expect(firstResult.outcome == .staged)
    #expect(renamedResult.outcome == .exactReimportNoOp)
    #expect(renamedResult.session == nil)
    #expect(renamedResult.summary.importedRowCount == 0)
    #expect(renamedResult.summary.skippedRowCount == 2)
    #expect(renamedResult.decisions == [
        .skippedExactReimport(reason: "Source row already exists for this account."),
        .skippedExactReimport(reason: "Source row already exists for this account."),
    ])
    #expect(store.stagedImportDrafts.count == 1)
}

@Test
func stageCSVImportDoesNotTreatExtraRepeatedRowsAsExactReimportNoOp() throws {
    let account = Account(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000123")!,
        name: "Checking",
        kind: .checking,
        institutionName: "Local Bank"
    )
    let store = MutableWorkspaceStore(accounts: [account])
    let service = WorkspaceService(store: store)
    let firstCSV = """
    Date,Description,Amount
    2026-04-01,Coffee Shop,-4.75
    """
    let repeatedCSV = """
    Date,Description,Amount
    2026-04-01,Coffee Shop,-4.75
    2026-04-01,Coffee Shop,-4.75
    """

    _ = try service.stageCSVImport(
        preview: try CSVImportPreviewService().makePreview(from: firstCSV),
        account: account,
        originalFilename: "checking-april.csv",
        csvText: firstCSV
    )
    let repeatedResult = try service.stageCSVImport(
        preview: try CSVImportPreviewService().makePreview(from: repeatedCSV),
        account: account,
        originalFilename: "checking-april-repeated.csv",
        csvText: repeatedCSV
    )

    #expect(repeatedResult.outcome == .staged)
    #expect(repeatedResult.summary.importedRowCount == 1)
    #expect(repeatedResult.summary.skippedRowCount == 1)
    #expect(repeatedResult.session != nil)
    #expect(store.stagedImportDrafts.count == 2)
}

@Test
func stageCSVImportCanNoOpExactReimportBeforeDateNormalization() throws {
    let account = Account(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000123")!,
        name: "Checking",
        kind: .checking,
        institutionName: "Local Bank"
    )
    let store = MutableWorkspaceStore(accounts: [account])
    let service = WorkspaceService(store: store)
    let preview = CSVImportPreview(
        headers: [
            CSVColumn(name: "Date", columnIndex: 0),
            CSVColumn(name: "Description", columnIndex: 1),
            CSVColumn(name: "Amount", columnIndex: 2),
        ],
        mapping: CSVColumnMapping(
            dateColumnIndex: 0,
            descriptionColumnIndex: 1,
            amount: .singleSignedAmount(columnIndex: 2)
        ),
        previewRows: [],
        validation: CSVImportValidationSummary(
            missingRequiredFields: [],
            validRowCount: 1,
            invalidRowCount: 0,
            rowIssues: []
        ),
        sourceRows: [
            CSVRow(
                sourceLineNumber: 2,
                cells: [
                    CSVCell(value: "April 1, 2026", columnIndex: 0),
                    CSVCell(value: "Coffee Shop", columnIndex: 1),
                    CSVCell(value: "-4.75", columnIndex: 2),
                ]
            ),
        ]
    )
    let rowHash = try WorkspaceService.rowHash(for: preview.sourceRows[0])
    store.existingSourceRowHashes = [rowHash]

    let result = try service.stageCSVImport(
        preview: preview,
        account: account,
        originalFilename: "renamed-export.csv",
        csvText: "Date,Description,Amount\nApril 1, 2026,Coffee Shop,-4.75"
    )

    #expect(result.outcome == .exactReimportNoOp)
    #expect(result.summary.skippedRowCount == 1)
    #expect(store.stagedImportDrafts.isEmpty)
}

@Test
func stageCSVImportFlagsLikelyDuplicatesForReviewInsteadOfSkipping() throws {
    let account = Account(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000123")!,
        name: "Checking",
        kind: .checking,
        institutionName: "Local Bank"
    )
    let store = MutableWorkspaceStore(accounts: [account])
    let service = WorkspaceService(store: store)
    let csv = """
    Date,Description,Amount
    2026-04-02,SQ *Coffee Shop,-4.75
    """
    let preview = try CSVImportPreviewService().makePreview(from: csv)
    let rowHash = try WorkspaceService.rowHash(for: preview.sourceRows[0])
    let existingTransactionID = UUID(uuidString: "00000000-0000-0000-0000-000000000999")!
    store.likelyDuplicateCandidates = [
        LikelyDuplicateCandidate(
            rowHash: rowHash,
            existingTransactionID: existingTransactionID,
            reason: "Same account, amount, normalized merchant, and nearby date."
        ),
    ]

    let result = try service.stageCSVImport(
        preview: preview,
        account: account,
        originalFilename: "checking-april.csv",
        csvText: csv
    )

    let draft = try #require(store.stagedImportDrafts.first)
    #expect(result.outcome == .staged)
    #expect(result.summary.importedRowCount == 0)
    #expect(result.summary.flaggedDuplicateRowCount == 1)
    #expect(result.decisions == [
        .flaggedLikelyDuplicate(
            existingTransactionID: existingTransactionID,
            reason: "Same account, amount, normalized merchant, and nearby date."
        ),
    ])
    #expect(draft.rows.map(\.importDecision) == result.decisions)
    #expect(draft.rows.map(\.validationStatus) == [.valid])
}

@Test
func stageCSVImportHandlesRepeatedRowsThatShareADuplicateCandidate() throws {
    let account = Account(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000123")!,
        name: "Checking",
        kind: .checking,
        institutionName: "Local Bank"
    )
    let store = MutableWorkspaceStore(accounts: [account])
    let service = WorkspaceService(store: store)
    let csv = """
    Date,Description,Amount
    2026-04-02,SQ *Coffee Shop,-4.75
    2026-04-02,SQ *Coffee Shop,-4.75
    """
    let preview = try CSVImportPreviewService().makePreview(from: csv)
    let rowHash = try WorkspaceService.rowHash(for: preview.sourceRows[0])
    let existingTransactionID = UUID(uuidString: "00000000-0000-0000-0000-000000000999")!
    store.likelyDuplicateCandidates = [
        LikelyDuplicateCandidate(
            rowHash: rowHash,
            existingTransactionID: existingTransactionID,
            reason: "Same account, amount, normalized merchant, and nearby date."
        ),
        LikelyDuplicateCandidate(
            rowHash: rowHash,
            existingTransactionID: existingTransactionID,
            reason: "Same account, amount, normalized merchant, and nearby date."
        ),
    ]

    let result = try service.stageCSVImport(
        preview: preview,
        account: account,
        originalFilename: "checking-april.csv",
        csvText: csv
    )

    #expect(result.summary.flaggedDuplicateRowCount == 2)
    #expect(result.decisions == [
        .flaggedLikelyDuplicate(
            existingTransactionID: existingTransactionID,
            reason: "Same account, amount, normalized merchant, and nearby date."
        ),
        .flaggedLikelyDuplicate(
            existingTransactionID: existingTransactionID,
            reason: "Same account, amount, normalized merchant, and nearby date."
        ),
    ])
}

@Test
func stageCSVImportSummarySeparatesPendingClassificationReviewFromLikelyDuplicates() throws {
    let account = Account(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000123")!,
        name: "Checking",
        kind: .checking,
        institutionName: "Local Bank"
    )
    let categoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000111")!
    let classifier = ClassificationEngine(
        heuristics: [
            ClassificationHeuristic(
                merchantPattern: "coffee",
                categoryID: categoryID,
                merchantName: "Coffee Shop"
            ),
        ]
    )
    let store = MutableWorkspaceStore(accounts: [account])
    store.preferences = WorkspacePreferences(
        suggestionsEnabled: true,
        seededHeuristicAutoAcceptEnabled: false
    )
    let service = WorkspaceService(store: store, classifier: classifier)
    let csv = """
    Date,Description,Amount
    2026-04-02,SQ *Coffee Shop,-4.75
    2026-04-03,Book Shop,-12.00
    """
    let preview = try CSVImportPreviewService().makePreview(from: csv)
    let duplicateRowHash = try WorkspaceService.rowHash(for: preview.sourceRows[1])
    let existingTransactionID = UUID(uuidString: "00000000-0000-0000-0000-000000000999")!
    store.likelyDuplicateCandidates = [
        LikelyDuplicateCandidate(
            rowHash: duplicateRowHash,
            existingTransactionID: existingTransactionID,
            reason: "Same account, amount, normalized merchant, and nearby date."
        ),
    ]

    let result = try service.stageCSVImport(
        preview: preview,
        account: account,
        originalFilename: "checking-april.csv",
        csvText: csv
    )

    #expect(result.summary.importedRowCount == 1)
    #expect(result.summary.skippedRowCount == 0)
    #expect(result.summary.pendingClassificationReviewRowCount == 1)
    #expect(result.summary.flaggedDuplicateRowCount == 1)
}

@Test
func stageCSVImportRejectsInvalidPreviewBeforeWriting() throws {
    let account = Account(name: "Checking", kind: .checking, institutionName: "Local Bank")
    let store = MutableWorkspaceStore(accounts: [account])
    let service = WorkspaceService(store: store)
    let csv = """
    Date,Description,Amount
    ,Missing Date,-4.75
    """
    let preview = try CSVImportPreviewService().makePreview(from: csv)

    #expect(throws: WorkspaceServiceError.importPreviewNotReady) {
        try service.stageCSVImport(
            preview: preview,
            account: account,
            originalFilename: "invalid.csv",
            csvText: csv
        )
    }
    #expect(store.stagedImportDrafts.isEmpty)
}

@Test
func stageCSVImportRejectsPreviewWithMissingSourceRowsBeforeWriting() throws {
    let account = Account(name: "Checking", kind: .checking, institutionName: "Local Bank")
    let store = MutableWorkspaceStore(accounts: [account])
    let service = WorkspaceService(store: store)
    let preview = CSVImportPreview(
        headers: [
            CSVColumn(name: "Date", columnIndex: 0),
            CSVColumn(name: "Description", columnIndex: 1),
            CSVColumn(name: "Amount", columnIndex: 2),
        ],
        mapping: CSVColumnMapping(
            dateColumnIndex: 0,
            descriptionColumnIndex: 1,
            amount: .singleSignedAmount(columnIndex: 2)
        ),
        previewRows: [
            CSVImportPreviewRow(
                sourceLineNumber: 2,
                cells: [
                    CSVCell(value: "2026-04-01", columnIndex: 0),
                    CSVCell(value: "Coffee Shop", columnIndex: 1),
                    CSVCell(value: "-4.75", columnIndex: 2),
                ],
                interpretedAmount: -4.75
            ),
        ],
        validation: CSVImportValidationSummary(
            missingRequiredFields: [],
            validRowCount: 1,
            invalidRowCount: 0,
            rowIssues: []
        )
    )

    #expect(throws: WorkspaceServiceError.importPreviewSourceRowsUnavailable) {
        try service.stageCSVImport(
            preview: preview,
            account: account,
            originalFilename: "missing-source-rows.csv",
            csvText: "Date,Description,Amount\n2026-04-01,Coffee Shop,-4.75"
        )
    }
    #expect(store.stagedImportDrafts.isEmpty)
}

@Test
func previewWithoutConfirmationDoesNotCreateStagedRecords() throws {
    let account = Account(name: "Checking", kind: .checking, institutionName: "Local Bank")
    let store = MutableWorkspaceStore(accounts: [account])
    let csv = """
    Date,Description,Amount
    2026-04-01,Coffee Shop,-4.75
    """

    _ = try CSVImportPreviewService().makePreview(from: csv)

    #expect(store.stagedImportDrafts.isEmpty)
}

private struct FixedSuggestionProvider: SuggestionProvider {
    var suggestion: ClassificationSuggestion?

    func suggestion(for candidate: NormalizedImportCandidate) -> ClassificationSuggestion? {
        suggestion
    }
}
