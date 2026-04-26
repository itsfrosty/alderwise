import Application
import Domain
import SwiftUI
import Testing

@testable import AlderwiseApp

@Test
@MainActor
func analysisOverviewLayoutShowsTheHeroAndRequiredPrimarySectionsWhenDataExists() throws {
    let snapshot = analysisOverviewTestSnapshot(
        comparisonSpend: Decimal(310),
        drivers: [
            analysisOverviewDriverRow(
                title: "Dining",
                scope: .category(analysisOverviewTestID("00000000-0000-0000-0000-000000000101")),
                currentSpend: Decimal(180),
                comparisonSpend: Decimal(110)
            )
        ],
        projectedInsights: [
            analysisOverviewSpendDriverInsight(
                title: "Dining",
                scope: .category(analysisOverviewTestID("00000000-0000-0000-0000-000000000101")),
                currentSpend: Decimal(180),
                comparisonSpend: Decimal(110)
            )
        ],
        paceSeries: [
            MonthlySpendPoint(day: 1, actualSpend: Decimal(25), expectedSpend: Decimal(20)),
            MonthlySpendPoint(day: 10, actualSpend: Decimal(180), expectedSpend: Decimal(160)),
        ]
    )

    let layout = AnalysisOverviewView.layout(for: snapshot)

    #expect(layout.hero.kicker == "Analysis / Overview")
    #expect(layout.hero.title == "Spend, pace, and the changes shaping this window")
    #expect(layout.hero.comparison != .none)
    #expect(layout.cards.map(\.kind) == [
        .spendOverTime,
        .currentMonthPace,
        .whatChanged,
        .commitmentsNeedingAttention,
        .dataTrust,
        .targetPressure,
    ])
    let spendCard = try #require(layout.card(kind: .spendOverTime))
    #expect(spendCard.visibility == .shownActionable)
    #expect(spendCard.entries.allSatisfy { $0.selection == nil })
    #expect(try #require(spendCard.spendChart).currentSpend == Decimal(420))
    #expect(try #require(spendCard.spendChart).comparisonSpend == Decimal(310))
    #expect(try #require(layout.card(kind: .currentMonthPace)).visibility == .shownActionable)
    #expect(try #require(layout.card(kind: .whatChanged)).visibility == .shownActionable)
    #expect(try #require(layout.card(kind: .commitmentsNeedingAttention)).visibility == .hidden)
    #expect(try #require(layout.card(kind: .dataTrust)).visibility == .hidden)
    #expect(try #require(layout.card(kind: .targetPressure)).visibility == .hidden)
}

@Test
@MainActor
func analysisOverviewLayoutDegradesCleanlyForNoComparisonAndLowDataStates() throws {
    let snapshot = analysisOverviewTestSnapshot(
        comparisonSpend: nil,
        drivers: [],
        projectedInsights: [],
        paceSeries: []
    )

    let layout = AnalysisOverviewView.layout(for: snapshot)

    #expect(layout.hero.kicker == "Analysis / Overview")
    #expect(layout.cards.map(\.kind) == [
        .spendOverTime,
        .currentMonthPace,
        .whatChanged,
        .commitmentsNeedingAttention,
        .dataTrust,
        .targetPressure,
    ])
    #expect(layout.hero.comparison == .none)
    let spendCard = try #require(layout.card(kind: .spendOverTime))
    #expect(spendCard.visibility == .shownEmpty)
    #expect(spendCard.emptyStateReason == .missingComparisonBaseline)
    #expect(spendCard.spendChart == nil)
    #expect(try #require(layout.card(kind: .currentMonthPace)).visibility == .shownEmpty)
    #expect(try #require(layout.card(kind: .currentMonthPace)).emptyStateReason == .insufficientPaceData)
    #expect(try #require(layout.card(kind: .whatChanged)).visibility == .shownEmpty)
    #expect(try #require(layout.card(kind: .whatChanged)).emptyStateReason == .noMaterialChanges)
}

