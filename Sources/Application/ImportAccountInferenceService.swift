import Domain
import Foundation

public struct ImportAccountInferenceService: Sendable {
    private let autoSelectScoreThreshold = 3
    private let autoSelectMarginThreshold = 2
    private let suggestionMarginThreshold = 1

    public init() {}

    public func inferAccount(for request: ImportAccountInferenceRequest) -> ImportAccountInferenceResult {
        let fingerprint = makeFingerprint(for: request)
        let accounts = request.importEligibleAccounts

        if let onlyAccount = accounts.onlyElement {
            let candidate = AccountInferenceCandidate(
                account: onlyAccount,
                score: 0,
                evidence: [.singleAvailableAccount],
                explanation: AccountInferenceEvidence.singleAvailableAccount.summary
            )
            return ImportAccountInferenceResult(
                disposition: .autoSelected,
                selectedAccountID: onlyAccount.id,
                fingerprint: fingerprint,
                candidates: [candidate],
                feedbackContext: nil
            )
        }

        let candidates = accounts.map { account in
            makeCandidate(
                for: account,
                fingerprint: fingerprint,
                historicalMatchCount: request.historicalMatchCountsByAccountID[account.id] ?? 0
            )
        }
        .sorted(by: candidateSort)

        let disposition = resolveDisposition(for: candidates)
        let selectedAccountID = selectedAccountID(for: disposition, candidates: candidates)

        return ImportAccountInferenceResult(
            disposition: disposition,
            selectedAccountID: selectedAccountID,
            fingerprint: fingerprint,
            candidates: candidates,
            feedbackContext: ImportAccountInferenceFeedbackContext(
                fingerprint: fingerprint,
                candidateAccountIDs: candidates.map(\.account.id),
                selectedAccountID: selectedAccountID,
                disposition: disposition
            )
        )
    }

    private func makeFingerprint(for request: ImportAccountInferenceRequest) -> ImportFingerprint {
        let normalizedFilename = normalize(request.originalFilename)
        return ImportFingerprint(
            originalFilename: request.originalFilename,
            normalizedFilename: normalizedFilename,
            filenameTokens: tokenize(normalizedFilename),
            normalizedHeaderNames: request.parsedArtifact.rowShapeSummary.normalizedHeaderNames,
            nonBlankColumnIndexesByRow: request.parsedArtifact.rowShapeSummary.nonBlankColumnIndexesByRow,
            profile: request.parsedArtifact.profile
        )
    }

    private func makeCandidate(
        for account: Account,
        fingerprint: ImportFingerprint,
        historicalMatchCount: Int
    ) -> AccountInferenceCandidate {
        var evidence: [AccountInferenceEvidence] = []
        var matchedTokens = Set<String>()

        let filenameTokenSet = Set(fingerprint.filenameTokens)
        let nameTokens = account.normalizedInferenceNameTokens
        let institutionTokens = account.normalizedInferenceInstitutionTokens
        let strongNameTokens = nameTokens.filter { !genericFilenameTokens.contains($0) }

        for token in strongNameTokens
        where filenameTokenSet.contains(token) && matchedTokens.insert(token).inserted {
            evidence.append(.filenameToken(token))
        }

        if evidence.isEmpty {
            for token in nameTokens
            where filenameTokenSet.contains(token) && matchedTokens.insert(token).inserted {
                evidence.append(.filenameToken(token))
            }
        }

        for token in institutionTokens
        where filenameTokenSet.contains(token) && matchedTokens.insert(token).inserted {
            evidence.append(.institutionToken(token))
        }

        if historicalMatchCount > 0 {
            evidence.append(.historicalMatch(count: historicalMatchCount))
        }

        return AccountInferenceCandidate(
            account: account,
            score: evidence.reduce(0) { partialResult, evidence in
                partialResult + score(for: evidence)
            },
            evidence: evidence,
            explanation: evidence.map(\.summary).joined(separator: "; ")
        )
    }

    private func resolveDisposition(for candidates: [AccountInferenceCandidate]) -> ImportAccountInferenceDisposition {
        guard let winner = candidates.first, winner.score > 0 else {
            return .unassigned
        }

        let runnerUpScore = candidates.dropFirst().first?.score ?? 0
        let margin = winner.score - runnerUpScore

        if winner.score >= autoSelectScoreThreshold && margin >= autoSelectMarginThreshold {
            return .autoSelected
        }

        if margin >= suggestionMarginThreshold {
            return .suggested
        }

        return .unassigned
    }

    private func selectedAccountID(
        for disposition: ImportAccountInferenceDisposition,
        candidates: [AccountInferenceCandidate]
    ) -> UUID? {
        switch disposition {
        case .autoSelected, .suggested:
            candidates.first?.account.id
        case .unassigned:
            nil
        }
    }

    private func score(for evidence: AccountInferenceEvidence) -> Int {
        switch evidence {
        case .singleAvailableAccount:
            0
        case .filenameToken, .institutionToken:
            1
        case .historicalMatch(let count):
            min(count, 1)
        }
    }

    private func candidateSort(lhs: AccountInferenceCandidate, rhs: AccountInferenceCandidate) -> Bool {
        if lhs.score != rhs.score {
            return lhs.score > rhs.score
        }
        if lhs.account.normalizedInferenceNameTokens != rhs.account.normalizedInferenceNameTokens {
            return lhs.account.normalizedInferenceNameTokens.lexicographicallyPrecedes(rhs.account.normalizedInferenceNameTokens)
        }
        return lhs.account.id.uuidString < rhs.account.id.uuidString
    }

    private func normalize(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: #"\.[a-z0-9]+$"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"[^a-z0-9]+"#, with: " ", options: .regularExpression)
            .split(separator: " ")
            .joined(separator: " ")
    }

    private func tokenize(_ normalizedValue: String) -> [String] {
        normalizedValue
            .split(separator: " ")
            .map(String.init)
            .filter { token in
                token.count > 1 && Int(token) == nil
            }
    }

    private var genericFilenameTokens: Set<String> {
        [
            "account",
            "apr",
            "april",
            "aug",
            "august",
            "checking",
            "csv",
            "dec",
            "december",
            "feb",
            "february",
            "jan",
            "january",
            "jul",
            "july",
            "jun",
            "june",
            "mar",
            "march",
            "may",
            "nov",
            "november",
            "oct",
            "october",
            "pdf",
            "qfx",
            "statement",
            "transactions",
        ]
    }
}

private extension Array {
    var onlyElement: Element? {
        count == 1 ? first : nil
    }
}
