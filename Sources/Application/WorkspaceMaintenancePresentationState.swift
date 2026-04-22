import Domain
import Foundation

public struct WorkspaceMaintenanceConfirmationState: Equatable {
    public let title: String
    public let message: String
    public let confirmLabel: String

    public static func current(action: PendingWorkspaceMaintenanceAction?) -> WorkspaceMaintenanceConfirmationState? {
        switch action {
        case .restoreBackup(let backupURL):
            return WorkspaceMaintenanceConfirmationState(
                title: "Restore Workspace Backup?",
                message: "A safety backup of the current workspace will be created before \(backupURL.lastPathComponent) overwrites it.",
                confirmLabel: "Overwrite Workspace"
            )
        case .reset:
            return WorkspaceMaintenanceConfirmationState(
                title: "Reset Workspace?",
                message: "Reset removes workspace data from this Mac and returns the workspace to a clean state. A mandatory backup is created first; if that backup cannot be created, reset is blocked. External backup files are not deleted.",
                confirmLabel: "Reset Workspace"
            )
        case .retryWorkspaceRecovery, nil:
            return nil
        }
    }

    public init(title: String, message: String, confirmLabel: String) {
        self.title = title
        self.message = message
        self.confirmLabel = confirmLabel
    }
}

public struct WorkspaceMaintenanceAlertState: Equatable {
    public let title: String
    public let message: String
    public let revealURL: URL?

    public static func current(
        outcome: WorkspaceMaintenanceOutcome?,
        failure: WorkspaceMaintenanceFailure?
    ) -> WorkspaceMaintenanceAlertState? {
        if let failure {
            return WorkspaceMaintenanceAlertState(
                title: "Workspace Maintenance Failed",
                message: failure.message,
                revealURL: nil
            )
        }

        guard let outcome else {
            return nil
        }

        switch outcome {
        case .backupCreated(let backup):
            return WorkspaceMaintenanceAlertState(
                title: "Workspace Updated",
                message: "Backup created:\n\(backup.fileURL.path)",
                revealURL: backup.fileURL
            )
        case .restored(let result):
            if let safetyBackup = result.safetyBackup {
                return WorkspaceMaintenanceAlertState(
                    title: "Workspace Updated",
                    message: """
                    Workspace restored from \(result.restoredFromURL.lastPathComponent).

                    Safety backup:
                    \(safetyBackup.fileURL.path)
                    """,
                    revealURL: safetyBackup.fileURL
                )
            }

            return WorkspaceMaintenanceAlertState(
                title: "Workspace Updated",
                message: "Workspace restored from \(result.restoredFromURL.lastPathComponent).",
                revealURL: result.restoredFromURL
            )
        case .reset(let result):
            return WorkspaceMaintenanceAlertState(
                title: "Workspace Updated",
                message: """
                Workspace reset completed.

                Mandatory backup:
                \(result.preResetBackupURL.path)
                """,
                revealURL: result.preResetBackupURL
            )
        }
    }

    public init(title: String, message: String, revealURL: URL?) {
        self.title = title
        self.message = message
        self.revealURL = revealURL
    }
}
