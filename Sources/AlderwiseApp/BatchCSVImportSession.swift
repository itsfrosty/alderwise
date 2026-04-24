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
}

enum BatchCSVImportRunResult: Equatable {
    case success(summary: StagedImportDecisionSummary, outcome: StagedCSVImportOutcome)
    case partialFailure(BatchCSVImportFailureContext)
}

@MainActor
final class BatchCSVImportSession: ObservableObject {
    @Published private(set) var draft: BatchCSVImportDraft
    @Published private(set) var importPhase: BatchCSVImportPhase = .editing

    init(
        selectedURLs: [URL],
        importEligibleAccounts: [Account],
        previewService: CSVImportPreviewService = CSVImportPreviewService()
    ) {
        let items = selectedURLs.map { url in
            let content = Self.loadContent(from: url, previewService: previewService)
            return BatchCSVImportItemDraft(
                originalFilename: url.lastPathComponent,
                content: content,
                selectedAccountID: Self.initialSelectedAccountID(
                    for: content,
                    importEligibleAccounts: importEligibleAccounts
                )
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
                    outcome: nil
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
                    outcome: nil
                )
            )
        }

        let accountsByID = Dictionary(uniqueKeysWithValues: accounts.map { ($0.id, $0) })
        let totalCount = draft.items.count
        var aggregateSummary = Self.emptySummary
        var aggregateOutcome: StagedCSVImportOutcome?
        var stagedFileCount = 0

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
                        outcome: aggregateOutcome
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
                        outcome: aggregateOutcome
                    )
                )
            }
        }

        importPhase = .editing
        return .success(
            summary: aggregateSummary,
            outcome: aggregateOutcome ?? .exactReimportNoOp
        )
    }

    private static func initialSelectionID(in items: [BatchCSVImportItemDraft]) -> UUID? {
        items.first(where: { $0.isReadyForImport == false })?.id ?? items.first?.id
    }

    private static func initialSelectedAccountID(
        for content: BatchCSVImportItemDraft.Content,
        importEligibleAccounts: [Account]
    ) -> UUID? {
        guard case .loaded = content, importEligibleAccounts.count == 1 else {
            return nil
        }

        return importEligibleAccounts[0].id
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
    enum Content: Equatable {
        case loaded(csvText: String, preview: CSVImportPreview)
        case loadFailed(message: String)
    }

    let id: UUID
    var originalFilename: String
    var content: Content
    var selectedAccountID: UUID?

    init(
        id: UUID = UUID(),
        originalFilename: String,
        content: Content,
        selectedAccountID: UUID?
    ) {
        self.id = id
        self.originalFilename = originalFilename
        self.content = content
        self.selectedAccountID = selectedAccountID
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
            if selectedAccountID == nil {
                return "Choose Account"
            }
            return preview.validation.isReadyForImport ? "Ready" : "Blocked"
        }
    }
}
