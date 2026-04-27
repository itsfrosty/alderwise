import Application
import Domain
import Foundation
import SwiftUI
import Testing

@testable import AlderwiseApp

@Suite
struct WorkspaceShellModelBatchCSVImportTests {
    @Test
    func accountCreationSheetStatePreservesEnteredValuesOnValidationFailure() {
        var state = AccountCreationSheetState(
            name: "   ",
            institutionName: "Local Bank",
            kind: .savings,
            errorMessage: nil
        )

        let didSubmit = state.submit { _, _, _ in
            Issue.record("Validation failures should not call onCreate.")
        }

        #expect(didSubmit == false)
        #expect(state.name == "   ")
        #expect(state.institutionName == "Local Bank")
        #expect(state.kind == .savings)
        #expect(state.errorMessage == "Enter an account name.")
    }

    @Test
    func accountCreationSheetStatePreservesEnteredValuesOnServiceFailure() {
        var state = AccountCreationSheetState(
            name: "Travel Card",
            institutionName: "Visa",
            kind: .creditCard,
            errorMessage: nil
        )

        let didSubmit = state.submit { _, _, _ in
            throw BatchCSVImportTestError(message: "Create failed")
        }

        #expect(didSubmit == false)
        #expect(state.name == "Travel Card")
        #expect(state.institutionName == "Visa")
        #expect(state.kind == .creditCard)
        #expect(state.errorMessage == "Create failed")
    }

    @Test
    @MainActor
    func generalAndImportScopedAccountCreationRoutesRemainDistinguishable() throws {
        let model = makeModel()
        let session = try makeBatchImportSession(
            importEligibleAccounts: [existingAccount(id: "00000000-0000-0000-0000-000000000401", name: "Checking")]
        )
        let itemID = try #require(session.draft.items.first?.id)

        model.beginAccountCreation()
        #expect(model.accountCreationRoute == .general)

        model.presentBatchImportSession(session)
        model.beginBatchImportAccountCreation(itemID: itemID)

        #expect(model.accountCreationRoute == .batchImport(itemID: itemID))
    }

    @Test
    @MainActor
    func accountCreationPresentationBindingsSplitGeneralAndBatchImportRoutes() throws {
        let model = makeModel()
        let session = try makeBatchImportSession(
            importEligibleAccounts: [existingAccount(id: "00000000-0000-0000-0000-000000000405", name: "Checking")]
        )
        let itemID = try #require(session.draft.items.first?.id)

        model.presentBatchImportSession(session)

        let generalBinding = WorkspaceRootView.generalAccountCreationSheetBinding(for: model)
        let batchBinding = WorkspaceRootView.batchImportAccountCreationSheetBinding(for: model)

        #expect(generalBinding.wrappedValue == false)
        #expect(batchBinding.wrappedValue == false)

        model.beginAccountCreation()

        #expect(generalBinding.wrappedValue == true)
        #expect(batchBinding.wrappedValue == false)

        model.beginBatchImportAccountCreation(itemID: itemID)

        #expect(generalBinding.wrappedValue == false)
        #expect(batchBinding.wrappedValue == true)
    }

    @Test
    @MainActor
    func accountCreationPresentationBindingsCancelThroughTheSharedModelHandler() throws {
        let model = makeModel()
        let session = try makeBatchImportSession(
            importEligibleAccounts: [existingAccount(id: "00000000-0000-0000-0000-000000000406", name: "Checking")]
        )
        let itemID = try #require(session.draft.items.first?.id)

        model.presentBatchImportSession(session)

        let generalBinding = WorkspaceRootView.generalAccountCreationSheetBinding(for: model)
        let batchBinding = WorkspaceRootView.batchImportAccountCreationSheetBinding(for: model)

        model.beginAccountCreation()
        generalBinding.wrappedValue = false
        #expect(model.accountCreationRoute == nil)

        model.beginBatchImportAccountCreation(itemID: itemID)
        batchBinding.wrappedValue = false
        #expect(model.accountCreationRoute == nil)
    }

