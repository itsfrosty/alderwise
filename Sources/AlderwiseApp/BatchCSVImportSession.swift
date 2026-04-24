import Application
import Domain
import Foundation
import SwiftUI

enum BatchCSVImportPhase: Equatable {
    case editing
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
}
