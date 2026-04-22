import Application
import Domain
import SwiftUI

struct HomeDashboardView: View {
    let snapshot: WorkspaceSnapshot
    let navigate: (HomeDashboardDestination) -> Void

    @EnvironmentObject private var model: WorkspaceShellModel

    private var dashboard: HomeDashboardSnapshot? {
        snapshot.homeDashboard
    }

    private var isEmptyWorkspace: Bool {
        dashboard?.isEmptyWorkspace ?? (snapshot.summary.transactionCount == 0)
    }

    private var summaryCards: [HomeDashboardSummaryCard] {
        dashboard?.summaryCards ?? []
    }

    private var targetRows: [HomeDashboardTargetRow] {
        dashboard?.targetRows ?? []
    }

    private var driverRows: [HomeDashboardDriverRow] {
        dashboard?.driverRows ?? []
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if isEmptyWorkspace {
                    emptyWorkspaceState
                } else {
                    heroCard

                    if targetRows.isEmpty {
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
                model.beginAccountCreation()
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

            Text(currency(dashboard?.hero?.amount ?? snapshot.monthlyReport.currentMonthAcceptedSpend))
                .font(.system(size: 34, weight: .semibold))

            Text(heroSubtitle)
                .foregroundStyle(.secondary)

            if let confidenceNote {
                Text(confidenceNote)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let chart = dashboard?.chart {
                PaceMiniChart(points: chart.points)
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

            Text("Compare this month with last month, then add a monthly limit when you’re ready to track pace.")
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                let currentMonthCard = summaryCards.first { $0.id == "current-month" }
                let lastMonthCard = summaryCards.first { $0.id == "last-month" }
                metricCard(
                    title: currentMonthCard?.title ?? "This Month",
                    value: currentMonthCard?.value ?? currency(snapshot.monthlyReport.currentMonthAcceptedSpend),
                    detail: currentMonthCard?.detail ?? "Accepted expenses"
                )
                metricCard(
                    title: lastMonthCard?.title ?? "Last Month",
                    value: lastMonthCard?.value ?? currency(snapshot.monthlyReport.lastMonthAcceptedSpend),
                    detail: lastMonthCard?.detail ?? lastMonthChangeText
                )
            }

            if driverRows.isEmpty == false {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Top Drivers")
                        .font(.headline)

                    ForEach(driverRows) { driver in
                        DriverRow(driver: driver, action: {
                            navigate(driver.destination)
                        })
                    }
                }
            } else {
                Text("More history needed for month-over-month changes")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let createTargetAction = dashboard?.actions.first(where: { $0.kind == .createFirstTarget }) {
                Button {
                    perform(createTargetAction.destination)
                } label: {
                    Label("Create Monthly Limit", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var targetsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tracked Limits")
                .font(.headline)

            if targetRows.isEmpty {
                Text("Create a monthly limit to track accepted spending.")
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(targetRows) { target in
                        Button {
                            navigate(target.destination)
                        } label: {
                            TargetRow(target: target)
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
                        DriverRow(driver: driver, action: {
                            navigate(driver.destination)
                        })
                    }
                }
                .padding(16)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }

    private var heroHeadline: String {
        if targetRows.isEmpty {
            return "No active targets"
        }

        switch dashboard?.hero?.status {
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
        if targetRows.isEmpty {
            let lastMonthValue = summaryCards.first { $0.id == "last-month" }?.value ?? currency(snapshot.monthlyReport.lastMonthAcceptedSpend)
            return "Last month closed at \(lastMonthValue) on the same accepted-spend basis."
        }

        let expected = currency(snapshot.monthlyReport.expectedPaceSpend)
        let qualifierSuffix = dashboard?.reviewQualifier.map { " \($0.message)" } ?? ""
        return "Expected pace is \(expected) for this point in the month.\(qualifierSuffix)"
    }

    private var confidenceNote: String? {
        if targetRows.isEmpty {
            return "Create a monthly limit to compare current spending against pace."
        }
        return dashboard?.reviewQualifier == nil ? "Based on accepted expense activity only." : nil
    }

    private var heroTint: Color {
        switch dashboard?.hero?.status {
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
        case .review, .targets, .transactions:
            navigate(destination)
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

    private func currency(_ amount: Decimal) -> String {
        CurrencyFormatter.shared.string(from: NSDecimalNumber(decimal: amount)) ?? "\(amount)"
    }
}

private struct DriverRow: View {
    let driver: HomeDashboardDriverRow
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(driver.title)
                        .font(.headline)
                    Text("Last month: \(driver.comparisonSpendText)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(driver.currentSpendText)
                        .font(.headline)
                    Text(driver.deltaText)
                        .font(.caption)
                        .foregroundStyle(driver.delta > 0 ? Color.orange : Color.secondary)
                }
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct TargetRow: View {
    let target: HomeDashboardTargetRow

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(target.name)
                    .font(.headline)
                Spacer()
                Text(target.spentText)
                    .foregroundStyle(.secondary)
            }
            ProgressView(
                value: min(NSDecimalNumber(decimal: target.spent).doubleValue, NSDecimalNumber(decimal: target.monthlyLimit).doubleValue),
                total: max(NSDecimalNumber(decimal: target.monthlyLimit).doubleValue, 0.01)
            )
            Text(target.remainingText)
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
