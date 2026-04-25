import Testing

@testable import AlderwiseApp

@Test
func analysisInspectorFitsWithinWorkspaceMinimumWindowAlongsideSidebar() {
    let reservedWidth = WorkspaceLayout.sidebarIdealWidth + WorkspaceLayout.analysisInspectorMinimumWidth

    #expect(reservedWidth < WorkspaceLayout.minimumWindowWidth)
}

@Test
func analysisInspectorWidthsRemainMonotonic() {
    #expect(WorkspaceLayout.analysisInspectorMinimumWidth < WorkspaceLayout.analysisInspectorIdealWidth)
    #expect(WorkspaceLayout.analysisInspectorIdealWidth < WorkspaceLayout.analysisInspectorMaximumWidth)
}

@Test
func analysisInspectorPrefersCollapsingAfterPrimaryAnalysisContent() {
    #expect(
        WorkspaceLayout.analysisInspectorCollapsePriority >
            WorkspaceLayout.analysisContentCollapsePriority
    )
}
