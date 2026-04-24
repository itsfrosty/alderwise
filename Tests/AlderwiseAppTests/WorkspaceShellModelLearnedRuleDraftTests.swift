import Application
import Domain
import Foundation
import Testing

@testable import AlderwiseApp

@Test
@MainActor
func beginNewLearnedRulePresentsBlankDraftSheet() {
    let store = LearnedRuleDraftWorkspaceStore()
    let service = WorkspaceService(store: store)
    let model = WorkspaceShellModel(store: nil, service: service)

    model.beginNewLearnedRule()

    #expect(model.learnedRuleDraftSheet?.mode == .newRule)
    #expect(model.learnedRuleDraftSheet?.draft == LearnedRuleDraft())
}

@Test
@MainActor
func showLearnedRulesPreservesSeededSelectionDeepLink() throws {
    let model = WorkspaceShellModel(
        store: nil,
        service: WorkspaceService(store: LearnedRuleDraftWorkspaceStore())
    )
    let seededSourceID = ClassificationRule(
        merchantPattern: "costco",
        categoryID: DefaultBudgetTaxonomy.CategoryID.groceries,
        merchantName: "Costco",
        sourceReferenceKind: .seededSourceID
    ).seededSourceID

    model.showLearnedRules(selection: .seededSource(seededSourceID))

    #expect(
        model.settingsDestination == .learnedRulesRoute(selection: .seededSource(seededSourceID))
    )
    #expect(model.pendingAppSectionNavigation == .rules)
}

@Test
@MainActor
func showTransactionsWithRuleFilterClearsHiddenSelectionAfterReload() {
    let matchingRow = makeTransactionLedgerRow(
        id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
        merchantName: "Coffee Shop"
    )
    let hiddenRow = TransactionLedgerRow(
        id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
        accountID: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
        accountName: "Checking",
        categoryID: UUID(uuidString: "55555555-5555-5555-5555-555555555555")!,
        categoryName: "Dining",
        rawDescription: "GROCERY MARKET",
        merchantName: "Grocery Market",
        amount: Decimal(-12.34),
        transactionDate: Date(timeIntervalSince1970: 1_778_000_000),
        postedDate: nil,
        direction: .expense,
        reviewStatus: .accepted,
        importOrigin: nil
    )
    let store = LearnedRuleDraftWorkspaceStore()
    store.transactionRows = [hiddenRow, matchingRow]
    let model = WorkspaceShellModel(
        store: nil,
        service: WorkspaceService(store: store)
    )
    let filter = TransactionLedgerFilter(
        ruleFilterIntent: TransactionLedgerRuleFilterIntent(
            source: .learnedRule(UUID(uuidString: "33333333-3333-3333-3333-333333333333")!),
            merchantPattern: "coffee shop",
            merchantLabel: "Coffee Shop",
            matchKind: .exactNormalizedMerchant
        )
    )

    #expect(model.selectedTransactionID == hiddenRow.id)

    model.showTransactions(filter: filter, clearSelection: true)

    #expect(model.pendingAppSectionNavigation == .transactions)
    #expect(model.transactionFilter == filter)
    #expect(model.selectedTransactionID == nil)
    #expect(model.selectedTransactionDetail == nil)
    #expect(model.matchingTransactions(in: model.snapshot.transactions).map(\.id) == [matchingRow.id])
}

@Test
@MainActor
func beginDuplicateLearnedRuleLoadsEditableDraftIntoSheet() {
    let ruleID = UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!
    let categoryID = UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!
    let store = LearnedRuleDraftWorkspaceStore()
    store.learnedRuleSummaries = [
        LearnedRuleSummary(
            id: ruleID,
            merchantPattern: "coffee shop",
            categoryID: categoryID,
            merchantName: "Coffee Shop",
            matchKind: .prefixNormalizedMerchant,
            createdAt: Date(timeIntervalSince1970: 1_776_400_000),
            lifecycle: .disabled(disabledAt: Date(timeIntervalSince1970: 1_776_400_100))
        )
    ]
    let service = WorkspaceService(store: store)
    let model = WorkspaceShellModel(store: nil, service: service)

    let didBegin = model.beginDuplicateLearnedRule(id: ruleID)

    #expect(didBegin)
    #expect(model.learnedRuleDraftSheet?.mode == .duplicateRule(sourceRuleID: ruleID))
    #expect(
        model.learnedRuleDraftSheet?.draft == LearnedRuleDraft(
            merchantPattern: "coffee shop",
            categoryID: categoryID,
            merchantName: "Coffee Shop",
            matchKind: .prefixNormalizedMerchant
        )
    )
}

