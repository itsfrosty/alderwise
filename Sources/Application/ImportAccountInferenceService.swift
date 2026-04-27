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
                historicalEvidence: request.historicalEvidenceByAccountID[account.id]
                    ?? ImportAccountInferenceAccountMemory(
                        positiveMatchCount: request.historicalMatchCountsByAccountID[account.id] ?? 0
                    )
            )
        }
        .sorted(by: candidateSort)

        let disposition = resolveDisposition(for: candidates)
        let selectedAccountID = selectedAccountID(for: disposition, candidates: candidates)

        return ImportAccountInferenceResult(
            disposition: disposition,
            selectedAccountID: selectedAccountID,
            fingerprint: fingerprint,
            candidates: candidates.map(\.candidate),
            feedbackContext: ImportAccountInferenceFeedbackContext(
                fingerprint: fingerprint,
                candidateAccountIDs: candidates.map(\.candidate.account.id),
                selectedAccountID: selectedAccountID,
                disposition: disposition
            )
        )
    }

    private func makeFingerprint(for request: ImportAccountInferenceRequest) -> ImportFingerprint {
        let normalizedFilename = normalizedFilenameIdentity(request.originalFilename)
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
        historicalEvidence: ImportAccountInferenceAccountMemory
    ) -> ScoredCandidate {
        var evidence: [AccountInferenceEvidence] = []
        var matchedTokens = Set<String>()

        let filenameTokenSet = Set(fingerprint.filenameTokens)
        let nameTokens = account.normalizedInferenceNameTokens
        let institutionTokens = account.normalizedInferenceInstitutionTokens
        let strongNameTokens = nameTokens.filter { !genericFilenameTokens.contains($0) }
        let historicalMatchCount = max(
            historicalEvidence.historicalMatchCount - historicalEvidence.overrideCount,
            0
        )

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
        if historicalEvidence.overrideCount >= historicalEvidence.historicalMatchCount &&
            historicalEvidence.overrideCount > 0 {
            evidence.append(.historicalOverride(count: historicalEvidence.overrideCount))
        }

        let totalScore = max(
            evidence.reduce(0) { partialResult, evidence in
                partialResult + score(for: evidence)
            },
            0
        )

        return ScoredCandidate(
            candidate: AccountInferenceCandidate(
                account: account,
                score: totalScore,
                evidence: evidence,
                explanation: evidence.map(\.summary).joined(separator: "; ")
            )
        )
    }

    private func resolveDisposition(for candidates: [ScoredCandidate]) -> ImportAccountInferenceDisposition {
        guard let winner = candidates.first, winner.candidate.score > 0 else {
            return .unassigned
        }

        let runnerUpScore = candidates.dropFirst().first?.candidate.score ?? 0
        let margin = winner.candidate.score - runnerUpScore

        if winner.candidate.score >= autoSelectScoreThreshold &&
            margin >= autoSelectMarginThreshold {
            return .autoSelected
        }

        if margin >= suggestionMarginThreshold {
            return .suggested
        }

        return .unassigned
    }

    private func selectedAccountID(
        for disposition: ImportAccountInferenceDisposition,
        candidates: [ScoredCandidate]
    ) -> UUID? {
        switch disposition {
        case .autoSelected, .suggested:
            candidates.first?.candidate.account.id
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
        case .historicalOverride(let count):
            -min(count, 1)
        }
    }

    private func candidateSort(lhs: ScoredCandidate, rhs: ScoredCandidate) -> Bool {
        if lhs.candidate.score != rhs.candidate.score {
            return lhs.candidate.score > rhs.candidate.score
        }
        if lhs.candidate.account.normalizedInferenceNameTokens != rhs.candidate.account.normalizedInferenceNameTokens {
            return lhs.candidate.account.normalizedInferenceNameTokens
                .lexicographicallyPrecedes(rhs.candidate.account.normalizedInferenceNameTokens)
        }
        return lhs.candidate.account.id.uuidString < rhs.candidate.account.id.uuidString
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

    private func normalizedFilenameIdentity(_ value: String) -> String {
        inferenceFilenameIdentityTokens(fromNormalizedValue: normalize(value)).joined(separator: " ")
    }

    private func tokenize(_ normalizedValue: String) -> [String] {
        inferenceFilenameIdentityTokens(fromNormalizedValue: normalizedValue)
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

    private var monthFilenameTokens: Set<String> {
        [
            "apr",
            "april",
            "aug",
            "august",
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
            "sep",
            "sept",
            "september",
        ]
    }

    private func inferenceFilenameIdentityTokens(fromNormalizedValue normalizedValue: String) -> [String] {
        let tokens = normalizedValue.split(separator: " ").map(String.init)

        return tokens.enumerated().compactMap { index, token in
            guard token.count > 1 else {
                return nil
            }
            if Int(token) != nil, shouldDropNumericFilenameToken(tokens, index: index) {
                return nil
            }
            return token
        }
    }

    private func shouldDropNumericFilenameToken(_ tokens: [String], index: Int) -> Bool {
        let token = tokens[index]
        guard let value = Int(token) else {
            return false
        }
        if (1900...2100).contains(value) {
            return true
        }
        guard token.count <= 2 else {
            return false
        }

        let neighbors = [index - 1, index + 1]
            .filter { tokens.indices.contains($0) }
            .map { tokens[$0] }

        return neighbors.contains(where: monthFilenameTokens.contains) ||
            neighbors.contains(where: isYearFilenameToken)
    }

    private func isYearFilenameToken(_ token: String) -> Bool {
        guard let value = Int(token) else {
            return false
        }
        return (1900...2100).contains(value)
    }
}

private struct ScoredCandidate: Sendable {
    let candidate: AccountInferenceCandidate
}

private extension Array {
    var onlyElement: Element? {
        count == 1 ? first : nil
    }
}
