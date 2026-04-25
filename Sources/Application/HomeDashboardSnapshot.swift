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
    case analysis
    case transactions
    case review
    case rulesManager
    case targetsManager
    case accountsManager
    case settings

    public static func make(for section: AppSection) -> WorkspaceDetailRoute {
        switch section {
        case .home:
            .home
        case .analysis:
            .analysis
        case .transactions:
            .transactions
        case .review:
            .review
        case .rules:
            .rulesManager
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
    private var titleOverride: String?

    public init(
        kind: HomeDashboardActionKind,
        destination: HomeDashboardDestination,
        prominence: HomeDashboardActionProminence,
        title: String? = nil
    ) {
        self.kind = kind
        self.destination = destination
        self.prominence = prominence
        self.titleOverride = title
    }

    // Temporary compatibility shim for the pre-Task-4 Home view.
    public var title: String {
        if let titleOverride {
            return titleOverride
        }
        return switch kind {
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

public struct HomeDashboardRecurringSection: Equatable, Sendable {
    public var merchantName: String
    public var title: String
    public var message: String
    public var destination: HomeDashboardDestination

    public init(
        merchantName: String,
        title: String,
        message: String,
        destination: HomeDashboardDestination
    ) {
        self.merchantName = merchantName
        self.title = title
        self.message = message
        self.destination = destination
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
    public var monthlyLimit: Decimal
    public var spent: Decimal
    public var remaining: Decimal
    public var spentText: String
    public var remainingText: String
    public var destination: HomeDashboardDestination

    public init(
        id: UUID,
        name: String,
        monthlyLimit: Decimal,
        spent: Decimal,
        remaining: Decimal,
        spentText: String,
        remainingText: String,
        destination: HomeDashboardDestination
    ) {
        self.id = id
        self.name = name
        self.monthlyLimit = monthlyLimit
        self.spent = spent
        self.remaining = remaining
        self.spentText = spentText
        self.remainingText = remainingText
        self.destination = destination
    }
}

public struct HomeDashboardDriverRow: Equatable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var currentSpendText: String
    public var comparisonSpendText: String
    public var delta: Decimal
    public var deltaText: String
    public var destination: HomeDashboardDestination

    public init(
        id: String,
        title: String,
        currentSpendText: String,
        comparisonSpendText: String,
        delta: Decimal,
        deltaText: String,
        destination: HomeDashboardDestination
    ) {
        self.id = id
        self.title = title
        self.currentSpendText = currentSpendText
        self.comparisonSpendText = comparisonSpendText
        self.delta = delta
        self.deltaText = deltaText
        self.destination = destination
    }
}

public struct HomeDashboardSnapshot: Equatable, Sendable {
    public var isEmptyWorkspace: Bool
    public var reviewQualifier: HomeDashboardReviewQualifier?
    public var hero: HomeDashboardHero?
    public var recurringSection: HomeDashboardRecurringSection?
    public var actions: [HomeDashboardAction]
    public var summaryCards: [HomeDashboardSummaryCard]
    public var chart: HomeDashboardChart?
    public var targetRows: [HomeDashboardTargetRow]
    public var driverRows: [HomeDashboardDriverRow]

    public init(
        isEmptyWorkspace: Bool,
        reviewQualifier: HomeDashboardReviewQualifier?,
        hero: HomeDashboardHero?,
        recurringSection: HomeDashboardRecurringSection?,
        actions: [HomeDashboardAction],
        summaryCards: [HomeDashboardSummaryCard],
        chart: HomeDashboardChart?,
        targetRows: [HomeDashboardTargetRow],
        driverRows: [HomeDashboardDriverRow]
    ) {
        self.isEmptyWorkspace = isEmptyWorkspace
        self.reviewQualifier = reviewQualifier
        self.hero = hero
        self.recurringSection = recurringSection
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
        monthlyReport: MonthlyReport,
        insights: WorkspaceInsightSummary = .empty
    ) -> HomeDashboardSnapshot {
        let isEmptyWorkspace = summary.transactionCount == 0
        let reviewQualifier = makeReviewQualifier(monthlyReport: monthlyReport, isEmptyWorkspace: isEmptyWorkspace)
        let recurringSection = makeRecurringSection(insights: insights, isEmptyWorkspace: isEmptyWorkspace)
        let targetRows = makeTargetRows(monthlyReport: monthlyReport, isEmptyWorkspace: isEmptyWorkspace)
        let driverRows = makeDriverRows(monthlyReport: monthlyReport, isEmptyWorkspace: isEmptyWorkspace)
        let actions = makeActions(monthlyReport: monthlyReport, isEmptyWorkspace: isEmptyWorkspace)

        return HomeDashboardSnapshot(
            isEmptyWorkspace: isEmptyWorkspace,
            reviewQualifier: reviewQualifier,
            hero: isEmptyWorkspace ? nil : HomeDashboardHero(
                amount: monthlyReport.currentMonthIncludedVisibleSpend,
                status: heroStatus(for: monthlyReport)
            ),
            recurringSection: recurringSection,
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

    private static func makeRecurringSection(
        insights: WorkspaceInsightSummary,
        isEmptyWorkspace: Bool
    ) -> HomeDashboardRecurringSection? {
        guard !isEmptyWorkspace,
              let detail = insights.insights.compactMap(recurringChargeDetail(from:)).first else {
            return nil
        }

        return HomeDashboardRecurringSection(
            merchantName: detail.normalizedMerchantName,
            title: "\(merchantDisplayName(detail.normalizedMerchantName)) may be recurring",
            message: "\(recurringCadenceTitle(detail.cadence)) at \(recurringAmountSummary(detail.amountRange)) across \(detail.observationCount) \(chargeLabel(count: detail.observationCount)).",
            destination: .transactions(TransactionDrilldownFilterBuilder.recurringChargeEvidence(detail: detail))
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
            message: "\(monthlyReport.pendingReviewCount) review item(s) can still recategorize some visible spend."
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
                    prominence: actions.isEmpty ? .primary : .secondary,
                    title: "Review \(pressuredTarget.name) target"
                )
            )
        }

        if let driver = positiveDriver(for: monthlyReport),
           targetScopes(monthlyReport.targets).contains(where: { scopeMatches($0, driver.scope) }) == false {
            actions.append(
                HomeDashboardAction(
                    kind: .spendDriver,
                    destination: .transactions(
                        TransactionDrilldownFilterBuilder.currentMonthIncludedVisibleExpenses(
                            monthStart: monthlyReport.monthStart,
                            scope: driver.scope
                        )
                    ),
                    prominence: actions.isEmpty ? .primary : .secondary,
                    title: "Inspect \(driver.title)"
                )
            )
        }

        if monthlyReport.targets.isEmpty,
           monthlyReport.pendingReviewCount == 0,
           monthlyReport.currentMonthIncludedVisibleSpend > 0 {
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
                value: currency(monthlyReport.currentMonthIncludedVisibleSpend),
                detail: "Visible expenses",
                destination: nil
            ),
            HomeDashboardSummaryCard(
                id: "last-month",
                title: "Last Month",
                value: currency(monthlyReport.lastMonthIncludedVisibleSpend),
                detail: changeDetail(
                    current: monthlyReport.currentMonthIncludedVisibleSpend,
                    previous: monthlyReport.lastMonthIncludedVisibleSpend
                ),
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
                        TransactionDrilldownFilterBuilder.currentMonthIncludedVisibleExpenses(
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
            emptyStateMessage: monthlyReport.paceSeries.isEmpty ? "Visible expenses will populate pace after this month starts." : nil
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
                monthlyLimit: target.monthlyLimit,
                spent: target.spent,
                remaining: target.remaining,
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
                comparisonSpendText: currency(driver.comparisonPeriodSpend),
                delta: driver.delta,
                deltaText: deltaText(driver.delta),
                destination: .transactions(
                    TransactionDrilldownFilterBuilder.currentMonthIncludedVisibleExpenses(
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
        case (_, .uncategorized):
            false
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
        case .uncategorized:
            "uncategorized"
        }
    }

    private static func recurringChargeDetail(from insight: WorkspaceInsight) -> RecurringChargeInsightDetail? {
        switch insight.kind {
        case .recurringCharge(let detail):
            detail
        case .spendDriverChange:
            nil
        }
    }

    private static func merchantDisplayName(_ merchantName: String) -> String {
        merchantName.localizedCapitalized
    }

    private static func recurringCadenceTitle(_ cadence: RecurringChargeCadence) -> String {
        switch cadence {
        case .monthly:
            "Monthly"
        case .quarterly:
            "Quarterly"
        case .annual:
            "Annual"
        }
    }

    private static func recurringAmountSummary(_ amountRange: RecurringChargeAmountRange) -> String {
        if amountRange.minimum == amountRange.maximum {
            return "about \(currency(amountRange.minimum))"
        }
        return "about \(currency(amountRange.minimum)) to \(currency(amountRange.maximum))"
    }

    private static func chargeLabel(count: Int) -> String {
        count == 1 ? "charge" : "charges"
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
