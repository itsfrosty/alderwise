import Application
import Domain
import Foundation
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

@Test
@MainActor
func analysisSidebarSelectionFlowStillUsesPrimarySelectionPreparation() {
    let model = WorkspaceShellModel(store: nil, service: nil)
    var selectedSectionRawValue = AppSection.home.rawValue

    WorkspaceRootView.applySidebarSelection(
        .analysis,
        selectedSectionRawValue: &selectedSectionRawValue,
        model: model
    )

    #expect(selectedSectionRawValue == AppSection.analysis.rawValue)
    #expect(model.pendingAppSectionNavigation == nil)
}
