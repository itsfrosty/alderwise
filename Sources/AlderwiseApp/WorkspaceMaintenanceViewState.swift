import Domain
import Foundation

enum PendingWorkspaceMaintenanceAction: Equatable {
    case retryWorkspaceRecovery
    case restoreBackup(URL)
    case reset
}

enum WorkspaceMaintenanceOutcome: Equatable {
    case backupCreated(WorkspaceBackup)
    case restored(WorkspaceRestoreResult)
    case reset(WorkspaceResetResult)

    var message: String {
        switch self {
        case .backupCreated(let backup):
            return "Backup created at \(backup.fileURL.path)"
        case .restored(let result):
            if let safetyBackup = result.safetyBackup {
                return "Workspace restored. Safety backup saved at \(safetyBackup.fileURL.path)"
            }
            return "Workspace restored."
        case .reset(let result):
            return "Workspace reset. Backup saved at \(result.preResetBackupURL.path)"
        }
    }
}

struct WorkspaceMaintenanceFailure: Equatable {
    enum Operation: Equatable {
        case preferencesUpdate
        case backup
        case restore
        case reset
    }

    var operation: Operation
    var message: String
}

enum WorkspaceStatus: Equatable {
    case loading
    case available(WorkspaceMetadata?)
    case failedToOpen(String)

    var metadata: WorkspaceMetadata? {
        switch self {
        case .available(let metadata):
            metadata
        case .loading, .failedToOpen:
            nil
        }
    }
}
