import Foundation

public struct SettingsPresentation: Equatable, Sendable {
    public let overview: Overview
    public let recovery: Recovery

    public init(workspaceStatus: WorkspaceStatus) {
        let healthStatus = HealthStatus(workspaceStatus: workspaceStatus)
        overview = Overview(
            title: "Overview",
            healthSectionTitle: "Workspace health",
            healthStatus: healthStatus,
            primaryActions: ActionSection(
                title: "Protect and recover your workspace",
                helperText: "Create a backup file before bigger changes, or restore from a known-good backup if this Mac's workspace needs to recover.",
                emphasis: .primary,
                actions: [
                    Action(id: .createBackup, title: "Create Backup", systemImage: "externaldrive.badge.plus"),
                    Action(id: .restoreBackup, title: "Restore Backup", systemImage: "externaldrive.badge.arrowtriangle.2.circlepath"),
                ]
            ),
            rules: Section(
                title: "Rules",
                helperText: "Review the rules Alderwise uses to keep categorization and import decisions predictable on this Mac.",
                emphasis: .secondary
            ),
            secondarySections: [
                Section(
                    title: "Import Automation",
                    helperText: "Tune local suggestions and review automation after backup and restore are set up.",
                    emphasis: .secondary
                ),
                Section(
                    title: "Advanced Details",
                    helperText: "Inspect the workspace location and current health details when you need to troubleshoot this Mac.",
                    emphasis: .secondary
                ),
            ]
        )
        recovery = Recovery(
            title: "Backups and Recovery",
            primaryActions: ActionSection(
                title: "Backup and restore",
                helperText: "Create a backup file before risky changes, or restore from a backup file when you need to recover this Mac's workspace.",
                emphasis: .primary,
                actions: [
                    Action(id: .createBackup, title: "Create Backup", systemImage: "externaldrive.badge.plus"),
                    Action(id: .restoreBackup, title: "Restore Backup", systemImage: "externaldrive.badge.arrowtriangle.2.circlepath"),
                ]
            ),
            reset: ActionSection(
                title: "Last Resort Reset",
                helperText: "Reset removes workspace data from this Mac after Alderwise creates the required backup. Use it only when backup and restore are not enough.",
                emphasis: .caution,
                actions: [
                    Action(id: .resetWorkspace, title: "Reset Workspace", systemImage: "trash"),
                ]
            )
        )
    }

    public struct Overview: Equatable, Sendable {
        public let title: String
        public let healthSectionTitle: String
        public let healthStatus: HealthStatus
        public let primaryActions: ActionSection
        public let rules: Section
        public let secondarySections: [Section]

        public init(
            title: String,
            healthSectionTitle: String,
            healthStatus: HealthStatus,
            primaryActions: ActionSection,
            rules: Section,
            secondarySections: [Section]
        ) {
            self.title = title
            self.healthSectionTitle = healthSectionTitle
            self.healthStatus = healthStatus
            self.primaryActions = primaryActions
            self.rules = rules
            self.secondarySections = secondarySections
        }
    }

    public struct Recovery: Equatable, Sendable {
        public let title: String
        public let primaryActions: ActionSection
        public let reset: ActionSection

        public init(title: String, primaryActions: ActionSection, reset: ActionSection) {
            self.title = title
            self.primaryActions = primaryActions
            self.reset = reset
        }
    }

    public struct HealthStatus: Equatable, Sendable {
        public enum State: Equatable, Sendable {
            case checking
            case healthy
            case recoveryNeeded
        }

        public let state: State
        public let title: String
        public let detail: String
        public let systemImage: String

        public init(state: State, title: String, detail: String, systemImage: String) {
            self.state = state
            self.title = title
            self.detail = detail
            self.systemImage = systemImage
        }

        public init(workspaceStatus: WorkspaceStatus) {
            switch workspaceStatus {
            case .loading:
                self.init(
                    state: .checking,
                    title: "Checking workspace health",
                    detail: "Alderwise is reading the local workspace before it shows backup and recovery guidance.",
                    systemImage: "clock.arrow.circlepath"
                )
            case .failedToOpen:
                self.init(
                    state: .recoveryNeeded,
                    title: "Workspace needs recovery",
                    detail: "Restore from a known-good backup, or inspect the workspace details below before you try again.",
                    systemImage: "exclamationmark.triangle.fill"
                )
            case .available(let metadata):
                if let metadata, metadata.databaseExists == false {
                    self.init(
                        state: .recoveryNeeded,
                        title: "Workspace needs recovery",
                        detail: "The expected workspace file is missing from this Mac. Restore a backup file to recover safely.",
                        systemImage: "externaldrive.badge.exclamationmark"
                    )
                } else {
                    self.init(
                        state: .healthy,
                        title: "Workspace looks healthy",
                        detail: "Back up before major changes so you have a recovery path if this Mac's workspace ever needs repair.",
                        systemImage: "checkmark.shield.fill"
                    )
                }
            }
        }
    }

    public struct Section: Equatable, Sendable {
        public let title: String
        public let helperText: String
        public let emphasis: Emphasis

        public init(title: String, helperText: String, emphasis: Emphasis) {
            self.title = title
            self.helperText = helperText
            self.emphasis = emphasis
        }
    }

    public struct ActionSection: Equatable, Sendable {
        public let title: String
        public let helperText: String
        public let emphasis: Emphasis
        public let actions: [Action]

        public init(title: String, helperText: String, emphasis: Emphasis, actions: [Action]) {
            self.title = title
            self.helperText = helperText
            self.emphasis = emphasis
            self.actions = actions
        }

        public func action(id: Action.ID) -> Action? {
            actions.first { $0.id == id }
        }
    }

    public struct Action: Equatable, Sendable {
        public enum ID: Equatable, Sendable {
            case createBackup
            case restoreBackup
            case resetWorkspace
            case openRules
            case revealInFinder
        }

        public let id: ID
        public let title: String
        public let systemImage: String

        public init(id: ID, title: String, systemImage: String) {
            self.id = id
            self.title = title
            self.systemImage = systemImage
        }
    }

    public enum Emphasis: Equatable, Sendable {
        case primary
        case secondary
        case caution
    }
}
