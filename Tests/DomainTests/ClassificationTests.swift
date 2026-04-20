import Domain
import Foundation
import Testing

@Test
func explicitRuleAutoAcceptsWhenThereIsNoDuplicateConcern() {
    let categoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000111")!
    let ruleID = UUID(uuidString: "00000000-0000-0000-0000-000000000222")!
    let engine = ClassificationEngine(
        explicitRules: [
            ClassificationRule(
                id: ruleID,
                merchantPattern: "coffee shop",
                categoryID: categoryID,
                merchantName: "Coffee Shop"
            ),
        ]
    )

    let decision = engine.classify(candidate: coffeeCandidate())

    #expect(decision == .autoAccepted(
        assignment: ClassificationAssignment(
            categoryID: categoryID,
            merchantName: "Coffee Shop"
        ),
        source: .rule,
        sourceReference: ruleID.uuidString,
        confidence: 1.0,
        reason: "Matched explicit merchant rule."
    ))
}

@Test
func explicitRuleTakesPrecedenceOverHeuristicAndSuggestion() {
    let explicitCategoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000111")!
    let heuristicCategoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000222")!
    let suggestedCategoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000333")!
    let ruleID = UUID(uuidString: "00000000-0000-0000-0000-000000000444")!
    let engine = ClassificationEngine(
        explicitRules: [
            ClassificationRule(
                id: ruleID,
                merchantPattern: "coffee",
                categoryID: explicitCategoryID,
                merchantName: "Rule Merchant"
            ),
        ],
        heuristics: [
            ClassificationHeuristic(
                merchantPattern: "coffee",
                categoryID: heuristicCategoryID,
                merchantName: "Heuristic Merchant"
            ),
        ],
        suggestionProvider: FixedSuggestionProvider(
            suggestion: ClassificationSuggestion(
                assignment: ClassificationAssignment(
                    categoryID: suggestedCategoryID,
                    merchantName: "Suggested Merchant"
                ),
                confidence: 0.99,
                sourceReference: "fixture"
            )
        ),
        priorAcceptedMerchantNames: ["coffee shop"]
    )

    let decision = engine.classify(candidate: coffeeCandidate())

    #expect(decision.assignment?.categoryID == explicitCategoryID)
    #expect(decision.source == .rule)
    #expect(decision.isAutoAccepted)
}

@Test
func emptyRuleAndHeuristicPatternsDoNotMatchEveryMerchant() {
    let ruleCategoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000111")!
    let heuristicCategoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000222")!
    let engine = ClassificationEngine(
        explicitRules: [
            ClassificationRule(
                merchantPattern: "  ",
                categoryID: ruleCategoryID,
                merchantName: "Blank Rule"
            ),
        ],
        heuristics: [
            ClassificationHeuristic(
                merchantPattern: "",
                categoryID: heuristicCategoryID,
                merchantName: "Blank Heuristic"
            ),
        ]
    )

    let decision = engine.classify(candidate: coffeeCandidate())

    #expect(decision == .reviewRequired(
        prefill: nil,
        source: nil,
        sourceReference: nil,
        confidence: nil,
        reason: "No classification matched."
    ))
}

@Test
func heuristicPrefillsButDoesNotAutoAccept() {
    let categoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000111")!
    let engine = ClassificationEngine(
        heuristics: [
            ClassificationHeuristic(
                merchantPattern: "coffee",
                categoryID: categoryID,
                merchantName: "Coffee Shop"
            ),
        ]
    )

    let decision = engine.classify(candidate: coffeeCandidate())

    #expect(decision == .reviewRequired(
        prefill: ClassificationAssignment(
            categoryID: categoryID,
            merchantName: "Coffee Shop"
        ),
        source: .heuristic,
        sourceReference: nil,
        confidence: 0.65,
        reason: "Deterministic heuristic requires review."
    ))
}

