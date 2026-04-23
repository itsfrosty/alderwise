import Foundation

public enum ClassificationDecisionSource: String, Codable, Equatable, Sendable {
    case rule
    case curatedPrefill
    case heuristic
    case suggestion
    case user
}

public enum ClassificationRuleMatchKind: String, Codable, Equatable, Sendable {
    case contains
    case exactNormalizedMerchant = "exact_normalized_merchant"
    case prefixNormalizedMerchant = "prefix_normalized_merchant"
}

public extension ClassificationRuleMatchKind {
    var isAdvancedManualAuthoringOption: Bool {
        self == .contains
    }

    var manualAuthoringHelpText: String {
        switch self {
        case .exactNormalizedMerchant:
            "Exact merchant matches one normalized merchant name."
        case .prefixNormalizedMerchant:
            "Shared prefix matches merchants that start with the same normalized prefix."
        case .contains:
            "Contains matches any normalized merchant name that includes this text."
        }
    }

    var manualAuthoringWarningText: String? {
        switch self {
        case .contains:
            "Contains can match multiple merchants and may recategorize accepted transactions that are already in this workspace."
        case .exactNormalizedMerchant, .prefixNormalizedMerchant:
            nil
        }
    }
}

public struct ClassificationAssignment: Codable, Equatable, Sendable {
    public var categoryID: UUID
    public var merchantName: String?

    public init(categoryID: UUID, merchantName: String?) {
        self.categoryID = categoryID
        self.merchantName = merchantName
    }
}

public struct ClassificationRule: Equatable, Sendable {
    public var id: UUID
    public var merchantPattern: String
    public var categoryID: UUID
    public var merchantName: String?
    public var matchKind: ClassificationRuleMatchKind

    public init(
        id: UUID = UUID(),
        merchantPattern: String,
        categoryID: UUID,
        merchantName: String?,
        matchKind: ClassificationRuleMatchKind = .contains
    ) {
        self.id = id
        self.merchantPattern = merchantPattern
        self.categoryID = categoryID
        self.merchantName = merchantName
        self.matchKind = matchKind
    }
}

public struct ClassificationHeuristic: Equatable, Sendable {
    public var merchantPattern: String
    public var categoryID: UUID
    public var merchantName: String?

    public init(merchantPattern: String, categoryID: UUID, merchantName: String?) {
        self.merchantPattern = merchantPattern
        self.categoryID = categoryID
        self.merchantName = merchantName
    }
}

public struct CuratedReviewPrefill: Equatable, Sendable {
    public var id: String
    public var merchantPattern: String
    public var assignment: ClassificationAssignment
    public var matchKind: ClassificationRuleMatchKind

    public init(
        id: String,
        merchantPattern: String,
        assignment: ClassificationAssignment,
        matchKind: ClassificationRuleMatchKind = .contains
    ) {
        self.id = id
        self.merchantPattern = merchantPattern
        self.assignment = assignment
        self.matchKind = matchKind
    }
}

public enum ReviewRuleLearningOption: Hashable, Codable, Equatable, Sendable {
    case exactNormalizedMerchant(pattern: String)
    case prefixNormalizedMerchant(pattern: String)

    public var pattern: String {
        switch self {
        case .exactNormalizedMerchant(let pattern),
             .prefixNormalizedMerchant(let pattern):
            pattern
        }
    }

    public var matchKind: ClassificationRuleMatchKind {
        switch self {
        case .exactNormalizedMerchant:
            .exactNormalizedMerchant
        case .prefixNormalizedMerchant:
            .prefixNormalizedMerchant
        }
    }

    public var title: String {
        switch self {
        case .exactNormalizedMerchant:
            "Exact merchant"
        case .prefixNormalizedMerchant:
            "Shared prefix"
        }
    }

    public var detail: String {
        switch self {
        case .exactNormalizedMerchant(let pattern):
            "Will match only \(pattern)."
        case .prefixNormalizedMerchant(let pattern):
            "Will match future merchants starting with \(pattern)."
        }
    }

    public func matchesMerchantName(_ merchantName: String) -> Bool {
        merchantName
            .normalizedClassificationPattern
            .matchesClassificationPattern(pattern, matchKind: matchKind)
    }

    public func resolvingEmptyPattern(fallbackPattern: String) -> ReviewRuleLearningOption {
        let resolvedPattern = pattern
            .normalizedClassificationPattern
            .nilIfEmpty
            ?? fallbackPattern.normalizedClassificationPattern

        switch matchKind {
        case .exactNormalizedMerchant:
            return .exactNormalizedMerchant(pattern: resolvedPattern)
        case .prefixNormalizedMerchant:
            return .prefixNormalizedMerchant(pattern: resolvedPattern)
        case .contains:
            return .exactNormalizedMerchant(pattern: resolvedPattern)
        }
    }

