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
                helperText: "Create a backup before major changes, or restore from a backup if you need to recover this workspace.",
                emphasis: .primary,
                actions: [
                    Action(id: .createBackup, title: "Create Backup", systemImage: "externaldrive.badge.plus"),
                    Action(id: .restoreBackup, title: "Restore Backup", systemImage: "externaldrive.badge.arrowtriangle.2.circlepath"),
                ]
            ),
            secondarySections: [
                Section(
                    title: "Import Automation",
                    helperText: "Control how Alderwise uses local suggestions during import and review.",
                    emphasis: .secondary
                ),
                Section(
                    title: "Advanced Details",
                    helperText: "Check the workspace location and file details when you need to troubleshoot.",
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
                helperText: "Use reset only when restore is not enough to get this workspace back into a good state.",
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
        public let secondarySections: [Section]

        public init(
            title: String,
            healthSectionTitle: String,
            healthStatus: HealthStatus,
            primaryActions: ActionSection,
            secondarySections: [Section]
        ) {
            self.title = title
            self.healthSectionTitle = healthSectionTitle
            self.healthStatus = healthStatus
            self.primaryActions = primaryActions
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
                    detail: "Alderwise is checking the local workspace and preparing recovery options.",
                    systemImage: "clock.arrow.circlepath"
                )
            case .failedToOpen:
                self.init(
                    state: .recoveryNeeded,
                    title: "Workspace needs recovery",
                    detail: "Restore a backup or inspect the workspace details below before trying again.",
                    systemImage: "exclamationmark.triangle.fill"
                )
            case .available(let metadata):
                if metadata == nil {
                    self.init(
                        state: .checking,
                        title: "Checking workspace details",
                        detail: "Alderwise opened the workspace, but some details are still loading. Backup and restore are available if you need a safe recovery path.",
                        systemImage: "clock.badge.exclamationmark"
                    )
                } else if let metadata, metadata.databaseExists == false {
                    self.init(
                        state: .recoveryNeeded,
                        title: "Workspace needs recovery",
                        detail: "The expected workspace file is missing from this Mac. Restore a backup file to recover safely.",
                        systemImage: "externaldrive.badge.exclamationmark"
                    )
                } else if let metadata, metadata.requiresReset {
                    self.init(
                        state: .recoveryNeeded,
                        title: "Workspace reset required",
                        detail: metadata.resetReason
                            ?? "This workspace must be reset before it can be used with this version of Alderwise.",
                        systemImage: "arrow.trianglehead.counterclockwise.rotate.90"
                    )
                } else {
                    self.init(
                        state: .healthy,
                        title: "Workspace looks healthy",
                        detail: "Create a backup before major changes so you can recover this workspace if needed.",
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