@Test
func highConfidenceSuggestionAutoAcceptsOnlyWithPriorHistoryAndNoDuplicateConcern() {
    let categoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000111")!
    let provider = FixedSuggestionProvider(
        suggestion: ClassificationSuggestion(
            assignment: ClassificationAssignment(
                categoryID: categoryID,
                merchantName: "Coffee Shop"
            ),
            confidence: 0.93,
            sourceReference: "fixture"
        )
    )
    let engine = ClassificationEngine(
        suggestionProvider: provider,
        priorAcceptedMerchantNames: ["coffee shop"]
    )

    let decision = engine.classify(candidate: coffeeCandidate())

    #expect(decision == .autoAccepted(
        assignment: ClassificationAssignment(
            categoryID: categoryID,
            merchantName: "Coffee Shop"
        ),
        source: .suggestion,
        sourceReference: "fixture",
        confidence: 0.93,
        reason: "High-confidence suggestion backed by prior accepted merchant history."
    ))
}

@Test
func priorAcceptedMerchantHistoryIsNormalizedBeforeSuggestionGate() {
    let categoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000111")!
    let provider = FixedSuggestionProvider(
        suggestion: ClassificationSuggestion(
            assignment: ClassificationAssignment(
                categoryID: categoryID,
                merchantName: "Coffee Shop"
            ),
            confidence: 0.93,
            sourceReference: "fixture"
        )
    )
    let engine = ClassificationEngine(
        suggestionProvider: provider,
        priorAcceptedMerchantNames: ["  Coffee Shop  "]
    )

    #expect(engine.classify(candidate: coffeeCandidate()).isAutoAccepted)
}

@Test
func suggestionsRequireReviewWhenConfidenceHistoryOrDuplicateGateFails() {
    let categoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000111")!
    let provider = FixedSuggestionProvider(
        suggestion: ClassificationSuggestion(
            assignment: ClassificationAssignment(
                categoryID: categoryID,
                merchantName: "Coffee Shop"
            ),
            confidence: 0.93,
            sourceReference: "fixture"
        )
    )
    let engineWithoutHistory = ClassificationEngine(suggestionProvider: provider)
    let engineWithHistory = ClassificationEngine(
        suggestionProvider: provider,
        priorAcceptedMerchantNames: ["coffee shop"]
    )

    let noHistoryDecision = engineWithoutHistory.classify(candidate: coffeeCandidate())
    let duplicateDecision = engineWithHistory.classify(
        candidate: coffeeCandidate(),
        hasDuplicateConcern: true
    )

    #expect(noHistoryDecision.isAutoAccepted == false)
    #expect(noHistoryDecision.source == .suggestion)
    #expect(noHistoryDecision.assignment?.categoryID == categoryID)
    #expect(duplicateDecision.isAutoAccepted == false)
    #expect(duplicateDecision.source == .suggestion)
    #expect(duplicateDecision.reason == "Suggestion requires review.")
}

@Test
func disabledSuggestionProviderBehavesLikeNoSuggestionProvider() {
    let categoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000111")!
    let provider = FixedSuggestionProvider(
        suggestion: ClassificationSuggestion(
            assignment: ClassificationAssignment(
                categoryID: categoryID,
                merchantName: "Coffee Shop"
            ),
            confidence: 0.99,
            sourceReference: "fixture"
        )
    )
    let disabledEngine = ClassificationEngine(
        suggestionProvider: provider,
        suggestionsEnabled: false,
        priorAcceptedMerchantNames: ["coffee shop"]
    )
    let noOpEngine = ClassificationEngine(
        suggestionProvider: NoOpSuggestionProvider(),
        priorAcceptedMerchantNames: ["coffee shop"]
    )

    #expect(disabledEngine.classify(candidate: coffeeCandidate()) == noOpEngine.classify(candidate: coffeeCandidate()))
}

private func coffeeCandidate() -> NormalizedImportCandidate {
    NormalizedImportCandidate(
        rowHash: "row-1",
        sourceLineNumber: 2,
        transactionDate: Date(timeIntervalSince1970: 1_775_171_200),
        rawDescription: "SQ *Coffee Shop",
        normalizedMerchantName: "coffee shop",
        amount: Decimal(-4.75)
    )
}

private struct FixedSuggestionProvider: SuggestionProvider {
    var suggestion: ClassificationSuggestion?

    func suggestion(for candidate: NormalizedImportCandidate) -> ClassificationSuggestion? {
        suggestion
    }
}
