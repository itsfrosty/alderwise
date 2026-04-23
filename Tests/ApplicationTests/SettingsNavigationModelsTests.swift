import Application
import Foundation
import Testing

@Test
func settingsDestinationSupportsOverviewAndRules() {
    let learnedRuleID = UUID(uuidString: "00000000-0000-0000-0000-000000000422")!
    let rulesDestination = LearnedRulesDestination(
        mode: .learned,
        selectedLearnedRuleID: learnedRuleID
    )

    let destinations: [SettingsDestination] = [
        .overview,
        .rules(rulesDestination),
    ]

    #expect(destinations.count == 2)
    #expect(destinations[0] == .overview)
    #expect(destinations[1] == .rules(rulesDestination))
}

@Test
func reviewCreatedLearnedRuleActionRulesDestinationMapsToRulesRoute() {
    let learnedRuleID = UUID(uuidString: "00000000-0000-0000-0000-000000000424")!
    let action = ReviewCreatedLearnedRuleAction.settingsRules(
        ruleID: learnedRuleID,
        merchantLabel: "Coffee Shop"
    )

    #expect(action.destination == .learnedRulesRoute(selectedLearnedRuleID: learnedRuleID))
}
