import Application
import Domain
import Persistence
import SwiftUI

@main
struct AlderwiseApp: App {
    @NSApplicationDelegateAdaptor(AppActivationDelegate.self) private var appDelegate
    @StateObject private var model = WorkspaceShellModel.makeDefault()

    var body: some Scene {
        WindowGroup {
            WorkspaceRootView(model: model)
                .frame(minWidth: 980, minHeight: 620)
        }
        .windowResizability(.contentSize)
    }
}
