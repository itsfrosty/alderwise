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

@Test
@MainActor
func sessionRunsInferenceOncePerLoadedFileAppliesConfidenceStatesAndSelectsFirstUnassignedItem() throws {
    let checking = batchCSVImportAccount(
        id: "00000000-0000-0000-0000-000000000351",
        name: "Checking",
        institutionName: "Local Credit Union"
    )
    let sapphire = batchCSVImportAccount(
        id: "00000000-0000-0000-0000-000000000352",
        name: "Sapphire Reserve",
        institutionName: "Chase"
    )
    let files = try BatchCSVImportSessionTestFiles.make(
        [
            ("2026-04_chase_sapphire_reserve_statement.csv", "Date,Description,Amount\n2026-04-01,Coffee,-4.75\n"),
            ("2026-04_chase_statement.csv", "Date,Description,Amount\n2026-04-02,Travel credit,20.00\n"),
            ("generic_statement.csv", "Date,Description,Amount\n2026-04-03,Groceries,-45.21\n"),
        ]
    )
    let unreadableURL = files.directoryURL.appendingPathComponent("unreadable.csv", isDirectory: true)
    try FileManager.default.createDirectory(at: unreadableURL, withIntermediateDirectories: true)

    let accounts = [checking, sapphire]
    let filenames = [
        "2026-04_chase_sapphire_reserve_statement.csv",
        "2026-04_chase_statement.csv",
        "generic_statement.csv",
        "unreadable.csv",
    ]
    let requests = try Dictionary(
        uniqueKeysWithValues: zip(files.urls + [unreadableURL], filenames).map { url, filename in
            (
                url,
                try batchCSVImportInferenceRequest(
                    originalFilename: filename,
                    accounts: accounts
                )
            )
        }
    )
    let results = requests.mapValues { ImportAccountInferenceService().inferAccount(for: $0) }
    var inferredFilenames: [String] = []

    let session = BatchCSVImportSession(
        selectedURLs: files.urls + [unreadableURL],
        importEligibleAccounts: accounts,
        initialInferenceRequestsByURL: requests,
        initialInferenceResultsByURL: results
    )
    inferredFilenames = session.draft.items.compactMap { item in
        guard case .loaded = item.content, item.initialInferenceDisposition != nil else {
            return nil
        }
        return item.originalFilename
    }

    #expect(inferredFilenames == [
        "2026-04_chase_sapphire_reserve_statement.csv",
        "2026-04_chase_statement.csv",
        "generic_statement.csv",
    ])
    #expect(session.draft.selectedItem?.originalFilename == "generic_statement.csv")

    let highConfidenceItem = try #require(
        session.draft.items.first(where: { $0.originalFilename == "2026-04_chase_sapphire_reserve_statement.csv" })
    )
    let mediumConfidenceItem = try #require(
        session.draft.items.first(where: { $0.originalFilename == "2026-04_chase_statement.csv" })
    )
    let lowConfidenceItem = try #require(
        session.draft.items.first(where: { $0.originalFilename == "generic_statement.csv" })
    )
    let unreadableItem = try #require(
        session.draft.items.first(where: { $0.originalFilename == "unreadable.csv" })
    )

    #expect(highConfidenceItem.selectedAccountID == sapphire.id)
    #expect(highConfidenceItem.initialInferenceDisposition == ImportAccountInferenceDisposition.autoSelected)
    #expect(highConfidenceItem.initialInferredOrSuggestedAccountID == sapphire.id)
    #expect(highConfidenceItem.selectionSource == BatchCSVImportItemDraft.AccountSelectionSource.inferred)
    #expect(highConfidenceItem.inferenceFeedbackContext?.disposition == ImportAccountInferenceDisposition.autoSelected)

    #expect(mediumConfidenceItem.selectedAccountID == sapphire.id)
    #expect(mediumConfidenceItem.initialInferenceDisposition == ImportAccountInferenceDisposition.suggested)
    #expect(mediumConfidenceItem.initialInferredOrSuggestedAccountID == sapphire.id)
    #expect(mediumConfidenceItem.selectionSource == BatchCSVImportItemDraft.AccountSelectionSource.suggested)
    #expect(mediumConfidenceItem.inferenceFeedbackContext?.disposition == ImportAccountInferenceDisposition.suggested)

    #expect(lowConfidenceItem.selectedAccountID == nil)
    #expect(lowConfidenceItem.initialInferenceDisposition == ImportAccountInferenceDisposition.unassigned)
    #expect(lowConfidenceItem.initialInferredOrSuggestedAccountID == nil)
    #expect(lowConfidenceItem.selectionSource == BatchCSVImportItemDraft.AccountSelectionSource.unassigned)
    #expect(lowConfidenceItem.inferenceFeedbackContext?.disposition == ImportAccountInferenceDisposition.unassigned)

    guard case .loadFailed = unreadableItem.content else {
        Issue.record("Expected unreadable.csv to remain a load failure.")
        return
    }
    #expect(unreadableItem.selectedAccountID == nil)
}

