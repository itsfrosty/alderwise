import Application
import Domain
import Foundation
import SwiftUI

enum BatchCSVImportPhase: Equatable {
    case editing
    case staging
    case importing(currentIndex: Int, totalCount: Int)

    var isExecuting: Bool {
        switch self {
        case .editing:
            false
        case .staging, .importing:
            true
        }
    }
}

struct BatchCSVImportFailureContext: Equatable {
    var failedItemID: UUID
    var failedFilename: String
    var stagedFileCount: Int
    var errorDescription: String
    var summary: StagedImportDecisionSummary
    var outcome: StagedCSVImportOutcome?
    var fileResults: [BatchCSVImportFileResult]
}

struct BatchCSVImportFileResult: Equatable {
    var itemID: UUID
    var originalFilename: String
    var stagedImportSessionID: Int64?
    var outcome: StagedCSVImportOutcome
    var finalSelectedAccountID: UUID
    var inferenceFeedbackContext: ImportAccountInferenceFeedbackContext?
}

enum BatchCSVImportRunResult: Equatable {
    case success(
        summary: StagedImportDecisionSummary,
        outcome: StagedCSVImportOutcome,
        fileResults: [BatchCSVImportFileResult]
    )
    case partialFailure(BatchCSVImportFailureContext)
}

@MainActor
final class BatchCSVImportSession: ObservableObject {
    typealias ImportAccountInferrer = (ImportAccountInferenceRequest) -> ImportAccountInferenceResult

    @Published private(set) var draft: BatchCSVImportDraft
    @Published private(set) var importPhase: BatchCSVImportPhase = .editing

    init(
        selectedURLs: [URL],
        importEligibleAccounts: [Account],
        previewService: CSVImportPreviewService = CSVImportPreviewService(),
        initialInferenceRequestsByURL: [URL: ImportAccountInferenceRequest] = [:],
        initialInferenceResultsByURL: [URL: ImportAccountInferenceResult] = [:]
    ) {
        let items = selectedURLs.map { url in
            let content = Self.loadContent(from: url, previewService: previewService)
            let inferenceRequest = initialInferenceRequestsByURL[url]
            let inferenceResult = initialInferenceResultsByURL[url]
            return BatchCSVImportItemDraft(
                originalFilename: url.lastPathComponent,
                content: content,
                selectedAccountID: nil,
                initialInferenceDisposition: nil,
                initialInferredOrSuggestedAccountID: nil,
                selectionSource: .unassigned,
                inferenceFeedbackContext: nil,
                importAccountInferenceRequest: inferenceRequest,
                initialInferenceResult: inferenceResult
            )
        }
        .map { item in
            Self.configuredInitialItem(
                from: item,
                importEligibleAccounts: importEligibleAccounts
            )
        }

        draft = BatchCSVImportDraft(
            items: items,
            selectedItemID: Self.initialSelectionID(in: items)
        )
    }

    func selectItem(id: UUID?) {
        guard importPhase.isExecuting == false else {
            return
        }
        draft.selectedItemID = id
    }

    func containsItem(id itemID: UUID) -> Bool {
        draft.items.contains { $0.id == itemID }
    }

    func setImportPhase(_ phase: BatchCSVImportPhase) {
        importPhase = phase
    }

    @discardableResult
    func setSelectedAccount(id accountID: UUID?, forItemID itemID: UUID) -> Bool {
        guard importPhase.isExecuting == false else {
            return false
        }
        guard let index = draft.items.firstIndex(where: { $0.id == itemID }) else {
            return false
        }

        draft.items[index].selectedAccountID = accountID
        draft.items[index].selectionSource = .manual
        return true
    }

    @discardableResult
    func selectAccount(id accountID: UUID, forItemID itemID: UUID) -> Bool {
        setSelectedAccount(id: accountID, forItemID: itemID)
    }

    @discardableResult
    func updateMapping(_ mapping: CSVColumnMapping, forItemID itemID: UUID) -> Bool {
        guard importPhase.isExecuting == false else {
            return false
        }
        guard let index = draft.items.firstIndex(where: { $0.id == itemID }) else {
            return false
        }
        guard case .loaded(let csvText, let preview) = draft.items[index].content else {
            return false
        }

        draft.items[index].content = .loaded(
            csvText: csvText,
            preview: preview.applying(mapping: mapping)
        )
        return true
    }

