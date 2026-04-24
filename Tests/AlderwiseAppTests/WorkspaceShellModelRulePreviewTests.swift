import Application
import Domain
import Foundation
import Testing

@testable import AlderwiseApp

@Test
@MainActor
func reviewRulePreviewWaitsForDebounceBeforeLoadingImpact() async throws {
    let item = makeReviewItem(
        id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
        normalizedMerchantName: "coffee shop 123"
    )
    let store = RulePreviewWorkspaceStore(reviewItems: [item])
    let service = WorkspaceService(store: store)
    let scheduler = ManualReviewRulePreviewScheduler()
    let loader = PreviewLoaderHarness()
    let model = WorkspaceShellModel(
        store: nil,
        service: service,
        reviewRulePreviewScheduler: scheduler.scheduler,
        reviewRulePreviewLoader: loader.load
    )

    model.scheduleReviewRulePreview(
        reviewItemID: item.id,
        createRuleEnabled: true,
        merchantPattern: "coffee shop 123",
        matchKind: .exactNormalizedMerchant
    )

    #expect(loader.receivedKeys.isEmpty)
    #expect(scheduler.pendingCount == 1)
    #expect(model.reviewRulePreviewState == .init(
        key: .init(
            reviewItemID: item.id,
            createRuleEnabled: true,
            merchantPattern: "coffee shop 123",
            matchKind: .exactNormalizedMerchant
        ),
        phase: .loading
    ))

    scheduler.fireNext()
    await Task.yield()

    #expect(loader.receivedKeys == [
        .init(
            reviewItemID: item.id,
            createRuleEnabled: true,
            merchantPattern: "coffee shop 123",
            matchKind: .exactNormalizedMerchant
        ),
    ])
}

@Test
@MainActor
func reviewRulePreviewIgnoresStaleResponseAfterSelectedItemChanges() async throws {
    let firstItem = makeReviewItem(
        id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
        normalizedMerchantName: "coffee shop 123"
    )
    let secondItem = makeReviewItem(
        id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
        normalizedMerchantName: "grocery world"
    )
    let store = RulePreviewWorkspaceStore(reviewItems: [firstItem, secondItem])
    let service = WorkspaceService(store: store)
    let scheduler = ManualReviewRulePreviewScheduler()
    let loader = PreviewLoaderHarness()
    let model = WorkspaceShellModel(
        store: nil,
        service: service,
        reviewRulePreviewScheduler: scheduler.scheduler,
        reviewRulePreviewLoader: loader.load
    )

    let firstKey = WorkspaceShellModel.ReviewRulePreviewKey(
        reviewItemID: firstItem.id,
        createRuleEnabled: true,
        merchantPattern: "coffee shop 123",
        matchKind: .exactNormalizedMerchant
    )
    let secondKey = WorkspaceShellModel.ReviewRulePreviewKey(
        reviewItemID: secondItem.id,
        createRuleEnabled: true,
        merchantPattern: "grocery world",
        matchKind: .exactNormalizedMerchant
    )

    model.scheduleReviewRulePreview(
        reviewItemID: firstItem.id,
        createRuleEnabled: true,
        merchantPattern: "coffee shop 123",
        matchKind: .exactNormalizedMerchant
    )
    scheduler.fireNext()
    await Task.yield()

    model.scheduleReviewRulePreview(
        reviewItemID: secondItem.id,
        createRuleEnabled: true,
        merchantPattern: "grocery world",
        matchKind: .exactNormalizedMerchant
    )
    #expect(model.reviewRulePreviewState == .init(key: secondKey, phase: .loading))
    scheduler.fireNext()
    await Task.yield()

    loader.resume(
        key: firstKey,
        with: .success(.ready(LearnedRuleImpactPreview(
            matchedAcceptedTransactionCount: 9,
            matchedPendingReviewItemCount: 4
        )))
    )
    await Task.yield()

    #expect(model.reviewRulePreviewState == .init(key: secondKey, phase: .loading))

    loader.resume(
        key: secondKey,
        with: .success(.ready(LearnedRuleImpactPreview(
            matchedAcceptedTransactionCount: 2,
            matchedPendingReviewItemCount: 1
        )))
    )
    await Task.yield()

    #expect(model.reviewRulePreviewState == .init(
        key: secondKey,
        phase: .ready(LearnedRuleImpactPreview(
            matchedAcceptedTransactionCount: 2,
            matchedPendingReviewItemCount: 1
        ))
    ))
}

