import Domain
import Foundation
import Testing

@Test
func explicitRuleAutoAcceptsWhenThereIsNoDuplicateConcern() {
    let categoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000111")!
    let ruleID = UUID(uuidString: "00000000-0000-0000-0000-000000000222")!
    let rule = ClassificationRule(
        id: ruleID,
        merchantPattern: "coffee shop",
        categoryID: categoryID,
        merchantName: "Coffee Shop"
    )
    let engine = ClassificationEngine(
        explicitRules: [
            rule,
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
func heuristicCanAutoAcceptWhenAggressivePolicyIsEnabled() {
    let categoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000111")!
    let engine = ClassificationEngine(
        heuristics: [
            ClassificationHeuristic(
                merchantPattern: "coffee",
                categoryID: categoryID,
                merchantName: "Coffee Shop"
            ),
        ],
        seededHeuristicAutoAcceptEnabled: true
    )

    let decision = engine.classify(candidate: coffeeCandidate())

    #expect(decision == .autoAccepted(
        assignment: ClassificationAssignment(
            categoryID: categoryID,
            merchantName: "Coffee Shop"
        ),
        source: .heuristic,
        sourceReference: nil,
        confidence: 0.65,
        reason: "Aggressive seeded heuristic matched."
    ))
}

@Test
func curatedReviewPrefillRequiresReviewWithStableSeedReference() {
    let categoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000111")!
    let engine = ClassificationEngine(
        curatedReviewPrefills: [
            CuratedReviewPrefill(
                id: "starter.coffee-family",
                merchantPattern: "coffee",
                assignment: ClassificationAssignment(
                    categoryID: categoryID,
                    merchantName: "Coffee Family"
                ),
                matchKind: .contains
            ),
        ]
    )

    let decision = engine.classify(candidate: coffeeCandidate())

    #expect(decision == .reviewRequired(
        prefill: ClassificationAssignment(
            categoryID: categoryID,
            merchantName: "Coffee Family"
        ),
        source: .curatedPrefill,
        sourceReference: "starter.coffee-family",
        confidence: nil,
        reason: "Curated starter match requires review before acceptance."
    ))
}

@Test
func curatedReviewPrefillTakesPrecedenceOverHeuristicAndSuggestion() {
    let curatedCategoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000111")!
    let heuristicCategoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000222")!
    let suggestedCategoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000333")!
    let engine = ClassificationEngine(
        curatedReviewPrefills: [
            CuratedReviewPrefill(
                id: "starter.coffee-family",
                merchantPattern: "coffee",
                assignment: ClassificationAssignment(
                    categoryID: curatedCategoryID,
                    merchantName: "Curated Coffee"
                ),
                matchKind: .contains
            ),
        ],
        heuristics: [
            ClassificationHeuristic(
                merchantPattern: "coffee",
                categoryID: heuristicCategoryID,
                merchantName: "Heuristic Coffee"
            ),
        ],
        suggestionProvider: FixedSuggestionProvider(
            suggestion: ClassificationSuggestion(
                assignment: ClassificationAssignment(
                    categoryID: suggestedCategoryID,
                    merchantName: "Suggested Coffee"
                ),
                confidence: 0.99,
                sourceReference: "fixture"
            )
        ),
        priorAcceptedMerchantNames: ["coffee shop"]
    )

    let decision = engine.classify(candidate: coffeeCandidate())

    #expect(decision.assignment?.categoryID == curatedCategoryID)
    #expect(decision.assignment?.merchantName == "Curated Coffee")
    #expect(decision.source == .curatedPrefill)
    #expect(decision.isAutoAccepted == false)
}

@Test
func explicitRulesStillTakePrecedenceOverCuratedReviewPrefills() {
    let explicitCategoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000111")!
    let curatedCategoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000222")!
    let ruleID = UUID(uuidString: "00000000-0000-0000-0000-000000000333")!
    let rule = ClassificationRule(
        id: ruleID,
        merchantPattern: "coffee",
        categoryID: explicitCategoryID,
        merchantName: "Explicit Coffee"
    )
    let engine = ClassificationEngine(
        explicitRules: [
            rule,
        ],
        curatedReviewPrefills: [
            CuratedReviewPrefill(
                id: "starter.coffee-family",
                merchantPattern: "coffee",
                assignment: ClassificationAssignment(
                    categoryID: curatedCategoryID,
                    merchantName: "Curated Coffee"
                ),
                matchKind: .contains
            ),
        ]
    )

    let decision = engine.classify(candidate: coffeeCandidate())

    #expect(decision == .autoAccepted(
        assignment: ClassificationAssignment(
            categoryID: explicitCategoryID,
            merchantName: "Explicit Coffee"
        ),
        source: .rule,
        sourceReference: ruleID.uuidString,
        confidence: 1.0,
        reason: "Matched explicit merchant rule."
    ))
}

