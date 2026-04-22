import Application
import Domain
import SwiftUI

struct HomeDashboardView: View {
    let snapshot: WorkspaceSnapshot
    let openReview: () -> Void
    let openTargets: (UUID?) -> Void
    let openTransactions: (TransactionLedgerFilter) -> Void

    @EnvironmentObject private var model: WorkspaceShellModel

    private var dashboard: HomeDashboardSnapshot? {
        snapshot.homeDashboard
    }

    private var driverRows: [DriverPresentation] {
        Array(snapshot.monthlyReport.drivers.prefix(3)).map(DriverPresentation.init)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if snapshot.summary.transactionCount == 0 {
                    emptyWorkspaceState
                } else {
                    heroCard

                    if snapshot.monthlyReport.hasActiveTargets == false {
                        noTargetsSection
                    } else {
                        targetsSection
                        driversSection
                    }
                }
            }
            .padding(24)
        }
        .navigationTitle("Home")
    }

    private var emptyWorkspaceState: some View {
        ContentUnavailableView {
            Label("Build your local spending workspace", systemImage: "house")
        } description: {
            Text("Start with Import CSV or create an account to prepare your first import.")
        } actions: {
            Button {
                model.beginCSVImport()
            } label: {
                Label("Import CSV", systemImage: "square.and.arrow.down")
            }
            .buttonStyle(.borderedProminent)

            Button {
                model.isPresentingAccountSheet = true
            } label: {
                Label("Create Account", systemImage: "plus")
            }
            .buttonStyle(.bordered)

            Button {
                model.addSampleAccount()
            } label: {
                Label("Add Sample Data", systemImage: "sparkles")
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, minHeight: 360)
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(heroHeadline)
                .font(.headline)
                .foregroundStyle(heroTint)

            Text(currency(dashboard?.hero.amount ?? snapshot.monthlyReport.currentMonthAcceptedSpend))
                .font(.system(size: 34, weight: .semibold))

            Text(heroSubtitle)
                .foregroundStyle(.secondary)

            if let confidenceNote {
                Text(confidenceNote)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if snapshot.monthlyReport.hasActiveTargets {
                PaceMiniChart(points: snapshot.monthlyReport.paceSeries)
                    .frame(height: 92)
            }

            if let primaryAction = dashboard?.primaryAction {
                Button {
                    perform(primaryAction.destination)
                } label: {
                    Label(primaryAction.title, systemImage: primaryActionSymbol(for: primaryAction.destination))
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var noTargetsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("No active targets")
                .font(.title3.weight(.semibold))

            Text("Compare this month with last month, then add a target when you’re ready to track pace.")
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                metricCard(
                    title: "This Month",
                    value: currency(snapshot.monthlyReport.currentMonthAcceptedSpend),
                    detail: "Accepted expenses"
                )
                metricCard(
                    title: "Last Month",
                    value: currency(snapshot.monthlyReport.lastMonthAcceptedSpend),
                    detail: lastMonthChangeText
                )
            }

            if driverRows.isEmpty == false {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Top Drivers")
                        .font(.headline)

                    ForEach(driverRows) { driver in
                        DriverRow(driver: driver.driver, action: {
                            openTransactions(transactionFilter(for: driver.driver))
                        }, currency: currency)
                    }
                }
            } else {
                Text("More history needed for month-over-month changes")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button {
                model.beginTargetCreation()
            } label: {
                Label("Create Target", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var targetsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Target Progress")
                .font(.headline)

            if snapshot.monthlyReport.targets.isEmpty {
                Text("Create a monthly category target to track accepted spending.")
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(snapshot.monthlyReport.targets) { target in
                        Button {
                            openTargets(target.id)
                        } label: {
                            TargetRow(target: target, currency: currency)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }

    private var driversSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Month-over-Month Drivers")
                .font(.headline)

            if driverRows.isEmpty {
                Text("More history needed for month-over-month changes")
                    .foregroundStyle(.secondary)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(driverRows) { driver in
                        DriverRow(driver: driver.driver, action: {
                            openTransactions(transactionFilter(for: driver.driver))
                        }, currency: currency)
                    }
                }
                .padding(16)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }

    private var heroHeadline: String {
        if snapshot.monthlyReport.hasActiveTargets == false {
            return "No active targets"
        }

        switch dashboard?.hero.status {
        case .underPace:
            return "Under target pace"
        case .onPace:
            return "On target pace"
        case .overPace:
            return "Over target pace"
        case nil:
            return "Monthly spending"
        }
    }

    private var heroSubtitle: String {
        if snapshot.monthlyReport.hasActiveTargets == false {
            return "Last month closed at \(currency(snapshot.monthlyReport.lastMonthAcceptedSpend)) on the same accepted-spend basis."
        }

        let expected = currency(snapshot.monthlyReport.expectedPaceSpend)
        let pending = snapshot.monthlyReport.pendingReviewCount
        let pendingSuffix = pending > 0 ? " \(pending) item\(pending == 1 ? "" : "s") still need review." : ""
        return "Expected pace is \(expected) for this point in the month.\(pendingSuffix)"
    }

    private var confidenceNote: String? {
        if snapshot.monthlyReport.hasActiveTargets == false {
            return "Create a target to compare current spending against a monthly pace."
        }
        return "Based on accepted expense activity only."
    }

    private var heroTint: Color {
        switch dashboard?.hero.status {
        case .underPace:
            return .green
        case .onPace:
            return .secondary
        case .overPace:
            return .orange
        case nil:
            return .secondary
        }
    }

    private var lastMonthChangeText: String {
        let delta = snapshot.monthlyReport.currentMonthAcceptedSpend - snapshot.monthlyReport.lastMonthAcceptedSpend
        if delta == 0 {
            return "Flat versus last month"
        }
        let direction = delta > 0 ? "up" : "down"
        return "\(direction.capitalized) \(currency(abs(delta)))"
    }

    private func metricCard(title: String, value: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(value)
                .font(.system(size: 28, weight: .semibold))
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func perform(_ destination: HomeDashboardDestination) {
        switch destination {
        case .review:
            openReview()
        case .targets(let targetID):
            openTargets(targetID)
        case .transactions(let filter):
            openTransactions(filter)
        }
    }

    private func primaryActionSymbol(for destination: HomeDashboardDestination) -> String {
        switch destination {
        case .review:
            return AppSection.review.systemImage
        case .targets:
            return AppSection.targets.systemImage
        case .transactions:
            return AppSection.transactions.systemImage
        }
    }

    private func transactionFilter(for driver: MonthlySpendingDriver) -> TransactionLedgerFilter {
        TransactionLedgerFilter(
            startDate: snapshot.monthlyReport.monthStart,
            endDate: endOfMonth(for: snapshot.monthlyReport.monthStart),
            categoryID: categoryID(for: driver.scope),
            categoryGroupID: categoryGroupID(for: driver.scope),
            direction: .expense,
            reviewStatus: .accepted
        )
    }

    private func categoryID(for scope: SpendingDriverScope) -> UUID? {
        switch scope {
        case .category(let id):
            return id
        case .categoryGroup:
            return nil
        }
    }

    private func categoryGroupID(for scope: SpendingDriverScope) -> UUID? {
        switch scope {
        case .category:
            return nil
        case .categoryGroup(let id):
            return id
        }
    }

    private func endOfMonth(for monthStart: Date) -> Date? {
        guard let nextMonth = Self.utcCalendar.date(byAdding: .month, value: 1, to: monthStart) else {
            return nil
        }
        return Self.utcCalendar.date(byAdding: .second, value: -1, to: nextMonth)
    }

    private func currency(_ amount: Decimal) -> String {
        CurrencyFormatter.shared.string(from: NSDecimalNumber(decimal: amount)) ?? "\(amount)"
    }

    private static var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar
    }
}

private struct DriverRow: View {
    let driver: MonthlySpendingDriver
    let action: () -> Void
    let currency: (Decimal) -> String

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(driver.title)
                        .font(.headline)
                    Text("Last month: \(currency(driver.comparisonPeriodSpend))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(currency(driver.currentPeriodSpend))
                        .font(.headline)
                    Text(deltaText)
                        .font(.caption)
                        .foregroundStyle(driver.delta > 0 ? Color.orange : Color.secondary)
                }
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var deltaText: String {
        if driver.delta == 0 {
            return "No change"
        }
        let trend = driver.delta > 0 ? "Up" : "Down"
        return "\(trend) \(currency(abs(driver.delta)))"
    }
}

private struct DriverPresentation: Identifiable {
    let driver: MonthlySpendingDriver
    let id: String

    init(driver: MonthlySpendingDriver) {
        self.driver = driver
        self.id = Self.makeID(for: driver)
    }

    private static func makeID(for driver: MonthlySpendingDriver) -> String {
        switch driver.scope {
        case .category(let id):
            return "category:\(id.uuidString):\(driver.title)"
        case .categoryGroup(let id):
            return "group:\(id.uuidString):\(driver.title)"
        }
    }
}

private struct TargetRow: View {
    let target: TargetProgress
    let currency: (Decimal) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(target.name)
                    .font(.headline)
                Spacer()
                Text("\(currency(target.spent)) of \(currency(target.monthlyLimit))")
                    .foregroundStyle(.secondary)
            }

            ProgressView(
                value: min(NSDecimalNumber(decimal: target.spent).doubleValue, NSDecimalNumber(decimal: target.monthlyLimit).doubleValue),
                total: max(NSDecimalNumber(decimal: target.monthlyLimit).doubleValue, 0.01)
            )

            Text("\(currency(target.remaining)) remaining")
                .font(.caption)
                .foregroundStyle(target.remaining >= 0 ? Color.secondary : Color.red)
        }
        .padding(.vertical, 8)
    }
}

private struct PaceMiniChart: View {
    let points: [MonthlySpendPoint]

    var body: some View {
        GeometryReader { proxy in
            let normalizedPoints = chartPoints(in: proxy.size)

            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.quaternary.opacity(0.35))

                if normalizedPoints.count >= 2 {
                    Path { path in
                        path.move(to: normalizedPoints[0].expected)
                        for point in normalizedPoints.dropFirst() {
                            path.addLine(to: point.expected)
                        }
                    }
                    .stroke(style: StrokeStyle(lineWidth: 2, dash: [5, 4]))
                    .foregroundStyle(.secondary)

                    Path { path in
                        path.move(to: normalizedPoints[0].actual)
                        for point in normalizedPoints.dropFirst() {
                            path.addLine(to: point.actual)
                        }
                    }
                    .stroke(lineWidth: 3)
                    .foregroundStyle(Color.accentColor)
                } else {
                    Text("Pace data will appear as the month fills in.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func chartPoints(in size: CGSize) -> [(actual: CGPoint, expected: CGPoint)] {
        guard points.isEmpty == false else {
            return []
        }

        let actualValues = points.map { NSDecimalNumber(decimal: $0.actualSpend).doubleValue }
        let expectedValues = points.map { NSDecimalNumber(decimal: $0.expectedSpend).doubleValue }
        let allValues = actualValues + expectedValues
        let maxValue = max(allValues.max() ?? 1, 1)
        let width = max(size.width, 1)
        let height = max(size.height, 1)
        let minDay = points.map(\.day).min() ?? 1
        let maxDay = points.map(\.day).max() ?? minDay
        let daySpan = max(maxDay - minDay, 1)

        return points.map { point in
            let x = CGFloat(point.day - minDay) / CGFloat(daySpan) * width
            let actualY = height - (CGFloat(NSDecimalNumber(decimal: point.actualSpend).doubleValue / maxValue) * (height - 12)) - 6
            let expectedY = height - (CGFloat(NSDecimalNumber(decimal: point.expectedSpend).doubleValue / maxValue) * (height - 12)) - 6
            return (
                actual: CGPoint(x: x, y: actualY),
                expected: CGPoint(x: x, y: expectedY)
            )
        }
    }
}

private enum CurrencyFormatter {
    static let shared: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = Locale.current.currency?.identifier ?? "USD"
        return formatter
    }()
}