@Test
@MainActor
func reviewRulePreviewRecomputesWhenRuleInputsChangeAndIgnoresOlderResponse() async throws {
    let item = makeReviewItem(
        id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
        normalizedMerchantName: "coffee shop 123"
    )
    let store = RulePreviewWorkspaceStore(reviewItems: [item])
    let service = WorkspaceService(store: store)
    let scheduler = ManualReviewRulePreviewScheduler()
    let loader = PreviewLoaderHarness()
    let model = WorkspaceShellModel(
        store: nil,
        service: service,
        reviewRulePreviewScheduler: scheduler.scheduler,
        reviewRulePreviewLoader: loader.load
    )

    let firstKey = WorkspaceShellModel.ReviewRulePreviewKey(
        reviewItemID: item.id,
        createRuleEnabled: true,
        merchantPattern: "coffee shop 123",
        matchKind: .exactNormalizedMerchant
    )
    let secondKey = WorkspaceShellModel.ReviewRulePreviewKey(
        reviewItemID: item.id,
        createRuleEnabled: true,
        merchantPattern: "coffee",
        matchKind: .prefixNormalizedMerchant
    )

    model.scheduleReviewRulePreview(
        reviewItemID: item.id,
        createRuleEnabled: true,
        merchantPattern: "coffee shop 123",
        matchKind: .exactNormalizedMerchant
    )
    scheduler.fireNext()
    await Task.yield()

    model.scheduleReviewRulePreview(
        reviewItemID: item.id,
        createRuleEnabled: true,
        merchantPattern: "coffee",
        matchKind: .prefixNormalizedMerchant
    )
    #expect(model.reviewRulePreviewState == .init(key: secondKey, phase: .loading))
    scheduler.fireNext()
    await Task.yield()

    loader.resume(
        key: firstKey,
        with: .success(.ready(LearnedRuleImpactPreview(
            matchedAcceptedTransactionCount: 7,
            matchedPendingReviewItemCount: 3
        )))
    )
    await Task.yield()

    #expect(model.reviewRulePreviewState == .init(key: secondKey, phase: .loading))

    loader.resume(
        key: secondKey,
        with: .success(.ready(LearnedRuleImpactPreview(
            matchedAcceptedTransactionCount: 5,
            matchedPendingReviewItemCount: 2
        )))
    )
    await Task.yield()

    #expect(model.reviewRulePreviewState == .init(
        key: secondKey,
        phase: .ready(LearnedRuleImpactPreview(
            matchedAcceptedTransactionCount: 5,
            matchedPendingReviewItemCount: 2
        ))
    ))
}

@Test
@MainActor
func reviewRulePreviewDoesNotRestartWhenSameInputsAreRescheduled() async throws {
    let item = makeReviewItem(
        id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
        normalizedMerchantName: "coffee shop 123"
    )
    let store = RulePreviewWorkspaceStore(reviewItems: [item])
    let service = WorkspaceService(store: store)
    let scheduler = ManualReviewRulePreviewScheduler()
    let loader = PreviewLoaderHarness()
    let model = WorkspaceShellModel(
        store: nil,
        service: service,
        reviewRulePreviewScheduler: scheduler.scheduler,
        reviewRulePreviewLoader: loader.load
    )

    let key = WorkspaceShellModel.ReviewRulePreviewKey(
        reviewItemID: item.id,
        createRuleEnabled: true,
        merchantPattern: "coffee shop 123",
        matchKind: .exactNormalizedMerchant
    )

    model.scheduleReviewRulePreview(
        reviewItemID: item.id,
        createRuleEnabled: true,
        merchantPattern: "coffee shop 123",
        matchKind: .exactNormalizedMerchant
    )

    model.scheduleReviewRulePreview(
        reviewItemID: item.id,
        createRuleEnabled: true,
        merchantPattern: "coffee shop 123",
        matchKind: .exactNormalizedMerchant
    )
    #expect(model.reviewRulePreviewState == .init(key: key, phase: .loading))
    #expect(scheduler.pendingCount == 1)

    scheduler.fireNext()
    await Task.yield()

    #expect(loader.receivedKeys == [key])
}

@Test
func reviewQueueDoesNotRefreshPreviewForMerchantNameOnlyEdits() throws {
    let source = try sourceText(in: "Sources/AlderwiseApp/ReviewQueueView.swift")

    #expect(source.contains(".onChange(of: merchantName)") == false)
}

@Test
func approvingRecommendedMerchantKeepsKeyboardFlowAndAdvancesSelection() {
    let firstItem = makeReviewItem(
        id: UUID(uuidString: "aaaaaaaa-1111-1111-1111-111111111111")!,
        normalizedMerchantName: "coffee shop"
    )
    let secondItem = makeReviewItem(
        id: UUID(uuidString: "bbbbbbbb-2222-2222-2222-222222222222")!,
        normalizedMerchantName: "grocery world"
    )
    let thirdItem = makeReviewItem(
        id: UUID(uuidString: "cccccccc-3333-3333-3333-333333333333")!,
        normalizedMerchantName: "book store"
    )

    let selectionAfterApproval = ReviewQueueSelection.selectionAfterApproving(
        approvedItemID: firstItem.id,
        items: [firstItem, secondItem, thirdItem]
    )
    #expect(selectionAfterApproval == secondItem.id)

    let selectionAfterRefresh = ReviewQueueSelection.selectionAfterItemsChange(
        currentSelectionID: selectionAfterApproval,
        items: [secondItem, thirdItem]
    )
    #expect(selectionAfterRefresh == secondItem.id)

    let wrappedSelection = ReviewQueueSelection.selectionAfterApproving(
        approvedItemID: thirdItem.id,
        items: [firstItem, secondItem, thirdItem]
    )
    #expect(wrappedSelection == firstItem.id)
}