@Test
func deterministicSeededSourceIDCanonicalizesWhitespaceAndCasingOnlyPatternChanges() {
    let categoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000777")!
    let loosePatternRule = ClassificationRule(
        merchantPattern: "  Coffee Shop  ",
        categoryID: categoryID,
        merchantName: "Coffee Shop",
        sourceReferenceKind: .seededSourceID
    )
    let canonicalPatternRule = ClassificationRule(
        merchantPattern: "coffee shop",
        categoryID: categoryID,
        merchantName: "Coffee Shop",
        sourceReferenceKind: .seededSourceID
    )

    #expect(loosePatternRule.seededSourceID == canonicalPatternRule.seededSourceID)
}

@Test
func curatedReviewPrefillsIgnoreSeededHeuristicAutoAcceptPreference() {
    let categoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000111")!
    let engine = ClassificationEngine(
        curatedReviewPrefills: [
            CuratedReviewPrefill(
                id: "starter.coffee-family",
                merchantPattern: "coffee",
                assignment: ClassificationAssignment(
                    categoryID: categoryID,
                    merchantName: "Curated Coffee"
                ),
                matchKind: .contains
            ),
        ],
        seededHeuristicAutoAcceptEnabled: true
    )

    let decision = engine.classify(candidate: coffeeCandidate())

    #expect(decision.isAutoAccepted == false)
    #expect(decision.source == .curatedPrefill)
    #expect(decision.reason == "Curated starter match requires review before acceptance.")
}

@Test
func curatedReviewPrefillsUseExactThenPrefixThenContainsOrdering() {
    let containsCategoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000111")!
    let prefixCategoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000222")!
    let exactCategoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000333")!
    let engine = ClassificationEngine(
        curatedReviewPrefills: [
            CuratedReviewPrefill(
                id: "starter.contains",
                merchantPattern: "99pledg",
                assignment: ClassificationAssignment(
                    categoryID: containsCategoryID,
                    merchantName: "Contains Match"
                ),
                matchKind: .contains
            ),
            CuratedReviewPrefill(
                id: "starter.prefix",
                merchantPattern: "99pledg",
                assignment: ClassificationAssignment(
                    categoryID: prefixCategoryID,
                    merchantName: "Prefix Match"
                ),
                matchKind: .prefixNormalizedMerchant
            ),
            CuratedReviewPrefill(
                id: "starter.exact",
                merchantPattern: "99pledg onir baweja",
                assignment: ClassificationAssignment(
                    categoryID: exactCategoryID,
                    merchantName: "Exact Match"
                ),
                matchKind: .exactNormalizedMerchant
            ),
        ]
    )

    let decision = engine.classify(
        candidate: NormalizedImportCandidate(
            rowHash: "row-1",
            sourceLineNumber: 2,
            transactionDate: Date(timeIntervalSince1970: 1_775_171_200),
            rawDescription: "99PLEDG*ONIR BAWEJA",
            normalizedMerchantName: "99pledg onir baweja",
            amount: Decimal(-25)
        )
    )

    #expect(decision == .reviewRequired(
        prefill: ClassificationAssignment(
            categoryID: exactCategoryID,
            merchantName: "Exact Match"
        ),
        source: .curatedPrefill,
        sourceReference: "starter.exact",
        confidence: nil,
        reason: "Curated starter match requires review before acceptance."
    ))
}

@Test
func exactRulesMatchOnlyExactNormalizedMerchantNames() {
    let categoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000111")!
    let engine = ClassificationEngine(
        explicitRules: [
            ClassificationRule(
                merchantPattern: "coffee shop",
                categoryID: categoryID,
                merchantName: "Coffee Shop",
                matchKind: .exactNormalizedMerchant
            ),
        ]
    )

    let exactDecision = engine.classify(candidate: coffeeCandidate())
    let nonExactDecision = engine.classify(
        candidate: NormalizedImportCandidate(
            rowHash: "row-2",
            sourceLineNumber: 3,
            transactionDate: Date(timeIntervalSince1970: 1_775_171_260),
            rawDescription: "Coffee Shop Downtown",
            normalizedMerchantName: "coffee shop downtown",
            amount: Decimal(-7.25)
        )
    )

    #expect(exactDecision.isAutoAccepted)
    #expect(nonExactDecision == .reviewRequired(
        prefill: nil,
        source: nil,
        sourceReference: nil,
        confidence: nil,
        reason: "No classification matched."
    ))
}

