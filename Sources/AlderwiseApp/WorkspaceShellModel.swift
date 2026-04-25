import Application
import Domain
import Persistence
import SwiftUI

@MainActor
final class WorkspaceShellModel: ObservableObject {
    enum State {
        case loading
        case loaded(WorkspaceSnapshot)
        case failed(String)
    }

    enum FileImportRequest {
        case csv
        case workspaceRestore
    }

    enum AccountCreationRoute: Equatable {
        case general
        case batchImport(itemID: UUID)
    }

    enum AccountCreationRouteError: LocalizedError, Equatable {
        case missingBatchImportContext

        var errorDescription: String? {
            switch self {
            case .missingBatchImportContext:
                "The import item is no longer available for account assignment."
            }
        }
    }

    struct ReviewRulePreviewKey: Hashable, Sendable {
        var reviewItemID: UUID
        var createRuleEnabled: Bool
        var merchantPattern: String
        var matchKind: ClassificationRuleMatchKind
    }

    enum ReviewRulePreviewPhase: Equatable, Sendable {
        case loading
        case ready(LearnedRuleImpactPreview)
        case noEligiblePreview
        case unavailable
        case error(String)
    }

    struct ReviewRulePreviewState: Equatable, Sendable {
        var key: ReviewRulePreviewKey
        var phase: ReviewRulePreviewPhase
    }

    struct ReviewRulePreviewScheduleToken {
        private let cancelOperation: @MainActor () -> Void

        init(_ cancelOperation: @escaping @MainActor () -> Void = {}) {
            self.cancelOperation = cancelOperation
        }

        @MainActor
        func cancel() {
            cancelOperation()
        }
    }

    struct ReviewRulePreviewScheduler {
        var schedule: @MainActor (
            _ delay: Duration,
            _ operation: @escaping @MainActor () async -> Void
        ) -> ReviewRulePreviewScheduleToken

        static let live = ReviewRulePreviewScheduler { delay, operation in
            let task = Task { @MainActor in
                do {
                    try await Task.sleep(for: delay)
                } catch {
                    return
                }
                guard Task.isCancelled == false else {
                    return
                }
                await operation()
            }
            return ReviewRulePreviewScheduleToken {
                task.cancel()
            }
        }
    }

    @Published private(set) var state: State = .loading
    @Published private(set) var accountCreationRoute: AccountCreationRoute?
    @Published var isPresentingFileImporter = false
    @Published var fileImportRequest: FileImportRequest?
    @Published var isPresentingTargetSheet = false
    @Published private(set) var batchImportSession: BatchCSVImportSession?
    @Published private(set) var managedTargets: [ManagedMonthlyTarget] = []
    @Published var selectedTargetID: UUID?
    @Published private(set) var settingsDestination: SettingsDestination = .overview
    @Published private(set) var learnedRuleManagerSnapshot: LearnedRuleManagerSnapshot?
    @Published private(set) var reviewCreatedLearnedRuleAction: ReviewCreatedLearnedRuleAction?
    @Published private(set) var pendingAppSectionNavigation: AppSection?
    @Published private(set) var analysisToolbarState = AnalysisToolbarState()
    @Published private(set) var analysisContext = AnalysisContext(
        range: .monthToDate,
        scope: .workspace,
        comparison: .previousPeriod
    )
    @Published private(set) var analysisSnapshot = AnalysisSnapshot.empty
    @Published var analysisErrorMessage: String?
    @Published private(set) var isPresentingAnalysisOverview = false
    @Published private(set) var analysisScreenState = AnalysisScreenState()
    @Published var learnedRuleManagerActionErrorMessage: String?
    @Published var importErrorMessage: String?
    @Published var importResultMessage: String?
    @Published var sampleDataMessage: String?
    @Published var transactionFilter = TransactionLedgerFilter.empty
    @Published var selectedTransactionID: UUID?
    @Published private(set) var selectedTransactionDetail: TransactionDetail?
    @Published var transactionDetailErrorMessage: String?
    @Published var reviewErrorMessage: String?
    @Published private(set) var workspacePreferences = WorkspacePreferences.default
    @Published private(set) var pendingMaintenanceAction: PendingWorkspaceMaintenanceAction?
    @Published private(set) var latestMaintenanceOutcome: WorkspaceMaintenanceOutcome?
    @Published private(set) var latestMaintenanceFailure: WorkspaceMaintenanceFailure?
    @Published private(set) var workspaceStatus: WorkspaceStatus = .loading
    @Published private(set) var reviewRulePreviewState: ReviewRulePreviewState?
    @Published private(set) var learnedRuleDraftPreviewState: ReviewRulePreviewState?
    @Published private(set) var learnedRuleDraftSheet: LearnedRuleDraftSheet?
    @Published private(set) var merchantRecommendationEligibilityByReviewItemID: [UUID: MerchantRecommendationEligibility] = [:]

