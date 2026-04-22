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
func homeDashboardUsesMonthlyReportPendingReviewCountAsReviewSourceOfTruth() throws {
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
    #expect(dashboard.actions.first?.kind == .reviewBacklog(count: 7))
    #expect(dashboard.actions.first?.destination == .review)
    #expect(dashboard.primaryAction?.title == "Finish 7 items in Review")
}

@Test
func homeDashboardBuildsCreateFirstTargetActionOnlyWhenAcceptedExpenseHistoryExists() {
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
func homeDashboardSkipsCreateFirstTargetActionWithoutAcceptedExpenseHistory() {
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
            reviewStatus: .accepted
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
            reviewStatus: .accepted
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
        reviewStatus: .accepted
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
        reviewStatus: .accepted
    ))
}

private func homeDashboardReport(
    pendingReviewCount: Int = 0,
    targets: [TargetProgress] = [],
    currentMonthAcceptedSpend: Decimal = 0,
    lastMonthAcceptedSpend: Decimal = 0,
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