    public static func options(forNormalizedMerchantName normalizedMerchantName: String) -> [ReviewRuleLearningOption] {
        let normalizedMerchantName = normalizedMerchantName.normalizedClassificationPattern
        guard !normalizedMerchantName.isEmpty else {
            return []
        }

        var options: [ReviewRuleLearningOption] = [
            .exactNormalizedMerchant(pattern: normalizedMerchantName),
        ]
        if let prefixPattern = suggestedPrefixPattern(forNormalizedMerchantName: normalizedMerchantName) {
            options.append(.prefixNormalizedMerchant(pattern: prefixPattern))
        }
        return options
    }

    public static func defaultOption(forNormalizedMerchantName normalizedMerchantName: String) -> ReviewRuleLearningOption? {
        options(forNormalizedMerchantName: normalizedMerchantName).first
    }

    private static func suggestedPrefixPattern(forNormalizedMerchantName normalizedMerchantName: String) -> String? {
        let tokens = normalizedMerchantName.split(separator: " ").map(String.init)
        guard tokens.count >= 2 else {
            return nil
        }

        let firstToken = tokens[0]
        guard tokenLooksLikeSharedPrefix(firstToken) else {
            return nil
        }
        return firstToken
    }

    private static func tokenLooksLikeSharedPrefix(_ token: String) -> Bool {
        guard (5...16).contains(token.count) else {
            return false
        }

        let hasLetter = token.range(of: #"[a-z]"#, options: .regularExpression) != nil
        let hasDigit = token.range(of: #"\d"#, options: .regularExpression) != nil
        return hasLetter && hasDigit
    }
}

public struct LearnedRuleMatchCandidate: Equatable, Sendable {
    public var normalizedMerchantName: String
    public var rawDescription: String

    public init(normalizedMerchantName: String, rawDescription: String) {
        self.normalizedMerchantName = normalizedMerchantName
        self.rawDescription = rawDescription
    }
}

public enum LearnedRuleMatcher {
    public static func normalizedPattern(
        _ merchantPattern: String,
        fallbackPattern: String? = nil
    ) -> String? {
        merchantPattern
            .normalizedClassificationPattern
            .nilIfEmpty
            ?? fallbackPattern?.normalizedClassificationPattern.nilIfEmpty
    }

    public static func matches(
        merchantPattern: String,
        matchKind: ClassificationRuleMatchKind,
        candidate: LearnedRuleMatchCandidate,
        merchantNormalizer: MerchantNormalizer = MerchantNormalizer()
    ) -> Bool {
        matches(
            merchantPattern: merchantPattern,
            matchKind: matchKind,
            normalizedMerchantName: candidate.normalizedMerchantName
        ) || matches(
            merchantPattern: merchantPattern,
            matchKind: matchKind,
            normalizedMerchantName: merchantNormalizer.normalize(candidate.rawDescription)
        )
    }

    public static func matches(
        merchantPattern: String,
        matchKind: ClassificationRuleMatchKind,
        normalizedMerchantName: String
    ) -> Bool {
        normalizedMerchantName
            .normalizedClassificationPattern
            .matchesClassificationPattern(merchantPattern, matchKind: matchKind)
    }
}

public struct ClassificationSuggestion: Equatable, Sendable {
    public var assignment: ClassificationAssignment
    public var confidence: Double
    public var sourceReference: String?

    public init(assignment: ClassificationAssignment, confidence: Double, sourceReference: String?) {
        self.assignment = assignment
        self.confidence = confidence
        self.sourceReference = sourceReference
    }
}

public protocol SuggestionProvider: Sendable {
    func suggestion(for candidate: NormalizedImportCandidate) -> ClassificationSuggestion?
}

public struct NoOpSuggestionProvider: SuggestionProvider {
    public init() {}

    public func suggestion(for candidate: NormalizedImportCandidate) -> ClassificationSuggestion? {
        nil
    }
}

public enum TransactionClassificationDecision: Equatable, Sendable {
    case autoAccepted(
        assignment: ClassificationAssignment,
        source: ClassificationDecisionSource,
        sourceReference: String?,
        confidence: Double,
        reason: String
    )
    case reviewRequired(
        prefill: ClassificationAssignment?,
        source: ClassificationDecisionSource?,
        sourceReference: String?,
        confidence: Double?,
        reason: String
    )

    public var isAutoAccepted: Bool {
        if case .autoAccepted = self {
            true
        } else {
            false
        }
    }

    public var assignment: ClassificationAssignment? {
        switch self {
        case .autoAccepted(let assignment, _, _, _, _):
            assignment
        case .reviewRequired(let prefill, _, _, _, _):
            prefill
        }
    }

    public var source: ClassificationDecisionSource? {
        switch self {
        case .autoAccepted(_, let source, _, _, _):
            source
        case .reviewRequired(_, let source, _, _, _):
            source
        }
    }

    public var reason: String {
        switch self {
        case .autoAccepted(_, _, _, _, let reason),
             .reviewRequired(_, _, _, _, let reason):
            reason
        }
    }
}

public struct ImportRowClassification: Equatable, Sendable {
    public var rowHash: String
    public var sourceLineNumber: Int
    public var decision: TransactionClassificationDecision

    public init(rowHash: String, sourceLineNumber: Int, decision: TransactionClassificationDecision) {
        self.rowHash = rowHash
        self.sourceLineNumber = sourceLineNumber
        self.decision = decision
    }
}

public struct ClassificationEngine: Sendable {
    private let explicitRules: [ClassificationRule]
    private let curatedReviewPrefills: [CuratedReviewPrefill]
    private let heuristics: [ClassificationHeuristic]
    private let suggestionProvider: any SuggestionProvider
    private let suggestionsEnabled: Bool
    private let seededHeuristicAutoAcceptEnabled: Bool
    private let priorAcceptedMerchantNames: Set<String>
    private let suggestionAutoAcceptThreshold: Double

    public init(
        explicitRules: [ClassificationRule] = [],
        curatedReviewPrefills: [CuratedReviewPrefill] = [],
        heuristics: [ClassificationHeuristic] = [],
        suggestionProvider: any SuggestionProvider = NoOpSuggestionProvider(),
        suggestionsEnabled: Bool = true,
        seededHeuristicAutoAcceptEnabled: Bool = false,
        priorAcceptedMerchantNames: Set<String> = [],
        suggestionAutoAcceptThreshold: Double = 0.92
    ) {
        self.explicitRules = orderedExplicitRules(explicitRules)
        self.curatedReviewPrefills = orderedCuratedReviewPrefills(curatedReviewPrefills)
        self.heuristics = heuristics
        self.suggestionProvider = suggestionProvider
        self.suggestionsEnabled = suggestionsEnabled
        self.seededHeuristicAutoAcceptEnabled = seededHeuristicAutoAcceptEnabled
        self.priorAcceptedMerchantNames = Set(priorAcceptedMerchantNames.map(\.normalizedClassificationPattern))
        self.suggestionAutoAcceptThreshold = suggestionAutoAcceptThreshold
    }

    public func appendingExplicitRules(_ rules: [ClassificationRule]) -> ClassificationEngine {
        ClassificationEngine(
            explicitRules: orderedExplicitRules(rules) + explicitRules,
            curatedReviewPrefills: curatedReviewPrefills,
            heuristics: heuristics,
            suggestionProvider: suggestionProvider,
            suggestionsEnabled: suggestionsEnabled,
            seededHeuristicAutoAcceptEnabled: seededHeuristicAutoAcceptEnabled,
            priorAcceptedMerchantNames: priorAcceptedMerchantNames,
            suggestionAutoAcceptThreshold: suggestionAutoAcceptThreshold
        )
    }

    public func settingSuggestionsEnabled(_ enabled: Bool) -> ClassificationEngine {
        ClassificationEngine(
            explicitRules: explicitRules,
            curatedReviewPrefills: curatedReviewPrefills,
            heuristics: heuristics,
            suggestionProvider: suggestionProvider,
            suggestionsEnabled: enabled,
            seededHeuristicAutoAcceptEnabled: seededHeuristicAutoAcceptEnabled,
            priorAcceptedMerchantNames: priorAcceptedMerchantNames,
            suggestionAutoAcceptThreshold: suggestionAutoAcceptThreshold
        )
    }

    public func settingSeededHeuristicAutoAcceptEnabled(_ enabled: Bool) -> ClassificationEngine {
        ClassificationEngine(
            explicitRules: explicitRules,
            curatedReviewPrefills: curatedReviewPrefills,
            heuristics: heuristics,
            suggestionProvider: suggestionProvider,
            suggestionsEnabled: suggestionsEnabled,
            seededHeuristicAutoAcceptEnabled: enabled,
            priorAcceptedMerchantNames: priorAcceptedMerchantNames,
            suggestionAutoAcceptThreshold: suggestionAutoAcceptThreshold
        )
    }

    public func classify(
        candidate: NormalizedImportCandidate,
        hasDuplicateConcern: Bool = false
    ) -> TransactionClassificationDecision {
        if let rule = explicitRules.first(where: { $0.matches(candidate) }) {
            let assignment = ClassificationAssignment(categoryID: rule.categoryID, merchantName: rule.merchantName)
            if hasDuplicateConcern {
                return .reviewRequired(
                    prefill: assignment,
                    source: .rule,
                    sourceReference: rule.id.uuidString,
                    confidence: 1.0,
                    reason: "Duplicate concern requires review."
                )
            }

            return .autoAccepted(
                assignment: assignment,
                source: .rule,
                sourceReference: rule.id.uuidString,
                confidence: 1.0,
                reason: "Matched explicit merchant rule."
            )
        }

        if let curatedReviewPrefill = curatedReviewPrefills.first(where: { $0.matches(candidate) }) {
            return .reviewRequired(
                prefill: curatedReviewPrefill.assignment,
                source: .curatedPrefill,
                sourceReference: curatedReviewPrefill.id,
                confidence: nil,
                reason: "Curated starter match requires review before acceptance."
            )
        }

        if let heuristic = heuristics.first(where: { $0.matches(candidate) }) {
            let assignment = ClassificationAssignment(categoryID: heuristic.categoryID, merchantName: heuristic.merchantName)
            if seededHeuristicAutoAcceptEnabled, !hasDuplicateConcern {
                return .autoAccepted(
                    assignment: assignment,
                    source: .heuristic,
                    sourceReference: nil,
                    confidence: 0.65,
                    reason: "Aggressive seeded heuristic matched."
                )
            }

            return .reviewRequired(
                prefill: assignment,
                source: .heuristic,
                sourceReference: nil,
                confidence: 0.65,
                reason: "Deterministic heuristic requires review."
            )
        }

        guard suggestionsEnabled, let suggestion = suggestionProvider.suggestion(for: candidate) else {
            return .reviewRequired(
                prefill: nil,
                source: nil,
                sourceReference: nil,
                confidence: nil,
                reason: "No classification matched."
            )
        }

        if suggestion.confidence >= suggestionAutoAcceptThreshold,
           priorAcceptedMerchantNames.contains(candidate.normalizedMerchantName),
           !hasDuplicateConcern {
            return .autoAccepted(
                assignment: suggestion.assignment,
                source: .suggestion,
                sourceReference: suggestion.sourceReference,
                confidence: suggestion.confidence,
                reason: "High-confidence suggestion backed by prior accepted merchant history."
            )
        }

        return .reviewRequired(
            prefill: suggestion.assignment,
            source: .suggestion,
            sourceReference: suggestion.sourceReference,
            confidence: suggestion.confidence,
            reason: "Suggestion requires review."
        )
    }
}

private func orderedExplicitRules(_ rules: [ClassificationRule]) -> [ClassificationRule] {
    orderedMatchKindItems(rules)
}

private func orderedCuratedReviewPrefills(_ prefills: [CuratedReviewPrefill]) -> [CuratedReviewPrefill] {
    orderedMatchKindItems(prefills)
}

private func orderedMatchKindItems<Item: MatchKindOrdered>(_ items: [Item]) -> [Item] {
    items.enumerated()
        .sorted { lhs, rhs in
            let lhsPriority = lhs.element.matchPriority
            let rhsPriority = rhs.element.matchPriority
            if lhsPriority != rhsPriority {
                return lhsPriority < rhsPriority
            }
            return lhs.offset < rhs.offset
        }
        .map(\.element)
}

private protocol MatchKindOrdered {
    var matchKind: ClassificationRuleMatchKind { get }
}

private extension MatchKindOrdered {
    var matchPriority: Int {
        switch matchKind {
        case .exactNormalizedMerchant:
            0
        case .prefixNormalizedMerchant:
            1
        case .contains:
            2
        }
    }
}

private extension ClassificationRule {
    func matches(_ candidate: NormalizedImportCandidate) -> Bool {
        LearnedRuleMatcher.matches(
            merchantPattern: merchantPattern,
            matchKind: matchKind,
            normalizedMerchantName: candidate.normalizedMerchantName
        )
    }
}

private extension CuratedReviewPrefill {
    func matches(_ candidate: NormalizedImportCandidate) -> Bool {
        LearnedRuleMatcher.matches(
            merchantPattern: merchantPattern,
            matchKind: matchKind,
            normalizedMerchantName: candidate.normalizedMerchantName
        )
    }
}

private extension ClassificationHeuristic {
    func matches(_ candidate: NormalizedImportCandidate) -> Bool {
        let pattern = merchantPattern.normalizedClassificationPattern
        return !pattern.isEmpty && candidate.normalizedMerchantName.contains(pattern)
    }
}

extension ClassificationRule: MatchKindOrdered {}
extension CuratedReviewPrefill: MatchKindOrdered {}

private extension String {
    var normalizedClassificationPattern: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    func matchesClassificationPattern(
        _ merchantPattern: String,
        matchKind: ClassificationRuleMatchKind
    ) -> Bool {
        let pattern = merchantPattern.normalizedClassificationPattern
        guard !pattern.isEmpty else {
            return false
        }

        switch matchKind {
        case .contains:
            return contains(pattern)
        case .exactNormalizedMerchant:
            return self == pattern
        case .prefixNormalizedMerchant:
            return self == pattern || hasPrefix(pattern + " ")
        }
    }

    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