    private let store: WorkspaceStore?
    private let service: WorkspaceService?
    private let csvImportPreviewService: CSVImportPreviewService
    private let merchantRecommendationEligibilityLoader: @MainActor @Sendable (String) throws -> MerchantRecommendationEligibility?
    private let reviewRulePreviewScheduler: ReviewRulePreviewScheduler
    private let reviewRulePreviewLoader: @MainActor @Sendable (ReviewRulePreviewKey) async throws -> LearnedRuleImpactPreviewState
    private let reviewRulePreviewDebounceDelay: Duration
    private let referenceDateProvider: @Sendable () -> Date
    private var scheduledReviewRulePreview: ReviewRulePreviewScheduleToken?
    private var scheduledLearnedRuleDraftPreview: ReviewRulePreviewScheduleToken?
    private var preservesClearedTransactionSelectionOnNextReload = false

    private static let learnedRuleDraftPreviewItemID = UUID(
        uuidString: "ffffffff-ffff-ffff-ffff-ffffffffffff"
    )!

    init(
        store: WorkspaceStore?,
        service: WorkspaceService?,
        csvImportPreviewService: CSVImportPreviewService = CSVImportPreviewService(),
        merchantRecommendationEligibilityLoader: (@MainActor @Sendable (String) throws -> MerchantRecommendationEligibility?)? = nil,
        reviewRulePreviewScheduler: ReviewRulePreviewScheduler = .live,
        reviewRulePreviewLoader: (@MainActor @Sendable (ReviewRulePreviewKey) async throws -> LearnedRuleImpactPreviewState)? = nil,
        reviewRulePreviewDebounceDelay: Duration = .milliseconds(250),
        referenceDateProvider: @escaping @Sendable () -> Date = Date.init
    ) {
        self.store = store
        self.service = service
        self.csvImportPreviewService = csvImportPreviewService
        self.referenceDateProvider = referenceDateProvider
        self.merchantRecommendationEligibilityLoader = merchantRecommendationEligibilityLoader ?? { [store] normalizedMerchantName in
            guard let store else {
                return nil
            }

            return try store.fetchMerchantRecommendationEligibility(
                normalizedMerchantName: normalizedMerchantName
            )
        }
        self.reviewRulePreviewScheduler = reviewRulePreviewScheduler
        self.reviewRulePreviewDebounceDelay = reviewRulePreviewDebounceDelay
        self.analysisContext = Self.defaultAnalysisContext(referenceDate: referenceDateProvider())
        self.reviewRulePreviewLoader = reviewRulePreviewLoader ?? { [service] key in
            guard let service else {
                return .unavailable
            }

            return try service.previewLearnedRuleImpact(
                reviewItemID: key.reviewItemID,
                createRuleEnabled: key.createRuleEnabled,
                merchantPattern: key.merchantPattern,
                matchKind: key.matchKind
            )
        }
        reload()
    }

    convenience init(services: AppServices) {
        self.init(
            store: services.store,
            service: services.workspaceService,
            csvImportPreviewService: services.csvImportPreviewService
        )
    }

    static func makeDefault(services makeServices: () throws -> AppServices) -> WorkspaceShellModel {
        do {
            return WorkspaceShellModel(services: try makeServices())
        } catch {
            return WorkspaceShellModel(store: nil, service: nil, initialError: error.localizedDescription)
        }
    }

    convenience init(store: WorkspaceStore?, service: WorkspaceService?, initialError: String) {
        self.init(store: store, service: service)
        applyFailedWorkspaceState(message: initialError)
    }

    var snapshot: WorkspaceSnapshot {
        switch state {
        case .loaded(let snapshot):
            snapshot
        case .loading, .failed:
            WorkspaceSnapshot(summary: .empty, accounts: [])
        }
    }

    var workspaceMetadata: WorkspaceMetadata? {
        workspaceStatus.metadata
    }

    var analysisOverviewSelection: AnalysisOverviewSelection? {
        analysisScreenState.overview.selection
    }

    var analysisCategoriesSelection: AnalysisCategoriesSelection? {
        analysisScreenState.categories.selection
    }

    var analysisCategoriesSort: AnalysisScreenState.CategoriesState.Sort {
        analysisScreenState.categories.sort
    }

    var analysisMerchantsSelection: AnalysisMerchantsSelection? {
        analysisScreenState.merchants.selection
    }

    func scheduleReviewRulePreview(
        reviewItemID: UUID,
        createRuleEnabled: Bool,
        merchantPattern: String,
        matchKind: ClassificationRuleMatchKind
    ) {
        let key = ReviewRulePreviewKey(
            reviewItemID: reviewItemID,
            createRuleEnabled: createRuleEnabled,
            merchantPattern: merchantPattern,
            matchKind: matchKind
        )

        if reviewRulePreviewState?.key == key,
           reviewRulePreviewState?.phase == .loading {
            return
        }

        scheduledReviewRulePreview?.cancel()
        scheduledReviewRulePreview = nil

        if createRuleEnabled == false {
            reviewRulePreviewState = ReviewRulePreviewState(key: key, phase: .noEligiblePreview)
            return
        }

        reviewRulePreviewState = ReviewRulePreviewState(key: key, phase: .loading)
        scheduledReviewRulePreview = reviewRulePreviewScheduler.schedule(
            reviewRulePreviewDebounceDelay
        ) { [weak self] in
            await self?.loadReviewRulePreview(for: key)
        }
    }

    func clearReviewRulePreview() {
        scheduledReviewRulePreview?.cancel()
        scheduledReviewRulePreview = nil
        reviewRulePreviewState = nil
    }

