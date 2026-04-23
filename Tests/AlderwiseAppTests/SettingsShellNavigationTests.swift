import Application
import Foundation
import Testing

@testable import AlderwiseApp

@Test
func directSettingsEntryResolvesToOverview() {
    let state = SettingsShellState.directEntry()

    #expect(state.destination == .overview)
    #expect(state.sidebarDestination == .overview)
}

@Test
func rulesDeepLinkResolvesToSettingsRules() {
    let learnedRuleID = UUID(uuidString: "00000000-0000-0000-0000-000000000433")!
    let destination = SettingsDestination.rules(
        LearnedRulesDestination(
            mode: .learned,
            selectedLearnedRuleID: learnedRuleID
        )
    )

    let state = SettingsShellState.deepLink(destination)

    #expect(state.destination == destination)
    #expect(state.sidebarDestination == .rules)
}

@Test
@MainActor
func showLearnedRulesSetsSettingsRouteAndPendingSettingsNavigation() {
    let learnedRuleID = UUID(uuidString: "00000000-0000-0000-0000-000000000444")!
    let model = WorkspaceShellModel(store: nil, service: nil)

    model.showLearnedRules(selectedLearnedRuleID: learnedRuleID)

    #expect(
        model.settingsDestination
            == .rules(
                LearnedRulesDestination(
                    mode: .learned,
                    selectedLearnedRuleID: learnedRuleID
                )
            )
    )
    #expect(model.pendingAppSectionNavigation == .settings)
}