    @Test
    @MainActor
    func openingAccountCreationFromABatchItemRecordsTheTriggerAndCancelKeepsTheSelectedItem() throws {
        let model = makeModel()
        let session = try makeBatchImportSession(
            importEligibleAccounts: [
                existingAccount(id: "00000000-0000-0000-0000-000000000402", name: "Checking"),
                existingAccount(id: "00000000-0000-0000-0000-000000000403", name: "Savings"),
            ]
        )
        let triggeringItemID = try #require(session.draft.items.first?.id)
        let selectedItemID = try #require(session.draft.items.last?.id)

        session.selectItem(id: selectedItemID)
        model.presentBatchImportSession(session)

        model.beginBatchImportAccountCreation(itemID: triggeringItemID)
        #expect(model.accountCreationRoute == .batchImport(itemID: triggeringItemID))
        #expect(model.batchImportSession?.draft.selectedItemID == selectedItemID)

        model.cancelAccountCreation()

        #expect(model.accountCreationRoute == nil)
        #expect(model.batchImportSession?.draft.selectedItemID == selectedItemID)
    }

    @Test
    @MainActor
    func accountCreationFailureKeepsTheImportScopedRouteOpenAndPreservesBatchSelection() throws {
        let store = WorkspaceShellModelBatchCSVImportStore()
        store.createAccountError = BatchCSVImportTestError(message: "Create failed")
        let model = makeModel(store: store)
        let session = try makeBatchImportSession(
            importEligibleAccounts: [store.initialAccount]
        )
        let triggeringItemID = try #require(session.draft.items.first?.id)
        let selectedItemID = try #require(session.draft.items.last?.id)
        let originalAccountIDs = session.draft.items.map(\.selectedAccountID)

        session.selectItem(id: selectedItemID)
        model.presentBatchImportSession(session)
        model.beginBatchImportAccountCreation(itemID: triggeringItemID)

        #expect(throws: BatchCSVImportTestError.self) {
            try model.createAccount(name: "Travel Card", kind: .creditCard, institutionName: "Visa")
        }

