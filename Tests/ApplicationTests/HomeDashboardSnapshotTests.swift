import Application
import Domain
import Foundation
import Testing

@Test
func homeDashboardRanksReviewBeforeTargetsDriversAndSetup() {
    let foodGroupID = homeDashboardID("00000000-0000-0000-0000-000000000201")
    let report = homeDashboardReport(
        pendingReviewCount: 3,
        targets: [
            homeDashboardTarget(
                id: "00000000-0000-0000-0000-000000000401",
                name: "Food",
                scope: .categoryGroup(foodGroupID),
                monthlyLimit: 100,
                spent: 120,
                remaining: -20,
                paceDelta: 20
            ),
        ],
        currentMonthAcceptedSpend: 120,
        lastMonthAcceptedSpend: 80,
        hasActiveTargets: true,
        totalMonthlyTargetLimit: 100,
        expectedPaceSpend: 90,
        paceDelta: 30,
        drivers: [
            homeDashboardDriver(
                title: "Food",
                scope: .categoryGroup(foodGroupID),
                currentPeriodSpend: 120,
                comparisonPeriodSpend: 80,
                delta: 40
            ),
        ],
        biggestShift: homeDashboardDriver(
            title: "Food",
            scope: .categoryGroup(foodGroupID),
            currentPeriodSpend: 120,
            comparisonPeriodSpend: 80,
            delta: 40
        )
    )

    let dashboard = HomeDashboardSnapshot.make(
        summary: WorkspaceSummary(accountCount: 1, transactionCount: 10, reviewCount: 3, targetCount: 1),
        monthlyReport: report
    )

    #expect(dashboard.isEmptyWorkspace == false)
    #expect(dashboard.reviewQualifier != nil)
    #expect(dashboard.actions.map(\.kind) == [
        .reviewBacklog(count: 3),
        .pressuredTarget,
    ])
}

@Test
func homeDashboardSuppressesCreateTargetPromptWhileReviewIsPending() {
    let report = homeDashboardReport(
        pendingReviewCount: 1,
        targets: [],
        currentMonthAcceptedSpend: 40,
        lastMonthAcceptedSpend: 25,
        hasActiveTargets: false,
        totalMonthlyTargetLimit: 0,
        expectedPaceSpend: 0,
        paceDelta: 0,
        drivers: [],
        biggestShift: nil
    )

    let dashboard = HomeDashboardSnapshot.make(
        summary: WorkspaceSummary(accountCount: 1, transactionCount: 10, reviewCount: 1, targetCount: 0),
        monthlyReport: report
    )

    #expect(dashboard.actions.contains { $0.kind == .createFirstTarget } == false)
    #expect(dashboard.reviewQualifier != nil)
}

@Test
func homeDashboardShowsVisibleSpendReviewQualifierFromMonthlyReport() throws {
    let report = homeDashboardReport(
        pendingReviewCount: 7,
        targets: [],
        currentMonthAcceptedSpend: 40,
        lastMonthAcceptedSpend: 25,
        hasActiveTargets: false,
        totalMonthlyTargetLimit: 0,
        expectedPaceSpend: 0,
        paceDelta: 0,
        drivers: [],
        biggestShift: nil
    )

    let dashboard = HomeDashboardSnapshot.make(
        summary: WorkspaceSummary(accountCount: 1, transactionCount: 10, reviewCount: 0, targetCount: 0),
        monthlyReport: report
    )

    let qualifier = try #require(dashboard.reviewQualifier)

    #expect(qualifier.pendingReviewCount == 7)
    #expect(qualifier.message == "7 review item(s) can still recategorize some visible spend.")
    #expect(dashboard.actions.first?.kind == .reviewBacklog(count: 7))
    #expect(dashboard.actions.first?.destination == .review)
    #expect(dashboard.primaryAction?.title == "Finish 7 items in Review")
}

@Test
func homeDashboardOmitsRecurringSectionWhenNoQualifyingInsightExists() {
    let report = homeDashboardReport(
        pendingReviewCount: 0,
        targets: [],
        currentMonthAcceptedSpend: 40,
        lastMonthAcceptedSpend: 25,
        hasActiveTargets: false,
        totalMonthlyTargetLimit: 0,
        expectedPaceSpend: 0,
        paceDelta: 0,
        drivers: [],
        biggestShift: nil
    )

    let dashboard = HomeDashboardSnapshot.make(
        summary: WorkspaceSummary(accountCount: 1, transactionCount: 10, reviewCount: 0, targetCount: 0),
        monthlyReport: report,
        insights: .empty
    )

    #expect(dashboard.recurringSection == nil)
}

