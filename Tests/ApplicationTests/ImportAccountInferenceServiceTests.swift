import Application
import Domain
import Foundation
import Testing

@Test
func strongFilenamePlusInstitutionEvidenceYieldsAutoSelected() throws {
    let target = account(
        id: "00000000-0000-0000-0000-000000000101",
        name: "Sapphire Reserve",
        institutionName: "Chase"
    )
    let other = account(
        id: "00000000-0000-0000-0000-000000000102",
        name: "House Checking",
        institutionName: "Local Credit Union"
    )

    let result = try infer(
        filename: "2026-04_chase_sapphire_reserve_statement.csv",
        accounts: [other, target]
    )

    #expect(result.disposition == .autoSelected)
    #expect(result.selectedAccountID == target.id)
    #expect(result.candidates.map(\.account.id) == [target.id, other.id])
    #expect(result.candidates.first?.evidence.map(\.summary) == [
        "filename token: sapphire",
        "filename token: reserve",
        "institution token: chase",
    ])
    #expect(result.candidates.first?.explanation == "filename token: sapphire; filename token: reserve; institution token: chase")
    #expect(result.feedbackContext?.selectedAccountID == target.id)
}

@Test
func weakFilenameEvidenceYieldsSuggestedNotAutoSelected() throws {
    let target = account(
        id: "00000000-0000-0000-0000-000000000111",
        name: "Sapphire Reserve",
        institutionName: "Chase"
    )
    let other = account(
        id: "00000000-0000-0000-0000-000000000112",
        name: "Daily Checking",
        institutionName: "Local Credit Union"
    )

    let result = try infer(
        filename: "2026-04_chase_statement.csv",
        accounts: [target, other]
    )

    #expect(result.disposition == .suggested)
    #expect(result.selectedAccountID == target.id)
    #expect(result.candidates.first?.score == 1)
    #expect(result.candidates.first?.evidence.map(\.summary) == ["institution token: chase"])
}

@Test
func conflictingCandidatesRemainUnassigned() throws {
    let checking = account(
        id: "00000000-0000-0000-0000-000000000121",
        name: "Checking",
        institutionName: "Chase"
    )
    let sapphire = account(
        id: "00000000-0000-0000-0000-000000000122",
        name: "Sapphire Reserve",
        institutionName: "Chase"
    )

    let result = try infer(
        filename: "2026-04_chase_checking_sapphire.csv",
        accounts: [checking, sapphire]
    )

    #expect(result.disposition == .unassigned)
    #expect(result.selectedAccountID == nil)
    #expect(result.candidates.map(\.score) == [2, 2])
}

@Test
func sharedInstitutionAcrossTwoAccountsDoesNotAutoSelectOnInstitutionTokenAlone() throws {
    let checking = account(
        id: "00000000-0000-0000-0000-000000000131",
        name: "House Checking",
        institutionName: "Chase"
    )
    let travel = account(
        id: "00000000-0000-0000-0000-000000000132",
        name: "Travel Card",
        institutionName: "Chase"
    )

    let result = try infer(
        filename: "2026-04_chase_statement.csv",
        accounts: [travel, checking]
    )

    #expect(result.disposition == .unassigned)
    #expect(result.selectedAccountID == nil)
    #expect(result.candidates.map(\.score) == [1, 1])
}

@Test
func genericFilenameTokensDoNotForceHighConfidence() throws {
    let checking = account(
        id: "00000000-0000-0000-0000-000000000141",
        name: "Daily Checking",
        institutionName: "Neighborhood Bank"
    )
    let savings = account(
        id: "00000000-0000-0000-0000-000000000142",
        name: "House Savings",
        institutionName: "Neighborhood Bank"
    )

    let result = try infer(
        filename: "checking_statement_march_2026.csv",
        accounts: [checking, savings]
    )

    #expect(result.disposition == .suggested)
    #expect(result.selectedAccountID == checking.id)
    #expect(result.candidates.first?.score == 1)
    #expect(result.candidates.first?.evidence.map(\.summary) == ["filename token: checking"])
}

@Test
func aliasFreeCollisionsRemainSuggestedOrUnassigned() throws {
    let flex = account(
        id: "00000000-0000-0000-0000-000000000151",
        name: "Freedom Flex",
        institutionName: "Chase"
    )
    let unlimited = account(
        id: "00000000-0000-0000-0000-000000000152",
        name: "Freedom Unlimited",
        institutionName: "Chase"
    )

    let result = try infer(
        filename: "2026-04_chase_freedom_statement.csv",
        accounts: [unlimited, flex]
    )

    #expect(result.disposition == .unassigned)
    #expect(result.selectedAccountID == nil)
    #expect(result.candidates.map(\.score) == [2, 2])
}