@Test
@MainActor
func analysisOverviewLayoutTreatsRecurringOnlyProjectedInsightsAsAWhatChangedEmptyState() throws {
    let snapshot = analysisOverviewTestSnapshot(
        drivers: [],
        projectedInsights: [analysisOverviewRecurringInsight(name: "netflix", amount: Decimal(15.49))]
    )

    let card = try #require(AnalysisOverviewView.layout(for: snapshot).card(kind: .whatChanged))

    #expect(card.entries.isEmpty)
    #expect(card.visibility == .shownEmpty)
    #expect(card.emptyStateReason == .noMaterialChanges)
}

@Test
func spendOverTimeComparisonChartDoesNotRenderAPhantomBarForZeroValues() {
    #expect(
        AnalysisOverviewView.comparisonChartFillWidth(
            containerWidth: 200,
            ratio: 0
        ) == 0
    )
    #expect(
        AnalysisOverviewView.comparisonChartFillWidth(
            containerWidth: 200,
            ratio: 0.02
        ) == 24
    )
}

@Test
@MainActor
func analysisOverviewLayoutShowsOptionalSupportSectionsOnlyWhenBackedBySnapshotData() throws {
    let recurringLayout = AnalysisOverviewView.layout(for: analysisOverviewTestSnapshot(
        recurring: [analysisOverviewRecurringRow(name: "netflix", amount: Decimal(15.49))]
    ))
    let planningPressureLayout = AnalysisOverviewView.layout(for: analysisOverviewTestSnapshot(
        monthlyTargets: [
            TargetProgress(
                id: analysisOverviewTestID("00000000-0000-0000-0000-000000000301"),
                name: "Dining",
                scope: .category(analysisOverviewTestID("00000000-0000-0000-0000-000000000302")),
                monthlyLimit: Decimal(250),
                spent: Decimal(320),
                remaining: Decimal(-70),
                paceDelta: Decimal(45)
            )
        ],
        hasActiveTargets: true
    ))
    let dataTrustLayout = AnalysisOverviewView.layout(for: analysisOverviewTestSnapshot(
        pendingReviewCount: 4
    ))
    let emptySupportLayout = AnalysisOverviewView.layout(for: analysisOverviewTestSnapshot())
    let targetClearLayout = AnalysisOverviewView.layout(for: analysisOverviewTestSnapshot(
        monthlyTargets: [
            TargetProgress(
                id: analysisOverviewTestID("00000000-0000-0000-0000-000000000351"),
                name: "Dining",
                scope: .category(analysisOverviewTestID("00000000-0000-0000-0000-000000000352")),
                monthlyLimit: Decimal(500),
                spent: Decimal(280),
                remaining: Decimal(220),
                paceDelta: Decimal(-15)
            )
        ],
        hasActiveTargets: true
    ))

    #expect(try #require(recurringLayout.card(kind: .commitmentsNeedingAttention)).visibility == .shownActionable)
    #expect(try #require(planningPressureLayout.card(kind: .targetPressure)).visibility == .shownActionable)
    #expect(try #require(dataTrustLayout.card(kind: .dataTrust)).visibility == .shownActionable)
    #expect(try #require(targetClearLayout.card(kind: .targetPressure)).visibility == .shownEmpty)
    #expect(try #require(emptySupportLayout.card(kind: .commitmentsNeedingAttention)).visibility == .hidden)
    #expect(try #require(emptySupportLayout.card(kind: .dataTrust)).visibility == .hidden)
}