@Test
func homeDashboardProjectsTopRecurringInsightIntoDedicatedSection() throws {
    let report = homeDashboardReport(
        pendingReviewCount: 0,
        targets: [],
        currentMonthAcceptedSpend: 40,
        lastMonthAcceptedSpend: 25,
        hasActiveTargets: false,
        totalMonthlyTargetLimit: 0,
        expectedPaceSpend: 0,
        paceDelta: 0,
        drivers: [],
        biggestShift: nil
    )

    let dashboard = HomeDashboardSnapshot.make(
        summary: WorkspaceSummary(accountCount: 1, transactionCount: 10, reviewCount: 0, targetCount: 0),
        monthlyReport: report,
        insights: homeDashboardRecurringInsights(
            merchantName: "netflix",
            cadence: .monthly,
            observationCount: 3,
            minimumAmount: Decimal(15.49),
            maximumAmount: Decimal(15.49)
        )
    )

    let section = try #require(dashboard.recurringSection)

    #expect(section.merchantName == "netflix")
    #expect(section.title == "Netflix may be recurring")
    #expect(section.message.contains("Monthly"))
    #expect(section.message.contains("3 charges"))
    #expect(section.destination == HomeDashboardDestination.transactions(
        TransactionLedgerFilter(
            startDate: homeDashboardUTCDate(year: 2026, month: 2, day: 9),
            endDate: homeDashboardEndOfDay(year: 2026, month: 4, day: 9),
            normalizedMerchantName: "netflix",
            direction: .expense,
            reviewStatuses: Set([.accepted, .pending]),
            visibility: .active
        )
    ))
}

@Test
func homeDashboardBuildsCreateFirstTargetActionOnlyWhenIncludedExpenseHistoryExists() {
    let report = homeDashboardReport(
        pendingReviewCount: 0,
        targets: [],
        currentMonthAcceptedSpend: 40,
        lastMonthAcceptedSpend: 0,
        hasActiveTargets: false,
        totalMonthlyTargetLimit: 0,
        expectedPaceSpend: 0,
        paceDelta: 0,
        drivers: [],
        biggestShift: nil
    )

    let dashboard = HomeDashboardSnapshot.make(
        summary: WorkspaceSummary(accountCount: 1, transactionCount: 10, reviewCount: 0, targetCount: 0),
        monthlyReport: report
    )

    #expect(dashboard.actions.map(\.kind) == [.createFirstTarget])
    #expect(dashboard.actions.first?.destination == .targets(nil))
}

@Test
func homeDashboardKeepsExistingActionOrderWhenRecurringInsightExists() throws {
    let foodGroupID = homeDashboardID("00000000-0000-0000-0000-000000000206")
    let travelCategoryID = homeDashboardID("00000000-0000-0000-0000-000000000115")
    let report = homeDashboardReport(
        pendingReviewCount: 3,
        targets: [
            homeDashboardTarget(
                id: "00000000-0000-0000-0000-000000000404",
                name: "Food",
                scope: .categoryGroup(foodGroupID),
                monthlyLimit: 100,
                spent: 120,
                remaining: -20,
                paceDelta: 20
            ),
        ],
        currentMonthAcceptedSpend: 140,
        lastMonthAcceptedSpend: 95,
        hasActiveTargets: true,
        totalMonthlyTargetLimit: 100,
        expectedPaceSpend: 90,
        paceDelta: 50,
        drivers: [
            homeDashboardDriver(
                title: "Travel",
                scope: .category(travelCategoryID),
                currentPeriodSpend: 65,
                comparisonPeriodSpend: 20,
                delta: 45
            ),
        ],
        biggestShift: homeDashboardDriver(
            title: "Travel",
            scope: .category(travelCategoryID),
            currentPeriodSpend: 65,
            comparisonPeriodSpend: 20,
            delta: 45
        )
    )

    let dashboard = HomeDashboardSnapshot.make(
        summary: WorkspaceSummary(accountCount: 1, transactionCount: 10, reviewCount: 3, targetCount: 1),
        monthlyReport: report,
        insights: homeDashboardRecurringInsights(
            merchantName: "netflix",
            cadence: .monthly,
            observationCount: 3,
            minimumAmount: Decimal(15.49),
            maximumAmount: Decimal(15.49)
        )
    )

    #expect(dashboard.recurringSection != nil)
    #expect(
        dashboard.actions.map(\HomeDashboardAction.kind) == [
            HomeDashboardActionKind.reviewBacklog(count: 3),
            HomeDashboardActionKind.pressuredTarget,
            HomeDashboardActionKind.spendDriver,
        ]
    )
}