    @discardableResult
    func removeItem(id itemID: UUID) -> Bool {
        guard importPhase.isExecuting == false else {
            return false
        }
        guard let index = draft.items.firstIndex(where: { $0.id == itemID }) else {
            return false
        }

        draft.items.remove(at: index)

        if draft.selectedItemID == itemID {
            draft.selectedItemID = Self.initialSelectionID(in: draft.items)
        } else if draft.selectedItemID != nil, draft.selectedItem == nil {
            draft.selectedItemID = Self.initialSelectionID(in: draft.items)
        }

        return true
    }

    func reevaluateUnassignedItems(
        importEligibleAccounts: [Account],
        using accountInferrer: ImportAccountInferrer
    ) {
        guard importPhase.isExecuting == false else {
            return
        }

        for index in draft.items.indices where draft.items[index].shouldReevaluateInference {
            if let onlyAccount = importEligibleAccounts.onlyElement {
                draft.items[index].selectedAccountID = onlyAccount.id
                draft.items[index].selectionSource = .singleEligibleAccount
                draft.items[index].inferenceFeedbackContext = nil
                draft.items[index].initialInferenceDisposition = nil
                draft.items[index].initialInferredOrSuggestedAccountID = nil
                draft.items[index].initialInferenceResult = nil
                continue
            }

            guard let request = draft.items[index].inferenceRequest(for: importEligibleAccounts) else {
                continue
            }

            Self.applyInferenceResult(
                accountInferrer(request),
                to: &draft.items[index]
            )
        }

        if draft.selectedItemID == nil {
            draft.selectedItemID = Self.initialSelectionID(in: draft.items)
        }
    }

    func confirmBatchCSVImport(
        service: WorkspaceService,
        accounts: [Account]
    ) async -> BatchCSVImportRunResult {
        let summary = Self.emptySummary
        guard draft.items.isEmpty == false else {
            importPhase = .editing
            return .partialFailure(
                BatchCSVImportFailureContext(
                    failedItemID: UUID(),
                    failedFilename: "Unknown File",
                    stagedFileCount: 0,
                    errorDescription: WorkspaceServiceError.importPreviewNotReady.localizedDescription,
                    summary: summary,
                    outcome: nil,
                    fileResults: []
                )
            )
        }

        if let firstBlockedItem = draft.items.first(where: { $0.isReadyForImport == false }) {
            draft.selectedItemID = firstBlockedItem.id
            importPhase = .editing
            return .partialFailure(
                BatchCSVImportFailureContext(
                    failedItemID: firstBlockedItem.id,
                    failedFilename: firstBlockedItem.originalFilename,
                    stagedFileCount: 0,
                    errorDescription: WorkspaceServiceError.importPreviewNotReady.localizedDescription,
                    summary: summary,
                    outcome: nil,
                    fileResults: []
                )
            )
        }

        let accountsByID = Dictionary(uniqueKeysWithValues: accounts.map { ($0.id, $0) })
        let totalCount = draft.items.count
        var aggregateSummary = Self.emptySummary
        var aggregateOutcome: StagedCSVImportOutcome?
        var stagedFileCount = 0
        var fileResults: [BatchCSVImportFileResult] = []

        for (index, item) in draft.items.enumerated() {
            importPhase = .importing(currentIndex: index + 1, totalCount: totalCount)
            await Task.yield()

            guard
                let preview = item.preview,
                let csvText = item.csvText,
                let accountID = item.selectedAccountID,
                let account = accountsByID[accountID]
            else {
                draft.selectedItemID = item.id
                importPhase = .editing
                return .partialFailure(
                    BatchCSVImportFailureContext(
                        failedItemID: item.id,
                        failedFilename: item.originalFilename,
                        stagedFileCount: stagedFileCount,
                        errorDescription: WorkspaceServiceError.importPreviewNotReady.localizedDescription,
                        summary: aggregateSummary,
                        outcome: aggregateOutcome,
                        fileResults: fileResults
                    )
                )
            }

            do {
                let result = try service.stageCSVImport(
                    preview: preview,
                    account: account,
                    originalFilename: item.originalFilename,
                    csvText: csvText
                )
                if result.outcome == .staged {
                    stagedFileCount += 1
                }
                aggregateSummary = Self.accumulate(summary: aggregateSummary, with: result.summary)
                aggregateOutcome = Self.accumulate(outcome: aggregateOutcome, with: result.outcome)
                fileResults.append(
                    BatchCSVImportFileResult(
                        itemID: item.id,
                        originalFilename: item.originalFilename,
                        stagedImportSessionID: result.session?.id,
                        outcome: result.outcome,
                        finalSelectedAccountID: accountID,
                        inferenceFeedbackContext: item.inferenceFeedbackContext
                    )
                )
            } catch {
                draft.selectedItemID = item.id
                importPhase = .editing
                return .partialFailure(
                    BatchCSVImportFailureContext(
                        failedItemID: item.id,
                        failedFilename: item.originalFilename,
                        stagedFileCount: stagedFileCount,
                        errorDescription: error.localizedDescription,
                        summary: aggregateSummary,
                        outcome: aggregateOutcome,
                        fileResults: fileResults
                    )
                )
            }
        }

        importPhase = .editing
        return .success(
            summary: aggregateSummary,
            outcome: aggregateOutcome ?? .exactReimportNoOp,
            fileResults: fileResults
        )
    }

