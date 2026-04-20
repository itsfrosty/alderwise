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

    @Published private(set) var state: State = .loading
    @Published var isPresentingAccountSheet = false
    @Published var isPresentingCSVImporter = false
    @Published var isPresentingImportPreview = false
    @Published private(set) var csvImportPreview: CSVImportPreview?
    @Published private(set) var pendingCSVImport: PendingCSVImport?
    @Published var importErrorMessage: String?
    @Published var importResultMessage: String?
    @Published var transactionFilter = TransactionLedgerFilter.empty
    @Published var selectedTransactionID: UUID?
    @Published private(set) var selectedTransactionDetail: TransactionDetail?

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

    static func makeDefault() -> WorkspaceShellModel {
        do {
            let store = try WorkspaceStore.live()
            try store.bootstrap()
            let service = WorkspaceService(store: store)
            return WorkspaceShellModel(store: store, service: service)
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
            if let selectedTransactionID,
               snapshot.transactions.contains(where: { $0.id == selectedTransactionID }) {
                selectedTransactionDetail = try service.loadTransactionDetail(id: selectedTransactionID)
            } else {
                selectedTransactionID = snapshot.transactions.first?.id
                selectedTransactionDetail = try selectedTransactionID.flatMap { try service.loadTransactionDetail(id: $0) }
            }
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func updateTransactionFilter(_ filter: TransactionLedgerFilter) {
        transactionFilter = filter
        reload()
    }

    func selectTransaction(id: UUID?) {
        selectedTransactionID = id
        guard let service, let id else {
            selectedTransactionDetail = nil
            return
        }

        do {
            selectedTransactionDetail = try service.loadTransactionDetail(id: id)
        } catch {
            state = .failed(error.localizedDescription)
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
        isPresentingCSVImporter = true
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