    func reload() {
        do {
            try loadWorkspaceState()
        } catch {
            applyFailedWorkspaceState(message: error.localizedDescription)
        }
    }

    func retryFailedWorkspaceRecovery() {
        pendingMaintenanceAction = .retryWorkspaceRecovery
        confirmPendingMaintenanceAction()
    }

    func reviewRulePreviewPhase(
        for key: ReviewRulePreviewKey
    ) -> ReviewRulePreviewPhase {
        guard let reviewRulePreviewState else {
            return key.createRuleEnabled ? .loading : .noEligiblePreview
        }
        guard reviewRulePreviewState.key == key else {
            return key.createRuleEnabled ? .loading : .noEligiblePreview
        }
        return reviewRulePreviewState.phase
    }

    func updateSuggestionsEnabled(_ isEnabled: Bool) {
        guard let service else {
            return
        }

        do {
            let preferences = WorkspacePreferences(
                suggestionsEnabled: isEnabled,
                seededHeuristicAutoAcceptEnabled: workspacePreferences.seededHeuristicAutoAcceptEnabled
            )
            try service.updateWorkspacePreferences(preferences)
            workspacePreferences = preferences
        } catch {
            recordMaintenanceFailure(.preferencesUpdate, error: error)
        }
    }

    func updateSeededHeuristicAutoAcceptEnabled(_ isEnabled: Bool) {
        guard let service else {
            return
        }

        do {
            let preferences = WorkspacePreferences(
                suggestionsEnabled: workspacePreferences.suggestionsEnabled,
                seededHeuristicAutoAcceptEnabled: isEnabled
            )
            try service.updateWorkspacePreferences(preferences)
            workspacePreferences = preferences
        } catch {
            recordMaintenanceFailure(.preferencesUpdate, error: error)
        }
    }

    func createWorkspaceBackup() {
        guard let service else {
            return
        }

        do {
            let backup = try service.createWorkspaceBackup()
            refreshWorkspaceMetadata()
            recordMaintenanceOutcome(.backupCreated(backup))
        } catch {
            recordMaintenanceFailure(.backup, error: error)
        }
    }

    func beginWorkspaceRestore() {
        fileImportRequest = .workspaceRestore
        isPresentingFileImporter = true
    }

    func beginWorkspaceRestoreConfirmation(backupURL: URL) {
        pendingMaintenanceAction = .restoreBackup(backupURL)
    }

    func beginWorkspaceResetConfirmation() {
        pendingMaintenanceAction = .reset
    }

    func cancelPendingMaintenanceAction() {
        pendingMaintenanceAction = nil
    }

    func dismissLatestMaintenanceOutcome() {
        latestMaintenanceOutcome = nil
    }

    func dismissLatestMaintenanceFailure() {
        latestMaintenanceFailure = nil
    }

    func confirmPendingMaintenanceAction() {
        switch pendingMaintenanceAction {
        case .retryWorkspaceRecovery:
            pendingMaintenanceAction = nil
            reload()
        case .restoreBackup(let backupURL):
            restoreWorkspace(backupURL: backupURL)
        case .reset:
            resetWorkspace()
        case nil:
            break
        }
    }

    func recordWorkspaceRestoreSelectionFailure(error: any Error) {
        recordMaintenanceFailure(.restore, error: error)
    }

    func updateTransactionFilter(_ filter: TransactionLedgerFilter) {
        transactionFilter = filter
        reload()
    }

    func showTransactions(filter: TransactionLedgerFilter, clearSelection: Bool = false) {
        if clearSelection {
            preservesClearedTransactionSelectionOnNextReload = true
            selectTransaction(id: nil)
        }
        pendingAppSectionNavigation = .transactions
        updateTransactionFilter(filter)
    }

    func showAnalysisTransactions(filter: TransactionLedgerFilter) {
        showTransactions(filter: filter, clearSelection: false)
    }

    func presentAnalysisOverview() {
        isPresentingAnalysisOverview = true
    }

    func dismissAnalysisOverview() {
        isPresentingAnalysisOverview = false
    }

    func setAnalysisOverviewSelection(_ selection: AnalysisOverviewSelection?) {
        updateAnalysisScreenState {
            $0.setOverviewSelection(selection)
        }
    }

    func setAnalysisCategoriesSelection(_ selection: AnalysisCategoriesSelection?) {
        updateAnalysisScreenState {
            $0.setCategoriesSelection(selection)
        }
    }

    func setAnalysisCategoriesSort(_ sort: AnalysisScreenState.CategoriesState.Sort) {
        updateAnalysisScreenState {
            $0.setCategoriesSort(sort)
        }
    }

    func setAnalysisMerchantsSelection(_ selection: AnalysisMerchantsSelection?) {
        updateAnalysisScreenState {
            $0.setMerchantsSelection(selection)
        }
    }

    func setAnalysisRange(_ range: AnalysisRange) {
        updateAnalysisContext { context in
            context.range = range
            context.resolvedInterval = nil
        }
    }

    func setAnalysisComparison(_ comparison: AnalysisComparisonMode) {
        updateAnalysisContext { context in
            context.comparison = comparison
        }
    }

    func showTarget(id: UUID?) {
        selectedTargetID = id
        pendingAppSectionNavigation = .targets
    }

