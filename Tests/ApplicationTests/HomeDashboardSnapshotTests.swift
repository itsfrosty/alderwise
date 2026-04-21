import Application
import Domain
import Foundation
import Testing

@Test
func homeDashboardPrioritizesReviewBacklogOverTargetsAndDrivers() {
    let report = MonthlyReport(
        monthStart: Date(timeIntervalSince1970: 1_775_084_800),
        currentMonthAcceptedSpend: Decimal(120),
        lastMonthAcceptedSpend: Decimal(80),
        pendingReviewCount: 7,
        targets: [
            TargetProgress(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000301")!,
                name: "Food",
                scope: .categoryGroup(UUID(uuidString: "00000000-0000-0000-0000-000000000201")!),
                monthlyLimit: Decimal(100),
                spent: Decimal(120),
                remaining: Decimal(-20),
                paceDelta: Decimal(35)
            ),
        ],
        hasActiveTargets: true,
        totalMonthlyTargetLimit: Decimal(100),
        expectedPaceSpend: Decimal(85),
        paceDelta: Decimal(35),
        paceSeries: [
            MonthlySpendPoint(day: 1, actualSpend: Decimal(20), expectedSpend: Decimal(3.2)),
        ],
        drivers: [
            MonthlySpendingDriver(
                title: "Food",
                scope: .categoryGroup(UUID(uuidString: "00000000-0000-0000-0000-000000000201")!),
                currentPeriodSpend: Decimal(120),
                comparisonPeriodSpend: Decimal(80),
                delta: Decimal(40)
            ),
        ],
        biggestShift: MonthlySpendingDriver(
            title: "Food",
            scope: .categoryGroup(UUID(uuidString: "00000000-0000-0000-0000-000000000201")!),
            currentPeriodSpend: Decimal(120),
            comparisonPeriodSpend: Decimal(80),
            delta: Decimal(40)
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
