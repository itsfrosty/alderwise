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

public enum HomeDashboardActionKind: Equatable, Sendable {
    case reviewBacklog(count: Int)
    case pressuredTarget
    case spendDriver
    case createFirstTarget
}

public enum HomeDashboardActionProminence: Equatable, Sendable {
    case primary
    case secondary
}

public struct HomeDashboardAction: Equatable, Sendable {
    public var kind: HomeDashboardActionKind
    public var destination: HomeDashboardDestination
    public var prominence: HomeDashboardActionProminence

    public init(
        kind: HomeDashboardActionKind,
        destination: HomeDashboardDestination,
        prominence: HomeDashboardActionProminence
    ) {
        self.kind = kind
        self.destination = destination
        self.prominence = prominence
    }

    // Temporary compatibility shim for the pre-Task-4 Home view.
    public var title: String {
        switch kind {
        case .reviewBacklog(let count):
            "Finish \(count) items in Review"
        case .pressuredTarget:
            "Review target"
        case .spendDriver:
            "Inspect spending driver"
        case .createFirstTarget:
            "Create monthly limit"
        }
    }
}

public struct HomeDashboardReviewQualifier: Equatable, Sendable {
    public var pendingReviewCount: Int
    public var message: String

    public init(pendingReviewCount: Int, message: String) {
        self.pendingReviewCount = pendingReviewCount
        self.message = message
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

public struct HomeDashboardSummaryCard: Equatable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var value: String
    public var detail: String
    public var destination: HomeDashboardDestination?

    public init(id: String, title: String, value: String, detail: String, destination: HomeDashboardDestination?) {
        self.id = id
        self.title = title
        self.value = value
        self.detail = detail
        self.destination = destination
    }
}

public struct HomeDashboardChart: Equatable, Sendable {
    public var title: String
    public var points: [MonthlySpendPoint]
    public var emptyStateMessage: String?

    public init(title: String, points: [MonthlySpendPoint], emptyStateMessage: String?) {
        self.title = title
        self.points = points
        self.emptyStateMessage = emptyStateMessage
    }
}

public struct HomeDashboardTargetRow: Equatable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var spentText: String
    public var remainingText: String
    public var destination: HomeDashboardDestination

    public init(
        id: UUID,
        name: String,
        spentText: String,
        remainingText: String,
        destination: HomeDashboardDestination
    ) {
        self.id = id
        self.name = name
        self.spentText = spentText
        self.remainingText = remainingText
        self.destination = destination
    }
}

public struct HomeDashboardDriverRow: Equatable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var currentSpendText: String
    public var deltaText: String
    public var destination: HomeDashboardDestination

    public init(
        id: String,
        title: String,
        currentSpendText: String,
        deltaText: String,
        destination: HomeDashboardDestination
    ) {
        self.id = id
        self.title = title
        self.currentSpendText = currentSpendText
        self.deltaText = deltaText
        self.destination = destination
    }
}

public struct HomeDashboardSnapshot: Equatable, Sendable {
    public var isEmptyWorkspace: Bool
    public var reviewQualifier: HomeDashboardReviewQualifier?
    public var hero: HomeDashboardHero?
    public var actions: [HomeDashboardAction]
    public var summaryCards: [HomeDashboardSummaryCard]
    public var chart: HomeDashboardChart?
    public var targetRows: [HomeDashboardTargetRow]
    public var driverRows: [HomeDashboardDriverRow]

    public init(
        isEmptyWorkspace: Bool,
        reviewQualifier: HomeDashboardReviewQualifier?,
        hero: HomeDashboardHero?,
        actions: [HomeDashboardAction],
        summaryCards: [HomeDashboardSummaryCard],
        chart: HomeDashboardChart?,
        targetRows: [HomeDashboardTargetRow],
        driverRows: [HomeDashboardDriverRow]
    ) {
        self.isEmptyWorkspace = isEmptyWorkspace
        self.reviewQualifier = reviewQualifier
        self.hero = hero
        self.actions = actions
        self.summaryCards = summaryCards
        self.chart = chart
        self.targetRows = targetRows
        self.driverRows = driverRows
    }

    // Temporary compatibility shim for the pre-Task-4 Home view.
    public var primaryAction: HomeDashboardAction? {
        actions.first
    }

