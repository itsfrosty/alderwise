import Testing

@testable import AlderwiseApp

@Test
func analysisToolbarAvoidsPrincipalPlacement() {
    #expect(AnalysisLayout.usesPrincipalToolbarPlacement == false)
}

@Test
func analysisInspectorFitsWithinWorkspaceMinimumWindowAlongsideSidebar() {
    let reservedWidth = WorkspaceLayout.sidebarIdealWidth + WorkspaceLayout.analysisInspectorMinimumWidth

    #expect(reservedWidth < WorkspaceLayout.minimumWindowWidth)
}

@Test
func transactionLedgerHeaderInsetsProtectLeadingControlsFromTheSplitViewDivider() {
    let insets = WorkspaceLayout.transactionLedgerHeaderInsets

    #expect(insets.leading == 20)
    #expect(insets.leading > insets.trailing)
    #expect(insets.top == 12)
    #expect(insets.bottom == 12)
}