@Test
func homeDashboardSkipsCreateFirstTargetActionWithoutIncludedExpenseHistory() {
    let report = homeDashboardReport(
        pendingReviewCount: 0,
        targets: [],
        currentMonthAcceptedSpend: 0,
        lastMonthAcceptedSpend: 0,
        hasActiveTargets: false,
        totalMonthlyTargetLimit: 0,
        expectedPaceSpend: 0,
        paceDelta: 0,
        drivers: [],
        biggestShift: nil
    )

    let dashboard = HomeDashboardSnapshot.make(
        summary: WorkspaceSummary(accountCount: 1, transactionCount: 10, reviewCount: 0, targetCount: 0),
        monthlyReport: report
    )

    #expect(dashboard.actions.isEmpty)
}

@Test
func homeDashboardTreatsHiddenOnlyWorkspaceAsEmptyEvenIfReviewCountsRemain() {
    let report = homeDashboardReport(
        pendingReviewCount: 2,
        currentMonthAcceptedSpend: 40,
        lastMonthAcceptedSpend: 25
    )

    let dashboard = HomeDashboardSnapshot.make(
        summary: WorkspaceSummary(accountCount: 1, transactionCount: 0, reviewCount: 2, targetCount: 0),
        monthlyReport: report
    )

    #expect(dashboard.isEmptyWorkspace)
    #expect(dashboard.reviewQualifier == nil)
    #expect(dashboard.hero == nil)
    #expect(dashboard.actions.isEmpty)
    #expect(dashboard.summaryCards.isEmpty)
    #expect(dashboard.targetRows.isEmpty)
    #expect(dashboard.driverRows.isEmpty)
}

@Test
func homeDashboardDedupesDriverActionWhenTargetAlreadyOwnsTheSameScope() {
    let foodGroupID = homeDashboardID("00000000-0000-0000-0000-000000000202")
    let report = homeDashboardReport(
        pendingReviewCount: 0,
        targets: [
            homeDashboardTarget(
                id: "00000000-0000-0000-0000-000000000402",
                name: "Food",
                scope: .categoryGroup(foodGroupID),
                monthlyLimit: 200,
                spent: 110,
                remaining: 90,
                paceDelta: 15
            ),
        ],
        currentMonthAcceptedSpend: 110,
        lastMonthAcceptedSpend: 95,
        hasActiveTargets: true,
        totalMonthlyTargetLimit: 200,
        expectedPaceSpend: 95,
        paceDelta: 15,
        drivers: [
            homeDashboardDriver(
                title: "Food",
                scope: .categoryGroup(foodGroupID),
                currentPeriodSpend: 110,
                comparisonPeriodSpend: 95,
                delta: 15
            ),
        ],
        biggestShift: homeDashboardDriver(
            title: "Food",
            scope: .categoryGroup(foodGroupID),
            currentPeriodSpend: 110,
            comparisonPeriodSpend: 95,
            delta: 15
        )
    )

    let dashboard = HomeDashboardSnapshot.make(
        summary: WorkspaceSummary(accountCount: 1, transactionCount: 10, reviewCount: 0, targetCount: 1),
        monthlyReport: report
    )

    #expect(dashboard.actions.map(\.kind) == [.pressuredTarget])
}

