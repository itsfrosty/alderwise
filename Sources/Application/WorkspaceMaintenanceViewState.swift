import Domain
import Foundation

public enum PendingWorkspaceMaintenanceAction: Equatable {
    case retryWorkspaceRecovery
    case restoreBackup(URL)
    case reset
}

public enum WorkspaceMaintenanceOutcome: Equatable {
    case backupCreated(WorkspaceBackup)
    case restored(WorkspaceRestoreResult)
    case reset(WorkspaceResetResult)

    public var message: String {
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

public struct WorkspaceMaintenanceFailure: Equatable {
    public enum Operation: Equatable {
        case preferencesUpdate
        case backup
        case restore
        case reset
    }

    public var operation: Operation
    public var message: String

    public init(operation: Operation, message: String) {
        self.operation = operation
        self.message = message
    }
}

public enum WorkspaceStatus: Equatable {
    case loading
    case available(WorkspaceMetadata?)
    case failedToOpen(String)

    public var metadata: WorkspaceMetadata? {
        switch self {
        case .available(let metadata):
            metadata
        case .loading, .failedToOpen:
            nil
        }
    }
}