    private static func initialSelectionID(in items: [BatchCSVImportItemDraft]) -> UUID? {
        items.first(where: { $0.isReadyForImport == false })?.id ?? items.first?.id
    }

    private static func configuredInitialItem(
        from item: BatchCSVImportItemDraft,
        importEligibleAccounts: [Account]
    ) -> BatchCSVImportItemDraft {
        guard case .loaded = item.content else {
            return item
        }

        if let onlyAccount = importEligibleAccounts.onlyElement {
            var convenienceItem = item
            convenienceItem.selectedAccountID = onlyAccount.id
            convenienceItem.selectionSource = .singleEligibleAccount
            convenienceItem.inferenceFeedbackContext = nil
            convenienceItem.initialInferenceDisposition = nil
            convenienceItem.initialInferredOrSuggestedAccountID = nil
            convenienceItem.initialInferenceResult = nil
            convenienceItem.importAccountInferenceRequest = nil
            return convenienceItem
        }

        guard
            let result = item.initialInferenceResult
        else {
            return item
        }

        var inferredItem = item
        applyInitialInferenceResult(
            result,
            to: &inferredItem
        )
        return inferredItem
    }

    private static func loadContent(
        from url: URL,
        previewService: CSVImportPreviewService
    ) -> BatchCSVImportItemDraft.Content {
        let accessedSecurityScope = url.startAccessingSecurityScopedResource()
        defer {
            if accessedSecurityScope {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let csvText = try String(contentsOf: url, encoding: .utf8)
            let preview = try previewService.makePreview(from: csvText)
            return .loaded(csvText: csvText, preview: preview)
        } catch {
            return .loadFailed(message: error.localizedDescription)
        }
    }

    private static var emptySummary: StagedImportDecisionSummary {
        StagedImportDecisionSummary(
            importedRowCount: 0,
            skippedRowCount: 0,
            pendingClassificationReviewRowCount: 0,
            flaggedDuplicateRowCount: 0
        )
    }

    private static func accumulate(
        summary: StagedImportDecisionSummary,
        with next: StagedImportDecisionSummary
    ) -> StagedImportDecisionSummary {
        StagedImportDecisionSummary(
            importedRowCount: summary.importedRowCount + next.importedRowCount,
            skippedRowCount: summary.skippedRowCount + next.skippedRowCount,
            pendingClassificationReviewRowCount: summary.pendingClassificationReviewRowCount + next.pendingClassificationReviewRowCount,
            flaggedDuplicateRowCount: summary.flaggedDuplicateRowCount + next.flaggedDuplicateRowCount
        )
    }

    private static func accumulate(
        outcome: StagedCSVImportOutcome?,
        with next: StagedCSVImportOutcome
    ) -> StagedCSVImportOutcome {
        switch (outcome, next) {
        case (.staged, _), (_, .staged):
            .staged
        case (.exactReimportNoOp, .exactReimportNoOp):
            .exactReimportNoOp
        case (nil, let outcome):
            outcome
        }
    }

    private static func applyInitialInferenceResult(
        _ result: ImportAccountInferenceResult,
        to item: inout BatchCSVImportItemDraft
    ) {
        item.initialInferenceDisposition = result.disposition
        item.initialInferredOrSuggestedAccountID = result.selectedAccountID
        applyInferenceResult(result, to: &item)
    }

    private static func applyInferenceResult(
        _ result: ImportAccountInferenceResult,
        to item: inout BatchCSVImportItemDraft
    ) {
        item.selectedAccountID = result.selectedAccountID
        item.initialInferenceResult = result
        item.selectionSource = switch result.disposition {
        case .autoSelected:
            .inferred
        case .suggested:
            .suggested
        case .unassigned:
            .unassigned
        }
        item.inferenceFeedbackContext = result.feedbackContext
    }
}

struct BatchCSVImportDraft: Equatable {
    var items: [BatchCSVImportItemDraft]
    var selectedItemID: UUID?

