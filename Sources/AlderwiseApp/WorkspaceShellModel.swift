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

    @Published private(set) var state: State = .loading
    @Published var isPresentingAccountSheet = false
    @Published var isPresentingFileImporter = false
    @Published var fileImportRequest: FileImportRequest?
    @Published var isPresentingImportPreview = false
    @Published var isPresentingTargetSheet = false
    @Published private(set) var managedTargets: [ManagedMonthlyTarget] = []
    @Published var selectedTargetID: UUID?
    @Published private(set) var settingsDestination: SettingsDestination = .overview
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

    private let store: WorkspaceStore?
    private let service: WorkspaceService?
    private let csvImportPreviewService: CSVImportPreviewService

    init(
        store: WorkspaceStore?,
        service: WorkspaceService?,
        csvImportPreviewService: CSVImportPreviewService = CSVImportPreviewService()
    ) {
        self.store = store
        self.service = service
        self.csvImportPreviewService = csvImportPreviewService
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

    func updateSelectedTransaction(draft: TransactionLedgerEditDraft) {
        guard let service, let selectedTransactionID else {
            return
        }

        do {
            try service.updateTransactionLedgerFields(id: selectedTransactionID, draft: draft)
            reload()
        } catch {
            applyFailedWorkspaceState(message: error.localizedDescription)
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

    func showLearnedRules(selectedLearnedRuleID: UUID? = nil) {
        settingsDestination = .learnedRules(
            LearnedRulesDestination(
                mode: .learned,
                selectedLearnedRuleID: selectedLearnedRuleID
            )
        )
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
            try service.approveClassificationReviewItem(
                id: id,
                assignment: assignment,
                ruleLearning: ruleLearning
            )
            reload()
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

        state = .loaded(snapshot)
        self.managedTargets = managedTargets
        workspaceStatus = .available(metadata)
        workspacePreferences = preferences

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
    }

    private func applyFailedWorkspaceState(message: String) {
        managedTargets = []
        selectedTargetID = nil
        selectedTransactionID = nil
        selectedTransactionDetail = nil
        transactionDetailErrorMessage = nil
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
}