@Test
@MainActor
func recurringMerchantDrilldownClearsSelectionAndLeavesNewestVisibleRowAsNextSelection() {
    let hiddenRow = TransactionLedgerRow(
        id: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!,
        accountID: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
        accountName: "Checking",
        isHidden: false,
        categoryID: nil,
        categoryName: nil,
        rawDescription: "Older selection",
        merchantName: "Other",
        amount: Decimal(-9),
        transactionDate: Date(timeIntervalSince1970: 1_780_000_000),
        postedDate: nil,
        direction: .expense,
        reviewStatus: .accepted,
        importOrigin: nil
    )
    let newerRecurringRow = TransactionLedgerRow(
        id: UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!,
        accountID: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
        accountName: "Checking",
        categoryID: nil,
        categoryName: nil,
        rawDescription: "Netflix Apr",
        merchantName: "Netflix",
        amount: Decimal(-15.49),
        transactionDate: Date(timeIntervalSince1970: 1_775_692_800),
        postedDate: nil,
        direction: .expense,
        reviewStatus: .accepted,
        importOrigin: nil
    )
    let olderRecurringRow = TransactionLedgerRow(
        id: UUID(uuidString: "cccccccc-cccc-cccc-cccc-cccccccccccc")!,
        accountID: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
        accountName: "Checking",
        categoryID: nil,
        categoryName: nil,
        rawDescription: "Netflix Mar",
        merchantName: "Netflix",
        amount: Decimal(-15.49),
        transactionDate: Date(timeIntervalSince1970: 1_773_187_200),
        postedDate: nil,
        direction: .expense,
        reviewStatus: .accepted,
        importOrigin: nil
    )
    let store = LearnedRuleDraftWorkspaceStore()
    store.transactionRows = [hiddenRow, olderRecurringRow, newerRecurringRow]
    let model = WorkspaceShellModel(
        store: nil,
        service: WorkspaceService(store: store)
    )
    let filter = TransactionLedgerFilter(
        startDate: Date(timeIntervalSince1970: 1_773_187_200),
        endDate: Date(timeIntervalSince1970: 1_775_779_199),
        normalizedMerchantName: "netflix",
        direction: .expense,
        visibility: .active
    )

    #expect(model.selectedTransactionID == hiddenRow.id)

    model.showTransactions(filter: filter, clearSelection: true)

    #expect(model.pendingAppSectionNavigation == .transactions)
    #expect(model.transactionFilter == filter)
    #expect(model.selectedTransactionID == nil)
    #expect(model.selectedTransactionDetail == nil)
    #expect(model.snapshot.transactions.map(\.id) == [newerRecurringRow.id, olderRecurringRow.id])
    #expect(
        TransactionLedgerSelectionState.selectionAfterReload(
            currentSelectionID: model.selectedTransactionID,
            visibleRows: model.snapshot.transactions
        ) == newerRecurringRow.id
    )
}