@Test
@MainActor
func reevaluatingStillUnassignedItemsAfterAccountChangesPreservesManualRows() throws {
    let checking = batchCSVImportAccount(
        id: "00000000-0000-0000-0000-000000000361",
        name: "Checking",
        institutionName: "Local Credit Union"
    )
    let savings = batchCSVImportAccount(
        id: "00000000-0000-0000-0000-000000000362",
        name: "Savings",
        institutionName: "Neighborhood Bank"
    )
    let travelCard = batchCSVImportAccount(
        id: "00000000-0000-0000-0000-000000000363",
        name: "Travel Card",
        institutionName: "Amex"
    )
    let files = try BatchCSVImportSessionTestFiles.make(
        [
            ("2026-04_amex_travel_card_statement_a.csv", "Date,Description,Amount\n2026-04-01,Flight,-320.00\n"),
            ("2026-04_amex_travel_card_statement_b.csv", "Date,Description,Amount\n2026-04-02,Hotel,-180.00\n"),
        ]
    )
    let initialAccounts = [checking, savings]
    let requests = try Dictionary(
        uniqueKeysWithValues: files.urls.map { url in
            (
                url,
                try batchCSVImportInferenceRequest(
                    originalFilename: url.lastPathComponent,
                    accounts: initialAccounts
                )
            )
        }
    )
    let results = requests.mapValues { ImportAccountInferenceService().inferAccount(for: $0) }

    let session = BatchCSVImportSession(
        selectedURLs: files.urls,
        importEligibleAccounts: initialAccounts,
        initialInferenceRequestsByURL: requests,
        initialInferenceResultsByURL: results
    )
    let manualItemID = try #require(session.draft.items.first?.id)
    let untouchedItemID = try #require(session.draft.items.last?.id)

    #expect(session.draft.items.allSatisfy { $0.selectionSource == BatchCSVImportItemDraft.AccountSelectionSource.unassigned })
    #expect(session.setSelectedAccount(id: checking.id, forItemID: manualItemID))

    var reevaluatedFilenames: [String] = []
    session.reevaluateUnassignedItems(
        importEligibleAccounts: initialAccounts + [travelCard]
    ) { request in
        reevaluatedFilenames.append(request.originalFilename)
        return ImportAccountInferenceService().inferAccount(for: request)
    }

    let manualItem = try #require(session.draft.items.first(where: { $0.id == manualItemID }))
    let reevaluatedItem = try #require(session.draft.items.first(where: { $0.id == untouchedItemID }))

    #expect(reevaluatedFilenames == ["2026-04_amex_travel_card_statement_b.csv"])
    #expect(manualItem.selectedAccountID == checking.id)
    #expect(manualItem.selectionSource == BatchCSVImportItemDraft.AccountSelectionSource.manual)
    #expect(reevaluatedItem.selectedAccountID == travelCard.id)
    #expect(reevaluatedItem.selectionSource == BatchCSVImportItemDraft.AccountSelectionSource.inferred)
    #expect(reevaluatedItem.initialInferenceDisposition == ImportAccountInferenceDisposition.unassigned)
    #expect(reevaluatedItem.initialInferredOrSuggestedAccountID == nil)
}

