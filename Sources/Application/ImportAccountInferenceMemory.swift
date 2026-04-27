import Domain
import Foundation

public struct ImportAccountInferenceHistoricalEvidence: Equatable, Sendable {
    public var accountEvidenceByID: [UUID: ImportAccountInferenceAccountMemory]

    public init(accountEvidenceByID: [UUID: ImportAccountInferenceAccountMemory] = [:]) {
        self.accountEvidenceByID = accountEvidenceByID
    }

    public var historicalMatchCountsByAccountID: [UUID: Int] {
        accountEvidenceByID.reduce(into: [:]) { result, entry in
            let historicalMatchCount = entry.value.historicalMatchCount
            guard historicalMatchCount > 0 else {
                return
            }
            result[entry.key] = historicalMatchCount
        }
    }

    public static let empty = ImportAccountInferenceHistoricalEvidence()
}

public struct ImportAccountInferenceAccountMemory: Equatable, Sendable {
    public var positiveMatchCount: Int
    public var overrideCount: Int
    public var bootstrapMatchCount: Int

    public init(
        positiveMatchCount: Int = 0,
        overrideCount: Int = 0,
        bootstrapMatchCount: Int = 0
    ) {
        self.positiveMatchCount = positiveMatchCount
        self.overrideCount = overrideCount
        self.bootstrapMatchCount = bootstrapMatchCount
    }

    public var historicalMatchCount: Int {
        positiveMatchCount + bootstrapMatchCount
    }
}

public enum ImportAccountInferenceFeedbackOutcome: Equatable, Sendable {
    case acceptedSuggestion(selectedAccountID: UUID)
    case overrodeSuggestion(selectedAccountID: UUID, losingSuggestedAccountID: UUID)
    case manualAssignment(selectedAccountID: UUID)
}

public struct ImportAccountInferenceFeedbackMemory: Equatable, Sendable {
    public var stagedImportSessionID: Int64?
    public var query: ImportAccountInferenceEvidenceQuery
    public var outcome: ImportAccountInferenceFeedbackOutcome

    public init(
        stagedImportSessionID: Int64?,
        query: ImportAccountInferenceEvidenceQuery,
        outcome: ImportAccountInferenceFeedbackOutcome
    ) {
        self.stagedImportSessionID = stagedImportSessionID
        self.query = query
        self.outcome = outcome
    }
}
