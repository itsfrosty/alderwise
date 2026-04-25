import Application
import Domain
import Foundation
import Testing

@testable import AlderwiseApp

@Test
func analysisToolbarStateRepairsUnavailablePageAgainstAvailableSnapshots() {
    let categoriesSnapshot = AnalysisCategoriesSnapshot(
        context: AnalysisContext(),
        report: CategoryAnalysisReport(context: AnalysisContext(), rows: []),
        targetProgress: []
    )

    let repaired = AnalysisToolbarState(
        selectedPage: .merchants,
        isInspectorVisible: false
    ).repaired(for: AnalysisSnapshot(categories: categoriesSnapshot))

    #expect(repaired.selectedPage == .categories)
    #expect(repaired.isInspectorVisible == false)
}

@Test
@MainActor
func analysisInspectorVisibilityAndPagePersistAcrossTransactionNavigation() {
    let model = WorkspaceShellModel(store: nil, service: nil)

    model.selectAnalysisPage(.merchants)
    model.setAnalysisInspectorVisible(false)
    model.showTransactions(
        filter: TransactionLedgerFilter(
            normalizedMerchantName: "netflix",
            direction: .expense,
            reviewStatuses: Set([.accepted, .pending]),
            visibility: .active
        )
    )

    #expect(model.analysisToolbarState.selectedPage == .merchants)
    #expect(model.analysisToolbarState.isInspectorVisible == false)
    #expect(model.pendingAppSectionNavigation == .transactions)
}
