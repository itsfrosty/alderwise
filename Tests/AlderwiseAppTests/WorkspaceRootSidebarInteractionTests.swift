import Application
import Domain
import Testing

@testable import AlderwiseApp

@Test
@MainActor
func directSidebarTapOverrideAppliesOnlyToSettings() {
    for section in AppSection.allCases where section != .settings {
        #expect(WorkspaceRootView.requiresDirectSidebarTapOverride(for: section) == false)
    }

    #expect(WorkspaceRootView.requiresDirectSidebarTapOverride(for: .settings))
}

@Test
@MainActor
func analysisSectionUsesThePrimarySidebarRoutingPath() {
    #expect(AppSection.allCases.contains(.analysis))
    #expect(WorkspaceDetailRoute.make(for: .analysis) == .analysis)
    #expect(WorkspaceRootView.requiresDirectSidebarTapOverride(for: .analysis) == false)
}