        #expect(model.accountCreationRoute == .batchImport(itemID: triggeringItemID))
        #expect(model.batchImportSession?.draft.selectedItemID == selectedItemID)
        #expect(model.batchImportSession?.draft.items.map(\.selectedAccountID) == originalAccountIDs)
    }

    @Test
    @MainActor
    func replacingBatchImportSessionClearsTheImportScopedAccountCreationRoute() throws {
        let store = WorkspaceShellModelBatchCSVImportStore()
        let model = makeModel(store: store)
        let originalSession = try makeBatchImportSession(
            importEligibleAccounts: [store.initialAccount]
        )
        let triggeringItemID = try #require(originalSession.draft.items.first?.id)

        model.presentBatchImportSession(originalSession)
        model.beginBatchImportAccountCreation(itemID: triggeringItemID)

        let replacementSession = try makeBatchImportSession(
            importEligibleAccounts: [store.initialAccount]
        )
        model.presentBatchImportSession(replacementSession)

        #expect(model.accountCreationRoute == nil)
        #expect(model.snapshot.importEligibleAccounts.map(\.id) == [store.initialAccount.id])
    }

    @Test
    @MainActor
    func successfulCreateClearsTheRouteAndAssignsTheNewAccountOnlyToTheTriggeringBatchItem() throws {
        let store = WorkspaceShellModelBatchCSVImportStore()
        let model = makeModel(store: store)
        let session = try makeBatchImportSession(
            importEligibleAccounts: [store.initialAccount]
        )
        let firstItemID = try #require(session.draft.items.first?.id)
        let secondItemID = try #require(session.draft.items.last?.id)
        let originalAccountID = try #require(session.draft.items.first?.selectedAccountID)

        model.presentBatchImportSession(session)
        model.beginBatchImportAccountCreation(itemID: secondItemID)

        let createdAccount = try model.createAccount(
            name: "Travel Card",
            kind: .creditCard,
            institutionName: "Visa"
        )

        #expect(model.accountCreationRoute == nil)
        #expect(model.batchImportSession?.draft.selectedItemID == firstItemID)
        #expect(accountID(for: firstItemID, in: model) == originalAccountID)
        #expect(accountID(for: secondItemID, in: model) == createdAccount.id)
        #expect(model.snapshot.importEligibleAccounts.map(\.id) == [originalAccountID, createdAccount.id])
    }

    @Test
    @MainActor
    func importingOneCSVOpensTheBatchPreflightFlowInsteadOfTheLegacyPreviewSheet() throws {
        let files = try BatchCSVImportSessionTestFiles.make(
            [("checking-april.csv", "Date,Description,Amount\n2026-04-01,Coffee,-4.75\n")]
        )
        let model = makeModel()

        model.importCSV(from: .success(files.urls))

        #expect(model.batchImportSession?.draft.items.map(\.originalFilename) == ["checking-april.csv"])
        #expect(model.batchImportSession?.draft.selectedItem?.originalFilename == "checking-april.csv")
        #expect(model.importErrorMessage == nil)
    }

    @Test
    @MainActor
    func importingMultipleCSVFilesCreatesOneBatchSessionAndSelectsTheFirstBlockedFile() throws {
        let files = try BatchCSVImportSessionTestFiles.make(
            [
                ("ready.csv", "Date,Description,Amount\n2026-04-01,Coffee,-4.75\n"),
                ("blocked.csv", "Date,Description,Amount\n2026-04-01,Coffee\n"),
                ("later.csv", "Date,Description,Amount\n2026-04-02,Payroll,1200.00\n"),
            ]
        )
        let model = makeModel()

        model.importCSV(from: .success(files.urls))

        #expect(model.batchImportSession?.draft.items.map(\.originalFilename) == ["ready.csv", "blocked.csv", "later.csv"])
        #expect(model.batchImportSession?.draft.selectedItem?.originalFilename == "blocked.csv")
        #expect(model.batchImportSession?.draft.isReadyForImport == false)
        #expect(model.importErrorMessage == nil)
    }

    @Test
    @MainActor
    func importingMultipleCSVFilesWithMultipleAccountsPrecomputesInferenceStates() throws {
        let files = try BatchCSVImportSessionTestFiles.make(
            [
                ("2026-04_chase_sapphire_reserve_statement.csv", "Date,Description,Amount\n2026-04-01,Coffee,-4.75\n"),
                ("2026-04_chase_statement.csv", "Date,Description,Amount\n2026-04-02,Travel credit,20.00\n"),
                ("generic_statement.csv", "Date,Description,Amount\n2026-04-03,Groceries,-45.21\n"),
            ]
        )
        let store = WorkspaceShellModelBatchCSVImportStore(
            initialAccounts: [
                existingAccount(
                    id: "00000000-0000-0000-0000-000000000451",
                    name: "Checking",
                    institutionName: "Local Credit Union"
                ),
                existingAccount(
                    id: "00000000-0000-0000-0000-000000000452",
                    name: "Sapphire Reserve",
                    institutionName: "Chase"
                ),
            ]
        )
        let model = makeModel(store: store)

        model.importCSV(from: .success(files.urls))

        let highConfidenceItem = try #require(
            model.batchImportSession?.draft.items.first(where: { $0.originalFilename == "2026-04_chase_sapphire_reserve_statement.csv" })
        )
        let mediumConfidenceItem = try #require(
            model.batchImportSession?.draft.items.first(where: { $0.originalFilename == "2026-04_chase_statement.csv" })
        )
        let lowConfidenceItem = try #require(
            model.batchImportSession?.draft.items.first(where: { $0.originalFilename == "generic_statement.csv" })
        )

        #expect(highConfidenceItem.selectionSource == .inferred)
        #expect(highConfidenceItem.selectedAccountID == store.accounts[1].id)
        #expect(mediumConfidenceItem.selectionSource == .suggested)
        #expect(mediumConfidenceItem.selectedAccountID == store.accounts[1].id)
        #expect(lowConfidenceItem.selectionSource == .unassigned)
        #expect(lowConfidenceItem.selectedAccountID == nil)
        #expect(model.batchImportSession?.draft.selectedItem?.originalFilename == "generic_statement.csv")
    }

    @Test
    @MainActor
    func creatingAccountReevaluatesStillUnassignedBatchItemsWithoutMutatingManualRows() throws {
        let checking = existingAccount(
            id: "00000000-0000-0000-0000-000000000461",
            name: "Checking",
            institutionName: "Local Credit Union"
        )
        let savings = existingAccount(
            id: "00000000-0000-0000-0000-000000000462",
            name: "Savings",
            institutionName: "Neighborhood Bank"
        )
        let files = try BatchCSVImportSessionTestFiles.make(
            [
                ("2026-04_amex_travel_card_statement_a.csv", "Date,Description,Amount\n2026-04-01,Flight,-320.00\n"),
                ("2026-04_amex_travel_card_statement_b.csv", "Date,Description,Amount\n2026-04-02,Hotel,-180.00\n"),
            ]
        )
        let store = WorkspaceShellModelBatchCSVImportStore(initialAccounts: [checking, savings])
        let model = makeModel(store: store)

        model.importCSV(from: .success(files.urls))
        let manualItemID = try #require(model.batchImportSession?.draft.items.first?.id)
        let untouchedItemID = try #require(model.batchImportSession?.draft.items.last?.id)

        #expect(model.batchImportSession?.setSelectedAccount(id: checking.id, forItemID: manualItemID) == true)

        let createdAccount = try model.createAccount(
            name: "Travel Card",
            kind: .creditCard,
            institutionName: "Amex"
        )

        let manualItem = try #require(
            model.batchImportSession?.draft.items.first(where: { $0.id == manualItemID })
        )
        let reevaluatedItem = try #require(
            model.batchImportSession?.draft.items.first(where: { $0.id == untouchedItemID })
        )

        #expect(manualItem.selectedAccountID == checking.id)
        #expect(manualItem.selectionSource == .manual)
        #expect(reevaluatedItem.selectedAccountID == createdAccount.id)
        #expect(reevaluatedItem.selectionSource == .inferred)
    }

    @Test
    @MainActor
    func creatingFirstEligibleAccountAppliesSingleAccountConvenienceToRemainingUnassignedRows() throws {
        let files = try BatchCSVImportSessionTestFiles.make(
            [
                ("first.csv", "Date,Description,Amount\n2026-04-01,Coffee,-4.75\n"),
                ("second.csv", "Date,Description,Amount\n2026-04-02,Tea,-3.25\n"),
            ]
        )
        let store = WorkspaceShellModelBatchCSVImportStore(initialAccounts: [])
        let model = makeModel(store: store)

        model.importCSV(from: .success(files.urls))
        let firstItemID = try #require(model.batchImportSession?.draft.items.first?.id)
        let secondItemID = try #require(model.batchImportSession?.draft.items.last?.id)

        model.beginBatchImportAccountCreation(itemID: firstItemID)
        let createdAccount = try model.createAccount(
            name: "Checking",
            kind: .checking,
            institutionName: "Local Bank"
        )

        #expect(accountID(for: firstItemID, in: model) == createdAccount.id)
        #expect(accountID(for: secondItemID, in: model) == createdAccount.id)
        #expect(
            model.batchImportSession?.draft.items.first(where: { $0.id == secondItemID })?.selectionSource
                == BatchCSVImportItemDraft.AccountSelectionSource.singleEligibleAccount
        )
    }

    @Test
    @MainActor
    func confirmingBatchImportAggregatesMixedStagedAndExactReimportResultsIntoOneSuccessMessage() async throws {
        let files = try BatchCSVImportSessionTestFiles.make(
            [
                ("april.csv", "Date,Description,Amount\n2026-04-01,Coffee,-4.75\n"),
                ("april-renamed.csv", "Date,Description,Amount\n2026-04-01,Coffee,-4.75\n"),
                ("may.csv", "Date,Description,Amount\n2026-05-01,Payroll,1250.00\n"),
            ]
        )
        let store = WorkspaceShellModelBatchCSVImportStore()
        let model = makeModel(store: store)

        model.importCSV(from: .success(files.urls))
        model.confirmBatchCSVImport()
        #expect(model.batchImportSession?.importPhase == .staging)

        await waitForBatchImportCompletion(in: model)

        #expect(model.batchImportSession == nil)
        #expect(model.importErrorMessage == nil)
        #expect(
            model.importResultMessage
                == "2 imported to Transactions, 1 skipped, 2 sent to Review, 0 likely duplicates waiting in Review."
        )
        #expect(store.createdSessions.map(\.originalFilename) == ["april.csv", "may.csv"])
    }

    @Test
    @MainActor
    func confirmingBatchImportKeepsBatchOpenOnFirstUnexpectedFailureAndSelectsTheFailingItem() async throws {
        let files = try BatchCSVImportSessionTestFiles.make(
            [
                ("broken.csv", "Date,Description,Amount\nnot-a-date,Coffee,-4.75\n"),
                ("later.csv", "Date,Description,Amount\n2026-05-01,Payroll,1250.00\n"),
            ]
        )
        let store = WorkspaceShellModelBatchCSVImportStore()
        let model = makeModel(store: store)

        model.importCSV(from: .success(files.urls))
        model.confirmBatchCSVImport()
        #expect(model.batchImportSession?.importPhase == .staging)

        await waitForBatchImportCompletion(in: model)

        #expect(model.batchImportSession?.draft.selectedItem?.originalFilename == "broken.csv")
        #expect(model.importResultMessage == nil)
        #expect(model.importErrorMessage?.contains("broken.csv") == true)
        #expect(model.importErrorMessage?.contains("No files were staged") == true)
        #expect(store.createdSessions.isEmpty)
    }

    @Test
    @MainActor
    func confirmingBatchImportStopsAfterLaterFailurePreservesEarlierStagesAndDoesNotAttemptRemainingFiles() async throws {
        let files = try BatchCSVImportSessionTestFiles.make(
            [
                ("april.csv", "Date,Description,Amount\n2026-04-01,Coffee,-4.75\n"),
                ("broken.csv", "Date,Description,Amount\nnot-a-date,Payroll,1250.00\n"),
                ("june.csv", "Date,Description,Amount\n2026-06-01,Rent,-800.00\n"),
            ]
        )
        let store = WorkspaceShellModelBatchCSVImportStore()
        let model = makeModel(store: store)

        model.importCSV(from: .success(files.urls))
        model.confirmBatchCSVImport()
        #expect(model.batchImportSession?.importPhase == .staging)

        await waitForBatchImportCompletion(in: model)

        #expect(model.batchImportSession?.draft.selectedItem?.originalFilename == "broken.csv")
        #expect(model.importResultMessage == nil)
        #expect(model.importErrorMessage?.contains("broken.csv") == true)
        #expect(model.importErrorMessage?.contains("1 file was staged") == true)
        #expect(store.createdSessions.map(\.originalFilename) == ["april.csv"])
    }

    @Test
    @MainActor
    func confirmingBatchImportRecordsAcceptedOverrideAndManualFeedbackForStagedFiles() async throws {
        let files = try BatchCSVImportSessionTestFiles.make(
            [
                ("2026-04_chase_sapphire_reserve_statement.csv", "Date,Description,Amount\n2026-04-01,Coffee,-4.75\n"),
                ("2026-04_chase_statement_override.csv", "Date,Description,Amount\n2026-04-02,Travel credit,20.00\n"),
                ("generic_statement.csv", "Date,Description,Amount\n2026-04-03,Groceries,-45.21\n"),
                ("2026-04_chase_sapphire_reserve_statement_copy.csv", "Date,Description,Amount\n2026-04-01,Coffee,-4.75\n"),
            ]
        )
        let checking = existingAccount(
            id: "00000000-0000-0000-0000-000000000471",
            name: "Checking",
            institutionName: "Local Credit Union"
        )
        let sapphire = existingAccount(
            id: "00000000-0000-0000-0000-000000000472",
            name: "Sapphire Reserve",
            institutionName: "Chase"
        )
        let store = WorkspaceShellModelBatchCSVImportStore(initialAccounts: [checking, sapphire])
        let model = makeModel(store: store)

        model.importCSV(from: .success(files.urls))

        let acceptedItemID = try #require(
            model.batchImportSession?.draft.items.first(where: {
                $0.originalFilename == "2026-04_chase_sapphire_reserve_statement.csv"
            })?.id
        )
        let overrideItemID = try #require(
            model.batchImportSession?.draft.items.first(where: {
                $0.originalFilename == "2026-04_chase_statement_override.csv"
            })?.id
        )
        let manualItemID = try #require(
            model.batchImportSession?.draft.items.first(where: {
                $0.originalFilename == "generic_statement.csv"
            })?.id
        )

        #expect(model.batchImportSession?.setSelectedAccount(id: checking.id, forItemID: acceptedItemID) == true)
        #expect(model.batchImportSession?.setSelectedAccount(id: sapphire.id, forItemID: acceptedItemID) == true)
        #expect(model.batchImportSession?.setSelectedAccount(id: checking.id, forItemID: overrideItemID) == true)
        #expect(model.batchImportSession?.setSelectedAccount(id: checking.id, forItemID: manualItemID) == true)

        model.confirmBatchCSVImport()
        await waitForBatchImportCompletion(in: model)

        #expect(model.importErrorMessage == nil)
        #expect(model.batchImportSession == nil)
        #expect(store.createdSessions.map(\.originalFilename) == [
            "2026-04_chase_sapphire_reserve_statement.csv",
            "2026-04_chase_statement_override.csv",
            "generic_statement.csv",
        ])
        #expect(store.recordedImportInferenceFeedback.map(\.originalFilename) == [
            "2026-04_chase_sapphire_reserve_statement.csv",
            "2026-04_chase_statement_override.csv",
            "generic_statement.csv",
        ])
        #expect(store.recordedImportInferenceFeedback.map(\.kind) == [
            .acceptedSuggestion,
            .overrodeSuggestion,
            .manualAssignment,
        ])
        #expect(store.recordedImportInferenceFeedback.map(\.selectedAccountID) == [
            sapphire.id,
            checking.id,
            checking.id,
        ])
        #expect(store.recordedImportInferenceFeedback.map(\.suggestedAccountID) == [
            sapphire.id,
            sapphire.id,
            nil,
        ])
        #expect(store.recordedImportInferenceFeedback.map(\.stagedImportSessionID) == [1, 2, 3])
    }

    @Test
    @MainActor
    func confirmingBatchImportSkipsInferenceFeedbackForSingleAccountConvenienceRows() async throws {
        let files = try BatchCSVImportSessionTestFiles.make(
            [("checking-april.csv", "Date,Description,Amount\n2026-04-01,Coffee,-4.75\n")]
        )
        let checking = existingAccount(
            id: "00000000-0000-0000-0000-000000000473",
            name: "Checking",
            institutionName: "Local Credit Union"
        )
        let store = WorkspaceShellModelBatchCSVImportStore(initialAccounts: [checking])
        let model = makeModel(store: store)

        model.importCSV(from: .success(files.urls))
        model.confirmBatchCSVImport()
        await waitForBatchImportCompletion(in: model)

        #expect(model.importErrorMessage == nil)
        #expect(store.createdSessions.map(\.originalFilename) == ["checking-april.csv"])
        #expect(store.recordedImportInferenceFeedback.isEmpty)
    }

    @Test
    @MainActor
    func retryingBatchImportAfterPartialFailureDoesNotDuplicateFeedbackForEarlierStagedFiles() async throws {
        let files = try BatchCSVImportSessionTestFiles.make(
            [
                ("2026-04_chase_sapphire_reserve_statement.csv", "Date,Description,Amount\n2026-04-01,Coffee,-4.75\n"),
                ("generic_statement.csv", "Date,Description,Amount\n2026-04-03,Groceries,-45.21\n"),
            ]
        )
        let checking = existingAccount(
            id: "00000000-0000-0000-0000-000000000474",
            name: "Checking",
            institutionName: "Local Credit Union"
        )
        let sapphire = existingAccount(
            id: "00000000-0000-0000-0000-000000000475",
            name: "Sapphire Reserve",
            institutionName: "Chase"
        )
        let store = WorkspaceShellModelBatchCSVImportStore(initialAccounts: [checking, sapphire])
        store.createSessionFailuresByFilename = [
            "generic_statement.csv": [BatchCSVImportTestError(message: "Temporary staging failure")]
        ]
        let model = makeModel(store: store)

        model.importCSV(from: .success(files.urls))
        let manualItemID = try #require(
            model.batchImportSession?.draft.items.first(where: { $0.originalFilename == "generic_statement.csv" })?.id
        )
        #expect(model.batchImportSession?.setSelectedAccount(id: checking.id, forItemID: manualItemID) == true)

        model.confirmBatchCSVImport()
        await waitForBatchImportCompletion(in: model)

        #expect(model.importResultMessage == nil)
        #expect(model.importErrorMessage?.contains("generic_statement.csv") == true)
        #expect(store.recordedImportInferenceFeedback.map(\.originalFilename) == [
            "2026-04_chase_sapphire_reserve_statement.csv"
        ])
        #expect(store.recordedImportInferenceFeedback.map(\.kind) == [.acceptedSuggestion])

        model.confirmBatchCSVImport()
        await waitForBatchImportCompletion(in: model)

        #expect(model.importErrorMessage == nil)
        #expect(model.batchImportSession == nil)
        #expect(store.createdSessions.map(\.originalFilename) == [
            "2026-04_chase_sapphire_reserve_statement.csv",
            "generic_statement.csv",
        ])
        #expect(store.recordedImportInferenceFeedback.map(\.originalFilename) == [
            "2026-04_chase_sapphire_reserve_statement.csv",
            "generic_statement.csv",
        ])
        #expect(store.recordedImportInferenceFeedback.map(\.kind) == [
            .acceptedSuggestion,
            .manualAssignment,
        ])
        #expect(store.recordedImportInferenceFeedback.map(\.stagedImportSessionID) == [1, 2])
    }

    @Test
    @MainActor
    func feedbackWriteFailuresDoNotChangeSuccessfulBatchImportUserFeedback() async throws {
        let files = try BatchCSVImportSessionTestFiles.make(
            [("2026-04_chase_sapphire_reserve_statement.csv", "Date,Description,Amount\n2026-04-01,Coffee,-4.75\n")]
        )
        let checking = existingAccount(
            id: "00000000-0000-0000-0000-000000000478",
            name: "Checking",
            institutionName: "Local Credit Union"
        )
        let sapphire = existingAccount(
            id: "00000000-0000-0000-0000-000000000479",
            name: "Sapphire Reserve",
            institutionName: "Chase"
        )
        let store = WorkspaceShellModelBatchCSVImportStore(initialAccounts: [checking, sapphire])
        store.recordImportInferenceFeedbackError = BatchCSVImportTestError(message: "Feedback write failed")
        let model = makeModel(store: store)

        model.importCSV(from: .success(files.urls))
        model.confirmBatchCSVImport()
        await waitForBatchImportCompletion(in: model)

        #expect(model.batchImportSession == nil)
        #expect(model.importErrorMessage == nil)
        #expect(
            model.importResultMessage
                == "1 imported to Transactions, 0 skipped, 1 sent to Review, 0 likely duplicates waiting in Review."
        )
        #expect(store.createdSessions.map(\.originalFilename) == [
            "2026-04_chase_sapphire_reserve_statement.csv"
        ])
        #expect(store.recordedImportInferenceFeedback.isEmpty)
    }

    @MainActor
    private func makeModel(
        store: WorkspaceShellModelBatchCSVImportStore = WorkspaceShellModelBatchCSVImportStore()
    ) -> WorkspaceShellModel {
        WorkspaceShellModel(store: nil, service: WorkspaceService(store: store))
    }

    @MainActor
    private func makeBatchImportSession(
        importEligibleAccounts: [Account]
    ) throws -> BatchCSVImportSession {
        let files = try BatchCSVImportSessionTestFiles.make(
            [
                ("checking-april.csv", "Date,Description,Amount\n2026-04-01,Coffee,-4.75\n"),
                ("checking-may.csv", "Date,Description,Amount\n2026-05-01,Payroll,1250.00\n"),
            ]
        )

        return BatchCSVImportSession(
            selectedURLs: files.urls,
            importEligibleAccounts: importEligibleAccounts
        )
    }

    @MainActor
    private func accountID(for itemID: UUID, in model: WorkspaceShellModel) -> UUID? {
        model.batchImportSession?.draft.items.first(where: { $0.id == itemID })?.selectedAccountID
    }

    @MainActor
    private func waitForBatchImportCompletion(
        in model: WorkspaceShellModel,
        maxYields: Int = 20
    ) async {
        for _ in 0..<maxYields {
            if model.batchImportSession == nil || model.importErrorMessage != nil || model.importResultMessage != nil {
                return
            }
            await Task.yield()
        }

        Issue.record("Timed out waiting for batch import completion.")
    }
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

