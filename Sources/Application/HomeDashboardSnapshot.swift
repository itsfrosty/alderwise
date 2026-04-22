import Domain
import Foundation

public enum HomeHeroStatus: Equatable, Sendable {
    case underPace
    case onPace
    case overPace
}

public enum HomeDashboardDestination: Equatable, Sendable {
    case review
    case targets(UUID?)
    case transactions(TransactionLedgerFilter)
}

public struct WorkspaceNavigationIntent: Equatable, Sendable {
    public var section: AppSection
    public var targetID: UUID?
    public var transactionFilter: TransactionLedgerFilter?

    public init(section: AppSection, targetID: UUID? = nil, transactionFilter: TransactionLedgerFilter? = nil) {
        self.section = section
        self.targetID = targetID
        self.transactionFilter = transactionFilter
    }
}

public enum WorkspaceDetailRoute: Equatable, Sendable {
    case home
    case transactions
    case review
    case targetsManager
    case accountsManager
    case settings

    public static func make(for section: AppSection) -> WorkspaceDetailRoute {
        switch section {
        case .home:
            .home
        case .transactions:
            .transactions
        case .review:
            .review
        case .targets:
            .targetsManager
        case .accounts:
            .accountsManager
        case .settings:
            .settings
        }
    }
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
        return HomeDashboardSnapshot(
            hero: HomeDashboardHero(
                amount: monthlyReport.currentMonthAcceptedSpend,
                status: heroStatus(for: monthlyReport)
            ),
            primaryAction: primaryAction(monthlyReport: monthlyReport)
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

    private static func primaryAction(monthlyReport: MonthlyReport) -> HomeDashboardAction? {
        if monthlyReport.pendingReviewCount > 0 {
            return HomeDashboardAction(
                title: "Finish \(monthlyReport.pendingReviewCount) items in Review",
                destination: .review
            )
        }

        if let overLimitTarget = monthlyReport.targets
            .filter({ $0.remaining < 0 })
            .max(by: compareTargetPressure) {
            return HomeDashboardAction(
                title: "Review \(overLimitTarget.name) target",
                destination: .targets(overLimitTarget.id)
            )
        }

        if let pressuredTarget = monthlyReport.targets
            .filter({ $0.paceDelta > 0 })
            .max(by: compareTargetPressure) {
            return HomeDashboardAction(
                title: "Review \(pressuredTarget.name) target",
                destination: .targets(pressuredTarget.id)
            )
        }

        if let biggestDriver = monthlyReport.drivers.first(where: { $0.delta > 0 }) {
            return HomeDashboardAction(
                title: "Inspect \(biggestDriver.title)",
                destination: .transactions(
                    TransactionDrilldownFilterBuilder.currentMonthAcceptedExpenses(
                        monthStart: monthlyReport.monthStart,
                        scope: biggestDriver.scope
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

public extension HomeDashboardDestination {
    var workspaceNavigationIntent: WorkspaceNavigationIntent {
        switch self {
        case .review:
            WorkspaceNavigationIntent(section: .review)
        case .targets(let targetID):
            WorkspaceNavigationIntent(section: .targets, targetID: targetID)
        case .transactions(let filter):
            WorkspaceNavigationIntent(section: .transactions, transactionFilter: filter)
        }
    }
}