@Test
@MainActor
func beginDuplicateLearnedRuleLoadsContainsRuleIntoAdvancedDraftSheet() {
    let ruleID = UUID(uuidString: "abababab-abab-abab-abab-abababababab")!
    let categoryID = UUID(uuidString: "cdcdcdcd-cdcd-cdcd-cdcd-cdcdcdcdcdcd")!
    let store = LearnedRuleDraftWorkspaceStore()
    store.learnedRuleSummaries = [
        LearnedRuleSummary(
            id: ruleID,
            merchantPattern: "coffee",
            categoryID: categoryID,
            merchantName: "Coffee",
            matchKind: .contains,
            createdAt: Date(timeIntervalSince1970: 1_776_400_120),
            lifecycle: .active
        )
    ]
    let service = WorkspaceService(store: store)
    let model = WorkspaceShellModel(store: nil, service: service)

    let didBegin = model.beginDuplicateLearnedRule(id: ruleID)

    #expect(didBegin)
    #expect(model.learnedRuleDraftSheet?.mode == .duplicateRule(sourceRuleID: ruleID))
    #expect(model.learnedRuleDraftSheet?.draft.matchKind == .contains)
    #expect(model.learnedRuleManagerActionErrorMessage == nil)
}

@Test
@MainActor
func saveLearnedRuleDraftCreatesExactRuleThroughShellModel() {
    let createdRuleID = UUID(uuidString: "cccccccc-cccc-cccc-cccc-cccccccccccc")!
    let categoryID = UUID(uuidString: "dddddddd-dddd-dddd-dddd-dddddddddddd")!
    let store = LearnedRuleDraftWorkspaceStore(nextCreatedLearnedRuleID: createdRuleID)
    let service = WorkspaceService(store: store)
    let model = WorkspaceShellModel(store: nil, service: service)
    model.beginNewLearnedRule()
    model.updateLearnedRuleDraft(
        LearnedRuleDraft(
            merchantPattern: "  Coffee Shop  ",
            categoryID: categoryID,
            merchantName: "Coffee Shop",
            matchKind: .exactNormalizedMerchant
        )
    )

    let didSave = model.saveLearnedRuleDraft()

    #expect(didSave)
    #expect(store.createdDrafts == [
        LearnedRuleDraft(
            merchantPattern: "  Coffee Shop  ",
            categoryID: categoryID,
            merchantName: "Coffee Shop",
            matchKind: .exactNormalizedMerchant
        )
    ])
    #expect(model.learnedRuleDraftSheet == nil)
    #expect(model.learnedRuleManagerActionErrorMessage == nil)
    #expect(model.settingsDestination == .learnedRulesRoute(selectedLearnedRuleID: createdRuleID))
    #expect(model.learnedRuleManagerSnapshot?.learned.rows.first?.id == createdRuleID)
    #expect(model.learnedRuleManagerSnapshot?.learned.rows.first?.merchantPattern == "coffee shop")
}

@Test
@MainActor
func saveLearnedRuleDraftCreatesSharedPrefixRuleThroughShellModel() {
    let createdRuleID = UUID(uuidString: "eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee")!
    let categoryID = UUID(uuidString: "ffffffff-ffff-ffff-ffff-ffffffffffff")!
    let store = LearnedRuleDraftWorkspaceStore(nextCreatedLearnedRuleID: createdRuleID)
    let service = WorkspaceService(store: store)
    let model = WorkspaceShellModel(store: nil, service: service)
    model.beginNewLearnedRule()
    model.updateLearnedRuleDraft(
        LearnedRuleDraft(
            merchantPattern: "Coffee",
            categoryID: categoryID,
            merchantName: "Coffee",
            matchKind: .prefixNormalizedMerchant
        )
    )

    let didSave = model.saveLearnedRuleDraft()

    #expect(didSave)
    #expect(store.createdDrafts == [
        LearnedRuleDraft(
            merchantPattern: "Coffee",
            categoryID: categoryID,
            merchantName: "Coffee",
            matchKind: .prefixNormalizedMerchant
        )
    ])
    #expect(model.learnedRuleDraftSheet == nil)
    #expect(model.settingsDestination == .learnedRulesRoute(selectedLearnedRuleID: createdRuleID))
    #expect(model.learnedRuleManagerSnapshot?.learned.rows.first?.matchKind == .prefixNormalizedMerchant)
}

