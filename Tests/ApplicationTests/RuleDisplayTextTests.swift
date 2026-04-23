import Application
import Domain
import Testing

@Test
func sharedVocabularyUsesLockedSectionAndFieldLabels() {
    #expect(RuleDisplayText.yourRules == "Your Rules")
    #expect(RuleDisplayText.builtInAutoApplied == "Built-In Auto-Applied")
    #expect(RuleDisplayText.builtInReviewFirst == "Built-In Review-First")
    #expect(RuleDisplayText.matchedBy == "Matched by")
}

@Test
func sharedVocabularyUsesAgreedMatchScopeLabels() {
    #expect(RuleDisplayText.matchScopeLabel(for: .exactNormalizedMerchant) == "Exact merchant")
    #expect(RuleDisplayText.matchScopeLabel(for: .prefixNormalizedMerchant) == "Shared prefix")
    #expect(RuleDisplayText.matchScopeLabel(for: .contains) == "Contains")
}

@Test
func learnedRuleManagerModelsReuseSharedSectionTitles() {
    #expect(ManagedLearnedRuleRow.sectionTitle == RuleDisplayText.yourRules)
    #expect(SeededRuleSourceKind.deterministicRule.sectionTitle == RuleDisplayText.builtInAutoApplied)
    #expect(SeededRuleSourceKind.curatedPrefill.sectionTitle == RuleDisplayText.builtInReviewFirst)
}
