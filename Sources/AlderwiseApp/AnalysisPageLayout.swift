import Foundation

enum AnalysisCardVisibilityState: String, Equatable {
    case hidden
    case shownEmpty
    case shownActionable
}

struct AnalysisCardFooterAction: Equatable {
    var primaryTitle: String?
    var secondaryTitles: [String]

    static let none = AnalysisCardFooterAction(
        primaryTitle: nil,
        secondaryTitles: []
    )
}

struct AnalysisPageCard<Kind: Hashable & Equatable>: Identifiable, Equatable {
    let kind: Kind
    let visibility: AnalysisCardVisibilityState
    let supportsSelection: Bool
    let footerAction: AnalysisCardFooterAction

    var id: String {
        String(describing: kind)
    }
}

struct AnalysisPageContract<Kind: Hashable & Equatable>: Equatable {
    let cards: [AnalysisPageCard<Kind>]

    func card(kind: Kind) -> AnalysisPageCard<Kind>? {
        cards.first(where: { $0.kind == kind })
    }
}
