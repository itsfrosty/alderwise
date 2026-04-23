import Application
import Domain
import Persistence
import SwiftUI

@MainActor
final class WorkspaceShellModel: ObservableObject {
    struct PendingCSVImport {
        var originalFilename: String
        var csvText: String
    }

    enum State {
        case loading
        case loaded(WorkspaceSnapshot)
        case failed(String)
    }

    enum FileImportRequest {
        case csv
        case workspaceRestore
    }

    struct ReviewRulePreviewKey: Hashable, Sendable {
        var reviewItemID: UUID
        var createRuleEnabled: Bool
        var merchantName: String
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
    @Published var isPresentingAccountSheet = false
    @Published var isPresentingFileImporter = false
    @Published var fileImportRequest: FileImportRequest?
    @Published var isPresentingImportPreview = false
    @Published var isPresentingTargetSheet = false
    @Published private(set) var managedTargets: [ManagedMonthlyTarget] = []
    @Published var selectedTargetID: UUID?
    @Published private(set) var settingsDestination: SettingsDestination = .overview
    @Published private(set) var learnedRuleManagerSnapshot: LearnedRuleManagerSnapshot?
    @Published private(set) var reviewCreatedLearnedRuleAction: ReviewCreatedLearnedRuleAction?
    @Published private(set) var pendingAppSectionNavigation: AppSection?
    @Published var learnedRuleManagerActionErrorMessage: String?
    @Published private(set) var csvImportPreview: CSVImportPreview?
    @Published private(set) var pendingCSVImport: PendingCSVImport?
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

    private let store: WorkspaceStore?
    private let service: WorkspaceService?
    private let csvImportPreviewService: CSVImportPreviewService
    private let reviewRulePreviewScheduler: ReviewRulePreviewScheduler
    private let reviewRulePreviewLoader: @MainActor @Sendable (ReviewRulePreviewKey) async throws -> LearnedRuleImpactPreviewState
    private let reviewRulePreviewDebounceDelay: Duration
    private var scheduledReviewRulePreview: ReviewRulePreviewScheduleToken?
    private var scheduledLearnedRuleDraftPreview: ReviewRulePreviewScheduleToken?

    private static let learnedRuleDraftPreviewItemID = UUID(
        uuidString: "ffffffff-ffff-ffff-ffff-ffffffffffff"
    )!

    init(
        store: WorkspaceStore?,
        service: WorkspaceService?,
        csvImportPreviewService: CSVImportPreviewService = CSVImportPreviewService(),
        reviewRulePreviewScheduler: ReviewRulePreviewScheduler = .live,
        reviewRulePreviewLoader: (@MainActor @Sendable (ReviewRulePreviewKey) async throws -> LearnedRuleImpactPreviewState)? = nil,
        reviewRulePreviewDebounceDelay: Duration = .milliseconds(250)
    ) {
        self.store = store
        self.service = service
        self.csvImportPreviewService = csvImportPreviewService
        self.reviewRulePreviewScheduler = reviewRulePreviewScheduler
        self.reviewRulePreviewDebounceDelay = reviewRulePreviewDebounceDelay
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

    func scheduleReviewRulePreview(
        reviewItemID: UUID,
        createRuleEnabled: Bool,
        merchantName: String,
        merchantPattern: String,
        matchKind: ClassificationRuleMatchKind
    ) {
        let key = ReviewRulePreviewKey(
            reviewItemID: reviewItemID,
            createRuleEnabled: createRuleEnabled,
            merchantName: merchantName,
            merchantPattern: merchantPattern,
            matchKind: matchKind
        )

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

    func selectTransaction(id: UUID?) {
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

    func beginTargetCreation() {
        isPresentingTargetSheet = true
    }

    func selectTarget(id: UUID?) {
        selectedTargetID = id
    }

    func selectSettingsDestination(_ destination: SettingsDestination) {
        settingsDestination = destination
    }

    func showLearnedRules(selection: LearnedRulesDestination.Selection? = nil) {
        settingsDestination = SettingsDestination.learnedRulesRoute(selection: selection)
        pendingAppSectionNavigation = .settings
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
        isPresentingAccountSheet = true
    }

    @discardableResult
    func createAccount(name: String, kind: AccountKind, institutionName: String?) throws -> Account {
        guard let service else {
            throw WorkspaceServiceError.accountManagementUnavailable
        }

        let account = try service.createAccount(
            named: name,
            kind: kind,
            institutionName: institutionName
        )
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

    func importCSV(from result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let didAccessScopedResource = url.startAccessingSecurityScopedResource()
            defer {
                if didAccessScopedResource {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            let csvText = try String(contentsOf: url, encoding: .utf8)
            csvImportPreview = try csvImportPreviewService.makePreview(from: csvText)
            pendingCSVImport = PendingCSVImport(
                originalFilename: url.lastPathComponent,
                csvText: csvText
            )
            isPresentingImportPreview = true
        } catch {
            importErrorMessage = error.localizedDescription
        }
    }

    func confirmCSVImport(preview: CSVImportPreview, account: Account) {
        guard let service, let pendingCSVImport else {
            return
        }

        do {
            let result = try service.stageCSVImport(
                preview: preview,
                account: account,
                originalFilename: pendingCSVImport.originalFilename,
                csvText: pendingCSVImport.csvText
            )
            dismissCSVImportPreview()
            reload()
            importResultMessage = ImportResultMessage.make(for: result.outcome, summary: result.summary)
        } catch {
            dismissCSVImportPreview()
            importErrorMessage = error.localizedDescription
        }
    }

    func dismissCSVImportPreview() {
        isPresentingImportPreview = false
        csvImportPreview = nil
        pendingCSVImport = nil
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

        let snapshot = try service.loadSnapshot(filter: transactionFilter)
        let managedTargets = try service.fetchManagedTargets(referenceDate: snapshot.monthlyReport.monthStart)
        let metadata = try? service.loadWorkspaceMetadata()
        let preferences = (try? service.loadWorkspacePreferences()) ?? .default
        let learnedRuleManagerSnapshot = try? service.loadLearnedRuleManagerSnapshot()

        state = .loaded(snapshot)
        self.managedTargets = managedTargets
        workspaceStatus = .available(metadata)
        workspacePreferences = preferences
        self.learnedRuleManagerSnapshot = learnedRuleManagerSnapshot

        if let selectedTargetID, managedTargets.contains(where: { $0.id == selectedTargetID }) == false {
            self.selectedTargetID = nil
        }
        let transactionID = if let selectedTransactionID,
                               snapshot.transactions.contains(where: { $0.id == selectedTransactionID }) {
            selectedTransactionID
        } else {
            snapshot.transactions.first?.id
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
        state = .failed(message)
        workspaceStatus = .failedToOpen(message)
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
            merchantName: "",
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