@Test
func prefixRulesMatchSharedMerchantFamilyAtTheStartOnly() {
    let categoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000111")!
    let engine = ClassificationEngine(
        explicitRules: [
            ClassificationRule(
                merchantPattern: "99pledg",
                categoryID: categoryID,
                merchantName: "Pledge",
                matchKind: .prefixNormalizedMerchant
            ),
        ]
    )

    let prefixDecision = engine.classify(
        candidate: NormalizedImportCandidate(
            rowHash: "row-prefix",
            sourceLineNumber: 2,
            transactionDate: Date(timeIntervalSince1970: 1_775_171_200),
            rawDescription: "99PLEDG*ONIR BAWEJA",
            normalizedMerchantName: "99pledg onir baweja",
            amount: Decimal(-25)
        )
    )
    let nonPrefixDecision = engine.classify(
        candidate: NormalizedImportCandidate(
            rowHash: "row-non-prefix",
            sourceLineNumber: 3,
            transactionDate: Date(timeIntervalSince1970: 1_775_171_260),
            rawDescription: "ONIR BAWEJA 99PLEDG",
            normalizedMerchantName: "onir baweja 99pledg",
            amount: Decimal(-25)
        )
    )

    #expect(prefixDecision.isAutoAccepted)
    #expect(nonPrefixDecision == .reviewRequired(
        prefill: nil,
        source: nil,
        sourceReference: nil,
        confidence: nil,
        reason: "No classification matched."
    ))
}

@Test
func readOnlyLearnedRuleMatcherReusesExactPrefixAndContainsMatchingSemantics() {
    let exactCandidate = LearnedRuleMatchCandidate(
        normalizedMerchantName: "alias merchant",
        rawDescription: "Coffee Shop"
    )
    let prefixCandidate = LearnedRuleMatchCandidate(
        normalizedMerchantName: "other merchant",
        rawDescription: "99PLEDG*ONIR BAWEJA"
    )
    let containsCandidate = LearnedRuleMatchCandidate(
        normalizedMerchantName: "daily coffee roasters",
        rawDescription: "DAILY COFFEE ROASTERS"
    )

    #expect(LearnedRuleMatcher.matches(
        merchantPattern: "coffee shop",
        matchKind: .exactNormalizedMerchant,
        candidate: exactCandidate
    ))
    #expect(LearnedRuleMatcher.matches(
        merchantPattern: "99pledg",
        matchKind: .prefixNormalizedMerchant,
        candidate: prefixCandidate
    ))
    #expect(LearnedRuleMatcher.matches(
        merchantPattern: "coffee",
        matchKind: .contains,
        candidate: containsCandidate
    ))
    #expect(LearnedRuleMatcher.matches(
        merchantPattern: "coffee shop",
        matchKind: .exactNormalizedMerchant,
        candidate: LearnedRuleMatchCandidate(
            normalizedMerchantName: "coffee shop downtown",
            rawDescription: "Coffee Shop Downtown"
        )
    ) == false)
}

@Test
func userFacingPrecedenceStatementsDescribeExactPrefixContainsOrder() {
    #expect(
        ClassificationRuleMatchKind.exactNormalizedMerchant.precedenceExplanation
            == "Precedence: Exact merchant beats Shared prefix and Contains for the same merchant text."
    )
    #expect(
        ClassificationRuleMatchKind.prefixNormalizedMerchant.precedenceExplanation
            == "Precedence: Shared prefix beats Contains, but Exact merchant beats Shared prefix when both match."
    )
    #expect(
        ClassificationRuleMatchKind.contains.precedenceExplanation
            == "Precedence: Contains is checked after Exact merchant and Shared prefix."
    )
}

@Test
func testMatchNormalizesUserEnteredMerchantTextForExactPrefixAndContainsRules() {
    #expect(
        LearnedRuleMatcher.testMatch(
            merchantPattern: "coffee shop",
            matchKind: .exactNormalizedMerchant,
            userEnteredMerchantText: "  COFFEE SHOP  "
        )
    )
    #expect(
        LearnedRuleMatcher.testMatch(
            merchantPattern: "99pledg",
            matchKind: .prefixNormalizedMerchant,
            userEnteredMerchantText: "99PLEDG*ONIR BAWEJA"
        )
    )
    #expect(
        LearnedRuleMatcher.testMatch(
            merchantPattern: "coffee",
            matchKind: .contains,
            userEnteredMerchantText: "DAILY COFFEE ROASTERS"
        )
    )
    #expect(
        LearnedRuleMatcher.testMatch(
            merchantPattern: "coffee shop",
            matchKind: .exactNormalizedMerchant,
            userEnteredMerchantText: "Coffee Shop Downtown"
        ) == false
    )
}

