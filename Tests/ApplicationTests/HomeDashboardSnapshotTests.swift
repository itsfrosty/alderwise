import Application
import Domain
import Foundation
import Testing

@Test
func homeDashboardPrioritizesReviewBacklogOverTargetsAndDrivers() {
    let report = homeDashboardReport(
        pendingReviewCount: 7,
        targets: [
            homeDashboardTarget(
                id: "00000000-0000-0000-0000-000000000301",
                name: "Food",
                scope: .categoryGroup(homeDashboardID("00000000-0000-0000-0000-000000000201")),
                monthlyLimit: 100,
                spent: 120,
                remaining: -20,
                paceDelta: 35
            ),
        ],
        currentMonthAcceptedSpend: 120,
        lastMonthAcceptedSpend: 80,
        hasActiveTargets: true,
        totalMonthlyTargetLimit: 100,
        expectedPaceSpend: 85,
        paceDelta: 35,
        drivers: [
            homeDashboardDriver(
                title: "Food",
                scope: .categoryGroup(homeDashboardID("00000000-0000-0000-0000-000000000201")),
                currentPeriodSpend: 120,
                comparisonPeriodSpend: 80,
                delta: 40
            ),
        ],
        biggestShift: homeDashboardDriver(
            title: "Food",
            scope: .categoryGroup(homeDashboardID("00000000-0000-0000-0000-000000000201")),
            currentPeriodSpend: 120,
            comparisonPeriodSpend: 80,
            delta: 40
        )
    )

    let dashboard = HomeDashboardSnapshot.make(
        summary: WorkspaceSummary(accountCount: 1, transactionCount: 10, reviewCount: 7, targetCount: 1),
        monthlyReport: report
    )

    #expect(dashboard.hero.status == .overPace)
    #expect(dashboard.primaryAction?.destination == .review)
    #expect(dashboard.primaryAction?.title == "Finish 7 items in Review")
}

@Test
func homeDashboardPrioritizesOverLimitTargetsWhenReviewBacklogIsEmpty() {
    let report = homeDashboardReport(
        pendingReviewCount: 0,
        targets: [
            homeDashboardTarget(
                id: "00000000-0000-0000-0000-000000000401",
                name: "Food",
                scope: .categoryGroup(homeDashboardID("00000000-0000-0000-0000-000000000201")),
                monthlyLimit: 100,
                spent: 120,
                remaining: -20,
                paceDelta: 20
            ),
        ],
        currentMonthAcceptedSpend: 120,
        lastMonthAcceptedSpend: 90,
        hasActiveTargets: true,
        totalMonthlyTargetLimit: 100,
        expectedPaceSpend: 100,
        paceDelta: 20,
        drivers: [],
        biggestShift: nil
    )

    let dashboard = HomeDashboardSnapshot.make(
        summary: WorkspaceSummary(accountCount: 1, transactionCount: 10, reviewCount: 0, targetCount: 1),
        monthlyReport: report
    )

    #expect(dashboard.primaryAction?.destination == .targets)
    #expect(dashboard.primaryAction?.title == "Review Food target")
}

@Test
func homeDashboardPrefersOverLimitTargetsEvenWhenADriverIsAlsoPresent() {
    let foodGroupID = homeDashboardID("00000000-0000-0000-0000-000000000201")
    let report = homeDashboardReport(
        pendingReviewCount: 0,
        targets: [
            homeDashboardTarget(
                id: "00000000-0000-0000-0000-000000000402",
                name: "Food",
                scope: .categoryGroup(foodGroupID),
                monthlyLimit: 100,
                spent: 120,
                remaining: -20,
                paceDelta: 20
            ),
        ],
        currentMonthAcceptedSpend: 120,
        lastMonthAcceptedSpend: 90,
        hasActiveTargets: true,
        totalMonthlyTargetLimit: 100,
        expectedPaceSpend: 100,
        paceDelta: 20,
        drivers: [
            homeDashboardDriver(
                title: "Food",
                scope: .categoryGroup(foodGroupID),
                currentPeriodSpend: 120,
                comparisonPeriodSpend: 90,
                delta: 30
            ),
        ],
        biggestShift: homeDashboardDriver(
            title: "Food",
            scope: .categoryGroup(foodGroupID),
            currentPeriodSpend: 120,
            comparisonPeriodSpend: 90,
            delta: 30
        )
    )

    let dashboard = HomeDashboardSnapshot.make(
        summary: WorkspaceSummary(accountCount: 1, transactionCount: 10, reviewCount: 0, targetCount: 1),
        monthlyReport: report
    )

    #expect(dashboard.primaryAction?.destination == .targets)
    #expect(dashboard.primaryAction?.title == "Review Food target")
}

@Test
func homeDashboardPrioritizesBiggestDriverWhenReviewBacklogAndTargetPressureAreEmpty() {
    let foodGroupID = homeDashboardID("00000000-0000-0000-0000-000000000201")
    let report = homeDashboardReport(
        pendingReviewCount: 0,
        targets: [],
        currentMonthAcceptedSpend: 40,
        lastMonthAcceptedSpend: 25,
        hasActiveTargets: false,
        totalMonthlyTargetLimit: 0,
        expectedPaceSpend: 0,
        paceDelta: 0,
        drivers: [
            homeDashboardDriver(
                title: "Food",
                scope: .categoryGroup(foodGroupID),
                currentPeriodSpend: 40,
                comparisonPeriodSpend: 25,
                delta: 15
            ),
        ],
        biggestShift: homeDashboardDriver(
            title: "Food",
            scope: .categoryGroup(foodGroupID),
            currentPeriodSpend: 40,
            comparisonPeriodSpend: 25,
            delta: 15
        )
    )

    let dashboard = HomeDashboardSnapshot.make(
        summary: WorkspaceSummary(accountCount: 1, transactionCount: 10, reviewCount: 0, targetCount: 0),
        monthlyReport: report
    )

    #expect(dashboard.primaryAction?.destination == .transactions(
        TransactionLedgerFilter(
            startDate: report.monthStart,
            endDate: homeDashboardAddingMonth(to: report.monthStart),
            categoryID: nil,
            categoryGroupID: foodGroupID,
            direction: .expense
        )
    ))
    #expect(dashboard.primaryAction?.title == "Inspect Food")
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
        monthStart: Date(timeIntervalSince1970: 1_775_084_800),
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

private func homeDashboardAddingMonth(to date: Date) -> Date? {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    return calendar.date(byAdding: .month, value: 1, to: date)
}
