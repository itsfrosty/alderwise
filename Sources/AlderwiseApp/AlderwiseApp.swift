import Application
import Domain
import Persistence
import SwiftUI

@main
struct AlderwiseApp: App {
    @NSApplicationDelegateAdaptor(AppActivationDelegate.self) private var appDelegate
    @StateObject private var model = WorkspaceShellModel.makeDefault()

    init() {
        NavigationSplitViewStateRepair.clearInvalidSidebarFrames()
    }

    var body: some Scene {
        WindowGroup {
            WorkspaceRootView(model: model)
                .frame(minWidth: 980, minHeight: 620)
        }
        .windowResizability(.contentSize)
    }
}

private enum NavigationSplitViewStateRepair {
    static func clearInvalidSidebarFrames(defaults: UserDefaults = .standard) {
        for key in defaults.dictionaryRepresentation().keys where key.contains("SidebarNavigationSplitView") {
            guard
                let frames = defaults.array(forKey: key) as? [String],
                frames.count >= 2,
                let sidebarFrame = splitViewFrame(from: frames[0]),
                let detailFrame = splitViewFrame(from: frames[1])
            else {
                continue
            }

            if detailFrame.minX < sidebarFrame.maxX {
                defaults.removeObject(forKey: key)
            }
        }
    }

    private static func splitViewFrame(from value: String) -> CGRect? {
        let components = value
            .split(separator: ",")
            .prefix(4)
            .compactMap { Double($0.trimmingCharacters(in: .whitespacesAndNewlines)) }

        guard components.count == 4 else {
            return nil
        }

        return CGRect(
            x: components[0],
            y: components[1],
            width: components[2],
            height: components[3]
        )
    }
}
