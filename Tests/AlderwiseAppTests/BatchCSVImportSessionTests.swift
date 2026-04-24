import Application
import Domain
import Foundation
import Testing

@testable import AlderwiseApp

@Test
@MainActor
func sessionBuildsOneDraftItemPerSelectedFileAndRetainsLoadedCSVText() throws {
    let files = try BatchCSVImportSessionTestFiles.make(
        [
            ("checking-april.csv", "Date,Description,Amount\n2026-04-01,Coffee,-4.75\n"),
            ("checking-may.csv", "Date,Description,Amount\n2026-05-01,Payroll,1250.00\n"),
        ]
    )

    let session = BatchCSVImportSession(
        selectedURLs: files.urls,
        importEligibleAccounts: [batchCSVImportAccount(id: "00000000-0000-0000-0000-000000000101", name: "Checking")]
    )

    try FileManager.default.removeItem(at: files.directoryURL)

    #expect(session.importPhase == .editing)
    #expect(session.draft.items.map(\.originalFilename) == ["checking-april.csv", "checking-may.csv"])
    #expect(session.draft.selectedItem?.originalFilename == "checking-april.csv")

    let firstItem = try #require(session.draft.items.first)
    let secondItem = try #require(session.draft.items.last)

    guard case .loaded(let firstCSVText, let firstPreview) = firstItem.content else {
        Issue.record("Expected first batch item to load successfully.")
        return
    }
    guard case .loaded(let secondCSVText, let secondPreview) = secondItem.content else {
        Issue.record("Expected second batch item to load successfully.")
        return
    }

    #expect(firstCSVText.contains("Coffee"))
    #expect(firstPreview.previewRows.map(\.sourceLineNumber) == [2])
    #expect(firstItem.selectedAccountID == batchCSVImportAccountID("00000000-0000-0000-0000-000000000101"))
    #expect(secondCSVText.contains("Payroll"))
    #expect(secondPreview.previewRows.map(\.sourceLineNumber) == [2])
    #expect(secondItem.selectedAccountID == batchCSVImportAccountID("00000000-0000-0000-0000-000000000101"))
    #expect(session.draft.isReadyForImport)
}

@Test
@MainActor
func sessionSelectsFirstBlockedItemAndKeepsMixedLoadFailuresScopedPerItem() throws {
    let fileManager = FileManager.default
    let directoryURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)

    let validURL = directoryURL.appendingPathComponent("valid.csv")
    try "Date,Description,Amount\n2026-04-01,Coffee,-4.75\n".write(to: validURL, atomically: true, encoding: .utf8)

    let parseFailedURL = directoryURL.appendingPathComponent("parse-failed.csv")
    try "Date,Description,Amount\n2026-04-01,Coffee\n".write(to: parseFailedURL, atomically: true, encoding: .utf8)

    let readFailedURL = directoryURL.appendingPathComponent("read-failed.csv", isDirectory: true)
    try fileManager.createDirectory(at: readFailedURL, withIntermediateDirectories: true)

    let session = BatchCSVImportSession(
        selectedURLs: [validURL, parseFailedURL, readFailedURL],
        importEligibleAccounts: [batchCSVImportAccount(id: "00000000-0000-0000-0000-000000000201", name: "Checking")]
    )

    #expect(session.draft.items.map(\.originalFilename) == ["valid.csv", "parse-failed.csv", "read-failed.csv"])
    #expect(session.draft.selectedItem?.originalFilename == "parse-failed.csv")
    #expect(session.draft.isReadyForImport == false)

    guard case .loaded(let csvText, let preview) = session.draft.items[0].content else {
        Issue.record("Expected the first batch item to remain loaded even when later items fail.")
        return
    }
    #expect(csvText.contains("Coffee"))
    #expect(preview.validation.isReadyForImport)
    #expect(session.draft.items[0].selectedAccountID == batchCSVImportAccountID("00000000-0000-0000-0000-000000000201"))

    guard case .loadFailed(let parseFailureMessage) = session.draft.items[1].content else {
        Issue.record("Expected parse failures to be stored on the item.")
        return
    }
    #expect(parseFailureMessage.contains("has 2 columns"))
    #expect(session.draft.items[1].selectedAccountID == nil)

    guard case .loadFailed(let readFailureMessage) = session.draft.items[2].content else {
        Issue.record("Expected read failures to be stored on the item.")
        return
    }
    #expect(readFailureMessage.isEmpty == false)
    #expect(session.draft.items[2].selectedAccountID == nil)
}

@Test
@MainActor
func sessionDoesNotAutoSelectAnAccountWhenMultipleEligibleAccountsExist() throws {
    let files = try BatchCSVImportSessionTestFiles.make(
        [
            ("checking.csv", "Date,Description,Amount\n2026-04-01,Coffee,-4.75\n"),
            ("savings.csv", "Date,Description,Amount\n2026-04-02,Interest,1.25\n"),
        ]
    )

    let session = BatchCSVImportSession(
        selectedURLs: files.urls,
        importEligibleAccounts: [
            batchCSVImportAccount(id: "00000000-0000-0000-0000-000000000301", name: "Checking"),
            batchCSVImportAccount(id: "00000000-0000-0000-0000-000000000302", name: "Savings"),
        ]
    )

    #expect(session.draft.selectedItem?.originalFilename == "checking.csv")
    #expect(session.draft.items.allSatisfy { $0.selectedAccountID == nil })
    #expect(session.draft.items.allSatisfy { $0.isReadyForImport == false })
    #expect(session.draft.isReadyForImport == false)
}

private struct BatchCSVImportSessionTestFiles {
    let directoryURL: URL
    let urls: [URL]

    static func make(_ files: [(filename: String, contents: String)]) throws -> BatchCSVImportSessionTestFiles {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        var urls: [URL] = []
        for file in files {
            let url = directoryURL.appendingPathComponent(file.filename)
            try file.contents.write(to: url, atomically: true, encoding: .utf8)
            urls.append(url)
        }

        return BatchCSVImportSessionTestFiles(directoryURL: directoryURL, urls: urls)
    }
}

private func batchCSVImportAccount(id: String, name: String) -> Account {
    Account(
        id: batchCSVImportAccountID(id),
        name: name,
        kind: .checking,
        institutionName: "Local Bank"
    )
}

private func batchCSVImportAccountID(_ rawValue: String) -> UUID {
    UUID(uuidString: rawValue)!
}