    func selectAnalysisPage(_ page: AnalysisPage) {
        analysisToolbarState = analysisToolbarState.selecting(page: page)
    }

    func setAnalysisInspectorVisible(_ isVisible: Bool) {
        analysisToolbarState = analysisToolbarState.settingInspectorVisibility(isVisible)
    }

    func toggleAnalysisInspector() {
        analysisToolbarState = analysisToolbarState.togglingInspectorVisibility()
    }

    func showAnalysis(page: AnalysisPage? = nil) {
        if let page {
            selectAnalysisPage(page)
        }
        ensureAnalysisLoaded()
        pendingAppSectionNavigation = .analysis
    }

    func ensureAnalysisLoaded() {
        guard let service else {
            return
        }

        do {
            analysisSnapshot = try service.loadAnalysisSnapshot(context: analysisContext)
            analysisErrorMessage = nil
            repairAnalysisState()
        } catch {
            analysisSnapshot = .empty
            analysisErrorMessage = error.localizedDescription
            repairAnalysisState()
        }
    }

    func matchingTransactions(in rows: [TransactionLedgerRow]) -> [TransactionLedgerRow] {
        guard let ruleFilterIntent = transactionFilter.ruleFilterIntent else {
            return rows
        }

        guard let service else {
            return rows.filter { row in
                ruleFilterIntent.matches(row)
            }
        }

        return service.transactions(matching: ruleFilterIntent, in: rows)
    }

    func selectTransaction(id: UUID?) {
        if id != nil {
            preservesClearedTransactionSelectionOnNextReload = false
        }
        selectedTransactionID = id
        loadSelectedTransactionDetail(id: id)
    }

    private func loadSelectedTransactionDetail(id: UUID?) {
        guard let service, let id else {
            selectedTransactionDetail = nil
            transactionDetailErrorMessage = nil
            return
        }

        do {
            selectedTransactionDetail = try service.loadTransactionDetail(id: id)
            transactionDetailErrorMessage = nil
        } catch {
            selectedTransactionDetail = nil
            transactionDetailErrorMessage = error.localizedDescription
        }
    }

    @discardableResult
    func updateSelectedTransaction(draft: TransactionLedgerEditDraft) -> Bool {
        guard let service, let selectedTransactionID else {
            return false
        }

        do {
            try service.updateTransactionLedgerFields(id: selectedTransactionID, draft: draft)
        } catch {
            transactionDetailErrorMessage = error.localizedDescription
            return false
        }

        do {
            try loadWorkspaceState()
            return true
        } catch {
            applyFailedWorkspaceState(message: error.localizedDescription)
            return false
        }
    }

    @discardableResult
    func setSelectedTransactionHidden(_ isHidden: Bool) -> Bool {
        guard let selectedTransactionID else {
            return false
        }

        return setTransactionHidden(id: selectedTransactionID, isHidden: isHidden)
    }

    @discardableResult
    func setTransactionHidden(id: UUID, isHidden: Bool) -> Bool {
        guard let service else {
            return false
        }

        do {
            try service.setTransactionHidden(id: id, isHidden: isHidden)
        } catch {
            transactionDetailErrorMessage = error.localizedDescription
            return false
        }

        do {
            try loadWorkspaceState()
            transactionDetailErrorMessage = nil
            return true
        } catch {
            applyFailedWorkspaceState(message: error.localizedDescription)
            return false
        }
    }

    func beginTargetCreation() {
        isPresentingTargetSheet = true
    }

    func selectTarget(id: UUID?) {
        selectedTargetID = id
    }

    func directSettingsSidebarEntry() {
        settingsDestination = .overview
    }

    func directRulesSidebarEntry() {
        settingsDestination = .learnedRulesRoute()
    }

    func prepareForSidebarSelection(_ section: AppSection) {
        switch section {
        case .settings:
            directSettingsSidebarEntry()
        case .rules:
            directRulesSidebarEntry()
        case .analysis:
            ensureAnalysisLoaded()
        case .home, .transactions, .review, .targets, .accounts:
            break
        }
    }

    func showRulesDestination(_ destination: SettingsDestination) {
        settingsDestination = destination
        pendingAppSectionNavigation = .rules
    }

    func showLearnedRules(selection: LearnedRulesDestination.Selection? = nil) {
        settingsDestination = SettingsDestination.learnedRulesRoute(selection: selection)
        pendingAppSectionNavigation = .rules
    }

    func showLearnedRules(selectedLearnedRuleID: UUID?) {
        showLearnedRules(selection: selectedLearnedRuleID.map { .learnedRule($0) })
    }

    func consumePendingAppSectionNavigation() {
        pendingAppSectionNavigation = nil
    }

    func beginNewLearnedRule() {
        learnedRuleDraftSheet = .newRule()
        clearLearnedRuleDraftPreview()
        learnedRuleManagerActionErrorMessage = nil
    }