@Test
@MainActor
func merchantRecommendationEligibilityLoadsOncePerUniqueMerchantAndPopulatesModelState() throws {
    let recommendedCategoryID = UUID(uuidString: "dddddddd-dddd-dddd-dddd-dddddddddddd")!
    let firstRecommendedItem = makeReviewItem(
        id: UUID(uuidString: "11111111-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!,
        normalizedMerchantName: "coffee shop"
    )
    let secondRecommendedItem = makeReviewItem(
        id: UUID(uuidString: "22222222-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!,
        normalizedMerchantName: "coffee shop"
    )
    let curatedItem = makeReviewItem(
        id: UUID(uuidString: "33333333-cccc-cccc-cccc-cccccccccccc")!,
        normalizedMerchantName: "coffee shop",
        source: .curatedPrefill
    )
    let unrelatedItem = makeReviewItem(
        id: UUID(uuidString: "44444444-dddd-dddd-dddd-dddddddddddd")!,
        normalizedMerchantName: "book store"
    )
    let store = RulePreviewWorkspaceStore(
        reviewItems: [
            firstRecommendedItem,
            secondRecommendedItem,
            curatedItem,
            unrelatedItem,
        ],
        merchantRecommendationEligibilityByMerchant: [
            "coffee shop": MerchantRecommendationEligibility(
                normalizedMerchantName: "coffee shop",
                categoryID: recommendedCategoryID,
                approvedDecisionCount: 3
            ),
        ]
    )
    let service = WorkspaceService(store: store)

    let model = WorkspaceShellModel(
        store: nil,
        service: service,
        merchantRecommendationEligibilityLoader: { merchant in
            try store.fetchMerchantRecommendationEligibility(normalizedMerchantName: merchant)
        }
    )

    #expect(model.merchantRecommendationEligibilityByReviewItemID == [
        firstRecommendedItem.id: MerchantRecommendationEligibility(
            normalizedMerchantName: "coffee shop",
            categoryID: recommendedCategoryID,
            approvedDecisionCount: 3
        ),
        secondRecommendedItem.id: MerchantRecommendationEligibility(
            normalizedMerchantName: "coffee shop",
            categoryID: recommendedCategoryID,
            approvedDecisionCount: 3
        ),
    ])
    #expect(store.fetchMerchantRecommendationEligibilityCalls == [
        "coffee shop": 1,
        "book store": 1,
    ])

    model.reload()

    #expect(model.merchantRecommendationEligibilityByReviewItemID == [
        firstRecommendedItem.id: MerchantRecommendationEligibility(
            normalizedMerchantName: "coffee shop",
            categoryID: recommendedCategoryID,
            approvedDecisionCount: 3
        ),
        secondRecommendedItem.id: MerchantRecommendationEligibility(
            normalizedMerchantName: "coffee shop",
            categoryID: recommendedCategoryID,
            approvedDecisionCount: 3
        ),
    ])
    #expect(store.fetchMerchantRecommendationEligibilityCalls == [
        "coffee shop": 2,
        "book store": 2,
    ])
}

@Test
@MainActor
func reviewRulePreviewShowsNoEligiblePreviewWhenRuleCreationIsDisabled() async throws {
    let item = makeReviewItem(
        id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
        normalizedMerchantName: "coffee shop 123"
    )
    let store = RulePreviewWorkspaceStore(reviewItems: [item])
    let service = WorkspaceService(store: store)
    let scheduler = ManualReviewRulePreviewScheduler()
    let loader = PreviewLoaderHarness()
    let model = WorkspaceShellModel(
        store: nil,
        service: service,
        reviewRulePreviewScheduler: scheduler.scheduler,
        reviewRulePreviewLoader: loader.load
    )

    model.scheduleReviewRulePreview(
        reviewItemID: item.id,
        createRuleEnabled: false,
        merchantPattern: "coffee shop 123",
        matchKind: .exactNormalizedMerchant
    )

    #expect(scheduler.pendingCount == 0)
    #expect(loader.receivedKeys.isEmpty)
    #expect(model.reviewRulePreviewState == .init(
        key: .init(
            reviewItemID: item.id,
            createRuleEnabled: false,
            merchantPattern: "coffee shop 123",
            matchKind: .exactNormalizedMerchant
        ),
        phase: .noEligiblePreview
    ))
}

