import Application
import Foundation

enum AnalysisPage: String, CaseIterable, Codable, Equatable, Hashable, Identifiable, Sendable {
    case overview
    case categories
    case merchants

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview:
            "Overview"
        case .categories:
            "Categories"
        case .merchants:
            "Merchants"
        }
    }
}

struct AnalysisToolbarState: Equatable, Sendable {
    var selectedPage: AnalysisPage
    var isInspectorVisible: Bool

    init(
        selectedPage: AnalysisPage = .overview,
        isInspectorVisible: Bool = true
    ) {
        self.selectedPage = selectedPage
        self.isInspectorVisible = isInspectorVisible
    }

    func repaired(for snapshot: AnalysisSnapshot) -> AnalysisToolbarState {
        let availablePages = Self.availablePages(in: snapshot)
        let repairedPage = availablePages.contains(selectedPage)
            ? selectedPage
            : availablePages.first ?? .overview
        return AnalysisToolbarState(
            selectedPage: repairedPage,
            isInspectorVisible: isInspectorVisible
        )
    }

    static func availablePages(in snapshot: AnalysisSnapshot) -> [AnalysisPage] {
        var pages: [AnalysisPage] = []
        if snapshot.overview != nil {
            pages.append(.overview)
        }
        if snapshot.categories != nil {
            pages.append(.categories)
        }
        if snapshot.merchants != nil {
            pages.append(.merchants)
        }
        return pages
    }
}