    @discardableResult
    func beginDuplicateLearnedRule(id: UUID) -> Bool {
        guard let service else {
            learnedRuleManagerActionErrorMessage = WorkspaceServiceError.learnedRuleManagementUnavailable.localizedDescription
            return false
        }

        do {
            guard let draft = try service.duplicateLearnedRuleAsDraft(id: id) else {
                learnedRuleManagerActionErrorMessage = "The selected learned rule is no longer available."
                return false
            }
            learnedRuleDraftSheet = .duplicateRule(sourceRuleID: id, draft: draft)
            updateLearnedRuleDraftPreview(for: draft)
            learnedRuleManagerActionErrorMessage = nil
            return true
        } catch {
            learnedRuleManagerActionErrorMessage = error.localizedDescription
            return false
        }
    }

    func updateLearnedRuleDraft(_ draft: LearnedRuleDraft) {
        guard var learnedRuleDraftSheet else {
            return
        }
        learnedRuleDraftSheet.draft = draft
        self.learnedRuleDraftSheet = learnedRuleDraftSheet
        updateLearnedRuleDraftPreview(for: draft)
    }

    func dismissLearnedRuleDraftSheet() {
        learnedRuleDraftSheet = nil
        clearLearnedRuleDraftPreview()
    }

    @discardableResult
    func saveLearnedRuleDraft() -> Bool {
        guard let service else {
            learnedRuleManagerActionErrorMessage = WorkspaceServiceError.learnedRuleManagementUnavailable.localizedDescription
            return false
        }
        guard let learnedRuleDraftSheet else {
            return false
        }
        guard learnedRuleDraftSheet.canSave else {
            learnedRuleManagerActionErrorMessage = LearnedRuleDraftSheet.unsupportedMatchKindMessage
            return false
        }

        do {
            let createdRule = try service.createLearnedRule(learnedRuleDraftSheet.draft)
            reload()
            settingsDestination = .learnedRulesRoute(selection: .learnedRule(createdRule.id))
            self.learnedRuleDraftSheet = nil
            clearLearnedRuleDraftPreview()
            learnedRuleManagerActionErrorMessage = nil
            return true
        } catch {
            learnedRuleManagerActionErrorMessage = error.localizedDescription
            return false
        }
    }

    @discardableResult
    func disableLearnedRule(id: UUID) -> Bool {
        guard let service else {
            return false
        }

        do {
            _ = try service.disableLearnedRule(id: id)
            reload()
            learnedRuleManagerActionErrorMessage = nil
            return true
        } catch {
            learnedRuleManagerActionErrorMessage = error.localizedDescription
            return false
        }
    }

    @discardableResult
    func enableLearnedRule(id: UUID) -> Bool {
        guard let service else {
            return false
        }

        do {
            _ = try service.enableLearnedRule(id: id)
            reload()
            learnedRuleManagerActionErrorMessage = nil
            return true
        } catch {
            learnedRuleManagerActionErrorMessage = error.localizedDescription
            return false
        }
    }

    @discardableResult
    func createMonthlyTarget(_ draft: MonthlyTargetDraft) throws -> UUID {
        guard let service else {
            throw WorkspaceServiceError.targetManagementUnavailable
        }

        let target = try service.createMonthlyTarget(draft)
        reload()
        selectedTargetID = target.id
        isPresentingTargetSheet = false
        return target.id
    }

    func updateMonthlyTarget(id: UUID, draft: MonthlyTargetDraft) throws {
        guard let service else {
            throw WorkspaceServiceError.targetManagementUnavailable
        }

        _ = try service.updateMonthlyTarget(id: id, draft)
        reload()
        selectedTargetID = id
    }

    func deleteMonthlyTarget(id: UUID) throws {
        guard let service else {
            throw WorkspaceServiceError.targetManagementUnavailable
        }

        let fallbackSelection = ManagedTargetSelection.nextTargetID(
            afterDeleting: id,
            currentSelection: selectedTargetID,
            availableTargets: managedTargets
        )
        try service.deleteMonthlyTarget(id: id)
        reload()
        selectedTargetID = fallbackSelection
    }

    @discardableResult
    func keepBothLikelyDuplicateReviewItem(id: UUID) -> Bool {
        guard let service else {
            return false
        }

        do {
            try service.keepBothLikelyDuplicateReviewItem(id: id)
            reload()
            reviewCreatedLearnedRuleAction = nil
            return true
        } catch {
            reviewErrorMessage = error.localizedDescription
            return false
        }
    }

    @discardableResult
    func approveClassificationReviewItem(
        id: UUID,
        assignment: ClassificationAssignment,
        ruleLearning: ReviewRuleLearningOption?
    ) -> Bool {
        guard let service else {
            return false
        }

        do {
            let result = try service.approveClassificationReviewItem(
                id: id,
                assignment: assignment,
                ruleLearning: ruleLearning
            )
            reload()
            reviewCreatedLearnedRuleAction = result.createdLearnedRuleAction
            return true
        } catch {
            reviewErrorMessage = error.localizedDescription
            return false
        }
    }

    func addSampleAccount() {
        guard let service else {
            return
        }

        do {
            let didAddSampleData = try service.seedSampleDataIfNeeded()
            reload()
            sampleDataMessage = didAddSampleData
                ? "Sample accounts were added."
                : "Sample data was skipped because this workspace already has accounts."
        } catch {
            applyFailedWorkspaceState(message: error.localizedDescription)
        }
    }

    func beginAccountCreation() {
        accountCreationRoute = .general
    }

