import Domain
import Foundation
import Testing

@Test
func phaseOneInsightRankerUsesDeterministicTieBreakers() {
    let ranked = WorkspaceInsightRanker.rankPhase1([
        recurringCandidate(
            merchantName: "zeta care",
            suppressionKey: "recurring:zeta",
            score: 90,
            confidence: 0.9,
            primaryDate: projectionUTCDate(year: 2026, month: 4, day: 10),
            secondaryKey: "zeta care",
            tertiaryKey: "a"
        ),
        recurringCandidate(
            merchantName: "aardvark care",
            suppressionKey: "recurring:aardvark",
            score: 90,
            confidence: 0.9,
            primaryDate: projectionUTCDate(year: 2026, month: 4, day: 10),
            secondaryKey: "aardvark care",
            tertiaryKey: "a"
        ),
        recurringCandidate(
            merchantName: "camera club",
            suppressionKey: "recurring:camera:b",
            score: 90,
            confidence: 0.9,
            primaryDate: projectionUTCDate(year: 2026, month: 4, day: 11),
            secondaryKey: "camera club",
            tertiaryKey: "b"
        ),
        recurringCandidate(
            merchantName: "camera club",
            suppressionKey: "recurring:camera:a",
            score: 90,
            confidence: 0.9,
            primaryDate: projectionUTCDate(year: 2026, month: 4, day: 11),
            secondaryKey: "camera club",
            tertiaryKey: "a"
        ),
    ])

    #expect(ranked.map(\.suppressionKey) == [
        "recurring:camera:a",
        "recurring:camera:b",
        "recurring:aardvark",
        "recurring:zeta",
    ])
    #expect(ranked.map(\.rank) == [1, 2, 3, 4])
}

@Test
func phaseOneHomeProjectionCapsAtOneInsightPerFamily() {
    let ranked = WorkspaceInsightRanker.rankPhase1([
        recurringCandidate(
            merchantName: "netflix",
            suppressionKey: "recurring:netflix",
            score: 96,
            confidence: 0.95,
            primaryDate: projectionUTCDate(year: 2026, month: 4, day: 9),
            secondaryKey: "netflix",
            tertiaryKey: "a"
        ),
        recurringCandidate(
            merchantName: "spotify",
            suppressionKey: "recurring:spotify",
            score: 90,
            confidence: 0.92,
            primaryDate: projectionUTCDate(year: 2026, month: 4, day: 8),
            secondaryKey: "spotify",
            tertiaryKey: "a"
        ),
        spendDriverCandidate(
            title: "Dining",
            suppressionKey: "driver:dining",
            score: 94,
            delta: Decimal(180),
            primaryDate: projectionUTCDate(year: 2026, month: 4, day: 15),
            secondaryKey: "Dining",
            tertiaryKey: "a"
        ),
        spendDriverCandidate(
            title: "Travel",
            suppressionKey: "driver:travel",
            score: 89,
            delta: Decimal(140),
            primaryDate: projectionUTCDate(year: 2026, month: 4, day: 15),
            secondaryKey: "Travel",
            tertiaryKey: "a"
        ),
    ])

    let projected = WorkspaceInsightProjectionPolicy.projectHome(from: ranked)

    #expect(projected.map(\.family) == [.recurringCharge, .spendDriverChange])
    #expect(projected.map(\.suppressionKey) == [
        "recurring:netflix",
        "driver:dining",
    ])
}

@Test
func homeProjectionSuppressesDuplicateRootCauseAndStaysStableAcrossRuns() {
    let candidates = [
        recurringCandidate(
            merchantName: "netflix",
            suppressionKey: "recurring:netflix",
            score: 95,
            confidence: 0.94,
            primaryDate: projectionUTCDate(year: 2026, month: 4, day: 9),
            secondaryKey: "netflix",
            tertiaryKey: "a"
        ),
        recurringCandidate(
            merchantName: "netflix",
            suppressionKey: "recurring:netflix",
            score: 93,
            confidence: 0.91,
            primaryDate: projectionUTCDate(year: 2026, month: 4, day: 8),
            secondaryKey: "netflix",
            tertiaryKey: "b"
        ),
        spendDriverCandidate(
            title: "Dining",
            suppressionKey: "driver:dining",
            score: 92,
            delta: Decimal(160),
            primaryDate: projectionUTCDate(year: 2026, month: 4, day: 15),
            secondaryKey: "Dining",
            tertiaryKey: "a"
        ),
        spendDriverCandidate(
            title: "Groceries",
            suppressionKey: "driver:groceries",
            score: 88,
            delta: Decimal(120),
            primaryDate: projectionUTCDate(year: 2026, month: 4, day: 15),
            secondaryKey: "Groceries",
            tertiaryKey: "a"
        ),
    ]

    let firstRanked = WorkspaceInsightRanker.rankPhase1(candidates)
    let secondRanked = WorkspaceInsightRanker.rankPhase1(candidates)
    let caps = WorkspaceInsightProjectionCaps(homeMaxTotal: 3, homeMaxPerFamily: 2)
    let firstProjected = WorkspaceInsightProjectionPolicy.projectHome(from: firstRanked, caps: caps)
    let secondProjected = WorkspaceInsightProjectionPolicy.projectHome(from: secondRanked, caps: caps)

    #expect(firstRanked == secondRanked)
    #expect(firstProjected == secondProjected)
    #expect(firstProjected.map(\.suppressionKey) == [
        "recurring:netflix",
        "driver:dining",
        "driver:groceries",
    ])
}