@Test
@MainActor
func duplicateBasenameFilesKeepInferenceBoundToTheirOwnURLs() throws {
    let rootDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let firstDirectory = rootDirectory.appendingPathComponent("first", isDirectory: true)
    let secondDirectory = rootDirectory.appendingPathComponent("second", isDirectory: true)
    try FileManager.default.createDirectory(at: firstDirectory, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: secondDirectory, withIntermediateDirectories: true)

    let firstURL = firstDirectory.appendingPathComponent("checking.csv")
    let secondURL = secondDirectory.appendingPathComponent("checking.csv")
    try "Date,Description,Amount\n2026-04-01,First,-1.00\n".write(to: firstURL, atomically: true, encoding: .utf8)
    try "Date,Description,Amount\n2026-04-02,Second,-2.00\n".write(to: secondURL, atomically: true, encoding: .utf8)

    let checking = batchCSVImportAccount(
        id: "00000000-0000-0000-0000-000000000371",
        name: "Checking",
        institutionName: "Local Credit Union"
    )
    let travel = batchCSVImportAccount(
        id: "00000000-0000-0000-0000-000000000372",
        name: "Travel Card",
        institutionName: "Amex"
    )
    let request = try batchCSVImportInferenceRequest(
        originalFilename: "checking.csv",
        accounts: [checking, travel]
    )
    let fingerprint = ImportAccountInferenceService().inferAccount(for: request).fingerprint
    let firstResult = ImportAccountInferenceResult(
        disposition: .suggested,
        selectedAccountID: checking.id,
        fingerprint: fingerprint,
        candidates: [],
        feedbackContext: nil
    )
    let secondResult = ImportAccountInferenceResult(
        disposition: .suggested,
        selectedAccountID: travel.id,
        fingerprint: fingerprint,
        candidates: [],
        feedbackContext: nil
    )

    let session = BatchCSVImportSession(
        selectedURLs: [firstURL, secondURL],
        importEligibleAccounts: [checking, travel],
        initialInferenceRequestsByURL: [
            firstURL: request,
            secondURL: request,
        ],
        initialInferenceResultsByURL: [
            firstURL: firstResult,
            secondURL: secondResult,
        ]
    )

    #expect(session.draft.items.map(\.selectedAccountID) == [checking.id, travel.id])
}

@Test
@MainActor
func selectingAnItemChangesTheSelectedDetailSourceItem() throws {
    let files = try BatchCSVImportSessionTestFiles.make(
        [
            ("checking.csv", "Date,Description,Amount\n2026-04-01,Coffee,-4.75\n"),
            ("savings.csv", "Date,Description,Amount\n2026-04-02,Interest,1.25\n"),
        ]
    )

    let session = BatchCSVImportSession(
        selectedURLs: files.urls,
        importEligibleAccounts: [batchCSVImportAccount(id: "00000000-0000-0000-0000-000000000501", name: "Checking")]
    )
    let secondItemID = try #require(session.draft.items.last?.id)

    session.selectItem(id: secondItemID)

    #expect(session.draft.selectedItemID == secondItemID)
    #expect(session.draft.selectedItem?.originalFilename == "savings.csv")
}