@Test
func homeDashboardUsesLargestPositiveDriverWhenReviewAndTargetPressureAreEmpty() {
    let foodGroupID = homeDashboardID("00000000-0000-0000-0000-000000000203")
    let travelCategoryID = homeDashboardID("00000000-0000-0000-0000-000000000113")
    let report = homeDashboardReport(
        pendingReviewCount: 0,
        targets: [],
        currentMonthAcceptedSpend: 60,
        lastMonthAcceptedSpend: 120,
        hasActiveTargets: false,
        totalMonthlyTargetLimit: 0,
        expectedPaceSpend: 0,
        paceDelta: 0,
        drivers: [
            homeDashboardDriver(
                title: "Travel",
                scope: .category(travelCategoryID),
                currentPeriodSpend: 50,
                comparisonPeriodSpend: 120,
                delta: -70
            ),
            homeDashboardDriver(
                title: "Food",
                scope: .categoryGroup(foodGroupID),
                currentPeriodSpend: 60,
                comparisonPeriodSpend: 20,
                delta: 40
            ),
        ],
        biggestShift: homeDashboardDriver(
            title: "Travel",
            scope: .category(travelCategoryID),
            currentPeriodSpend: 50,
            comparisonPeriodSpend: 120,
            delta: -70
        )
    )

    let dashboard = HomeDashboardSnapshot.make(
        summary: WorkspaceSummary(accountCount: 1, transactionCount: 10, reviewCount: 0, targetCount: 0),
        monthlyReport: report
    )

    #expect(dashboard.actions.first?.kind == .spendDriver)
    #expect(dashboard.actions.first?.destination == .transactions(
        TransactionLedgerFilter(
            startDate: report.monthStart,
            endDate: homeDashboardEndOfMonth(report.monthStart),
            categoryID: nil,
            categoryGroupID: foodGroupID,
            direction: .expense,
            reviewStatuses: Set([.accepted, .pending])
        )
    ))
    #expect(dashboard.primaryAction?.title == "Inspect Food")
}

@Test
func homeDashboardBuildsStructuralRowsAndChartFromMonthlyReport() throws {
    let foodGroupID = homeDashboardID("00000000-0000-0000-0000-000000000204")
    let report = homeDashboardReport(
        pendingReviewCount: 0,
        targets: [
            homeDashboardTarget(
                id: "00000000-0000-0000-0000-000000000403",
                name: "Food",
                scope: .categoryGroup(foodGroupID),
                monthlyLimit: 200,
                spent: 110,
                remaining: 90,
                paceDelta: 15
            ),
        ],
        currentMonthAcceptedSpend: 110,
        lastMonthAcceptedSpend: 95,
        hasActiveTargets: true,
        totalMonthlyTargetLimit: 200,
        expectedPaceSpend: 95,
        paceDelta: 15,
        paceSeries: [
            MonthlySpendPoint(day: 1, actualSpend: 20, expectedSpend: 15),
            MonthlySpendPoint(day: 2, actualSpend: 30, expectedSpend: 25),
        ],
        drivers: [
            homeDashboardDriver(
                title: "Food",
                scope: .categoryGroup(foodGroupID),
                currentPeriodSpend: 110,
                comparisonPeriodSpend: 95,
                delta: 15
            ),
        ],
        biggestShift: homeDashboardDriver(
            title: "Food",
            scope: .categoryGroup(foodGroupID),
            currentPeriodSpend: 110,
            comparisonPeriodSpend: 95,
            delta: 15
        )
    )

    let dashboard = HomeDashboardSnapshot.make(
        summary: WorkspaceSummary(accountCount: 1, transactionCount: 10, reviewCount: 0, targetCount: 1),
        monthlyReport: report
    )

    let chart = try #require(dashboard.chart)
    let targetRow = try #require(dashboard.targetRows.first)
    let driverRow = try #require(dashboard.driverRows.first)

    #expect(chart.points == report.paceSeries)
    #expect(targetRow.destination == .targets(homeDashboardID("00000000-0000-0000-0000-000000000403")))
    #expect(driverRow.destination == .transactions(
        TransactionLedgerFilter(
            startDate: report.monthStart,
            endDate: homeDashboardEndOfMonth(report.monthStart),
            categoryID: nil,
            categoryGroupID: foodGroupID,
            direction: .expense,
            reviewStatuses: Set([.accepted, .pending])
        )
    ))
}

@Test
func homeDashboardPrimaryActionCompatibilityUsesTheFirstRankedAction() {
    let report = homeDashboardReport(
        pendingReviewCount: 2,
        targets: [],
        currentMonthAcceptedSpend: 40,
        lastMonthAcceptedSpend: 25,
        hasActiveTargets: false,
        totalMonthlyTargetLimit: 0,
        expectedPaceSpend: 0,
        paceDelta: 0,
        drivers: [],
        biggestShift: nil
    )

    let dashboard = HomeDashboardSnapshot.make(
        summary: WorkspaceSummary(accountCount: 1, transactionCount: 10, reviewCount: 2, targetCount: 0),
        monthlyReport: report
    )

    #expect(dashboard.primaryAction?.kind == .reviewBacklog(count: 2))
    #expect(dashboard.primaryAction?.destination.workspaceNavigationIntent == WorkspaceNavigationIntent(section: .review))
}

