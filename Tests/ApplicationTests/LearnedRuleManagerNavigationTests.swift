import Application
import Domain
import Foundation
import Testing

@Test
func settingsDestinationLearnedRulesForcesLearnedModeAndPreservesSelectedRuleID() {
    let learnedRuleID = UUID(uuidString: "00000000-0000-0000-0000-000000000411")!

    let destination = SettingsDestination.learnedRules(selectedLearnedRuleID: learnedRuleID)

    #expect(destination.learnedRulesDestination?.mode == .learned)
    #expect(destination.learnedRulesDestination?.selectedLearnedRuleID == learnedRuleID)
}

