import Application
import Domain
import Foundation
import Testing

@Test
func curatedPrefillUsesBuiltInReviewFirstCopyAndDisablesRuleLearningByDefault() {
    let groceriesID = UUID(uuidString: "00000000-0000-0000-0000-000000000111")!
    let item = makeReviewItem(
        source: .curatedPrefill,
        reason: "Curated starter match requires review before acceptance.",
        categoryID: groceriesID
    )
    let presentation = ReviewPresentation(
        categories: [
            BudgetCategory(id: groceriesID, name: "Groceries", kind: .expense),
        ]
    )

    #expect(presentation.queueSubtitle(for: item) == "checking-april.csv · Row 7 · Built-In Review-First: Groceries")
    #expect(
        presentation.starterHintCaption(for: item)
            == "Built-In Review-First suggested category: Groceries. Review before accepting."
    )
    #expect(presentation.initialCreateRuleValue(for: item) == false)
    #expect(
        presentation.initialRuleLearningSelection(for: item)
            == .exactNormalizedMerchant(pattern: "coffee shop")
    )
}

@Test
func nonCuratedItemsKeepExistingSubtitleBehaviorAndLeaveRuleLearningEnabled() {
    let item = makeReviewItem(
        source: .heuristic,
        reason: "Low confidence category suggestion."
    )
    let presentation = ReviewPresentation(categories: [])

    #expect(presentation.queueSubtitle(for: item) == "checking-april.csv · Row 7 · Low confidence category suggestion.")
    #expect(presentation.starterHintCaption(for: item) == nil)
    #expect(presentation.initialCreateRuleValue(for: item) == true)
    #expect(
        presentation.initialRuleLearningSelection(for: item)
            == .exactNormalizedMerchant(pattern: "coffee shop")
    )
}

@Test
func sourceLabelsUseHumanReadableStrings() {
    #expect(ReviewPresentation.sourceLabel(for: .curatedPrefill) == "Built-In Review-First")
    #expect(ReviewPresentation.sourceLabel(for: .rule) == "Rule")
    #expect(ReviewPresentation.sourceLabel(for: nil) == "Unclassified")
}

@Test
func curatedPrefillFallsBackToGenericHintWhenCategoryNameIsWhitespace() {
    let groceriesID = UUID(uuidString: "00000000-0000-0000-0000-000000000111")!
    let item = makeReviewItem(
        source: .curatedPrefill,
        reason: "Curated starter match requires review before acceptance.",
        categoryID: groceriesID
    )
    let presentation = ReviewPresentation(
        categories: [
            BudgetCategory(id: groceriesID, name: "   ", kind: .expense),
        ]
    )

    #expect(presentation.queueSubtitle(for: item) == "checking-april.csv · Row 7 · Built-In Review-First")
    #expect(presentation.starterHintCaption(for: item) == "Built-In Review-First suggestion. Review before accepting.")
}

@Test
func curatedPrefillDefaultsToExactWhenPrefixLearningIsAvailable() {
    let donationsID = UUID(uuidString: "00000000-0000-0000-0000-000000000112")!
    let item = makeReviewItem(
        source: .curatedPrefill,
        reason: "Curated starter match requires review before acceptance.",
        categoryID: donationsID,
        normalizedMerchantName: "99pledg onir baweja"
    )
    let presentation = ReviewPresentation(
        categories: [
            BudgetCategory(id: donationsID, name: "Donations", kind: .expense),
        ]
    )

    #expect(
        presentation.initialRuleLearningSelection(for: item)
            == .exactNormalizedMerchant(pattern: "99pledg onir baweja")
    )
    #expect(
        presentation.resolvedRuleLearningSelection(for: item, selectedRuleLearning: nil)
            == .exactNormalizedMerchant(pattern: "99pledg onir baweja")
    )
}

@Test
func resolvedRuleLearningSelectionPreservesExplicitUserChoice() {
    let donationsID = UUID(uuidString: "00000000-0000-0000-0000-000000000112")!
    let item = makeReviewItem(
        source: .curatedPrefill,
        reason: "Curated starter match requires review before acceptance.",
        categoryID: donationsID,
        normalizedMerchantName: "99pledg onir baweja"
    )
    let presentation = ReviewPresentation(
        categories: [
            BudgetCategory(id: donationsID, name: "Donations", kind: .expense),
        ]
    )

    #expect(
        presentation.resolvedRuleLearningSelection(
            for: item,
            selectedRuleLearning: .prefixNormalizedMerchant(pattern: "99pledg")
        ) == .prefixNormalizedMerchant(pattern: "99pledg")
    )
}

private func makeReviewItem(
    source: ClassificationDecisionSource?,
    reason: String?,
    categoryID: UUID? = nil,
    normalizedMerchantName: String = "coffee shop"
) -> PendingReviewItem {
    PendingReviewItem(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000555")!,
        type: .lowConfidenceCategory,
        status: .pending,
        reason: reason,
        createdAt: Date(timeIntervalSince1970: 1_775_171_200),
        sourceFile: PendingReviewSourceFile(
            accountID: UUID(uuidString: "00000000-0000-0000-0000-000000000123")!,
            originalFilename: "checking-april.csv"
        ),
        sourceRow: PendingReviewSourceRow(
            id: 42,
            sourceLineNumber: 7,
            rowHash: "row-1-sha256",
            rawPayload: #"["2026-04-01","Coffee Shop","-4.75"]"#
        ),
        duplicateTransactionID: nil,
        classification: PendingReviewClassification(
            normalizedMerchantName: normalizedMerchantName,
            prefill: categoryID.map { ClassificationAssignment(categoryID: $0, merchantName: "Coffee Shop") },
            source: source,
            sourceReference: "starter:coffee",
            confidence: nil
        )
    )
}
