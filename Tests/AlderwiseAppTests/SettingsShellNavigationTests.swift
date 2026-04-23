import Application
import Foundation
import Testing

@testable import AlderwiseApp

@Test
func learnedRulesRouteBuildsDefaultRulesDestination() {
    #expect(
        SettingsDestination.learnedRulesRoute()
            == .rules(
                LearnedRulesDestination(
                    mode: .learned,
                    selectedLearnedRuleID: nil
                )
            )
    )
}

@Test
func learnedRulesRoutePreservesSelectedRule() {
    let learnedRuleID = UUID(uuidString: "00000000-0000-0000-0000-000000000433")!

    #expect(
        SettingsDestination.learnedRulesRoute(selectedLearnedRuleID: learnedRuleID)
            == .rules(
                LearnedRulesDestination(
                    mode: .learned,
                    selectedLearnedRuleID: learnedRuleID
                )
            )
    )
}

@Test
@MainActor
func showLearnedRulesSetsRulesRouteAndPendingRulesNavigation() {
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
    #expect(model.pendingAppSectionNavigation == .rules)
}

@Test
@MainActor
func reEnteringSettingsFromSidebarResetsRulesDeepLinkToOverview() {
    let learnedRuleID = UUID(uuidString: "00000000-0000-0000-0000-000000000455")!
    let model = WorkspaceShellModel(store: nil, service: nil)

    model.showLearnedRules(selectedLearnedRuleID: learnedRuleID)
    model.directSettingsSidebarEntry()

    #expect(model.settingsDestination == .overview)
}

@Test
@MainActor
func selectingRulesFromSidebarBuildsDefaultRulesRoute() {
    let model = WorkspaceShellModel(store: nil, service: nil)

    model.prepareForSidebarSelection(.rules)

    #expect(
        model.settingsDestination
            == .rules(
                LearnedRulesDestination(
                    mode: .learned,
                    selectedLearnedRuleID: nil
                )
            )
    )
}