private func makeReviewItem(
    id: UUID,
    normalizedMerchantName: String,
    source: ClassificationDecisionSource? = .suggestion
) -> PendingReviewItem {
    PendingReviewItem(
        id: id,
        type: .lowConfidenceCategory,
        status: .pending,
        reason: "Needs review",
        createdAt: Date(timeIntervalSince1970: 0),
        sourceFile: PendingReviewSourceFile(
            accountID: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!,
            originalFilename: "import.csv"
        ),
        sourceRow: PendingReviewSourceRow(
            id: 1,
            sourceLineNumber: 1,
            rowHash: "row-\(id.uuidString)",
            rawPayload: "payload"
        ),
        duplicateTransactionID: nil,
        classification: PendingReviewClassification(
            normalizedMerchantName: normalizedMerchantName,
            prefill: nil,
            source: source,
            sourceReference: nil,
            confidence: 0.4
        )
    )
}

private func sourceText(in relativePath: String) throws -> String {
    let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let sourceURL = repoRoot.appendingPathComponent(relativePath)
    return try String(contentsOf: sourceURL, encoding: .utf8)
}

@MainActor
private final class ManualReviewRulePreviewScheduler {
    private struct Entry {
        var id: UUID
        var operation: @MainActor () async -> Void
    }

    private var entries: [Entry] = []

    var scheduler: WorkspaceShellModel.ReviewRulePreviewScheduler {
        .init { _, operation in
            let id = UUID()
            self.entries.append(Entry(id: id, operation: operation))
            return WorkspaceShellModel.ReviewRulePreviewScheduleToken {
                self.entries.removeAll { $0.id == id }
            }
        }
    }

    var pendingCount: Int {
        entries.count
    }

    func fireNext() {
        let operation = entries.removeFirst().operation
        Task { @MainActor in
            await operation()
        }
    }
}

@MainActor
private final class PreviewLoaderHarness {
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
        let continuation = continuations.removeValue(forKey: key)
        switch result {
        case .success(let state):
            continuation?.resume(returning: state)
        case .failure(let error):
            continuation?.resume(throwing: error)
        }
    }
}

private final class RulePreviewWorkspaceStore: @unchecked Sendable, WorkspaceStoring, StagedImportWriting, ImportDecisionReading, ReviewQueueReading, ReportingReading, TargetManaging, WorkspacePreferencesManaging, MerchantRecommendationEligibilityReading {
    private let reviewItems: [PendingReviewItem]
    private let merchantRecommendationEligibilityByMerchant: [String: MerchantRecommendationEligibility]
    private(set) var fetchMerchantRecommendationEligibilityCalls: [String: Int] = [:]

    init(
        reviewItems: [PendingReviewItem],
        merchantRecommendationEligibilityByMerchant: [String: MerchantRecommendationEligibility] = [:]
    ) {
        self.reviewItems = reviewItems
        self.merchantRecommendationEligibilityByMerchant = merchantRecommendationEligibilityByMerchant
    }

    func fetchSummary() throws -> WorkspaceSummary {
        .empty
    }

    func fetchAccounts() throws -> [Account] {
        []
    }

    func fetchManagementAccounts() throws -> [Account] {
        []
    }

    func fetchImportEligibleAccounts() throws -> [Account] {
        []
    }

    func fetchLedgerFilterAccounts() throws -> [Account] {
        []
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
        fatalError("Not used in these tests")
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

    func fetchPendingReviewItems() throws -> [PendingReviewItem] {
        reviewItems
    }

    func fetchMerchantRecommendationEligibility(
        normalizedMerchantName: String
    ) throws -> MerchantRecommendationEligibility? {
        fetchMerchantRecommendationEligibilityCalls[normalizedMerchantName, default: 0] += 1
        return merchantRecommendationEligibilityByMerchant[normalizedMerchantName]
    }

    func fetchMonthlyReport(referenceDate: Date) throws -> MonthlyReport {
        .empty
    }

    func fetchManagedTargets(referenceDate: Date) throws -> [ManagedMonthlyTarget] {
        []
    }

    func createMonthlyTarget(_ draft: MonthlyTargetDraft, createdAt: Date) throws -> MonthlyTarget {
        fatalError("Not used in these tests")
    }

    func updateMonthlyTarget(id: UUID, _ draft: MonthlyTargetDraft) throws -> MonthlyTarget {
        fatalError("Not used in these tests")
    }

    func deleteMonthlyTarget(id: UUID) throws {}

    func fetchWorkspacePreferences() throws -> WorkspacePreferences {
        .default
    }

    func updateWorkspacePreferences(_ preferences: WorkspacePreferences) throws {}
}
