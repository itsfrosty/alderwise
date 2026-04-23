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
func saveLearnedRuleDraftRejectsContainsMatchKind() {
    let categoryID = UUID(uuidString: "12121212-1212-1212-1212-121212121212")!
    let store = LearnedRuleDraftWorkspaceStore()
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

    #expect(didSave == false)
    #expect(store.createdDrafts.isEmpty)
    #expect(model.learnedRuleDraftSheet?.draft.matchKind == .contains)
    #expect(model.learnedRuleManagerActionErrorMessage == "Contains rules are not available in manual authoring yet.")
}

private final class LearnedRuleDraftWorkspaceStore: @unchecked Sendable, WorkspaceStoring, StagedImportWriting, ImportDecisionReading, LearnedRuleManaging, TargetManaging, WorkspacePreferencesManaging {
    var summary: WorkspaceSummary = .empty
    var accounts: [Account] = []
    var learnedRuleSummaries: [LearnedRuleSummary] = []
    var createdDrafts: [LearnedRuleDraft] = []
    var nextCreatedLearnedRuleID: UUID

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
}