@Test
@MainActor
func selectingAccountAndChangingMappingOnlyAffectTheSelectedItem() throws {
    let files = try BatchCSVImportSessionTestFiles.make(
        [
            ("checking.csv", "Date,Description,Amount\n2026-04-01,Coffee,-4.75\n"),
            ("savings.csv", "Date,Description,Amount\n2026-04-02,Interest,1.25\n"),
        ]
    )

    let checkingAccount = batchCSVImportAccount(
        id: "00000000-0000-0000-0000-000000000502",
        name: "Checking"
    )
    let savingsAccount = batchCSVImportAccount(
        id: "00000000-0000-0000-0000-000000000503",
        name: "Savings"
    )
    let session = BatchCSVImportSession(
        selectedURLs: files.urls,
        importEligibleAccounts: [checkingAccount, savingsAccount]
    )
    let firstItemID = try #require(session.draft.items.first?.id)
    let secondItemID = try #require(session.draft.items.last?.id)

    session.selectItem(id: firstItemID)
    #expect(session.selectAccount(id: checkingAccount.id, forItemID: firstItemID))

    let firstPreviewBeforeEdit = try #require(preview(forItemID: firstItemID, in: session))

    session.selectItem(id: secondItemID)
    #expect(session.selectAccount(id: savingsAccount.id, forItemID: secondItemID))
    #expect(
        session.updateMapping(
            CSVColumnMapping(
                dateColumnIndex: 0,
                descriptionColumnIndex: 1,
                amount: nil
            ),
            forItemID: secondItemID
        )
    )

    let firstItem = try #require(session.draft.items.first(where: { $0.id == firstItemID }))
    let secondItem = try #require(session.draft.items.first(where: { $0.id == secondItemID }))
    let firstPreviewAfterEdit = try #require(preview(forItemID: firstItemID, in: session))
    let secondPreview = try #require(preview(forItemID: secondItemID, in: session))

    #expect(firstItem.selectedAccountID == checkingAccount.id)
    #expect(firstPreviewBeforeEdit.mapping == firstPreviewAfterEdit.mapping)
    #expect(firstPreviewAfterEdit.validation.isReadyForImport)

    #expect(secondItem.selectedAccountID == savingsAccount.id)
    #expect(secondPreview.mapping.amount == nil)
    #expect(secondPreview.validation.isReadyForImport == false)
}

@Test
@MainActor
func removingABlockedFileUpdatesReadinessAndSelectionAndKeepsImportAllDisabledUntilThen() throws {
    let fileManager = FileManager.default
    let directoryURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)

    let validURL = directoryURL.appendingPathComponent("valid.csv")
    try "Date,Description,Amount\n2026-04-01,Coffee,-4.75\n".write(to: validURL, atomically: true, encoding: .utf8)

    let blockedURL = directoryURL.appendingPathComponent("blocked.csv")
    try "Date,Description,Amount\n2026-04-01,Coffee\n".write(to: blockedURL, atomically: true, encoding: .utf8)

    let session = BatchCSVImportSession(
        selectedURLs: [validURL, blockedURL],
        importEligibleAccounts: [batchCSVImportAccount(id: "00000000-0000-0000-0000-000000000504", name: "Checking")]
    )
    let blockedItemID = try #require(session.draft.selectedItemID)

    #expect(session.draft.selectedItem?.originalFilename == "blocked.csv")
    #expect(session.draft.isReadyForImport == false)

    #expect(session.removeItem(id: blockedItemID))

    #expect(session.draft.items.map(\.originalFilename) == ["valid.csv"])
    #expect(session.draft.selectedItem?.originalFilename == "valid.csv")
    #expect(session.draft.isReadyForImport)
}

@Test
@MainActor
func confirmBatchImportStagesFilesSequentiallyAndAggregatesMixedStagedAndExactReimportResults() async throws {
    let account = batchCSVImportAccount(
        id: "00000000-0000-0000-0000-000000000601",
        name: "Checking"
    )
    let files = try BatchCSVImportSessionTestFiles.make(
        [
            ("april.csv", "Date,Description,Amount\n2026-04-01,Coffee,-4.75\n"),
            ("april-renamed.csv", "Date,Description,Amount\n2026-04-01,Coffee,-4.75\n"),
            ("may.csv", "Date,Description,Amount\n2026-05-01,Payroll,1250.00\n"),
        ]
    )
    let session = BatchCSVImportSession(
        selectedURLs: files.urls,
        importEligibleAccounts: [account]
    )
    let store = BatchCSVImportSessionExecutionStore(accounts: [account])
    let service = WorkspaceService(store: store)

    let result = await session.confirmBatchCSVImport(service: service, accounts: [account])

    guard case .success(let summary, let outcome, let fileResults) = result else {
        Issue.record("Expected the batch import to succeed.")
        return
    }

    #expect(
        summary == StagedImportDecisionSummary(
            importedRowCount: 2,
            skippedRowCount: 1,
            pendingClassificationReviewRowCount: 2,
            flaggedDuplicateRowCount: 0
        )
    )
    #expect(outcome == .staged)
    #expect(fileResults.map(\.itemID) == session.draft.items.map(\.id))
    #expect(fileResults.map(\.originalFilename) == ["april.csv", "april-renamed.csv", "may.csv"])
    #expect(fileResults.map(\.stagedImportSessionID) == [1, nil, 2])
    #expect(fileResults.map(\.outcome) == [.staged, .exactReimportNoOp, .staged])
    #expect(fileResults.map(\.finalSelectedAccountID) == [account.id, account.id, account.id])
    #expect(fileResults.allSatisfy { $0.inferenceFeedbackContext == nil })
    #expect(store.createdSessions.map(\.originalFilename) == ["april.csv", "may.csv"])
    #expect(session.importPhase == .editing)
}