    public static func make(
        summary: WorkspaceSummary,
        monthlyReport: MonthlyReport
    ) -> HomeDashboardSnapshot {
        let isEmptyWorkspace = summary.transactionCount == 0
        let reviewQualifier = makeReviewQualifier(monthlyReport: monthlyReport, isEmptyWorkspace: isEmptyWorkspace)
        let targetRows = makeTargetRows(monthlyReport: monthlyReport, isEmptyWorkspace: isEmptyWorkspace)
        let driverRows = makeDriverRows(monthlyReport: monthlyReport, isEmptyWorkspace: isEmptyWorkspace)
        let actions = makeActions(monthlyReport: monthlyReport, isEmptyWorkspace: isEmptyWorkspace)

        return HomeDashboardSnapshot(
            isEmptyWorkspace: isEmptyWorkspace,
            reviewQualifier: reviewQualifier,
            hero: isEmptyWorkspace ? nil : HomeDashboardHero(
                amount: monthlyReport.currentMonthAcceptedSpend,
                status: heroStatus(for: monthlyReport)
            ),
            actions: actions,
            summaryCards: makeSummaryCards(
                monthlyReport: monthlyReport,
                reviewQualifier: reviewQualifier,
                isEmptyWorkspace: isEmptyWorkspace
            ),
            chart: makeChart(monthlyReport: monthlyReport, isEmptyWorkspace: isEmptyWorkspace),
            targetRows: targetRows,
            driverRows: driverRows
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

    private static func makeReviewQualifier(
        monthlyReport: MonthlyReport,
        isEmptyWorkspace: Bool
    ) -> HomeDashboardReviewQualifier? {
        guard !isEmptyWorkspace, monthlyReport.pendingReviewCount > 0 else {
            return nil
        }

        return HomeDashboardReviewQualifier(
            pendingReviewCount: monthlyReport.pendingReviewCount,
            message: "\(monthlyReport.pendingReviewCount) pending review item(s) can still change this month's accepted-only status."
        )
    }

    private static func makeActions(
        monthlyReport: MonthlyReport,
        isEmptyWorkspace: Bool
    ) -> [HomeDashboardAction] {
        guard !isEmptyWorkspace else {
            return []
        }

        var actions: [HomeDashboardAction] = []
        if monthlyReport.pendingReviewCount > 0 {
            actions.append(
                HomeDashboardAction(
                    kind: .reviewBacklog(count: monthlyReport.pendingReviewCount),
                    destination: .review,
                    prominence: .primary
                )
            )
        }

        if let pressuredTarget = pressuredTarget(for: monthlyReport) {
            actions.append(
                HomeDashboardAction(
                    kind: .pressuredTarget,
                    destination: .targets(pressuredTarget.id),
                    prominence: actions.isEmpty ? .primary : .secondary
                )
            )
        }

        if let driver = positiveDriver(for: monthlyReport),
           targetScopes(monthlyReport.targets).contains(where: { scopeMatches($0, driver.scope) }) == false {
            actions.append(
                HomeDashboardAction(
                    kind: .spendDriver,
                    destination: .transactions(
                        TransactionDrilldownFilterBuilder.currentMonthAcceptedExpenses(
                            monthStart: monthlyReport.monthStart,
                            scope: driver.scope
                        )
                    ),
                    prominence: actions.isEmpty ? .primary : .secondary
                )
            )
        }

        if monthlyReport.targets.isEmpty,
           monthlyReport.pendingReviewCount == 0,
           monthlyReport.currentMonthAcceptedSpend > 0 {
            actions.append(
                HomeDashboardAction(
                    kind: .createFirstTarget,
                    destination: .targets(nil),
                    prominence: actions.isEmpty ? .primary : .secondary
                )
            )
        }

        return Array(actions.prefix(3))
    }

    private static func makeSummaryCards(
        monthlyReport: MonthlyReport,
        reviewQualifier: HomeDashboardReviewQualifier?,
        isEmptyWorkspace: Bool
    ) -> [HomeDashboardSummaryCard] {
        guard !isEmptyWorkspace else {
            return []
        }

        var cards = [
            HomeDashboardSummaryCard(
                id: "current-month",
                title: "This Month",
                value: currency(monthlyReport.currentMonthAcceptedSpend),
                detail: "Accepted expenses",
                destination: nil
            ),
            HomeDashboardSummaryCard(
                id: "last-month",
                title: "Last Month",
                value: currency(monthlyReport.lastMonthAcceptedSpend),
                detail: changeDetail(current: monthlyReport.currentMonthAcceptedSpend, previous: monthlyReport.lastMonthAcceptedSpend),
                destination: nil
            ),
        ]

        if let reviewQualifier {
            cards.append(
                HomeDashboardSummaryCard(
                    id: "review",
                    title: "Review",
                    value: "\(reviewQualifier.pendingReviewCount)",
                    detail: "Pending items",
                    destination: .review
                )
            )
            return cards
        }

        if let pressuredTarget = pressuredTarget(for: monthlyReport) {
            let pressureValue = pressuredTarget.remaining < 0 ? abs(pressuredTarget.remaining) : pressuredTarget.paceDelta
            cards.append(
                HomeDashboardSummaryCard(
                    id: "target-pressure",
                    title: "Target Pressure",
                    value: currency(pressureValue),
                    detail: pressuredTarget.name,
                    destination: .targets(pressuredTarget.id)
                )
            )
            return cards
        }

        if let driver = positiveDriver(for: monthlyReport) {
            cards.append(
                HomeDashboardSummaryCard(
                    id: "driver",
                    title: "Strongest Driver",
                    value: deltaText(driver.delta),
                    detail: driver.title,
                    destination: .transactions(
                        TransactionDrilldownFilterBuilder.currentMonthAcceptedExpenses(
                            monthStart: monthlyReport.monthStart,
                            scope: driver.scope
                        )
                    )
                )
            )
        }

        return cards
    }

    private static func makeChart(
        monthlyReport: MonthlyReport,
        isEmptyWorkspace: Bool
    ) -> HomeDashboardChart? {
        guard !isEmptyWorkspace, monthlyReport.hasActiveTargets else {
            return nil
        }

        return HomeDashboardChart(
            title: "Pace",
            points: monthlyReport.paceSeries,
            emptyStateMessage: monthlyReport.paceSeries.isEmpty ? "Accepted expenses will populate pace after this month starts." : nil
        )
    }

    private static func makeTargetRows(
        monthlyReport: MonthlyReport,
        isEmptyWorkspace: Bool
    ) -> [HomeDashboardTargetRow] {
        guard !isEmptyWorkspace else {
            return []
        }

        return monthlyReport.targets.map { target in
            HomeDashboardTargetRow(
                id: target.id,
                name: target.name,
                spentText: "\(currency(target.spent)) of \(currency(target.monthlyLimit))",
                remainingText: remainingText(target.remaining),
                destination: .targets(target.id)
            )
        }
    }

    private static func makeDriverRows(
        monthlyReport: MonthlyReport,
        isEmptyWorkspace: Bool
    ) -> [HomeDashboardDriverRow] {
        guard !isEmptyWorkspace else {
            return []
        }

        return Array(monthlyReport.drivers.prefix(3)).map { driver in
            HomeDashboardDriverRow(
                id: driverID(driver),
                title: driver.title,
                currentSpendText: currency(driver.currentPeriodSpend),
                deltaText: deltaText(driver.delta),
                destination: .transactions(
                    TransactionDrilldownFilterBuilder.currentMonthAcceptedExpenses(
                        monthStart: monthlyReport.monthStart,
                        scope: driver.scope
                    )
                )
            )
        }
    }

    private static func pressuredTarget(for monthlyReport: MonthlyReport) -> TargetProgress? {
        if let overLimitTarget = monthlyReport.targets
            .filter({ $0.remaining < 0 })
            .max(by: compareTargetPressure) {
            return overLimitTarget
        }

        return monthlyReport.targets
            .filter({ $0.paceDelta > 0 })
            .max(by: compareTargetPressure)
    }

    private static func positiveDriver(for monthlyReport: MonthlyReport) -> MonthlySpendingDriver? {
        monthlyReport.drivers.first(where: { $0.delta > 0 })
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

    private static func targetScopes(_ targets: [TargetProgress]) -> [TargetScope] {
        targets.map(\.scope)
    }

    private static func scopeMatches(_ targetScope: TargetScope, _ driverScope: SpendingDriverScope) -> Bool {
        switch (targetScope, driverScope) {
        case (.category(let lhs), .category(let rhs)):
            lhs == rhs
        case (.categoryGroup(let lhs), .categoryGroup(let rhs)):
            lhs == rhs
        default:
            false
        }
    }

    private static func driverID(_ driver: MonthlySpendingDriver) -> String {
        switch driver.scope {
        case .category(let id):
            "category:\(id.uuidString)"
        case .categoryGroup(let id):
            "group:\(id.uuidString)"
        }
    }

    private static func currency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = Locale.current.currency?.identifier ?? "USD"
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "\(amount)"
    }

    private static func changeDetail(current: Decimal, previous: Decimal) -> String {
        let delta = current - previous
        if delta == 0 {
            return "Flat versus last month"
        }

        return delta > 0 ? "Up \(currency(abs(delta)))" : "Down \(currency(abs(delta)))"
    }

    private static func deltaText(_ delta: Decimal) -> String {
        if delta == 0 {
            return "Flat"
        }

        return delta > 0 ? "Up \(currency(abs(delta)))" : "Down \(currency(abs(delta)))"
    }

    private static func remainingText(_ remaining: Decimal) -> String {
        if remaining < 0 {
            return "\(currency(abs(remaining))) over"
        }

        return "\(currency(remaining)) remaining"
    }
}

// Temporary compatibility shim for the pre-Task-4 Home view.
public extension Optional where Wrapped == HomeDashboardHero {
    var amount: Decimal {
        switch self {
        case .some(let hero):
            hero.amount
        case .none:
            .zero
        }
    }

    var status: HomeHeroStatus? {
        switch self {
        case .some(let hero):
            hero.status
        case .none:
            nil
        }
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
