import Domain
import Foundation

public enum HomeHeroStatus: Equatable, Sendable {
    case underPace
    case onPace
    case overPace
}

public enum HomeDashboardDestination: Equatable, Sendable {
    case review
    case targets
    case transactions(TransactionLedgerFilter)
}

public struct HomeDashboardAction: Equatable, Sendable {
    public var title: String
    public var destination: HomeDashboardDestination

    public init(title: String, destination: HomeDashboardDestination) {
        self.title = title
        self.destination = destination
    }
}

public struct HomeDashboardHero: Equatable, Sendable {
    public var amount: Decimal
    public var status: HomeHeroStatus

    public init(amount: Decimal, status: HomeHeroStatus) {
        self.amount = amount
        self.status = status
    }
}

public struct HomeDashboardSnapshot: Equatable, Sendable {
    public var hero: HomeDashboardHero
    public var primaryAction: HomeDashboardAction?

    public init(hero: HomeDashboardHero, primaryAction: HomeDashboardAction?) {
        self.hero = hero
        self.primaryAction = primaryAction
    }

    public static func make(
        summary: WorkspaceSummary,
        monthlyReport: MonthlyReport
    ) -> HomeDashboardSnapshot {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return HomeDashboardSnapshot(
            hero: HomeDashboardHero(
                amount: monthlyReport.currentMonthAcceptedSpend,
                status: heroStatus(for: monthlyReport)
            ),
            primaryAction: primaryAction(summary: summary, monthlyReport: monthlyReport, calendar: calendar)
        )
    }

    private static func heroStatus(for monthlyReport: MonthlyReport) -> HomeHeroStatus {
        if monthlyReport.paceDelta > 0 {
            return .overPace
        }
        if monthlyReport.paceDelta < 0 {
            return .underPace
        }
        return .onPace
    }

    private static func primaryAction(
        summary: WorkspaceSummary,
        monthlyReport: MonthlyReport,
        calendar: Calendar
    ) -> HomeDashboardAction? {
        if summary.reviewCount > 0 {
            return HomeDashboardAction(
                title: "Finish \(summary.reviewCount) items in Review",
                destination: .review
            )
        }

        if let overLimitTarget = monthlyReport.targets
            .filter({ $0.remaining < 0 })
            .max(by: compareTargetPressure) {
            return HomeDashboardAction(
                title: "Review \(overLimitTarget.name) target",
                destination: .targets
            )
        }

        if let pressuredTarget = monthlyReport.targets
            .filter({ $0.paceDelta > 0 })
            .max(by: compareTargetPressure) {
            return HomeDashboardAction(
                title: "Review \(pressuredTarget.name) target",
                destination: .targets
            )
        }

        if let biggestDriver = monthlyReport.biggestShift, biggestDriver.delta > 0 {
            return HomeDashboardAction(
                title: "Inspect \(biggestDriver.title)",
                destination: .transactions(
                    TransactionLedgerFilter(
                        startDate: monthlyReport.monthStart,
                        endDate: calendar.date(byAdding: .month, value: 1, to: monthlyReport.monthStart),
                        categoryID: biggestDriver.scope.categoryID,
                        categoryGroupID: biggestDriver.scope.categoryGroupID,
                        direction: .expense
                    )
                )
            )
        }

        return nil
    }

    private static func compareTargetPressure(_ lhs: TargetProgress, _ rhs: TargetProgress) -> Bool {
        if lhs.paceDelta != rhs.paceDelta {
            return lhs.paceDelta < rhs.paceDelta
        }
        if lhs.remaining != rhs.remaining {
            return lhs.remaining > rhs.remaining
        }
        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }
}

private extension SpendingDriverScope {
    var categoryID: UUID? {
        switch self {
        case .category(let id):
            return id
        case .categoryGroup:
            return nil
        }
    }

    var categoryGroupID: UUID? {
        switch self {
        case .category:
            return nil
        case .categoryGroup(let id):
            return id
        }
    }
}