@Test
func targetsSectionUsesDedicatedManagerRoute() {
    #expect(WorkspaceDetailRoute.make(for: .rules) == .rulesManager)
    #expect(WorkspaceDetailRoute.make(for: .targets) == .targetsManager)
    #expect(WorkspaceDetailRoute.make(for: .accounts) == .accountsManager)
}

@Test
func transactionDrilldownFilterBuilderBuildsCurrentMonthAcceptedCategoryGroupFilter() {
    let monthStart = homeDashboardUTCDate(year: 2026, month: 4, day: 1)
    let foodGroupID = homeDashboardID("00000000-0000-0000-0000-000000000205")

    let filter = TransactionDrilldownFilterBuilder.currentMonthAcceptedExpenses(
        monthStart: monthStart,
        scope: TargetScope.categoryGroup(foodGroupID)
    )

    #expect(filter == TransactionLedgerFilter(
        startDate: monthStart,
        endDate: homeDashboardEndOfMonth(monthStart),
        categoryID: nil,
        categoryGroupID: foodGroupID,
        direction: .expense,
        reviewStatuses: Set([.accepted, .pending])
    ))
}

@Test
func transactionDrilldownFilterBuilderBuildsCurrentMonthIncludedVisibleCategoryGroupFilter() {
    let monthStart = homeDashboardUTCDate(year: 2026, month: 4, day: 1)
    let foodGroupID = homeDashboardID("00000000-0000-0000-0000-000000000215")

    let filter = TransactionDrilldownFilterBuilder.currentMonthIncludedVisibleExpenses(
        monthStart: monthStart,
        scope: TargetScope.categoryGroup(foodGroupID)
    )

    #expect(filter == TransactionLedgerFilter(
        startDate: monthStart,
        endDate: homeDashboardEndOfMonth(monthStart),
        categoryID: nil,
        categoryGroupID: foodGroupID,
        direction: .expense,
        reviewStatuses: Set([.accepted, .pending])
    ))
}

@Test
func transactionDrilldownFilterBuilderBuildsCurrentMonthAcceptedCategoryFilter() {
    let monthStart = homeDashboardUTCDate(year: 2026, month: 4, day: 1)
    let categoryID = homeDashboardID("00000000-0000-0000-0000-000000000114")

    let filter = TransactionDrilldownFilterBuilder.currentMonthAcceptedExpenses(
        monthStart: monthStart,
        scope: TargetScope.category(categoryID)
    )

    #expect(filter == TransactionLedgerFilter(
        startDate: monthStart,
        endDate: homeDashboardEndOfMonth(monthStart),
        categoryID: categoryID,
        categoryGroupID: nil,
        direction: .expense,
        reviewStatuses: Set([.accepted, .pending])
    ))
}

@Test
func transactionDrilldownFilterBuilderBuildsCurrentMonthAcceptedUncategorizedFilter() {
    let monthStart = homeDashboardUTCDate(year: 2026, month: 4, day: 1)

    let filter = TransactionDrilldownFilterBuilder.currentMonthAcceptedExpenses(
        monthStart: monthStart,
        scope: SpendingDriverScope.uncategorized
    )

    #expect(filter == TransactionLedgerFilter(
        startDate: monthStart,
        endDate: homeDashboardEndOfMonth(monthStart),
        uncategorizedOnly: true,
        direction: .expense,
        reviewStatuses: Set([.accepted, .pending])
    ))
}

private func homeDashboardReport(
    pendingReviewCount: Int = 0,
    targets: [TargetProgress] = [],
    currentMonthAcceptedSpend: Decimal = 0,
    lastMonthAcceptedSpend: Decimal = 0,
    expenseBasis: ReportingExpenseBasis = .includedVisibleExpenses,
    hasActiveTargets: Bool = false,
    totalMonthlyTargetLimit: Decimal = 0,
    expectedPaceSpend: Decimal = 0,
    paceDelta: Decimal = 0,
    paceSeries: [MonthlySpendPoint] = [MonthlySpendPoint(day: 1, actualSpend: Decimal(20), expectedSpend: Decimal(3.2))],
    drivers: [MonthlySpendingDriver] = [],
    biggestShift: MonthlySpendingDriver? = nil
) -> MonthlyReport {
    MonthlyReport(
        monthStart: homeDashboardUTCDate(year: 2026, month: 4, day: 1),
        currentMonthAcceptedSpend: currentMonthAcceptedSpend,
        lastMonthAcceptedSpend: lastMonthAcceptedSpend,
        expenseBasis: expenseBasis,
        pendingReviewCount: pendingReviewCount,
        targets: targets,
        hasActiveTargets: hasActiveTargets,
        totalMonthlyTargetLimit: totalMonthlyTargetLimit,
        expectedPaceSpend: expectedPaceSpend,
        paceDelta: paceDelta,
        paceSeries: paceSeries,
        drivers: drivers,
        biggestShift: biggestShift
    )
}