private func recurringCandidate(
    merchantName: String,
    suppressionKey: String,
    score: Double,
    confidence: Double,
    primaryDate: Date,
    secondaryKey: String,
    tertiaryKey: String
) -> WorkspaceInsightCandidate {
    WorkspaceInsightCandidate(
        kind: .recurringCharge(
            RecurringChargeInsightDetail(
                accountID: projectionID("00000000-0000-0000-0000-000000000101"),
                normalizedMerchantName: merchantName,
                cadence: .monthly,
                observationCount: 3,
                amountRange: RecurringChargeAmountRange(minimum: Decimal(12.99), maximum: Decimal(12.99)),
                supportingTransactionIDs: [
                    projectionID("00000000-0000-0000-0000-000000000201"),
                    projectionID("00000000-0000-0000-0000-000000000202"),
                    projectionID("00000000-0000-0000-0000-000000000203"),
                ],
                firstObservedDate: projectionUTCDate(year: 2026, month: 2, day: 9),
                lastObservedDate: primaryDate,
                nextExpectedDateWindow: nil
            )
        ),
        confidence: confidence,
        score: score,
        suppressionKey: suppressionKey,
        evidence: InsightEvidence(
            metricBasis: .includedVisibleExpenses,
            resolvedInterval: DateInterval(
                start: projectionUTCDate(year: 2026, month: 2, day: 1),
                end: projectionUTCDate(year: 2026, month: 4, day: 30)
            ),
            scope: .merchant(merchantName),
            reconciliationRule: .recurringObservationSet,
            destination: InsightEvidenceDestination(scope: .merchant(merchantName), direction: .expense)
        ),
        tieBreaker: WorkspaceInsightTieBreaker(
            primaryDate: primaryDate,
            secondaryKey: secondaryKey,
            tertiaryKey: tertiaryKey
        )
    )
}

private func spendDriverCandidate(
    title: String,
    suppressionKey: String,
    score: Double,
    delta: Decimal,
    primaryDate: Date,
    secondaryKey: String,
    tertiaryKey: String
) -> WorkspaceInsightCandidate {
    let categoryID = projectionID("00000000-0000-0000-0000-000000000301")
    return WorkspaceInsightCandidate(
        kind: .spendDriverChange(
            SpendDriverChangeInsightDetail(
                title: title,
                scope: .category(categoryID),
                currentSpend: delta,
                comparisonSpend: .zero,
                delta: delta
            )
        ),
        confidence: 1,
        score: score,
        suppressionKey: suppressionKey,
        evidence: InsightEvidence(
            metricBasis: .includedVisibleExpenses,
            resolvedInterval: DateInterval(
                start: projectionUTCDate(year: 2026, month: 4, day: 1),
                end: projectionUTCDate(year: 2026, month: 4, day: 30)
            ),
            scope: .category(categoryID),
            reconciliationRule: .exactTransactionSum,
            destination: InsightEvidenceDestination(scope: .category(categoryID), direction: .expense)
        ),
        tieBreaker: WorkspaceInsightTieBreaker(
            primaryDate: primaryDate,
            secondaryKey: secondaryKey,
            tertiaryKey: tertiaryKey
        )
    )
}

private func projectionUTCDate(year: Int, month: Int, day: Int) -> Date {
    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = day
    components.calendar = projectionUTCCalendar
    return components.date!
}

private let projectionUTCCalendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
    return calendar
}()

private func projectionID(_ value: String) -> UUID {
    UUID(uuidString: value)!
}
