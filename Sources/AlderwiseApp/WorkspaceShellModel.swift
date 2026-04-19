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

    private let store: WorkspaceStore?
    private let service: WorkspaceService?

    init(store: WorkspaceStore?, service: WorkspaceService?) {
        self.store = store
        self.service = service
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
        guard let store else {
            return
        }

        do {
            _ = try store.createAccount(named: "Checking", kind: .checking, institutionName: "Local Bank")
            reload()
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}