private struct BatchCSVImportTestError: Error, Equatable, LocalizedError {
    let message: String

    var errorDescription: String? { message }
}

private final class WorkspaceShellModelBatchCSVImportStore: @unchecked Sendable, WorkspaceStoring, StagedImportWriting, ImportDecisionReading, ImportAccountInferenceWriting, TargetManaging, WorkspaceMaintenanceManaging, WorkspacePreferencesManaging {
    struct RecordedImportInferenceFeedback: Equatable {
        enum Kind: Equatable {
            case acceptedSuggestion
            case overrodeSuggestion
            case manualAssignment
        }

        var stagedImportSessionID: Int64?
        var originalFilename: String
        var selectedAccountID: UUID
        var suggestedAccountID: UUID?
        var kind: Kind
    }

    let initialAccount = existingAccount(
        id: "00000000-0000-0000-0000-000000000404",
        name: "Checking"
    )

    var createAccountError: BatchCSVImportTestError?
    var createSessionFailuresByFilename: [String: [BatchCSVImportTestError]] = [:]
    var recordImportInferenceFeedbackError: BatchCSVImportTestError?
    private(set) var createdSessions: [StagedImportSessionDraft] = []
    private(set) var recordedImportInferenceFeedback: [RecordedImportInferenceFeedback] = []