@Test
func evidenceOrderingAndExplanationOutputAreDeterministic() throws {
    let target = account(
        id: "00000000-0000-0000-0000-000000000161",
        name: "Everyday Card",
        institutionName: "Acme Bank"
    )
    let other = account(
        id: "00000000-0000-0000-0000-000000000162",
        name: "Travel Card",
        institutionName: "Acme Bank"
    )
    let request = try makeRequest(
        filename: "2026_everyday_acme_everyday_card.csv",
        accounts: [other, target]
    )
    let service = ImportAccountInferenceService()

    let first = service.inferAccount(for: request)
    let second = service.inferAccount(for: request)

    #expect(first == second)
    #expect(first.candidates.first?.evidence.map(\.summary) == [
        "filename token: everyday",
        "filename token: card",
        "institution token: acme",
    ])
    #expect(first.candidates.first?.explanation == "filename token: everyday; filename token: card; institution token: acme")
}

@Test
func correlatedInstitutionAndNameTokenDoesNotDoubleCountTowardConfidence() throws {
    let target = account(
        id: "00000000-0000-0000-0000-000000000166",
        name: "Chase Checking",
        institutionName: "Chase"
    )
    let other = account(
        id: "00000000-0000-0000-0000-000000000167",
        name: "Travel Card",
        institutionName: "Chase"
    )

    let result = try infer(
        filename: "2026-04_chase_statement.csv",
        accounts: [target, other]
    )

    #expect(result.disposition == .unassigned)
    #expect(result.selectedAccountID == nil)
    #expect(result.candidates.map(\.score) == [1, 1])
}

@Test
func historicalEvidenceCanBreakTiesWithoutAutoSelecting() throws {
    let preferred = account(
        id: "00000000-0000-0000-0000-000000000168",
        name: "House Checking",
        institutionName: "Chase"
    )
    let other = account(
        id: "00000000-0000-0000-0000-000000000169",
        name: "Travel Card",
        institutionName: "Chase"
    )

    let result = ImportAccountInferenceService().inferAccount(
        for: try makeRequest(
            filename: "2026-04_chase_statement.csv",
            accounts: [preferred, other],
            historicalMatchCountsByAccountID: [preferred.id: 3]
        )
    )

    #expect(result.disposition == .suggested)
    #expect(result.selectedAccountID == preferred.id)
    #expect(result.candidates.first?.evidence.map(\.summary) == [
        "institution token: chase",
        "historical match count: 3",
    ])
}

@Test
func overrideHistoryReducesConfidenceWithoutChangingWinner() throws {
    let preferred = account(
        id: "00000000-0000-0000-0000-000000000172",
        name: "Sapphire Reserve",
        institutionName: "Chase"
    )
    let other = account(
        id: "00000000-0000-0000-0000-000000000173",
        name: "Daily Checking",
        institutionName: "Local Credit Union"
    )

    let result = ImportAccountInferenceService().inferAccount(
        for: try makeRequest(
            filename: "2026-04_chase_sapphire_reserve_statement.csv",
            accounts: [other, preferred],
            historicalEvidenceByAccountID: [
                preferred.id: ImportAccountInferenceAccountMemory(
                    positiveMatchCount: 1,
                    overrideCount: 1
                ),
            ]
        )
    )

    #expect(result.selectedAccountID == preferred.id)
    #expect(result.disposition == .suggested)
    #expect(result.candidates.first?.score == 2)
    #expect(result.candidates.first?.evidence.map(\.summary) == [
        "filename token: sapphire",
        "filename token: reserve",
        "institution token: chase",
        "historical override count: 1",
    ])
}

