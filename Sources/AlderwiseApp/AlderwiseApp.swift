import SwiftUI

struct AnalysisInspectorCommandContext {
    let toggle: @MainActor () -> Void
}

private struct AnalysisInspectorCommandContextKey: FocusedValueKey {
    typealias Value = AnalysisInspectorCommandContext
}

extension FocusedValues {
    var analysisInspectorCommandContext: AnalysisInspectorCommandContext? {
        get { self[AnalysisInspectorCommandContextKey.self] }
        set { self[AnalysisInspectorCommandContextKey.self] = newValue }
    }
}

struct WorkspaceCommandMenu: Commands {
    @FocusedValue(\.analysisInspectorCommandContext) private var analysisInspectorCommandContext

    var body: some Commands {
        CommandGroup(after: .sidebar) {
            Button("Toggle Analysis Inspector") {
                analysisInspectorCommandContext?.toggle()
            }
            .keyboardShortcut("i", modifiers: [.command, .option])
            .disabled(analysisInspectorCommandContext == nil)
        }
    }
}

@main
struct AlderwiseApp: App {
    @NSApplicationDelegateAdaptor(AppActivationDelegate.self) private var appDelegate
    @StateObject private var model: WorkspaceShellModel

    init() {
        NavigationSplitViewStateRepair.clearInvalidSidebarFrames()
        _model = StateObject(wrappedValue: WorkspaceShellModel.makeDefault(services: AppServices.live))
    }

    var body: some Scene {
        WindowGroup {
            WorkspaceRootView(model: model)
                .frame(
                    minWidth: WorkspaceLayout.minimumWindowWidth,
                    minHeight: WorkspaceLayout.minimumWindowHeight
                )
        }
        .windowResizability(.contentSize)
        .commands {
            WorkspaceCommandMenu()
        }
    }
}

enum NavigationSplitViewStateRepair {
    private static let legacyDomainNames = ["AlderwiseApp"]

    static func clearInvalidSidebarFrames(defaults: UserDefaults = .standard) {
        for key in invalidSidebarFrameKeys(in: defaults.dictionaryRepresentation()) {
            defaults.removeObject(forKey: key)
        }

        for domainName in legacyDomainNames {
            sanitizePersistentDomain(named: domainName, defaults: defaults)
        }
    }

    static func invalidSidebarFrameKeys(in domain: [String: Any]) -> [String] {
        domain.compactMap { key, value in
            guard key.contains("SidebarNavigationSplitView"), hasInvalidSidebarFrames(value) else {
                return nil
            }
            return key
        }
        .sorted()
    }

    static func sanitizedDomain(_ domain: [String: Any]) -> [String: Any] {
        var sanitized = domain
        for key in invalidSidebarFrameKeys(in: domain) {
            sanitized.removeValue(forKey: key)
        }
        return sanitized
    }

    private static func sanitizePersistentDomain(named domainName: String, defaults: UserDefaults) {
        guard let domain = defaults.persistentDomain(forName: domainName) else {
            return
        }

        let sanitized = sanitizedDomain(domain)
        guard sanitized.count != domain.count else {
            return
        }

        defaults.setPersistentDomain(sanitized, forName: domainName)
    }

    private static func hasInvalidSidebarFrames(_ value: Any) -> Bool {
        guard
            let frames = value as? [String],
            frames.count >= 2,
            let sidebarFrame = splitViewFrame(from: frames[0]),
            let detailFrame = splitViewFrame(from: frames[1])
        else {
            return false
        }

        return detailFrame.minX < sidebarFrame.maxX
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
