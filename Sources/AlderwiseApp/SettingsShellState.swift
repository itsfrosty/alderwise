import Application
import Foundation

struct SettingsShellState: Equatable {
    var destination: SettingsDestination

    var sidebarDestination: SettingsSidebarDestination {
        destination.sidebarDestination
    }

    static func directEntry() -> SettingsShellState {
        SettingsShellState(destination: .overview)
    }

    static func sidebarSelection(_ destination: SettingsSidebarDestination) -> SettingsShellState {
        SettingsShellState(destination: route(for: destination))
    }

    static func deepLink(_ destination: SettingsDestination) -> SettingsShellState {
        SettingsShellState(destination: destination)
    }

    private static func route(for destination: SettingsSidebarDestination) -> SettingsDestination {
        switch destination {
        case .overview:
            .overview
        case .backupsAndRecovery:
            .backupsAndRecovery
        case .rules:
            .learnedRulesRoute()
        }
    }
}