@Test
func patternLikeMerchantsOfferExactAndPrefixLearningOptions() {
    let options = ReviewRuleLearningOption.options(forNormalizedMerchantName: "99pledg onir baweja")

    #expect(options == [
        .exactNormalizedMerchant(pattern: "99pledg onir baweja"),
        .prefixNormalizedMerchant(pattern: "99pledg"),
    ])
    #expect(
        ReviewRuleLearningOption.defaultOption(forNormalizedMerchantName: "99pledg onir baweja")
            == .exactNormalizedMerchant(pattern: "99pledg onir baweja")
    )
}

@Test
func reviewLearningOptionsNeverExposeContainsMatching() {
    let patternLikeOptions = ReviewRuleLearningOption.options(
        forNormalizedMerchantName: "99pledg onir baweja"
    )
    let ordinaryOptions = ReviewRuleLearningOption.options(
        forNormalizedMerchantName: "daily coffee roasters"
    )

    #expect(
        patternLikeOptions.allSatisfy { option in
            switch option {
            case .exactNormalizedMerchant, .prefixNormalizedMerchant:
                true
            }
        }
    )
    #expect(
        ordinaryOptions.allSatisfy { option in
            switch option {
            case .exactNormalizedMerchant, .prefixNormalizedMerchant:
                true
            }
        }
    )
}

@Test
func containsMatchKindUsesStrongerManualAuthoringWarningCopy() {
    #expect(ClassificationRuleMatchKind.contains.isAdvancedManualAuthoringOption)
    #expect(
        ClassificationRuleMatchKind.contains.manualAuthoringWarningText
            == "Contains can match multiple merchants and may recategorize accepted transactions that are already in this workspace."
    )
    #expect(ClassificationRuleMatchKind.prefixNormalizedMerchant.manualAuthoringWarningText == nil)
}

@Test
func ordinaryMerchantsOnlyOfferExactLearning() {
    let options = ReviewRuleLearningOption.options(forNormalizedMerchantName: "dishdash 408 7741889 ca")

    #expect(options == [
        .exactNormalizedMerchant(pattern: "dishdash 408 7741889 ca"),
    ])
    #expect(
        ReviewRuleLearningOption.defaultOption(forNormalizedMerchantName: "dishdash 408 7741889 ca")
            == .exactNormalizedMerchant(pattern: "dishdash 408 7741889 ca")
    )
}

@Test
func learnedRuleFallbackPatternNormalizesWhitespaceOnlyInput() {
    let exactRule = ReviewRuleLearningOption
        .exactNormalizedMerchant(pattern: "   ")
        .resolvingEmptyPattern(fallbackPattern: "Coffee Shop")
    let prefixRule = ReviewRuleLearningOption
        .prefixNormalizedMerchant(pattern: "   ")
        .resolvingEmptyPattern(fallbackPattern: "99PLEDG Onir Baweja")

    #expect(exactRule == .exactNormalizedMerchant(pattern: "coffee shop"))
    #expect(prefixRule == .prefixNormalizedMerchant(pattern: "99pledg onir baweja"))
}

@Test
func appendedRulesTakePrecedenceOverSeededRules() {
    let seededCategoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000111")!
    let learnedCategoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000222")!
    let engine = ClassificationEngine(
        explicitRules: [
            ClassificationRule(
                merchantPattern: "coffee shop",
                categoryID: seededCategoryID,
                merchantName: "Seeded Coffee",
                matchKind: .exactNormalizedMerchant
            ),
        ]
    )
    .appendingExplicitRules([
        ClassificationRule(
            merchantPattern: "coffee shop",
            categoryID: learnedCategoryID,
            merchantName: "Learned Coffee",
            matchKind: .exactNormalizedMerchant
        ),
    ])

    let decision = engine.classify(candidate: coffeeCandidate())

    #expect(decision.assignment?.categoryID == learnedCategoryID)
    #expect(decision.assignment?.merchantName == "Learned Coffee")
}