    private(set) var accounts: [Account]

    init(initialAccounts: [Account]? = nil) {
        accounts = initialAccounts ?? [initialAccount]
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
        if let createAccountError {
            throw createAccountError
        }

        let account = Account(name: named, kind: kind, institutionName: institutionName)
        accounts.append(account)
        return account
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
        if var failures = createSessionFailuresByFilename[draft.originalFilename], failures.isEmpty == false {
            let failure = failures.removeFirst()
            createSessionFailuresByFilename[draft.originalFilename] = failures
            throw failure
        }

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

    func recordImportAccountInferenceFeedback(
        for query: ImportAccountInferenceEvidenceQuery,
        stagedImportSessionID: Int64?,
        selectedAccountID: UUID,
        suggestedAccountID: UUID?
    ) throws {
        if let recordImportInferenceFeedbackError {
            throw recordImportInferenceFeedbackError
        }

        let kind: RecordedImportInferenceFeedback.Kind
        if let suggestedAccountID {
            kind = suggestedAccountID == selectedAccountID ? .acceptedSuggestion : .overrodeSuggestion
        } else {
            kind = .manualAssignment
        }

        let feedback = RecordedImportInferenceFeedback(
            stagedImportSessionID: stagedImportSessionID,
            originalFilename: query.originalFilename,
            selectedAccountID: selectedAccountID,
            suggestedAccountID: suggestedAccountID,
            kind: kind
        )

        if let stagedImportSessionID,
           let existingIndex = recordedImportInferenceFeedback.firstIndex(where: {
               $0.stagedImportSessionID == stagedImportSessionID
           }) {
            recordedImportInferenceFeedback[existingIndex] = feedback
        } else {
            recordedImportInferenceFeedback.append(feedback)
        }
    }

    func fetchManagedTargets(referenceDate: Date) throws -> [ManagedMonthlyTarget] {
        []
    }

    func createMonthlyTarget(_ draft: MonthlyTargetDraft, createdAt: Date) throws -> MonthlyTarget {
        fatalError("Not used in this test")
    }

    func updateMonthlyTarget(id: UUID, _ draft: MonthlyTargetDraft) throws -> MonthlyTarget {
        fatalError("Not used in this test")
    }

    func deleteMonthlyTarget(id: UUID) throws {}

    func fetchWorkspaceMetadata() throws -> WorkspaceMetadata {
        WorkspaceMetadata(
            databaseURL: URL(fileURLWithPath: "/tmp/alderwise-batch-import.sqlite"),
            databaseExists: true,
            databaseSizeBytes: 0,
            modifiedAt: nil
        )
    }

    func createWorkspaceBackup(in directory: URL?, now: Date) throws -> WorkspaceBackup {
        fatalError("Not used in this test")
    }

    func restoreWorkspaceBackup(
        from backupURL: URL,
        safetyBackupDirectory: URL?,
        now: Date
    ) throws -> WorkspaceRestoreResult {
        fatalError("Not used in this test")
    }

    func resetWorkspace() throws -> WorkspaceResetResult {
        fatalError("Not used in this test")
    }

    func fetchWorkspacePreferences() throws -> WorkspacePreferences {
        .default
    }

    func updateWorkspacePreferences(_ preferences: WorkspacePreferences) throws {}
}

private func existingAccount(id: String, name: String, institutionName: String? = "Local Bank") -> Account {
    Account(
        id: UUID(uuidString: id)!,
        name: name,
        kind: .checking,
        institutionName: institutionName
    )
}
