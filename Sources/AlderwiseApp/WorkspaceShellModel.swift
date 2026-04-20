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

    @Published private(set) var state: State = .loading
    @Published var isPresentingAccountSheet = false
    @Published var isPresentingCSVImporter = false
    @Published var isPresentingImportPreview = false
    @Published private(set) var csvImportPreview: CSVImportPreview?
    @Published var importErrorMessage: String?

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
            state = .loaded(try service.loadSnapshot())
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
            isPresentingImportPreview = true
        } catch {
            importErrorMessage = error.localizedDescription
        }
    }
}