@Test
func exactLearnedRulesTakePrecedenceOverBroaderPrefixRules() {
    let prefixCategoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000111")!
    let exactCategoryID = UUID(uuidString: "00000000-0000-0000-0000-000000000222")!
    let engine = ClassificationEngine()
        .appendingExplicitRules([
            ClassificationRule(
                merchantPattern: "99pledg",
                categoryID: prefixCategoryID,
                merchantName: "Pledge Family",
                matchKind: .prefixNormalizedMerchant
            ),
            ClassificationRule(
                merchantPattern: "99pledg onir baweja",
                categoryID: exactCategoryID,
                merchantName: "Onir Baweja",
                matchKind: .exactNormalizedMerchant
            ),
        ])

    let decision = engine.classify(
        candidate: NormalizedImportCandidate(
            rowHash: "row-1",
            sourceLineNumber: 2,
            transactionDate: Date(timeIntervalSince1970: 1_775_171_200),
            rawDescription: "99PLEDG*ONIR BAWEJA",
            normalizedMerchantName: "99pledg onir baweja",
            amount: Decimal(-25)
        )
    )

    #expect(decision.assignment?.categoryID == exactCategoryID)
    #expect(decision.assignment?.merchantName == "Onir Baweja")
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

@Test
func seededClassifierMatchesRepresentativeSampleMerchants() {
    let classifier = SeededClassification.liveClassifier()
    let cases: [(description: String, categoryID: UUID, autoAccepted: Bool)] = [
        ("VENMO            PAYMENT    1049657853223   WEB ID: 3264681992", DefaultBudgetTaxonomy.CategoryID.transfers, true),
        ("CONNECTYOURCARE  OPTUMCLAIM                 PPD ID: 7261274092", DefaultBudgetTaxonomy.CategoryID.medicalAndPharmacy, true),
        ("IRS              USATAXPYMT 240650542279973 WEB ID: 3387702000", DefaultBudgetTaxonomy.CategoryID.taxes, true),
        ("PGANDE           WEB ONLINE 69773024032626  WEB ID: 5940742640", DefaultBudgetTaxonomy.CategoryID.utilities, true),
        ("DISHDASH 408-7741889 CA", DefaultBudgetTaxonomy.CategoryID.restaurantsAndBars, true),
        ("AUTOPAY 999990000061865RAUTOPAY AUTO-PMT", DefaultBudgetTaxonomy.CategoryID.transfers, true),
        ("KHANS KARAHI KABOB (WA 165-06819470 CA", DefaultBudgetTaxonomy.CategoryID.restaurantsAndBars, true),
        ("MERIT VEGAN RESTAURANT Sunnyvale CA", DefaultBudgetTaxonomy.CategoryID.restaurantsAndBars, true),
        ("HAPPY SUSHI SANTA CLARA CA", DefaultBudgetTaxonomy.CategoryID.restaurantsAndBars, true),
        ("SQ *TOBANG KOREAN BBQ SANTA CLARA CA", DefaultBudgetTaxonomy.CategoryID.restaurantsAndBars, true),
        ("SRI ANANDABHAVAN SUNNYVALE CA null XXXXXXXXXXXX3969", DefaultBudgetTaxonomy.CategoryID.restaurantsAndBars, true),
        ("WALMART.COM WALMART.COM AR", DefaultBudgetTaxonomy.CategoryID.shoppingAndClothing, true),
        ("FLAGSTAR BANK TROY MI", DefaultBudgetTaxonomy.CategoryID.rentAndMortgage, true),
        ("TAJ MAHAL SUNNYVALE CA null XXXXXXXXXXXX2110", DefaultBudgetTaxonomy.CategoryID.restaurantsAndBars, true),
        ("PAMF 2441 MISSION CO M SANTA CLARA CA null XXXXXXXXXXXX3969", DefaultBudgetTaxonomy.CategoryID.medicalAndPharmacy, true),
        ("CHAVEZ SUPERMARKET SUNNYVALE CA null XXXXXXXXXXXX2110", DefaultBudgetTaxonomy.CategoryID.groceries, true),
        ("FRANCHISE TAX BO PAYMENTS   129035404    PM WEB ID: 1282532045", DefaultBudgetTaxonomy.CategoryID.taxes, true),
        ("INTEREST PAID 03-31-2026", DefaultBudgetTaxonomy.CategoryID.income, true),
        ("AUTOMATIC PAYMENT - THANK", DefaultBudgetTaxonomy.CategoryID.transfers, true),
        ("META             DIRECT DEP                 PPD ID: 9111111101", DefaultBudgetTaxonomy.CategoryID.income, true),
        ("DISNEYPLUS          888-905-7888        CA", DefaultBudgetTaxonomy.CategoryID.subscriptionsAndEntertainment, true),
        ("GOOGLE *YOUTUBEPREMIUM MOUNTAIN VIEW CA", DefaultBudgetTaxonomy.CategoryID.subscriptionsAndEntertainment, true),
        ("BLUE BOTTLE COFFEE PALO ALTO CA", DefaultBudgetTaxonomy.CategoryID.coffeeShops, true),
        ("T J MAXX #0712 SUNNYVALE CA", DefaultBudgetTaxonomy.CategoryID.shoppingAndClothing, true),
        ("MARSHALLS #0567 SAN JOSE CA", DefaultBudgetTaxonomy.CategoryID.shoppingAndClothing, true),
        ("PROGRESSIVE INS 4407", DefaultBudgetTaxonomy.CategoryID.autoMaintenanceAndInsurance, true),
        ("BB TUITION MGMT ACH", DefaultBudgetTaxonomy.CategoryID.educationAndStudentLoans, true),
        ("BEAST ACADEMY ONLINE", DefaultBudgetTaxonomy.CategoryID.educationAndStudentLoans, true),
        ("AIRBORNE GYMNASTICS CAMP", DefaultBudgetTaxonomy.CategoryID.childcareAndKidsActivities, true),
        ("WATERWORKS SWIM SCHOOL", DefaultBudgetTaxonomy.CategoryID.childcareAndKidsActivities, true),
        ("TUTU SCHOOL LOS ALTOS", DefaultBudgetTaxonomy.CategoryID.childcareAndKidsActivities, true),
        ("FIRST POSITION DANCE CO", DefaultBudgetTaxonomy.CategoryID.childcareAndKidsActivities, true),
        ("BITES* CHAAT BHAVAN EX WWW.DELIVERYCCA", DefaultBudgetTaxonomy.CategoryID.restaurantsAndBars, false),
    ]

    for (index, testCase) in cases.enumerated() {
        let decision = classifier.classify(
            candidate: NormalizedImportCandidate(
                rowHash: "sample-\(index)",
                sourceLineNumber: index + 2,
                transactionDate: Date(timeIntervalSince1970: 1_775_171_200 + Double(index)),
                rawDescription: testCase.description,
                normalizedMerchantName: MerchantNormalizer().normalize(testCase.description),
                amount: Decimal(-10)
            )
        )

        #expect(decision.isAutoAccepted == testCase.autoAccepted)
        #expect(decision.assignment?.categoryID == testCase.categoryID)
    }
}

@Test
func seededClassifierRoutesRepresentativeCuratedPrefillThroughReview() {
    let classifier = SeededClassification.liveClassifier()
    let cases: [(description: String, categoryID: UUID, merchantName: String, sourceReference: String)] = [
        ("99PLEDG*ONIR BAWEJA", DefaultBudgetTaxonomy.CategoryID.donations, "99PLEDG", "starter.99pledg.family"),
        ("CHOICELUNCH 855-465-8624 CA", DefaultBudgetTaxonomy.CategoryID.childcareAndKidsActivities, "Choicelunch", "starter.choicelunch.school-lunch"),
        ("LINELEADER       J2542 RCUR                 PPD ID: 8263863381", DefaultBudgetTaxonomy.CategoryID.childcareAndKidsActivities, "LineLeader", "starter.lineleader.childcare-billing"),
    ]

    for (index, testCase) in cases.enumerated() {
        let decision = classifier.classify(
            candidate: NormalizedImportCandidate(
                rowHash: "curated-\(index)",
                sourceLineNumber: index + 2,
                transactionDate: Date(timeIntervalSince1970: 1_775_171_200 + Double(index)),
                rawDescription: testCase.description,
                normalizedMerchantName: MerchantNormalizer().normalize(testCase.description),
                amount: Decimal(-25)
            )
        )

        #expect(decision == .reviewRequired(
            prefill: ClassificationAssignment(
                categoryID: testCase.categoryID,
                merchantName: testCase.merchantName
            ),
            source: .curatedPrefill,
            sourceReference: testCase.sourceReference,
            confidence: nil,
            reason: "Curated starter match requires review before acceptance."
        ))
    }
}