@Test
@MainActor
func saveLearnedRuleDraftCreatesContainsRuleThroughShellModel() {
    let categoryID = UUID(uuidString: "12121212-1212-1212-1212-121212121212")!
    let createdRuleID = UUID(uuidString: "34343434-3434-3434-3434-343434343434")!
    let store = LearnedRuleDraftWorkspaceStore(nextCreatedLearnedRuleID: createdRuleID)
    let service = WorkspaceService(store: store)
    let model = WorkspaceShellModel(store: nil, service: service)
    model.beginNewLearnedRule()
    model.updateLearnedRuleDraft(
        LearnedRuleDraft(
            merchantPattern: "Coffee",
            categoryID: categoryID,
            merchantName: "Coffee",
            matchKind: .contains
        )
    )

    let didSave = model.saveLearnedRuleDraft()

    #expect(didSave)
    #expect(store.createdDrafts == [
        LearnedRuleDraft(
            merchantPattern: "Coffee",
            categoryID: categoryID,
            merchantName: "Coffee",
            matchKind: .contains
        )
    ])
    #expect(model.learnedRuleDraftSheet == nil)
    #expect(model.learnedRuleManagerActionErrorMessage == nil)
    #expect(model.settingsDestination == .learnedRulesRoute(selectedLearnedRuleID: createdRuleID))
    #expect(model.learnedRuleManagerSnapshot?.learned.rows.first?.matchKind == .contains)
}

@Test
@MainActor
func manualContainsDraftReusesPreviewInfrastructure() async throws {
    let scheduler = ManualLearnedRuleDraftPreviewScheduler()
    let loader = LearnedRuleDraftPreviewLoaderHarness()
    let model = WorkspaceShellModel(
        store: nil,
        service: WorkspaceService(store: LearnedRuleDraftWorkspaceStore()),
        reviewRulePreviewScheduler: scheduler.scheduler,
        reviewRulePreviewLoader: loader.load
    )
    model.beginNewLearnedRule()

    model.updateLearnedRuleDraft(
        LearnedRuleDraft(
            merchantPattern: "Coffee",
            categoryID: UUID(uuidString: "56565656-5656-5656-5656-565656565656")!,
            merchantName: "Coffee",
            matchKind: .contains
        )
    )

    #expect(model.learnedRuleDraftPreviewState?.phase == .loading)
    #expect(scheduler.pendingCount == 1)

    scheduler.fireNext()
    await Task.yield()

    let key = try #require(loader.receivedKeys.only)
    #expect(key.createRuleEnabled)
    #expect(key.merchantPattern == "Coffee")
    #expect(key.matchKind == .contains)

    loader.resume(
        key: key,
        with: .success(.ready(LearnedRuleImpactPreview(
            matchedAcceptedTransactionCount: 4,
            matchedPendingReviewItemCount: 2
        )))
    )
    await Task.yield()

    #expect(model.learnedRuleDraftPreviewState?.phase == .ready(LearnedRuleImpactPreview(
        matchedAcceptedTransactionCount: 4,
        matchedPendingReviewItemCount: 2
    )))
}

@Test
@MainActor
func manualContainsPreviewDoesNotRestartForMerchantNameOnlyEdits() async throws {
    let scheduler = ManualLearnedRuleDraftPreviewScheduler()
    let loader = LearnedRuleDraftPreviewLoaderHarness()
    let model = WorkspaceShellModel(
        store: nil,
        service: WorkspaceService(store: LearnedRuleDraftWorkspaceStore()),
        reviewRulePreviewScheduler: scheduler.scheduler,
        reviewRulePreviewLoader: loader.load
    )
    model.beginNewLearnedRule()

    model.updateLearnedRuleDraft(
        LearnedRuleDraft(
            merchantPattern: "Coffee",
            categoryID: UUID(uuidString: "67676767-6767-6767-6767-676767676767")!,
            merchantName: "Coffee",
            matchKind: .contains
        )
    )
    #expect(scheduler.pendingCount == 1)
    #expect(scheduler.scheduledCount == 1)

    model.updateLearnedRuleDraft(
        LearnedRuleDraft(
            merchantPattern: "Coffee",
            categoryID: UUID(uuidString: "67676767-6767-6767-6767-676767676767")!,
            merchantName: "Coffee Roasters",
            matchKind: .contains
        )
    )

    #expect(scheduler.pendingCount == 1)
    #expect(scheduler.scheduledCount == 1)

    scheduler.fireNext()
    await Task.yield()

    let key = try #require(loader.receivedKeys.only)
    #expect(key.merchantPattern == "Coffee")
}