@Test
@MainActor
func confirmBatchImportStopsOnFirstUnexpectedFailureAndDoesNotAttemptLaterFiles() async throws {
    let account = batchCSVImportAccount(
        id: "00000000-0000-0000-0000-000000000602",
        name: "Checking"
    )
    let files = try BatchCSVImportSessionTestFiles.make(
        [
            ("april.csv", "Date,Description,Amount\n2026-04-01,Coffee,-4.75\n"),
            ("broken.csv", "Date,Description,Amount\nnot-a-date,Payroll,1250.00\n"),
            ("june.csv", "Date,Description,Amount\n2026-06-01,Rent,-800.00\n"),
        ]
    )
    let session = BatchCSVImportSession(
        selectedURLs: files.urls,
        importEligibleAccounts: [account]
    )
    let store = BatchCSVImportSessionExecutionStore(accounts: [account])
    let service = WorkspaceService(store: store)
    let failedItemID = try #require(
        session.draft.items.first(where: { $0.originalFilename == "broken.csv" })?.id
    )

    let result = await session.confirmBatchCSVImport(service: service, accounts: [account])

    guard case .partialFailure(let failure) = result else {
        Issue.record("Expected the batch import to stop on the broken file.")
        return
    }

    #expect(failure.failedItemID == failedItemID)
    #expect(failure.failedFilename == "broken.csv")
    #expect(failure.stagedFileCount == 1)
    #expect(
        failure.errorDescription
            == WorkspaceServiceError.importPreviewCouldNotNormalizeRow(line: 2).localizedDescription
    )
    #expect(
        failure.summary == StagedImportDecisionSummary(
            importedRowCount: 1,
            skippedRowCount: 0,
            pendingClassificationReviewRowCount: 1,
            flaggedDuplicateRowCount: 0
        )
    )
    #expect(failure.outcome == .staged)
    #expect(failure.fileResults.map(\.itemID) == [session.draft.items[0].id])
    #expect(failure.fileResults.map(\.originalFilename) == ["april.csv"])
    #expect(failure.fileResults.map(\.stagedImportSessionID) == [1])
    #expect(failure.fileResults.map(\.outcome) == [.staged])
    #expect(failure.fileResults.map(\.finalSelectedAccountID) == [account.id])
    #expect(failure.fileResults.allSatisfy { $0.inferenceFeedbackContext == nil })
    #expect(store.createdSessions.map(\.originalFilename) == ["april.csv"])
    #expect(session.draft.selectedItemID == failedItemID)
    #expect(session.importPhase == .editing)
}

@MainActor
private func preview(forItemID itemID: UUID, in session: BatchCSVImportSession) -> CSVImportPreview? {
    guard let item = session.draft.items.first(where: { $0.id == itemID }) else {
        return nil
    }

    return firstPreview(for: item)
}

private func firstPreview(for item: BatchCSVImportItemDraft) -> CSVImportPreview? {
    guard case .loaded(_, let preview) = item.content else {
        return nil
    }

    return preview
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
    batchCSVImportAccount(id: id, name: name, institutionName: "Local Bank")
}

private func batchCSVImportAccount(id: String, name: String, institutionName: String?) -> Account {
    Account(
        id: batchCSVImportAccountID(id),
        name: name,
        kind: .checking,
        institutionName: institutionName
    )
}

private func batchCSVImportAccountID(_ rawValue: String) -> UUID {
    UUID(uuidString: rawValue)!
}

