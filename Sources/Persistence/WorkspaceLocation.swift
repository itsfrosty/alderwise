import Foundation

public struct WorkspaceLocation {
    public let databaseURL: URL

    public init(databaseURL: URL) {
        self.databaseURL = databaseURL
    }

    public var databasePath: String {
        databaseURL.path
    }

    public static func live() throws -> WorkspaceLocation {
        let supportDirectory = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return try live(applicationSupportDirectory: supportDirectory)
    }

    public static func live(
        applicationSupportDirectory supportDirectory: URL,
        fileManager: FileManager = .default
    ) throws -> WorkspaceLocation {
        let directory = supportDirectory.appendingPathComponent("Alderwise", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return WorkspaceLocation(databaseURL: directory.appendingPathComponent("workspace.sqlite"))
    }
}