    var selectedItem: BatchCSVImportItemDraft? {
        guard let selectedItemID else {
            return nil
        }

        return items.first { $0.id == selectedItemID }
    }

    var isReadyForImport: Bool {
        items.isEmpty == false && items.allSatisfy(\.isReadyForImport)
    }
}

struct BatchCSVImportItemDraft: Identifiable, Equatable {
    private static let lowConfidenceNoMatchText =
        "No likely account match was found for this file. Select a destination account to continue."

    struct SidebarDetailPresentation: Equatable {
        var accountLabel: String
        var confidenceLabel: String?
        var trailingSummary: String
    }

    enum AccountSelectionSource: Equatable {
        case singleEligibleAccount
        case inferred
        case suggested
        case manual
        case unassigned
    }

    enum Content: Equatable {
        case loaded(csvText: String, preview: CSVImportPreview)
        case loadFailed(message: String)
    }

    let id: UUID
    var originalFilename: String
    var content: Content
    var selectedAccountID: UUID?
    var initialInferenceDisposition: ImportAccountInferenceDisposition?
    var initialInferredOrSuggestedAccountID: UUID?
    var selectionSource: AccountSelectionSource
    var inferenceFeedbackContext: ImportAccountInferenceFeedbackContext?
    var importAccountInferenceRequest: ImportAccountInferenceRequest?
    var initialInferenceResult: ImportAccountInferenceResult?

    init(
        id: UUID = UUID(),
        originalFilename: String,
        content: Content,
        selectedAccountID: UUID?,
        initialInferenceDisposition: ImportAccountInferenceDisposition?,
        initialInferredOrSuggestedAccountID: UUID?,
        selectionSource: AccountSelectionSource,
        inferenceFeedbackContext: ImportAccountInferenceFeedbackContext?,
        importAccountInferenceRequest: ImportAccountInferenceRequest?,
        initialInferenceResult: ImportAccountInferenceResult?
    ) {
        self.id = id
        self.originalFilename = originalFilename
        self.content = content
        self.selectedAccountID = selectedAccountID
        self.initialInferenceDisposition = initialInferenceDisposition
        self.initialInferredOrSuggestedAccountID = initialInferredOrSuggestedAccountID
        self.selectionSource = selectionSource
        self.inferenceFeedbackContext = inferenceFeedbackContext
        self.importAccountInferenceRequest = importAccountInferenceRequest
        self.initialInferenceResult = initialInferenceResult
    }

    var isReadyForImport: Bool {
        guard case .loaded(_, let preview) = content else {
            return false
        }

        return selectedAccountID != nil && preview.validation.isReadyForImport
    }

    var preview: CSVImportPreview? {
        guard case .loaded(_, let preview) = content else {
            return nil
        }

        return preview
    }