    func beginBatchImportAccountCreation(itemID: UUID) {
        guard let batchImportSession, batchImportSession.containsItem(id: itemID) else {
            return
        }

        accountCreationRoute = .batchImport(itemID: itemID)
    }

    func cancelAccountCreation() {
        accountCreationRoute = nil
    }

    func presentBatchImportSession(_ session: BatchCSVImportSession) {
        batchImportSession = session
        if case .batchImport = accountCreationRoute {
            accountCreationRoute = nil
        }
    }

    func dismissBatchImportSession() {
        batchImportSession = nil
        if case .batchImport = accountCreationRoute {
            accountCreationRoute = nil
        }
    }

    func selectBatchImportItem(id: UUID?) {
        batchImportSession?.selectItem(id: id)
    }

    func selectBatchImportAccount(id accountID: UUID?, forItemID itemID: UUID) {
        _ = batchImportSession?.setSelectedAccount(id: accountID, forItemID: itemID)
    }

    func updateBatchImportMapping(_ mapping: CSVColumnMapping, forItemID itemID: UUID) {
        _ = batchImportSession?.updateMapping(mapping, forItemID: itemID)
    }

    func removeBatchImportItem(id itemID: UUID) {
        guard batchImportSession?.removeItem(id: itemID) == true else {
            return
        }

        if batchImportSession?.draft.items.isEmpty == true {
            dismissBatchImportSession()
        }
    }

    @discardableResult
    func createAccount(name: String, kind: AccountKind, institutionName: String?) throws -> Account {
        guard let service else {
            throw WorkspaceServiceError.accountManagementUnavailable
        }

        if case .batchImport(let itemID) = accountCreationRoute {
            guard let batchImportSession, batchImportSession.containsItem(id: itemID) else {
                throw AccountCreationRouteError.missingBatchImportContext
            }
        }

        let account = try service.createAccount(
            named: name,
            kind: kind,
            institutionName: institutionName
        )
        if case .batchImport(let itemID) = accountCreationRoute {
            _ = batchImportSession?.selectAccount(id: account.id, forItemID: itemID)
        }
        accountCreationRoute = nil
        reload()
        return account
    }

    func updateAccount(id: UUID, name: String, kind: AccountKind, institutionName: String?) throws {
        guard let service else {
            throw WorkspaceServiceError.accountManagementUnavailable
        }

        _ = try service.updateAccount(
            id: id,
            named: name,
            kind: kind,
            institutionName: institutionName
        )
        reload()
    }

    func archiveAccount(id: UUID) throws {
        guard let service else {
            throw WorkspaceServiceError.accountManagementUnavailable
        }

        _ = try service.archiveAccount(id: id)
        reload()
    }

    func restoreAccount(id: UUID) throws {
        guard let service else {
            throw WorkspaceServiceError.accountManagementUnavailable
        }

        _ = try service.restoreAccount(id: id)
        reload()
    }

    func deleteAccountPermanently(id: UUID) throws {
        guard let service else {
            throw WorkspaceServiceError.accountManagementUnavailable
        }

        try service.deleteAccountPermanently(id: id)
        reload()
    }

    func beginCSVImport() {
        fileImportRequest = .csv
        isPresentingFileImporter = true
    }

    func importCSV(from result: Result<[URL], Error>) {
        do {
            let urls = try result.get()
            guard urls.isEmpty == false else {
                throw CocoaError(.fileNoSuchFile)
            }

            let session = BatchCSVImportSession(
                selectedURLs: urls,
                importEligibleAccounts: snapshot.importEligibleAccounts,
                previewService: csvImportPreviewService
            )
            presentBatchImportSession(session)
        } catch {
            dismissBatchImportSession()
            importErrorMessage = error.localizedDescription
        }
    }

    func confirmBatchCSVImport() {
        guard let batchImportSession, let service else {
            return
        }
        guard batchImportSession.importPhase.isExecuting == false else {
            return
        }
        guard batchImportSession.draft.isReadyForImport else {
            return
        }

        importErrorMessage = nil
        importResultMessage = nil
        batchImportSession.setImportPhase(.staging)
        let accounts = snapshot.accounts

        Task { @MainActor [weak self] in
            await Task.yield()
            guard let self, self.batchImportSession === batchImportSession else {
                return
            }

            let result = await batchImportSession.confirmBatchCSVImport(
                service: service,
                accounts: accounts
            )
            guard self.batchImportSession === batchImportSession else {
                return
            }

            switch result {
            case .success(let summary, let outcome):
                dismissBatchImportSession()
                reload()
                importResultMessage = ImportResultMessage.make(for: outcome, summary: summary)
            case .partialFailure(let failure):
                if failure.outcome == .staged {
                    reload()
                }
                importErrorMessage = batchImportFailureMessage(for: failure)
            }
        }
    }

    private func batchImportFailureMessage(
        for failure: BatchCSVImportFailureContext
    ) -> String {
        let prefix = "Import failed on \(failure.failedFilename)."
        guard failure.stagedFileCount > 0 else {
            return "\(prefix) No files were staged before the failure. \(failure.errorDescription)"
        }

        let stagedContext: String
        if failure.stagedFileCount == 1 {
            stagedContext = "1 file was staged before the failure."
        } else {
            stagedContext = "\(failure.stagedFileCount) files were staged before the failure."
        }

        return "\(prefix) \(stagedContext) Earlier staged files remain available. \(failure.errorDescription)"
    }

