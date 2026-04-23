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