    var csvText: String? {
        guard case .loaded(let csvText, _) = content else {
            return nil
        }

        return csvText
    }

    var loadFailureMessage: String? {
        guard case .loadFailed(let message) = content else {
            return nil
        }

        return message
    }

    var statusText: String {
        switch content {
        case .loadFailed:
            return "Error"
        case .loaded(_, let preview):
            return selectedAccountID != nil && preview.validation.isReadyForImport ? "Ready" : "Blocked"
        }
    }

    func displayAccountLabel(using accountsByID: [UUID: Account]) -> String {
        guard let selectedAccountID else {
            return "Unassigned"
        }

        return accountDisplayLabel(for: accountsByID[selectedAccountID])
    }

    var confidenceLabel: String? {
        switch presentedSelectionSource {
        case .inferred:
            return "Inferred"
        case .suggested:
            return "Suggested"
        default:
            return nil
        }
    }

    var inferenceExplanationText: String? {
        if presentedSelectionSource == .unassigned,
           currentInferenceResult?.disposition == .unassigned,
           selectedAccountID == nil {
            return Self.lowConfidenceNoMatchText
        }

        switch presentedSelectionSource {
        case .inferred, .suggested:
            return currentInferenceExplanation
        default:
            return nil
        }
    }

    func sidebarDetailPresentation(using accountsByID: [UUID: Account]) -> SidebarDetailPresentation {
        SidebarDetailPresentation(
            accountLabel: displayAccountLabel(using: accountsByID),
            confidenceLabel: confidenceLabel,
            trailingSummary: validationSummaryText ?? "Could not load preview"
        )
    }

    func sidebarDetailText(using accountsByID: [UUID: Account]) -> String {
        let presentation = sidebarDetailPresentation(using: accountsByID)
        var components = [presentation.accountLabel]
        if let confidenceLabel = presentation.confidenceLabel {
            components.append(confidenceLabel)
        }
        return "\(components.joined(separator: " · ")) · \(presentation.trailingSummary)"
    }

    var shouldReevaluateInference: Bool {
        guard case .loaded = content else {
            return false
        }

        return selectedAccountID == nil && selectionSource == .unassigned
    }

    func inferenceRequest(for importEligibleAccounts: [Account]) -> ImportAccountInferenceRequest? {
        guard let importAccountInferenceRequest else {
            return nil
        }

        return ImportAccountInferenceRequest(
            originalFilename: importAccountInferenceRequest.originalFilename,
            parsedArtifact: importAccountInferenceRequest.parsedArtifact,
            importEligibleAccounts: importEligibleAccounts,
            historicalMatchCountsByAccountID: importAccountInferenceRequest.historicalMatchCountsByAccountID
        )
    }

    private var presentedSelectionSource: AccountSelectionSource {
        guard selectedAccountID != nil else {
            return .unassigned
        }

        if selectionSource == .singleEligibleAccount {
            return .singleEligibleAccount
        }

        guard
            let currentInferenceResult,
            selectedAccountID == currentInferenceResult.selectedAccountID
        else {
            return .manual
        }

        return switch currentInferenceResult.disposition {
        case .autoSelected:
            .inferred
        case .suggested:
            .suggested
        case .unassigned:
            .manual
        }
    }

    private var currentInferenceResult: ImportAccountInferenceResult? {
        initialInferenceResult
    }

    private var currentInferenceExplanation: String? {
        guard let currentInferenceResult else {
            return nil
        }

        return currentInferenceResult.candidates.first(
            where: { $0.account.id == currentInferenceResult.selectedAccountID }
        )?.explanation
    }

    private var validationSummaryText: String? {
        guard case .loaded(_, let preview) = content else {
            return nil
        }

        return "\(preview.validation.validRowCount) valid, \(preview.validation.invalidRowCount) invalid"
    }

    private func accountDisplayLabel(for account: Account?) -> String {
        guard let account else {
            return "Unknown Account"
        }
        if let institutionName = account.institutionName {
            return "\(account.name) · \(institutionName)"
        }
        return account.name
    }
}

private extension Array {
    var onlyElement: Element? {
        count == 1 ? first : nil
    }
}
