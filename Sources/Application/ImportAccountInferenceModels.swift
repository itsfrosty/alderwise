import Domain
import Foundation

public struct ImportFingerprint: Equatable, Sendable {
    public let originalFilename: String
    public let normalizedFilename: String
    public let filenameTokens: [String]
    public let normalizedHeaderNames: [String]
    public let nonBlankColumnIndexesByRow: [[Int]]
    public let profile: CSVImportProfile

    public init(
        originalFilename: String,
        normalizedFilename: String,
        filenameTokens: [String],
        normalizedHeaderNames: [String],
        nonBlankColumnIndexesByRow: [[Int]],
        profile: CSVImportProfile
    ) {
        self.originalFilename = originalFilename
        self.normalizedFilename = normalizedFilename
        self.filenameTokens = filenameTokens
        self.normalizedHeaderNames = normalizedHeaderNames
        self.nonBlankColumnIndexesByRow = nonBlankColumnIndexesByRow
        self.profile = profile
    }
}

public struct ImportAccountInferenceRequest: Equatable, Sendable {
    public let originalFilename: String
    public let parsedArtifact: ImportParsedArtifact
    public let importEligibleAccounts: [Account]
    public let historicalMatchCountsByAccountID: [UUID: Int]
    public let historicalEvidenceByAccountID: [UUID: ImportAccountInferenceAccountMemory]

    public init(
        originalFilename: String,
        parsedArtifact: ImportParsedArtifact,
        importEligibleAccounts: [Account],
        historicalMatchCountsByAccountID: [UUID: Int],
        historicalEvidenceByAccountID: [UUID: ImportAccountInferenceAccountMemory] = [:]
    ) {
        self.originalFilename = originalFilename
        self.parsedArtifact = parsedArtifact
        self.importEligibleAccounts = importEligibleAccounts
        self.historicalMatchCountsByAccountID = historicalMatchCountsByAccountID
        self.historicalEvidenceByAccountID = historicalEvidenceByAccountID
    }
}

public enum ImportAccountInferenceDisposition: String, Equatable, Sendable {
    case autoSelected
    case suggested
    case unassigned
}

public struct ImportAccountInferenceResult: Equatable, Sendable {
    public let disposition: ImportAccountInferenceDisposition
    public let selectedAccountID: UUID?
    public let fingerprint: ImportFingerprint
    public let candidates: [AccountInferenceCandidate]
    public let feedbackContext: ImportAccountInferenceFeedbackContext?

    public init(
        disposition: ImportAccountInferenceDisposition,
        selectedAccountID: UUID?,
        fingerprint: ImportFingerprint,
        candidates: [AccountInferenceCandidate],
        feedbackContext: ImportAccountInferenceFeedbackContext?
    ) {
        self.disposition = disposition
        self.selectedAccountID = selectedAccountID
        self.fingerprint = fingerprint
        self.candidates = candidates
        self.feedbackContext = feedbackContext
    }
}

public enum AccountInferenceEvidence: Equatable, Sendable {
    case singleAvailableAccount
    case filenameToken(String)
    case institutionToken(String)
    case historicalMatch(count: Int)
    case historicalOverride(count: Int)

    public var summary: String {
        switch self {
        case .singleAvailableAccount:
            "single available account"
        case .filenameToken(let token):
            "filename token: \(token)"
        case .institutionToken(let token):
            "institution token: \(token)"
        case .historicalMatch(let count):
            "historical match count: \(count)"
        case .historicalOverride(let count):
            "historical override count: \(count)"
        }
    }
}

public struct AccountInferenceCandidate: Equatable, Sendable {
    public let account: Account
    public let score: Int
    public let evidence: [AccountInferenceEvidence]
    public let explanation: String

    public init(
        account: Account,
        score: Int,
        evidence: [AccountInferenceEvidence],
        explanation: String
    ) {
        self.account = account
        self.score = score
        self.evidence = evidence
        self.explanation = explanation
    }
}

public struct ImportAccountInferenceFeedbackContext: Equatable, Sendable {
    public let fingerprint: ImportFingerprint
    public let candidateAccountIDs: [UUID]
    public let selectedAccountID: UUID?
    public let disposition: ImportAccountInferenceDisposition

    public init(
        fingerprint: ImportFingerprint,
        candidateAccountIDs: [UUID],
        selectedAccountID: UUID?,
        disposition: ImportAccountInferenceDisposition
    ) {
        self.fingerprint = fingerprint
        self.candidateAccountIDs = candidateAccountIDs
        self.selectedAccountID = selectedAccountID
        self.disposition = disposition
    }
}
