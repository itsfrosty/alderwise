import Application
import Domain
import Foundation
import Testing

@Test
func sharedVocabularySurfacesDoNotInlineLegacyLabels() throws {
    let learnedRulesSource = try sourceText(in: "Sources/AlderwiseApp/LearnedRulesManagerView.swift")
    #expect(learnedRulesSource.contains("Learned rules plus Alderwise's included deterministic rules and starter prefills.") == false)
    #expect(learnedRulesSource.contains("title: \"Learned\",") == false)
    #expect(learnedRulesSource.contains("title: \"Deterministic Rules\",") == false)
    #expect(learnedRulesSource.contains("title: \"Starter Prefills\",") == false)

    let settingsSource = try sourceText(in: "Sources/AlderwiseApp/SettingsView.swift")
    #expect(settingsSource.contains("Browse learned rules alongside Alderwise's included deterministic rules and starter prefills.") == false)
    #expect(settingsSource.contains("Label(\"Open Rules\"") == false)

    let detailSource = try sourceText(in: "Sources/AlderwiseApp/TransactionDetailInspectorView.swift")
    #expect(detailSource.contains("LabeledContent(\"Match Scope\"") == false)
    #expect(detailSource.contains("Button(\"View in Learned Rules\")") == false)
}

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

@Test
func detailSourceCopyStaysMoreSpecificThanSectionTitles() {
    #expect(ManagedLearnedRuleRow.detailSourceText == "Learned from Review")
    #expect(ManagedLearnedRuleRow.detailSourceText != ManagedLearnedRuleRow.sectionTitle)
    #expect(SeededRuleSourceKind.deterministicRule.detailSourceTypeText == "Built-In Auto-Applied rule")
    #expect(SeededRuleSourceKind.curatedPrefill.detailSourceTypeText == "Built-In Review-First hint")
}

private func sourceText(in relativePath: String) throws -> String {
    let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let sourceURL = repoRoot.appendingPathComponent(relativePath)
    return try String(contentsOf: sourceURL, encoding: .utf8)
}
