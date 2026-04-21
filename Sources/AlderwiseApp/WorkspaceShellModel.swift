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
    @Published private(set) var csvImportPreview: CSVImportPreview?
    @Published private(set) var pendingCSVImport: PendingCSVImport?
    @Published var importErrorMessage: String?
    @Published var importResultMessage: String?
    @Published var transactionFilter = TransactionLedgerFilter.empty
    @Published var selectedTransactionID: UUID?
    @Published private(set) var selectedTransactionDetail: TransactionDetail?
    @Published var transactionDetailErrorMessage: String?
    @Published var reviewErrorMessage: String?
    @Published private(set) var workspaceMetadata: WorkspaceMetadata?
    @Published private(set) var workspacePreferences = WorkspacePreferences.default
    @Published var workspaceMaintenanceMessage: String?
    @Published var workspaceMaintenanceErrorMessage: String?

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
        state = .failed(initialError)
    }

    var snapshot: WorkspaceSnapshot {
        switch state {
        case .loaded(let snapshot):
            snapshot
        case .loading, .failed:
            WorkspaceSnapshot(summary: .empty, accounts: [])
        }
    }

    func reload() {
        guard let service else {
            return
        }

        do {
            let snapshot = try service.loadSnapshot(filter: transactionFilter)
            state = .loaded(snapshot)
            workspaceMetadata = try? service.loadWorkspaceMetadata()
            workspacePreferences = (try? service.loadWorkspacePreferences()) ?? .default
            let transactionID = if let selectedTransactionID,
                                   snapshot.transactions.contains(where: { $0.id == selectedTransactionID }) {
                selectedTransactionID
            } else {
                snapshot.transactions.first?.id
            }
            selectedTransactionID = transactionID
            loadSelectedTransactionDetail(id: transactionID)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func updateSuggestionsEnabled(_ isEnabled: Bool) {
        guard let service else {
            return
        }

        do {
            let preferences = WorkspacePreferences(suggestionsEnabled: isEnabled)
            try service.updateWorkspacePreferences(preferences)
            workspacePreferences = preferences
        } catch {
            workspaceMaintenanceErrorMessage = error.localizedDescription
        }
    }

    func createWorkspaceBackup() {
        guard let service else {
            return
        }

        do {
            let backup = try service.createWorkspaceBackup()
            workspaceMaintenanceMessage = "Backup created at \(backup.fileURL.path)"
            workspaceMetadata = try? service.loadWorkspaceMetadata()
        } catch {
            workspaceMaintenanceErrorMessage = error.localizedDescription
        }
    }

    func beginWorkspaceRestore() {
        fileImportRequest = .workspaceRestore
        isPresentingFileImporter = true
    }

    func restoreWorkspace(from result: Result<URL, Error>) {
        guard let service else {
            return
        }

        do {
            let url = try result.get()
            let didAccessScopedResource = url.startAccessingSecurityScopedResource()
            defer {
                if didAccessScopedResource {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            let restoreResult = try service.restoreWorkspaceBackup(from: url)
            reload()
            if let safetyBackup = restoreResult.safetyBackup {
                workspaceMaintenanceMessage = "Workspace restored. Safety backup saved at \(safetyBackup.fileURL.path)"
            } else {
                workspaceMaintenanceMessage = "Workspace restored."
            }
        } catch {
            workspaceMaintenanceErrorMessage = error.localizedDescription
        }
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
            state = .failed(error.localizedDescription)
        }
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
        createRule: Bool
    ) -> Bool {
        guard let service else {
            return false
        }

        do {
            try service.approveClassificationReviewItem(
                id: id,
                assignment: assignment,
                createRule: createRule
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
            try service.seedSampleDataIfNeeded()
            reload()
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func createAccount(name: String, kind: AccountKind, institutionName: String?) {
        guard let service else {
            return
        }

        do {
            _ = try service.createAccount(
                named: name,
                kind: kind,
                institutionName: institutionName
            )
            reload()
        } catch {
            state = .failed(error.localizedDescription)
        }
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
            switch result.outcome {
            case .staged:
                importResultMessage = "\(result.summary.importedRowCount) rows staged. \(result.summary.flaggedDuplicateRowCount) likely duplicates flagged."
            case .exactReimportNoOp:
                importResultMessage = "\(result.summary.skippedRowCount) rows already imported. No changes made."
            }
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
}
