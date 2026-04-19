import Foundation

public struct WorkspaceLocation {
    public let databaseURL: URL

    public static func live() throws -> WorkspaceLocation {
        let supportDirectory = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = supportDirectory.appendingPathComponent("Alderwise", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return WorkspaceLocation(databaseURL: directory.appendingPathComponent("workspace.sqlite"))
    }
}
