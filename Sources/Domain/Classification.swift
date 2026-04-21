import Foundation

public enum ClassificationDecisionSource: String, Codable, Equatable, Sendable {
    case rule
    case heuristic
    case suggestion
    case user
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

    public init(id: UUID = UUID(), merchantPattern: String, categoryID: UUID, merchantName: String?) {
        self.id = id
        self.merchantPattern = merchantPattern
        self.categoryID = categoryID
        self.merchantName = merchantName
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
    private let heuristics: [ClassificationHeuristic]
    private let suggestionProvider: any SuggestionProvider
    private let suggestionsEnabled: Bool
    private let priorAcceptedMerchantNames: Set<String>
    private let suggestionAutoAcceptThreshold: Double

    public init(
        explicitRules: [ClassificationRule] = [],
        heuristics: [ClassificationHeuristic] = [],
        suggestionProvider: any SuggestionProvider = NoOpSuggestionProvider(),
        suggestionsEnabled: Bool = true,
        priorAcceptedMerchantNames: Set<String> = [],
        suggestionAutoAcceptThreshold: Double = 0.92
    ) {
        self.explicitRules = explicitRules
        self.heuristics = heuristics
        self.suggestionProvider = suggestionProvider
        self.suggestionsEnabled = suggestionsEnabled
        self.priorAcceptedMerchantNames = Set(priorAcceptedMerchantNames.map(\.normalizedClassificationPattern))
        self.suggestionAutoAcceptThreshold = suggestionAutoAcceptThreshold
    }

    public func appendingExplicitRules(_ rules: [ClassificationRule]) -> ClassificationEngine {
        ClassificationEngine(
            explicitRules: explicitRules + rules,
            heuristics: heuristics,
            suggestionProvider: suggestionProvider,
            suggestionsEnabled: suggestionsEnabled,
            priorAcceptedMerchantNames: priorAcceptedMerchantNames,
            suggestionAutoAcceptThreshold: suggestionAutoAcceptThreshold
        )
    }

    public func settingSuggestionsEnabled(_ enabled: Bool) -> ClassificationEngine {
        ClassificationEngine(
            explicitRules: explicitRules,
            heuristics: heuristics,
            suggestionProvider: suggestionProvider,
            suggestionsEnabled: enabled,
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

        if let heuristic = heuristics.first(where: { $0.matches(candidate) }) {
            return .reviewRequired(
                prefill: ClassificationAssignment(categoryID: heuristic.categoryID, merchantName: heuristic.merchantName),
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

private extension ClassificationRule {
    func matches(_ candidate: NormalizedImportCandidate) -> Bool {
        let pattern = merchantPattern.normalizedClassificationPattern
        return !pattern.isEmpty && candidate.normalizedMerchantName.contains(pattern)
    }
}

private extension ClassificationHeuristic {
    func matches(_ candidate: NormalizedImportCandidate) -> Bool {
        let pattern = merchantPattern.normalizedClassificationPattern
        return !pattern.isEmpty && candidate.normalizedMerchantName.contains(pattern)
    }
}

private extension String {
    var normalizedClassificationPattern: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}
