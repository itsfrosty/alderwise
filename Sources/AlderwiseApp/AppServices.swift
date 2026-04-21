import Application
import Domain
import Persistence

struct AppServices {
    var store: WorkspaceStore
    var workspaceService: WorkspaceService
    var csvImportPreviewService: CSVImportPreviewService

    static func live() throws -> AppServices {
        let store = try WorkspaceStore.live()
        try store.bootstrap()

        return AppServices(
            store: store,
            workspaceService: WorkspaceService(
                store: store,
                classifier: SeededClassification.liveClassifier()
            ),
            csvImportPreviewService: CSVImportPreviewService()
        )
    }
}
