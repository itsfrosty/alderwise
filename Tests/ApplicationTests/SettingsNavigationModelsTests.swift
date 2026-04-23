import Application
import Foundation
import Testing

@Test
func settingsSidebarDestinationIsHashableAndSupportsOverviewBackupsAndRecoveryAndRules() {
    let destinations: Set<SettingsSidebarDestination> = [
        .overview,
        .backupsAndRecovery,
        .rules,
    ]

    #expect(destinations.count == 3)
    #expect(destinations.contains(.overview))
    #expect(destinations.contains(.backupsAndRecovery))
    #expect(destinations.contains(.rules))
}

@Test
func settingsDestinationSupportsOverviewBackupsAndRecoveryAndRules() {
    let learnedRuleID = UUID(uuidString: "00000000-0000-0000-0000-000000000422")!
    let rulesDestination = LearnedRulesDestination(
        mode: .learned,
        selectedLearnedRuleID: learnedRuleID
    )

    let destinations: [SettingsDestination] = [
        .overview,
        .backupsAndRecovery,
        .rules(rulesDestination),
    ]

    #expect(destinations.count == 3)
    #expect(destinations[0] == .overview)
    #expect(destinations[1] == .backupsAndRecovery)
    #expect(destinations[2] == .rules(rulesDestination))
}

@Test
func settingsDestinationMapsToSidebarDestination() {
    let learnedRuleID = UUID(uuidString: "00000000-0000-0000-0000-000000000423")!
    let rulesDestination = SettingsDestination.rules(
        LearnedRulesDestination(
            mode: .learned,
            selectedLearnedRuleID: learnedRuleID
        )
    )

    #expect(SettingsDestination.overview.sidebarDestination == .overview)
    #expect(SettingsDestination.backupsAndRecovery.sidebarDestination == .backupsAndRecovery)
    #expect(rulesDestination.sidebarDestination == .rules)
}

@Test
func reviewCreatedLearnedRuleActionRulesDestinationMapsToRulesSidebarSelection() {
    let learnedRuleID = UUID(uuidString: "00000000-0000-0000-0000-000000000424")!
    let action = ReviewCreatedLearnedRuleAction.settingsRules(
        ruleID: learnedRuleID,
        merchantLabel: "Coffee Shop"
    )

    #expect(action.destination.sidebarDestination == .rules)
    #expect(
        action.destination
            == .rules(
                LearnedRulesDestination(
                    mode: .learned,
                    selectedLearnedRuleID: learnedRuleID
                )
            )
    )
}
