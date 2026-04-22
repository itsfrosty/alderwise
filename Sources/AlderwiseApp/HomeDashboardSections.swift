import Application
import Domain
import SwiftUI

struct HomeDashboardSections: View {
    let summaryCards: [HomeDashboardSummaryCard]
    let targetRows: [HomeDashboardTargetRow]
    let driverRows: [HomeDashboardDriverRow]
    let createTargetAction: HomeDashboardAction?
    let currentMonthAcceptedSpend: Decimal
    let lastMonthAcceptedSpend: Decimal
    let navigate: (HomeDashboardDestination) -> Void
    let perform: (HomeDashboardDestination) -> Void
    let currency: (Decimal) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if targetRows.isEmpty {
                noTargetsSection
            } else {
                targetsSection
                driversSection
            }
        }
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
                    value: currentMonthCard?.value ?? currency(currentMonthAcceptedSpend),
                    detail: currentMonthCard?.detail ?? "Accepted expenses"
                )
                metricCard(
                    title: lastMonthCard?.title ?? "Last Month",
                    value: lastMonthCard?.value ?? currency(lastMonthAcceptedSpend),
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

            if let createTargetAction {
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
        .frame(maxWidth: .infinity, alignment: .leading)
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
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var lastMonthChangeText: String {
        let delta = currentMonthAcceptedSpend - lastMonthAcceptedSpend
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
