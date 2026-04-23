import Application
import Domain
import Foundation
import Testing

@Test
func learnedRulesRouteForcesLearnedModeAndPreservesSelectedRuleID() {
    let learnedRuleID = UUID(uuidString: "00000000-0000-0000-0000-000000000411")!

    let destination = SettingsDestination.learnedRulesRoute(
        selectedLearnedRuleID: learnedRuleID
    )

    #expect(
        destination
            == .rules(
                LearnedRulesDestination(
                    mode: .learned,
                    selectedLearnedRuleID: learnedRuleID
                )
            )
    )
}

@Test
func learnedRulesDestinationCarriesOnlyModeAndSelection() {
    let destination = LearnedRulesDestination(mode: .learned, selectedLearnedRuleID: nil)
    let mirroredDestination = Mirror(reflecting: destination)
    let labels = mirroredDestination.children.compactMap(\.label)

    #expect(labels == ["mode", "selectedLearnedRuleID"])
    #expect(labels.contains { $0.localizedCaseInsensitiveContains("search") } == false)
    #expect(labels.contains { $0.localizedCaseInsensitiveContains("focus") } == false)
    #expect(labels.contains { $0.localizedCaseInsensitiveContains("filter") } == false)
}

@Test
func reviewCreatedLearnedRuleActionRulesDeepLinkTargetsSettingsRules() {
    let learnedRuleID = UUID(uuidString: "00000000-0000-0000-0000-000000000412")!

    let action = ReviewCreatedLearnedRuleAction.settingsRules(
        ruleID: learnedRuleID,
        merchantLabel: "Coffee Shop"
    )

    #expect(action.ruleID == learnedRuleID)
    #expect(action.merchantLabel == "Coffee Shop")
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
