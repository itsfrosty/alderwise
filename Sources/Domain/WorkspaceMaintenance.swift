import Foundation

public struct WorkspaceMetadata: Equatable, Sendable {
    public var databaseURL: URL
    public var databaseExists: Bool
    public var databaseSizeBytes: Int64
    public var modifiedAt: Date?

    public init(
        databaseURL: URL,
        databaseExists: Bool,
        databaseSizeBytes: Int64,
        modifiedAt: Date?
    ) {
        self.databaseURL = databaseURL
        self.databaseExists = databaseExists
        self.databaseSizeBytes = databaseSizeBytes
        self.modifiedAt = modifiedAt
    }
}

public struct WorkspaceBackup: Equatable, Sendable {
    public var fileURL: URL
    public var createdAt: Date
    public var sizeBytes: Int64

    public init(fileURL: URL, createdAt: Date, sizeBytes: Int64) {
        self.fileURL = fileURL
        self.createdAt = createdAt
        self.sizeBytes = sizeBytes
    }
}

public struct WorkspaceRestoreResult: Equatable, Sendable {
    public var restoredFromURL: URL
    public var safetyBackup: WorkspaceBackup?
    public var restoredAt: Date

    public init(
        restoredFromURL: URL,
        safetyBackup: WorkspaceBackup?,
        restoredAt: Date
    ) {
        self.restoredFromURL = restoredFromURL
        self.safetyBackup = safetyBackup
        self.restoredAt = restoredAt
    }
}

public protocol WorkspaceMaintenanceManaging: Sendable {
    func fetchWorkspaceMetadata() throws -> WorkspaceMetadata
    func createWorkspaceBackup(in directory: URL?, now: Date) throws -> WorkspaceBackup
    func restoreWorkspaceBackup(
        from backupURL: URL,
        safetyBackupDirectory: URL?,
        now: Date
    ) throws -> WorkspaceRestoreResult
}

public struct WorkspacePreferences: Equatable, Sendable {
    public var suggestionsEnabled: Bool
    public var seededHeuristicAutoAcceptEnabled: Bool

    public init(
        suggestionsEnabled: Bool = true,
        seededHeuristicAutoAcceptEnabled: Bool = false
    ) {
        self.suggestionsEnabled = suggestionsEnabled
        self.seededHeuristicAutoAcceptEnabled = seededHeuristicAutoAcceptEnabled
    }

    public static let `default` = WorkspacePreferences()
}

public protocol WorkspacePreferencesManaging: Sendable {
    func fetchWorkspacePreferences() throws -> WorkspacePreferences
    func updateWorkspacePreferences(_ preferences: WorkspacePreferences) throws
}

public extension WorkspaceMaintenanceManaging {
    func createWorkspaceBackup(in directory: URL? = nil, now: Date = .now) throws -> WorkspaceBackup {
        try createWorkspaceBackup(in: directory, now: now)
    }

    func restoreWorkspaceBackup(
        from backupURL: URL,
        safetyBackupDirectory: URL? = nil,
        now: Date = .now
    ) throws -> WorkspaceRestoreResult {
        try restoreWorkspaceBackup(
            from: backupURL,
            safetyBackupDirectory: safetyBackupDirectory,
            now: now
        )
    }
}

public enum WorkspaceMaintenanceError: Error, Equatable, Sendable {
    case onDiskWorkspaceRequired
    case restoreSourceIsCurrentWorkspace
    case invalidRestoreCandidate(String)
}

extension WorkspaceMaintenanceError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .onDiskWorkspaceRequired:
            "Workspace backup and restore requires an on-disk workspace."
        case .restoreSourceIsCurrentWorkspace:
            "Choose a backup file that is different from the active workspace."
        case .invalidRestoreCandidate(let reason):
            "The selected file is not a supported Alderwise workspace backup. \(reason)"
        }
    }
}