@Test
@MainActor
func analysisOverviewCommittedSelectionStillDrivesInspectorAndDrilldown() throws {
    let driver = analysisOverviewDriverRow(
        title: "Dining",
        scope: .category(analysisOverviewTestID("00000000-0000-0000-0000-000000000401")),
        currentSpend: Decimal(180),
        comparisonSpend: Decimal(110)
    )
    let snapshot = analysisOverviewTestSnapshot(drivers: [driver])
    let layout = AnalysisOverviewView.layout(for: snapshot)
    let card = try #require(layout.card(kind: .whatChanged))
    let entry = try #require(card.entries.first)
    var committedSelection: AnalysisOverviewSelection?

    entry.commitSelection(
        into: Binding(
            get: { committedSelection },
            set: { committedSelection = $0 }
        )
    )

    let selection = try #require(committedSelection)

    #expect(AnalysisInspectorView<AnalysisOverviewSelection, EmptyView>.showsPlaceholder(for: selection) == false)
    #expect(snapshot.transactionFilter(for: selection) == TransactionLedgerFilter(
        startDate: analysisOverviewTestUTCDate(year: 2026, month: 4, day: 1),
        endDate: analysisOverviewTestUTCDate(year: 2026, month: 4, day: 15).addingTimeInterval(86_399),
        categoryID: analysisOverviewTestID("00000000-0000-0000-0000-000000000401"),
        direction: .expense,
        reviewStatuses: Set([.accepted, .pending]),
        visibility: .active
    ))
}

private func analysisOverviewTestSnapshot(
    comparisonSpend: Decimal? = Decimal(310),
    drivers: [AnalysisSpendRow] = [
        analysisOverviewDriverRow(
            title: "Dining",
            scope: .category(analysisOverviewTestID("00000000-0000-0000-0000-000000000111")),
            currentSpend: Decimal(180),
            comparisonSpend: Decimal(110)
        )
    ],
    recurring: [MerchantRecurringReportRow] = [],
    projectedInsights: [WorkspaceInsight] = [],
    paceSeries: [MonthlySpendPoint] = [
        MonthlySpendPoint(day: 1, actualSpend: Decimal(25), expectedSpend: Decimal(20)),
        MonthlySpendPoint(day: 10, actualSpend: Decimal(180), expectedSpend: Decimal(160)),
    ],
    pendingReviewCount: Int = 0,
    monthlyTargets: [TargetProgress] = [],
    hasActiveTargets: Bool = false
) -> AnalysisOverviewSnapshot {
    let context = AnalysisContext(
        range: .monthToDate,
        referenceDate: analysisOverviewTestUTCDate(year: 2026, month: 4, day: 15),
        scope: .workspace,
        comparison: comparisonSpend == nil ? .none : .previousPeriod,
        metricBasis: .includedVisibleExpenses
    )
    return AnalysisOverviewSnapshot(
        context: context,
        report: OverviewReport(
            context: context,
            currentSpend: Decimal(420),
            comparisonSpend: comparisonSpend,
            drivers: drivers,
            recurring: recurring
        ),
        monthlyReport: MonthlyReport(
            monthStart: analysisOverviewTestUTCDate(year: 2026, month: 4, day: 1),
            currentMonthAcceptedSpend: Decimal(420),
            lastMonthAcceptedSpend: Decimal(310),
            expenseBasis: .includedVisibleExpenses,
            pendingReviewCount: pendingReviewCount,
            targets: monthlyTargets,
            hasActiveTargets: hasActiveTargets,
            totalMonthlyTargetLimit: Decimal(700),
            expectedPaceSpend: Decimal(390),
            paceDelta: Decimal(30),
            paceSeries: paceSeries,
            drivers: [],
            biggestShift: nil
        ),
        projectedInsights: projectedInsights
    )
}

private func analysisOverviewDriverRow(
    title: String,
    scope: InsightEvidenceScope,
    currentSpend: Decimal,
    comparisonSpend: Decimal
) -> AnalysisSpendRow {
    AnalysisSpendRow(
        title: title,
        scope: scope,
        currentSpend: currentSpend,
        comparisonSpend: comparisonSpend,
        delta: currentSpend - comparisonSpend,
        evidence: analysisOverviewEvidence(scope: scope)
    )
}