@Test
func learnedRuleDraftViewKeepsContainsBehindAdvancedDisclosure() throws {
    let source = try sourceText(in: "Sources/AlderwiseApp/LearnedRulesManagerView.swift")

    #expect(source.contains("DisclosureGroup(\"Advanced\""))
    #expect(source.contains("manualAuthoringWarningText"))
}

private final class LearnedRuleDraftWorkspaceStore: @unchecked Sendable, WorkspaceStoring, StagedImportWriting, ImportDecisionReading, LearnedRuleManaging, TargetManaging, WorkspacePreferencesManaging, TransactionLedgerReading {
    var summary: WorkspaceSummary = .empty
    var accounts: [Account] = []
    var learnedRuleSummaries: [LearnedRuleSummary] = []
    var createdDrafts: [LearnedRuleDraft] = []
    var nextCreatedLearnedRuleID: UUID
    var transactionRows: [TransactionLedgerRow] = []

    init(nextCreatedLearnedRuleID: UUID = UUID(uuidString: "99999999-9999-9999-9999-999999999999")!) {
        self.nextCreatedLearnedRuleID = nextCreatedLearnedRuleID
    }

    func fetchSummary() throws -> WorkspaceSummary {
        summary
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
        Account(id: id, name: "Archived", kind: .checking, institutionName: nil, archivedAt: archivedAt)
    }

    func restoreAccount(id: UUID) throws -> Account {
        Account(id: id, name: "Restored", kind: .checking, institutionName: nil)
    }

    func deleteAccountPermanently(id: UUID) throws {}