@Test
func seededClassifierUsesSaferPrefixMatchingForFirstPositionDance() {
    let classifier = SeededClassification.liveClassifier()

    let prefixedDecision = classifier.classify(
        candidate: NormalizedImportCandidate(
            rowHash: "first-position-prefix",
            sourceLineNumber: 2,
            transactionDate: Date(timeIntervalSince1970: 1_775_171_600),
            rawDescription: "FIRST POSITION DANCE CO",
            normalizedMerchantName: MerchantNormalizer().normalize("FIRST POSITION DANCE CO"),
            amount: Decimal(-75)
        )
    )
    let embeddedDecision = classifier.classify(
        candidate: NormalizedImportCandidate(
            rowHash: "first-position-embedded",
            sourceLineNumber: 3,
            transactionDate: Date(timeIntervalSince1970: 1_775_171_601),
            rawDescription: "MY FIRST POSITION DANCE RECITAL",
            normalizedMerchantName: MerchantNormalizer().normalize("MY FIRST POSITION DANCE RECITAL"),
            amount: Decimal(-75)
        )
    )

    #expect(prefixedDecision.isAutoAccepted)
    #expect(prefixedDecision.assignment?.categoryID == DefaultBudgetTaxonomy.CategoryID.childcareAndKidsActivities)
    #expect(embeddedDecision.assignment?.categoryID != DefaultBudgetTaxonomy.CategoryID.childcareAndKidsActivities)
    #expect(embeddedDecision.assignment?.merchantName != "First Position Dance")
}

