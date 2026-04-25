import Application
import Domain
import SwiftUI

struct AnalysisOverviewView: View {
    let snapshot: AnalysisOverviewSnapshot
    @Binding var selection: AnalysisOverviewSelection?
    let onShowTransactions: (TransactionLedgerFilter) -> Void
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    spendTrendCard
                    paceCard
                    projectedInsightsSection
                    driversSection
                    recurringSection
                }
                .padding(24)
            }

            Divider()

            AnalysisInspectorView(
                snapshot: snapshot,
                selection: selection,
                onShowTransactions: onShowTransactions
            )
        }
        .frame(minWidth: 960, minHeight: 620)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") {
                    onClose()
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Overview Preview")
                    .font(.largeTitle.weight(.semibold))
                Text("Incubated analysis view for spend trend, pace, drivers, and recurring commitments.")
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var spendTrendCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Spend Trend")
                .font(.headline)
            Text(currency(snapshot.report.currentSpend))
                .font(.system(size: 34, weight: .semibold))
            if let comparisonSpend = snapshot.report.comparisonSpend {
                Text("Previous comparison: \(currency(comparisonSpend))")
                    .foregroundStyle(.secondary)
            }
        }
        .cardStyle()
    }

    private var paceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Current-Month Pace")
                .font(.headline)
            Text("Visible spend \(currency(snapshot.monthlyReport.currentMonthAcceptedSpend)) against expected pace \(currency(snapshot.monthlyReport.expectedPaceSpend)).")
                .foregroundStyle(.secondary)

            OverviewPaceMiniChart(points: snapshot.monthlyReport.paceSeries)
                .frame(height: 120)
        }
        .cardStyle()
    }

    @ViewBuilder
    private var projectedInsightsSection: some View {
        if snapshot.projectedInsights.isEmpty == false {
            VStack(alignment: .leading, spacing: 12) {
                Text("Highlights")
                    .font(.headline)
                ForEach(Array(snapshot.projectedInsights.enumerated()), id: \.offset) { _, insight in
                    Button {
                        selection = .insight(insight)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(insightTitle(insight))
                                    .font(.subheadline.weight(.semibold))
                                Text(insightSubtitle(insight))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(12)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
            .cardStyle()
        }
    }

    private var driversSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Drivers")
                .font(.headline)
            if snapshot.report.drivers.isEmpty {
                Text("No material drivers were detected for the active context.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(snapshot.report.drivers.enumerated()), id: \.offset) { _, driver in
                    Button {
                        selection = .driver(driver)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(driver.title)
                                    .font(.subheadline.weight(.semibold))
                                Text("Delta \(currency(abs(driver.delta)))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(currency(driver.currentSpend))
                                .font(.subheadline.monospacedDigit())
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 6)
                }
            }
        }
        .cardStyle()
    }

    private var recurringSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recurring Summary")
                .font(.headline)
            if snapshot.report.recurring.isEmpty {
                Text("No recurring commitments were confidently detected in this scope.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(snapshot.report.recurring.prefix(3).enumerated()), id: \.offset) { _, recurring in
                    Button {
                        selection = .recurring(recurring)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(recurring.detail.normalizedMerchantName.localizedCapitalized)
                                    .font(.subheadline.weight(.semibold))
                                Text("\(recurring.detail.cadence.rawValue.capitalized) • \(recurring.detail.observationCount) observations")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(currency(recurring.detail.amountRange.maximum))
                                .font(.subheadline.monospacedDigit())
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 6)
                }
            }
        }
        .cardStyle()
    }

    private func insightTitle(_ insight: WorkspaceInsight) -> String {
        switch insight.kind {
        case .recurringCharge(let detail):
            "\(detail.normalizedMerchantName.localizedCapitalized) may be recurring"
        case .spendDriverChange(let detail):
            "\(detail.title) changed materially"
        }
    }

    private func insightSubtitle(_ insight: WorkspaceInsight) -> String {
        switch insight.kind {
        case .recurringCharge(let detail):
            "\(detail.observationCount) observations"
        case .spendDriverChange(let detail):
            "Delta \(currency(abs(detail.delta)))"
        }
    }

    private func currency(_ amount: Decimal) -> String {
        CurrencyFormatter.shared.string(from: NSDecimalNumber(decimal: amount)) ?? "\(amount)"
    }
}

private extension View {
    func cardStyle() -> some View {
        self
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
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

private struct OverviewPaceMiniChart: View {
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
