import Application
import Domain
import Testing

@testable import AlderwiseApp

@Test
func analysisToolbarRepairFallsBackToTheFirstAvailableFamily() {
    let repaired = AnalysisToolbarState(
        selectedPage: .merchants,
        isInspectorVisible: true
    ).repaired(for: AnalysisSnapshot(categories: analysisToolbarCategoriesSnapshot()))

    #expect(repaired.selectedPage == .categories)
}

@Test
@MainActor
func analysisInspectorToggleDoesNotChangeTheSelectedFamily() {
    let model = WorkspaceShellModel(store: nil, service: nil)

    model.selectAnalysisPage(.categories)
    model.setAnalysisInspectorVisible(false)
    model.toggleAnalysisInspector()

    #expect(model.analysisToolbarState.selectedPage == .categories)
    #expect(model.analysisToolbarState.isInspectorVisible)
}

private func analysisToolbarCategoriesSnapshot() -> AnalysisCategoriesSnapshot {
    AnalysisCategoriesSnapshot(
        context: AnalysisContext(),
        report: CategoryAnalysisReport(context: AnalysisContext(), rows: []),
        targetProgress: []
    )
}