private func analysisOverviewRecurringRow(
    name: String,
    amount: Decimal
) -> MerchantRecurringReportRow {
    MerchantRecurringReportRow(
        detail: RecurringChargeInsightDetail(
            accountID: analysisOverviewTestID("00000000-0000-0000-0000-000000000211"),
            normalizedMerchantName: name,
            cadence: .monthly,
            observationCount: 4,
            amountRange: RecurringChargeAmountRange(minimum: amount, maximum: amount),
            supportingTransactionIDs: [
                analysisOverviewTestID("00000000-0000-0000-0000-000000000212")
            ],
            firstObservedDate: analysisOverviewTestUTCDate(year: 2026, month: 1, day: 9),
            lastObservedDate: analysisOverviewTestUTCDate(year: 2026, month: 4, day: 9),
            nextExpectedDateWindow: nil
        ),
        evidence: analysisOverviewEvidence(scope: .merchant(name))
    )
}

private func analysisOverviewSpendDriverInsight(
    title: String,
    scope: InsightEvidenceScope,
    currentSpend: Decimal,
    comparisonSpend: Decimal
) -> WorkspaceInsight {
    let detail = SpendDriverChangeInsightDetail(
        title: title,
        scope: analysisOverviewDriverScope(scope),
        currentSpend: currentSpend,
        comparisonSpend: comparisonSpend,
        delta: currentSpend - comparisonSpend
    )
    return WorkspaceInsight(
        kind: .spendDriverChange(detail),
        confidence: 0.93,
        rank: 1,
        score: 0.93,
        suppressionKey: "driver-\(title)",
        evidence: analysisOverviewEvidence(scope: scope),
        tieBreaker: WorkspaceInsightTieBreaker(
            primaryDate: analysisOverviewTestUTCDate(year: 2026, month: 4, day: 15),
            secondaryKey: title,
            tertiaryKey: title
        )
    )
}

private func analysisOverviewDriverScope(
    _ scope: InsightEvidenceScope
) -> SpendingDriverScope {
    switch scope {
    case .category(let id):
        .category(id)
    case .categoryGroup(let id):
        .categoryGroup(id)
    case .workspace, .uncategorized, .merchant, .account:
        .uncategorized
    }
}

private func analysisOverviewRecurringInsight(
    name: String,
    amount: Decimal
) -> WorkspaceInsight {
    let detail = RecurringChargeInsightDetail(
        accountID: analysisOverviewTestID("00000000-0000-0000-0000-000000000221"),
        normalizedMerchantName: name,
        cadence: .monthly,
        observationCount: 4,
        amountRange: RecurringChargeAmountRange(minimum: amount, maximum: amount),
        supportingTransactionIDs: [
            analysisOverviewTestID("00000000-0000-0000-0000-000000000222")
        ],
        firstObservedDate: analysisOverviewTestUTCDate(year: 2026, month: 1, day: 9),
        lastObservedDate: analysisOverviewTestUTCDate(year: 2026, month: 4, day: 9),
        nextExpectedDateWindow: nil
    )
    return WorkspaceInsight(
        kind: .recurringCharge(detail),
        confidence: 0.91,
        rank: 1,
        score: 0.91,
        suppressionKey: "recurring:\(name)",
        evidence: analysisOverviewEvidence(scope: .merchant(name)),
        tieBreaker: WorkspaceInsightTieBreaker(
            primaryDate: analysisOverviewTestUTCDate(year: 2026, month: 4, day: 15),
            secondaryKey: name,
            tertiaryKey: name
        )
    )
}

private func analysisOverviewEvidence(scope: InsightEvidenceScope) -> InsightEvidence {
    InsightEvidence(
        metricBasis: .includedVisibleExpenses,
        resolvedInterval: DateInterval(
            start: analysisOverviewTestUTCDate(year: 2026, month: 4, day: 1),
            end: analysisOverviewTestUTCDate(year: 2026, month: 4, day: 16)
        ),
        scope: scope,
        reconciliationRule: .exactTransactionSum,
        destination: InsightEvidenceDestination(
            scope: scope,
            direction: .expense
        )
    )
}

private func analysisOverviewTestUTCDate(year: Int, month: Int, day: Int) -> Date {
    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = day
    components.calendar = analysisOverviewTestUTCCalendar
    return components.date!
}

private let analysisOverviewTestUTCCalendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
    return calendar
}()

private func analysisOverviewTestID(_ value: String) -> UUID {
    UUID(uuidString: value)!
}