    private func resetWorkspace() {
        guard let service else {
            pendingMaintenanceAction = nil
            return
        }

        do {
            let result = try service.resetWorkspace()
            try loadWorkspaceState()
            recordMaintenanceOutcome(.reset(result))
        } catch {
            recordMaintenanceFailure(.reset, error: error)
        }
    }

    private func restoreWorkspace(backupURL: URL) {
        guard let service else {
            pendingMaintenanceAction = nil
            return
        }

        do {
            let didAccessScopedResource = backupURL.startAccessingSecurityScopedResource()
            defer {
                if didAccessScopedResource {
                    backupURL.stopAccessingSecurityScopedResource()
                }
            }

            let restoreResult = try service.restoreWorkspaceBackup(from: backupURL)
            try loadWorkspaceState()
            recordMaintenanceOutcome(.restored(restoreResult))
        } catch {
            recordMaintenanceFailure(.restore, error: error)
        }
    }

    private func loadWorkspaceState() throws {
        guard let service else {
            return
        }

        let referenceDate = referenceDateProvider()
        let snapshot = try service.loadSnapshot(
            filter: transactionFilter,
            referenceDate: referenceDate
        )
        let managedTargets = try service.fetchManagedTargets(referenceDate: referenceDate)
        let metadata = try? service.loadWorkspaceMetadata()
        let preferences = (try? service.loadWorkspacePreferences()) ?? .default
        let learnedRuleManagerSnapshot = try? service.loadLearnedRuleManagerSnapshot()
        let merchantRecommendationEligibilityByReviewItemID = loadMerchantRecommendationEligibility(
            for: snapshot.pendingReviewItems
        )

        state = .loaded(snapshot)
        self.managedTargets = managedTargets
        workspaceStatus = .available(metadata)
        workspacePreferences = preferences
        self.learnedRuleManagerSnapshot = learnedRuleManagerSnapshot
        self.merchantRecommendationEligibilityByReviewItemID = merchantRecommendationEligibilityByReviewItemID
        analysisContext.referenceDate = referenceDate

        if analysisSnapshot != .empty {
            do {
                analysisSnapshot = try service.loadAnalysisSnapshot(context: analysisContext)
                analysisErrorMessage = nil
            } catch {
                analysisSnapshot = .empty
                analysisErrorMessage = error.localizedDescription
            }
        }
        repairAnalysisState()

        if let selectedTargetID, managedTargets.contains(where: { $0.id == selectedTargetID }) == false {
            self.selectedTargetID = nil
        }
        let visibleTransactions = matchingTransactions(in: snapshot.transactions)
        let transactionID: UUID?
        if preservesClearedTransactionSelectionOnNextReload {
            transactionID = nil
            preservesClearedTransactionSelectionOnNextReload = false
        } else {
            transactionID = TransactionLedgerSelectionState.selectionAfterReload(
                currentSelectionID: selectedTransactionID,
                visibleRows: visibleTransactions
            )
        }
        selectedTransactionID = transactionID
        loadSelectedTransactionDetail(id: transactionID)

        if let previewState = reviewRulePreviewState,
           snapshot.pendingReviewItems.contains(where: { $0.id == previewState.key.reviewItemID }) == false {
            clearReviewRulePreview()
        }
    }

    private func applyFailedWorkspaceState(message: String) {
        clearReviewRulePreview()
        managedTargets = []
        selectedTargetID = nil
        selectedTransactionID = nil
        selectedTransactionDetail = nil
        transactionDetailErrorMessage = nil
        learnedRuleManagerSnapshot = nil
        reviewCreatedLearnedRuleAction = nil
        pendingAppSectionNavigation = nil
        analysisToolbarState = AnalysisToolbarState()
        analysisContext = Self.defaultAnalysisContext(referenceDate: referenceDateProvider())
        analysisSnapshot = .empty
        analysisErrorMessage = nil
        isPresentingAnalysisOverview = false
        analysisScreenState = AnalysisScreenState()
        merchantRecommendationEligibilityByReviewItemID = [:]
        state = .failed(message)
        workspaceStatus = .failedToOpen(message)
    }

    private func repairAnalysisState() {
        analysisToolbarState = analysisToolbarState.repaired(for: analysisSnapshot)
        updateAnalysisScreenState {
            $0.repairSelections(for: analysisSnapshot)
        }

        if analysisSnapshot.overview == nil {
            isPresentingAnalysisOverview = false
        }
    }

    private func updateAnalysisScreenState(
        _ update: (inout AnalysisScreenState) -> Void
    ) {
        var nextState = analysisScreenState
        update(&nextState)
        analysisScreenState = nextState
    }

    private func updateAnalysisContext(
        _ update: (inout AnalysisContext) -> Void
    ) {
        var nextContext = analysisContext
        update(&nextContext)

        guard nextContext != analysisContext else {
            return
        }

        analysisContext = nextContext
        reloadAnalysisSnapshotIfNeeded()
    }

