import Application
import Domain
import Foundation
import Testing

@Test
func settingsDestinationLearnedRulesForcesLearnedModeAndPreservesSelectedRuleID() {
    let learnedRuleID = UUID(uuidString: "00000000-0000-0000-0000-000000000411")!
    let learnedRulesDestination = LearnedRulesDestination(
        mode: .learned,
        selectedLearnedRuleID: learnedRuleID
    )

    let destination = SettingsDestination.learnedRules(learnedRulesDestination)

    #expect(destination == .learnedRules(learnedRulesDestination))
}

@Test
func learnedRulesDestinationCarriesOnlyModeAndSelection() {
    let destination = LearnedRulesDestination(mode: .learned, selectedLearnedRuleID: nil)
    let mirroredDestination = Mirror(reflecting: destination)
    let labels = mirroredDestination.children.compactMap(\.label)

    #expect(labels == ["mode", "selectedLearnedRuleID"])
    #expect(labels.contains { $0.localizedCaseInsensitiveContains("search") } == false)
    #expect(labels.contains { $0.localizedCaseInsensitiveContains("filter") } == false)
}