@Test
func seededClassifierRoutesAirlinesToFlights() {
    let classifier = SeededClassification.liveClassifier()

    let cases: [(description: String, merchantName: String)] = [
        ("AIR INDIA DELHI IN", "Air India"),
        ("EMIRATES 800-777-3999 AE", "Emirates"),
        ("UNITED AIRLINES HOUSTON TX", "United Airlines"),
        ("TURKISH AIRLINES SAN FRANCISCO CA", "Turkish Airlines"),
    ]

    for (index, testCase) in cases.enumerated() {
        let decision = classifier.classify(
            candidate: NormalizedImportCandidate(
                rowHash: "flight-\(index)",
                sourceLineNumber: index + 2,
                transactionDate: Date(timeIntervalSince1970: 1_775_171_200 + Double(index)),
                rawDescription: testCase.description,
                normalizedMerchantName: MerchantNormalizer().normalize(testCase.description),
                amount: Decimal(-250)
            )
        )

        #expect(decision.isAutoAccepted)
        #expect(decision.assignment?.categoryID == DefaultBudgetTaxonomy.CategoryID.flights)
        #expect(decision.assignment?.merchantName == testCase.merchantName)
        #expect(decision.source == .rule)
        #expect(decision.reason == "Matched explicit merchant rule.")
    }
}

@Test
func seededClassifierRoutesClearHotelDescriptorsToHotels() {
    let classifier = SeededClassification.liveClassifier()

    let cases: [(description: String, merchantName: String)] = [
        ("GRAND HYATT SFO SAN FRANCISCO CA", "Grand Hyatt"),
        ("MARRIOTT MARQUIS SAN DIEGO CA", "Marriott Marquis"),
        ("WESTIN ST FRANCIS SAN FRANCISCO CA", "Westin St. Francis"),
    ]

    for (index, testCase) in cases.enumerated() {
        let decision = classifier.classify(
            candidate: NormalizedImportCandidate(
                rowHash: "hotel-\(index)",
                sourceLineNumber: index + 2,
                transactionDate: Date(timeIntervalSince1970: 1_775_171_300 + Double(index)),
                rawDescription: testCase.description,
                normalizedMerchantName: MerchantNormalizer().normalize(testCase.description),
                amount: Decimal(-400)
            )
        )

        #expect(decision.isAutoAccepted)
        #expect(decision.assignment?.categoryID == DefaultBudgetTaxonomy.CategoryID.hotels)
        #expect(decision.assignment?.merchantName == testCase.merchantName)
        #expect(decision.source == .rule)
        #expect(decision.reason == "Matched explicit merchant rule.")
    }
}

@Test
func seededClassifierRoutesTravelAggregatorsThroughReviewFirst() {
    let classifier = SeededClassification.liveClassifier()

    let cases: [(description: String, merchantName: String, sourceReference: String)] = [
        ("BOOKING.COM AMSTERDAM NL", "Booking.com", "starter.travel.booking-com"),
        ("AMEX TRAVEL 800-297-2977 CA", "Amex Travel", "starter.travel.amex-travel"),
    ]

    for (index, testCase) in cases.enumerated() {
        let decision = classifier.classify(
            candidate: NormalizedImportCandidate(
                rowHash: "aggregator-\(index)",
                sourceLineNumber: index + 2,
                transactionDate: Date(timeIntervalSince1970: 1_775_171_400 + Double(index)),
                rawDescription: testCase.description,
                normalizedMerchantName: MerchantNormalizer().normalize(testCase.description),
                amount: Decimal(-325)
            )
        )

        #expect(decision == .reviewRequired(
            prefill: ClassificationAssignment(
                categoryID: DefaultBudgetTaxonomy.CategoryID.hotels,
                merchantName: testCase.merchantName
            ),
            source: .curatedPrefill,
            sourceReference: testCase.sourceReference,
            confidence: nil,
            reason: "Curated starter match requires review before acceptance."
        ))
    }
}

@Test
func issuerCreditArtifactsRouteThroughBuiltInReviewFirst() {
    let classifier = SeededClassification.liveClassifier()
    let cases: [(description: String, categoryID: UUID, merchantName: String, sourceReference: String)] = [
        (
            "PLATINUM DIGITAL ENTERTAINMENT CREDIT",
            DefaultBudgetTaxonomy.CategoryID.subscriptionsAndEntertainment,
            "Platinum Digital Entertainment Credit",
            "starter.issuer-credit.platinum-digital-entertainment-credit"
        ),
        (
            "AMEX AIRLINE FEE REIMBURSEMENT",
            DefaultBudgetTaxonomy.CategoryID.flights,
            "Amex Airline Fee Reimbursement",
            "starter.issuer-credit.amex-airline-fee-reimbursement"
        ),
        (
            "PLATINUM HOTEL CREDIT",
            DefaultBudgetTaxonomy.CategoryID.hotels,
            "Platinum Hotel Credit",
            "starter.issuer-credit.platinum-hotel-credit"
        ),
    ]

    for (index, testCase) in cases.enumerated() {
        let decision = classifier.classify(
            candidate: NormalizedImportCandidate(
                rowHash: "issuer-credit-\(index)",
                sourceLineNumber: index + 2,
                transactionDate: Date(timeIntervalSince1970: 1_775_171_500 + Double(index)),
                rawDescription: testCase.description,
                normalizedMerchantName: MerchantNormalizer().normalize(testCase.description),
                amount: Decimal(-25)
            )
        )

        #expect(decision == .reviewRequired(
            prefill: ClassificationAssignment(
                categoryID: testCase.categoryID,
                merchantName: testCase.merchantName
            ),
            source: .curatedPrefill,
            sourceReference: testCase.sourceReference,
            confidence: nil,
            reason: "Curated starter match requires review before acceptance."
        ))
    }
}