private func homeDashboardRecurringInsights(
    merchantName: String,
    cadence: RecurringChargeCadence,
    observationCount: Int,
    minimumAmount: Decimal,
    maximumAmount: Decimal
) -> WorkspaceInsightSummary {
    WorkspaceInsightSummary(
        insights: [
            WorkspaceInsight(
                kind: .recurringCharge(
                    RecurringChargeInsightDetail(
                        accountID: homeDashboardID("00000000-0000-0000-0000-000000009001"),
                        normalizedMerchantName: merchantName,
                        cadence: cadence,
                        observationCount: observationCount,
                        amountRange: RecurringChargeAmountRange(
                            minimum: minimumAmount,
                            maximum: maximumAmount
                        ),
                        supportingTransactionIDs: [
                            homeDashboardID("00000000-0000-0000-0000-000000009101"),
                            homeDashboardID("00000000-0000-0000-0000-000000009102"),
                            homeDashboardID("00000000-0000-0000-0000-000000009103"),
                        ],
                        firstObservedDate: homeDashboardUTCDate(year: 2026, month: 2, day: 9),
                        lastObservedDate: homeDashboardUTCDate(year: 2026, month: 4, day: 9),
                        nextExpectedDateWindow: nil
                    )
                ),
                confidence: 0.92,
                rank: 1,
                score: 92,
                suppressionKey: "recurring:\(merchantName)",
                evidence: InsightEvidence(
                    metricBasis: .includedVisibleExpenses,
                    resolvedInterval: DateInterval(
                        start: homeDashboardUTCDate(year: 2026, month: 2, day: 9),
                        end: homeDashboardUTCDate(year: 2026, month: 4, day: 10)
                    ),
                    scope: .merchant(merchantName),
                    reconciliationRule: .recurringObservationSet,
                    destination: InsightEvidenceDestination(
                        scope: .merchant(merchantName),
                        direction: .expense
                    )
                ),
                tieBreaker: WorkspaceInsightTieBreaker(
                    primaryDate: homeDashboardUTCDate(year: 2026, month: 4, day: 9),
                    secondaryKey: merchantName,
                    tertiaryKey: "home-dashboard"
                )
            ),
        ]
    )
}

private func homeDashboardTarget(
    id: String,
    name: String,
    scope: TargetScope,
    monthlyLimit: Decimal,
    spent: Decimal,
    remaining: Decimal,
    paceDelta: Decimal
) -> TargetProgress {
    TargetProgress(
        id: homeDashboardID(id),
        name: name,
        scope: scope,
        monthlyLimit: monthlyLimit,
        spent: spent,
        remaining: remaining,
        paceDelta: paceDelta
    )
}

private func homeDashboardDriver(
    title: String,
    scope: SpendingDriverScope,
    currentPeriodSpend: Decimal,
    comparisonPeriodSpend: Decimal,
    delta: Decimal
) -> MonthlySpendingDriver {
    MonthlySpendingDriver(
        title: title,
        scope: scope,
        currentPeriodSpend: currentPeriodSpend,
        comparisonPeriodSpend: comparisonPeriodSpend,
        delta: delta
    )
}

private func homeDashboardID(_ value: String) -> UUID {
    UUID(uuidString: value)!
}

private func homeDashboardUTCDate(
    year: Int,
    month: Int,
    day: Int,
    hour: Int = 0,
    minute: Int = 0,
    second: Int = 0
) -> Date {
    var components = DateComponents()
    components.calendar = Calendar(identifier: .gregorian)
    components.timeZone = TimeZone(secondsFromGMT: 0)
    components.year = year
    components.month = month
    components.day = day
    components.hour = hour
    components.minute = minute
    components.second = second
    return components.date!
}

private func homeDashboardEndOfMonth(_ monthStart: Date) -> Date? {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    guard let nextMonth = calendar.date(byAdding: DateComponents(month: 1), to: monthStart) else {
        return nil
    }
    return calendar.date(byAdding: DateComponents(second: -1), to: nextMonth)
}

private func homeDashboardEndOfDay(year: Int, month: Int, day: Int) -> Date {
    homeDashboardUTCDate(year: year, month: month, day: day, hour: 23, minute: 59, second: 59)
}