    func createStagedImportSession(_ draft: StagedImportSessionDraft) throws -> StagedImportSession {
        fatalError("Not used in this test")
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

    func fetchLearnedRuleSummaries() throws -> [LearnedRuleSummary] {
        learnedRuleSummaries
    }

    func fetchLearnedRuleSummary(id: UUID) throws -> LearnedRuleSummary? {
        learnedRuleSummaries.first { $0.id == id }
    }

    func fetchLearnedRuleDetail(id: UUID) throws -> ManagedLearnedRule? {
        guard let summary = learnedRuleSummaries.first(where: { $0.id == id }) else {
            return nil
        }

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

    func createLearnedRule(_ draft: LearnedRuleDraft, createdAt: Date) throws -> ManagedLearnedRule {
        createdDrafts.append(draft)
        let rule = ManagedLearnedRule(
            id: nextCreatedLearnedRuleID,
            merchantPattern: draft.normalizedMerchantPattern ?? draft.merchantPattern,
            categoryID: draft.categoryID,
            merchantName: draft.merchantName,
            matchKind: draft.matchKind,
            createdAt: createdAt,
            lifecycle: .active
        )
        learnedRuleSummaries.insert(
            LearnedRuleSummary(
                id: rule.id,
                merchantPattern: rule.merchantPattern,
                categoryID: rule.categoryID,
                merchantName: rule.merchantName,
                matchKind: rule.matchKind,
                createdAt: rule.createdAt,
                lifecycle: .active
            ),
            at: 0
        )
        return rule
    }

    func disableLearnedRule(id: UUID, disabledAt: Date) throws -> ManagedLearnedRule {
        let index = try #require(learnedRuleSummaries.firstIndex { $0.id == id })
        learnedRuleSummaries[index].lifecycle = .disabled(disabledAt: disabledAt)
        return try #require(try fetchLearnedRuleDetail(id: id))
    }

    func enableLearnedRule(id: UUID) throws -> ManagedLearnedRule {
        let index = try #require(learnedRuleSummaries.firstIndex { $0.id == id })
        learnedRuleSummaries[index].lifecycle = .active
        return try #require(try fetchLearnedRuleDetail(id: id))
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

    func fetchWorkspacePreferences() throws -> WorkspacePreferences {
        .default
    }

    func updateWorkspacePreferences(_ preferences: WorkspacePreferences) throws {}

    func fetchTransactionLedger(filter: TransactionLedgerFilter) throws -> [TransactionLedgerRow] {
        transactionRows
            .filter { row in
                if let normalizedMerchantName = filter.normalizedMerchantName?.lowercased(),
                   row.merchantName.lowercased() != normalizedMerchantName {
                    return false
                }
                if let startDate = filter.startDate, row.transactionDate < startDate {
                    return false
                }
                if let endDate = filter.endDate, row.transactionDate > endDate {
                    return false
                }
                if let direction = filter.direction, row.direction != direction {
                    return false
                }
                switch filter.visibility ?? .active {
                case .active:
                    if row.isHidden {
                        return false
                    }
                case .hidden:
                    if row.isHidden == false {
                        return false
                    }
                case .all:
                    break
                }
                return true
            }
            .sorted {
                if $0.transactionDate != $1.transactionDate {
                    return $0.transactionDate > $1.transactionDate
                }
                return $0.id.uuidString < $1.id.uuidString
            }
    }

    func fetchTransactionDetail(id: UUID) throws -> TransactionDetail? {
        guard let row = transactionRows.first(where: { $0.id == id }) else {
            return nil
        }

        return TransactionDetail(
            row: row,
            notes: nil,
            decisionSource: nil,
            decisionSourceReference: nil,
            confidence: nil,
            duplicateStatus: "none"
        )
    }

    func fetchTransactionImportOrigins() throws -> [TransactionImportOrigin] {
        []
    }
}

@MainActor
private final class ManualLearnedRuleDraftPreviewScheduler {
    private struct Entry {
        var id: UUID
        var operation: @MainActor () async -> Void
    }

    private var entries: [Entry] = []
    private(set) var scheduledCount = 0

    var pendingCount: Int {
        entries.count
    }

    var scheduler: WorkspaceShellModel.ReviewRulePreviewScheduler {
        .init { _, operation in
            let id = UUID()
            self.scheduledCount += 1
            self.entries.append(Entry(id: id, operation: operation))
            return WorkspaceShellModel.ReviewRulePreviewScheduleToken {
                self.entries.removeAll { $0.id == id }
            }
        }
    }

    func fireNext() {
        let operation = entries.removeFirst().operation
        Task { @MainActor in
            await operation()
        }
    }
}

private func makeTransactionLedgerRow(id: UUID, merchantName: String) -> TransactionLedgerRow {
    TransactionLedgerRow(
        id: id,
        accountID: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
        accountName: "Checking",
        categoryID: UUID(uuidString: "55555555-5555-5555-5555-555555555555")!,
        categoryName: "Dining",
        rawDescription: merchantName.uppercased(),
        merchantName: merchantName,
        amount: Decimal(-12.34),
        transactionDate: Date(timeIntervalSince1970: 1_777_000_000),
        postedDate: nil,
        direction: .expense,
        reviewStatus: .accepted,
        importOrigin: nil
    )
}

@MainActor
private final class LearnedRuleDraftPreviewLoaderHarness {
    private var continuations: [WorkspaceShellModel.ReviewRulePreviewKey: CheckedContinuation<LearnedRuleImpactPreviewState, Error>] = [:]
    private(set) var receivedKeys: [WorkspaceShellModel.ReviewRulePreviewKey] = []

    func load(_ key: WorkspaceShellModel.ReviewRulePreviewKey) async throws -> LearnedRuleImpactPreviewState {
        receivedKeys.append(key)
        return try await withCheckedThrowingContinuation { continuation in
            continuations[key] = continuation
        }
    }

    func resume(
        key: WorkspaceShellModel.ReviewRulePreviewKey,
        with result: Result<LearnedRuleImpactPreviewState, Error>
    ) {
        continuations.removeValue(forKey: key)?.resume(with: result)
    }
}

private extension Array {
    var only: Element? {
        count == 1 ? first : nil
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