@Test
func airlineFeeReimbursementPrefillsFlights() {
    let classifier = SeededClassification.liveClassifier()

    let decision = classifier.classify(
        candidate: NormalizedImportCandidate(
            rowHash: "issuer-credit-airline",
            sourceLineNumber: 2,
            transactionDate: Date(timeIntervalSince1970: 1_775_171_510),
            rawDescription: "AMEX AIRLINE FEE REIMBURSEMENT",
            normalizedMerchantName: MerchantNormalizer().normalize("AMEX AIRLINE FEE REIMBURSEMENT"),
            amount: Decimal(-200)
        )
    )

    #expect(decision.assignment?.categoryID == DefaultBudgetTaxonomy.CategoryID.flights)
    #expect(decision.assignment?.merchantName == "Amex Airline Fee Reimbursement")
    #expect(decision.source == .curatedPrefill)
    #expect(decision.source != .rule)
    #expect(decision.source != .heuristic)
    #expect(decision.isAutoAccepted == false)
}

@Test
func hotelCreditPrefillsHotels() {
    let classifier = SeededClassification.liveClassifier()

    let decision = classifier.classify(
        candidate: NormalizedImportCandidate(
            rowHash: "issuer-credit-hotel",
            sourceLineNumber: 2,
            transactionDate: Date(timeIntervalSince1970: 1_775_171_520),
            rawDescription: "PLATINUM HOTEL CREDIT",
            normalizedMerchantName: MerchantNormalizer().normalize("PLATINUM HOTEL CREDIT"),
            amount: Decimal(-200)
        )
    )

    #expect(decision.assignment?.categoryID == DefaultBudgetTaxonomy.CategoryID.hotels)
    #expect(decision.assignment?.merchantName == "Platinum Hotel Credit")
    #expect(decision.source == .curatedPrefill)
    #expect(decision.source != .rule)
    #expect(decision.source != .heuristic)
    #expect(decision.isAutoAccepted == false)
}

@Test
func specificSeededRulesBeatBroaderMerchantRules() {
    let classifier = SeededClassification.liveClassifier()

    let costcoRxDecision = classifier.classify(
        candidate: NormalizedImportCandidate(
            rowHash: "costco-rx",
            sourceLineNumber: 2,
            transactionDate: Date(timeIntervalSince1970: 1_775_171_200),
            rawDescription: "COSTCO RX #0423 7144342702 CA",
            normalizedMerchantName: MerchantNormalizer().normalize("COSTCO RX #0423 7144342702 CA"),
            amount: Decimal(-12.34)
        )
    )
    let walmartComDecision = classifier.classify(
        candidate: NormalizedImportCandidate(
            rowHash: "walmart-com",
            sourceLineNumber: 3,
            transactionDate: Date(timeIntervalSince1970: 1_775_171_260),
            rawDescription: "WALMART.COM WALMART.COM AR",
            normalizedMerchantName: MerchantNormalizer().normalize("WALMART.COM WALMART.COM AR"),
            amount: Decimal(-2.53)
        )
    )
    let walmartStoreDecision = classifier.classify(
        candidate: NormalizedImportCandidate(
            rowHash: "wal-mart-store",
            sourceLineNumber: 4,
            transactionDate: Date(timeIntervalSince1970: 1_775_171_320),
            rawDescription: "WAL-MART #3123 SANTA CLARA CA",
            normalizedMerchantName: MerchantNormalizer().normalize("WAL-MART #3123 SANTA CLARA CA"),
            amount: Decimal(-75.20)
        )
    )

    #expect(costcoRxDecision.assignment?.categoryID == DefaultBudgetTaxonomy.CategoryID.medicalAndPharmacy)
    #expect(walmartComDecision.assignment?.categoryID == DefaultBudgetTaxonomy.CategoryID.shoppingAndClothing)
    #expect(walmartStoreDecision.assignment?.categoryID == DefaultBudgetTaxonomy.CategoryID.groceries)
}
