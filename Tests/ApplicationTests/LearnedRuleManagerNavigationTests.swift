import Application
import Domain
import Foundation
import Testing

@Test
func learnedRulesRouteForcesLearnedModeAndPreservesSelectedLearnedRuleSelection() {
    let learnedRuleID = UUID(uuidString: "00000000-0000-0000-0000-000000000411")!

    let destination = SettingsDestination.learnedRulesRoute(
        selection: .learnedRule(learnedRuleID)
    )

    #expect(
        destination
            == .learnedRules(
                LearnedRulesDestination(
                    mode: .learned,
                    selection: .learnedRule(learnedRuleID)
                )
            )
    )
}

@Test
func learnedRulesRouteForcesSeededModeAndPreservesSelectedSeededSourceSelection() {
    let seededSourceID = "deterministic:contains:costco"

    let destination = SettingsDestination.learnedRulesRoute(
        selection: .seededSource(seededSourceID)
    )

    #expect(
        destination
            == .learnedRules(
                LearnedRulesDestination(
                    mode: .seeded,
                    selection: .seededSource(seededSourceID)
                )
            )
    )
}

@Test
func learnedRulesDestinationCarriesOnlyModeAndSelectionPayload() {
    let destination = LearnedRulesDestination(mode: .learned, selection: nil)
    let mirroredDestination = Mirror(reflecting: destination)
    let labels = mirroredDestination.children.compactMap(\.label)

    #expect(labels == ["mode", "selection"])
    #expect(labels.contains { $0.localizedCaseInsensitiveContains("search") } == false)
    #expect(labels.contains { $0.localizedCaseInsensitiveContains("filter") } == false)
}