private func batchCSVImportInferenceRequest(
    originalFilename: String,
    accounts: [Account]
) throws -> ImportAccountInferenceRequest {
    ImportAccountInferenceRequest(
        originalFilename: originalFilename,
        parsedArtifact: try CSVImportPreviewService().makeParsedArtifact(from: sampleBatchCSV()),
        importEligibleAccounts: accounts,
        historicalMatchCountsByAccountID: [:]
    )
}

private func sampleBatchCSV() -> String {
    """
    Date,Description,Amount
    2026-04-01,Sample transaction,-12.34
    """
}

private final class BatchCSVImportSessionExecutionStore: @unchecked Sendable, WorkspaceStoring, StagedImportWriting, ImportDecisionReading {
    let accounts: [Account]
    private(set) var createdSessions: [StagedImportSessionDraft] = []

    init(accounts: [Account]) {
        self.accounts = accounts
    }

    func fetchSummary() throws -> WorkspaceSummary {
        .empty
    }

    func fetchAccounts() throws -> [Account] {
        accounts
    }

    func fetchManagementAccounts() throws -> [Account] {
        accounts
    }

    func fetchImportEligibleAccounts() throws -> [Account] {
        accounts
    }

    func fetchLedgerFilterAccounts() throws -> [Account] {
        accounts
    }

    func fetchPermanentlyDeletableAccountIDs() throws -> Set<UUID> {
        []
    }

    func fetchCategories() throws -> [BudgetCategory] {
        []
    }

    func fetchCategoryGroups() throws -> [BudgetCategoryGroup] {
        []
    }

    func createAccount(named: String, kind: AccountKind, institutionName: String?) throws -> Account {
        Account(name: named, kind: kind, institutionName: institutionName)
    }

    func updateAccount(id: UUID, named: String, kind: AccountKind, institutionName: String?) throws -> Account {
        Account(id: id, name: named, kind: kind, institutionName: institutionName)
    }

    func archiveAccount(id: UUID, archivedAt: Date) throws -> Account {
        try #require(accounts.first(where: { $0.id == id }))
    }

    func restoreAccount(id: UUID) throws -> Account {
        try #require(accounts.first(where: { $0.id == id }))
    }

    func deleteAccountPermanently(id: UUID) throws {}

    func createStagedImportSession(_ draft: StagedImportSessionDraft) throws -> StagedImportSession {
        createdSessions.append(draft)

        let sourceFile = StagedSourceFile(
            id: Int64(createdSessions.count),
            accountID: draft.accountID,
            originalFilename: draft.originalFilename,
            contentHash: draft.contentHash,
            importedAt: draft.importedAt,
            rowCount: draft.rows.count
        )
        let rows = draft.rows.enumerated().map { index, row in
            StagedSourceRow(
                id: Int64(index + 1),
                sourceFileID: sourceFile.id,
                sourceLineNumber: row.sourceLineNumber,
                rawPayload: row.rawPayload,
                rowHash: row.rowHash,
                validationStatus: row.validationStatus,
                importDecision: row.importDecision
            )
        }

        return StagedImportSession(
            id: sourceFile.id,
            sourceFile: sourceFile,
            mapping: draft.mapping,
            validRowCount: draft.validRowCount,
            invalidRowCount: draft.invalidRowCount,
            status: draft.status,
            rows: rows
        )
    }

    func fetchExistingSourceRowHashes(accountID: UUID, rowHashes: Set<String>) throws -> Set<String> {
        []
    }

    func fetchExistingSourceRowHashCounts(accountID: UUID, rowHashes: Set<String>) throws -> [String: Int] {
        let existingHashes = Set(
            createdSessions
                .filter { $0.accountID == accountID }
                .flatMap(\.rows)
                .map(\.rowHash)
                .filter { rowHashes.contains($0) }
        )
        return Dictionary(uniqueKeysWithValues: existingHashes.map { ($0, 1) })
    }

    func fetchLikelyDuplicateTransactions(
        accountID: UUID,
        candidates: [NormalizedImportCandidate]
    ) throws -> [LikelyDuplicateCandidate] {
        []
    }
}