@Test
func overridePenaltyIsBoundedToSinglePoint() throws {
    let preferred = account(
        id: "00000000-0000-0000-0000-000000000174",
        name: "Sapphire Reserve",
        institutionName: "Chase"
    )
    let other = account(
        id: "00000000-0000-0000-0000-000000000175",
        name: "Daily Checking",
        institutionName: "Local Credit Union"
    )

    let oneOverride = ImportAccountInferenceService().inferAccount(
        for: try makeRequest(
            filename: "2026-04_chase_sapphire_reserve_statement.csv",
            accounts: [other, preferred],
            historicalEvidenceByAccountID: [
                preferred.id: ImportAccountInferenceAccountMemory(
                    positiveMatchCount: 1,
                    overrideCount: 1
                ),
            ]
        )
    )
    let manyOverrides = ImportAccountInferenceService().inferAccount(
        for: try makeRequest(
            filename: "2026-04_chase_sapphire_reserve_statement.csv",
            accounts: [other, preferred],
            historicalEvidenceByAccountID: [
                preferred.id: ImportAccountInferenceAccountMemory(
                    positiveMatchCount: 1,
                    overrideCount: 4
                ),
            ]
        )
    )

    #expect(oneOverride.selectedAccountID == preferred.id)
    #expect(manyOverrides.selectedAccountID == preferred.id)
    #expect(oneOverride.disposition == .suggested)
    #expect(manyOverrides.disposition == .suggested)
    #expect(oneOverride.candidates.first?.score == 2)
    #expect(manyOverrides.candidates.first?.score == 2)
}

@Test
func fingerprintNormalizedFilenameDropsRoutineNumericTokens() throws {
    let target = account(
        id: "00000000-0000-0000-0000-000000000170",
        name: "Checking",
        institutionName: "Chase"
    )

    let result = try infer(
        filename: "Checking-April-2026-04.csv",
        accounts: [target]
    )

    #expect(result.fingerprint.normalizedFilename == "checking april")
    #expect(result.fingerprint.filenameTokens == ["checking", "april"])
}

@Test
func fingerprintNormalizedFilenamePreservesNonDateNumericDisambiguators() throws {
    let target = account(
        id: "00000000-0000-0000-0000-000000000176",
        name: "Checking 1234",
        institutionName: "Chase"
    )

    let result = try infer(
        filename: "Checking-1234.csv",
        accounts: [target]
    )

    #expect(result.fingerprint.normalizedFilename == "checking 1234")
    #expect(result.fingerprint.filenameTokens == ["checking", "1234"])
}

@Test
func singleAccountConveniencePathDoesNotParticipateInInferenceFeedback() throws {
    let onlyAccount = account(
        id: "00000000-0000-0000-0000-000000000171",
        name: "Checking",
        institutionName: "Chase"
    )

    let result = try infer(
        filename: "generic_statement.csv",
        accounts: [onlyAccount]
    )

    #expect(result.disposition == .autoSelected)
    #expect(result.selectedAccountID == onlyAccount.id)
    #expect(result.feedbackContext == nil)
    #expect(result.candidates == [
        AccountInferenceCandidate(
            account: onlyAccount,
            score: 0,
            evidence: [.singleAvailableAccount],
            explanation: "single available account"
        ),
    ])
}

private func infer(filename: String, accounts: [Account]) throws -> ImportAccountInferenceResult {
    ImportAccountInferenceService().inferAccount(
        for: try makeRequest(filename: filename, accounts: accounts)
    )
}

private func makeRequest(
    filename: String,
    accounts: [Account],
    historicalMatchCountsByAccountID: [UUID: Int] = [:],
    historicalEvidenceByAccountID: [UUID: ImportAccountInferenceAccountMemory] = [:]
) throws -> ImportAccountInferenceRequest {
    let mergedHistoricalMatchCountsByAccountID = historicalEvidenceByAccountID.reduce(
        into: historicalMatchCountsByAccountID
    ) { partialResult, entry in
        partialResult[entry.key] = entry.value.historicalMatchCount
    }

    return ImportAccountInferenceRequest(
        originalFilename: filename,
        parsedArtifact: try CSVImportPreviewService().makeParsedArtifact(from: sampleCSV()),
        importEligibleAccounts: accounts,
        historicalMatchCountsByAccountID: mergedHistoricalMatchCountsByAccountID,
        historicalEvidenceByAccountID: historicalEvidenceByAccountID
    )
}

private func account(id: String, name: String, institutionName: String?) -> Account {
    Account(
        id: UUID(uuidString: id)!,
        name: name,
        kind: .checking,
        institutionName: institutionName,
        createdAt: Date(timeIntervalSince1970: 0)
    )
}

private func sampleCSV() -> String {
    """
    Date,Description,Amount
    2026-04-01,Sample transaction,-12.34
    """
}