    private func reloadAnalysisSnapshotIfNeeded() {
        guard analysisSnapshot != .empty || analysisErrorMessage != nil else {
            return
        }

        ensureAnalysisLoaded()
    }

    private func loadMerchantRecommendationEligibility(
        for items: [PendingReviewItem]
    ) -> [UUID: MerchantRecommendationEligibility] {
        let eligibleItemsByMerchant = Dictionary(grouping: items.compactMap { item -> (String, UUID)? in
            guard item.classification?.source != .curatedPrefill else {
                return nil
            }
            guard let normalizedMerchantName = item.classification?.normalizedMerchantName
                .trimmingCharacters(in: .whitespacesAndNewlines),
                  normalizedMerchantName.isEmpty == false else {
                return nil
            }
            return (normalizedMerchantName, item.id)
        }, by: \.0)

        var eligibilityByReviewItemID: [UUID: MerchantRecommendationEligibility] = [:]
        for (normalizedMerchantName, itemPairs) in eligibleItemsByMerchant {
            guard let eligibility = try? merchantRecommendationEligibilityLoader(normalizedMerchantName) else {
                continue
            }
            for (_, itemID) in itemPairs {
                eligibilityByReviewItemID[itemID] = eligibility
            }
        }
        return eligibilityByReviewItemID
    }

    private func refreshWorkspaceMetadata() {
        guard case .available = workspaceStatus, let service else {
            return
        }

        workspaceStatus = .available(try? service.loadWorkspaceMetadata())
    }

    private func recordMaintenanceOutcome(_ outcome: WorkspaceMaintenanceOutcome) {
        pendingMaintenanceAction = nil
        latestMaintenanceFailure = nil
        latestMaintenanceOutcome = outcome
    }

    private func recordMaintenanceFailure(
        _ operation: WorkspaceMaintenanceFailure.Operation,
        error: any Error
    ) {
        pendingMaintenanceAction = nil
        latestMaintenanceOutcome = nil
        latestMaintenanceFailure = WorkspaceMaintenanceFailure(
            operation: operation,
            message: error.localizedDescription
        )
    }

    private func loadReviewRulePreview(for key: ReviewRulePreviewKey) async {
        do {
            let preview = try await reviewRulePreviewLoader(key)
            guard reviewRulePreviewState?.key == key else {
                return
            }

            let phase: ReviewRulePreviewPhase
            switch preview {
            case .ready(let impact):
                phase = .ready(impact)
            case .noEligiblePreview:
                phase = .noEligiblePreview
            case .unavailable:
                phase = .unavailable
            }

            reviewRulePreviewState = ReviewRulePreviewState(key: key, phase: phase)
        } catch {
            guard reviewRulePreviewState?.key == key else {
                return
            }
            reviewRulePreviewState = ReviewRulePreviewState(
                key: key,
                phase: .error(error.localizedDescription)
            )
        }
    }

    private func updateLearnedRuleDraftPreview(for draft: LearnedRuleDraft) {
        guard draft.matchKind == .contains else {
            scheduledLearnedRuleDraftPreview?.cancel()
            scheduledLearnedRuleDraftPreview = nil
            learnedRuleDraftPreviewState = nil
            return
        }

        let key = ReviewRulePreviewKey(
            reviewItemID: Self.learnedRuleDraftPreviewItemID,
            createRuleEnabled: true,
            merchantPattern: draft.merchantPattern,
            matchKind: draft.matchKind
        )

        if learnedRuleDraftPreviewState?.key == key {
            return
        }

        scheduledLearnedRuleDraftPreview?.cancel()
        scheduledLearnedRuleDraftPreview = nil

        learnedRuleDraftPreviewState = ReviewRulePreviewState(key: key, phase: .loading)
        scheduledLearnedRuleDraftPreview = reviewRulePreviewScheduler.schedule(
            reviewRulePreviewDebounceDelay
        ) { [weak self] in
            await self?.loadLearnedRuleDraftPreview(for: key)
        }
    }

    private func clearLearnedRuleDraftPreview() {
        scheduledLearnedRuleDraftPreview?.cancel()
        scheduledLearnedRuleDraftPreview = nil
        learnedRuleDraftPreviewState = nil
    }

    private func loadLearnedRuleDraftPreview(for key: ReviewRulePreviewKey) async {
        do {
            let preview = try await reviewRulePreviewLoader(key)
            guard learnedRuleDraftPreviewState?.key == key else {
                return
            }

            let phase: ReviewRulePreviewPhase
            switch preview {
            case .ready(let impact):
                phase = .ready(impact)
            case .noEligiblePreview:
                phase = .noEligiblePreview
            case .unavailable:
                phase = .unavailable
            }

            learnedRuleDraftPreviewState = ReviewRulePreviewState(key: key, phase: phase)
        } catch {
            guard learnedRuleDraftPreviewState?.key == key else {
                return
            }
            learnedRuleDraftPreviewState = ReviewRulePreviewState(
                key: key,
                phase: .error(error.localizedDescription)
            )
        }
    }
}

private extension WorkspaceShellModel {
    static func defaultAnalysisContext(referenceDate: Date) -> AnalysisContext {
        AnalysisContext(
            range: .monthToDate,
            referenceDate: referenceDate,
            scope: .workspace,
            comparison: .previousPeriod
        )
    }
}
