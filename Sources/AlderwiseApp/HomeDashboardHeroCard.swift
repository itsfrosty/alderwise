import Application
import Domain
import SwiftUI

struct HomeDashboardHeroCard: View {
    let hero: HomeDashboardHero?
    let qualifier: HomeDashboardReviewQualifier?
    let chart: HomeDashboardChart?
    let currency: (Decimal) -> String
    let hasActiveTargets: Bool
    let currentMonthAcceptedSpend: Decimal
    let expectedPaceSpend: Decimal

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            statusLabel

            Text(currency(hero?.amount ?? currentMonthAcceptedSpend))
                .font(.system(size: 38, weight: .semibold))

            Text(heroSubtitle)
                .foregroundStyle(.secondary)

            if let confidenceNote {
                Text(confidenceNote)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let qualifier {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "checklist.unchecked")
                        .foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Accepted-only status")
                            .font(.subheadline.weight(.semibold))
                        Text(qualifier.message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(12)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            if let chart {
                VStack(alignment: .leading, spacing: 10) {
                    PaceMiniChart(points: chart.points)
                        .frame(height: 112)

                    HStack(spacing: 16) {
                        legendChip(title: "Actual", symbol: "line.diagonal", tint: .accentColor)
                        legendChip(title: "Expected", symbol: "ellipsis", tint: .secondary)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var statusLabel: some View {
        Label {
            Text(statusTitle)
                .font(.headline)
        } icon: {
            Image(systemName: statusSymbol)
        }
        .foregroundStyle(heroTint)
    }

    private var heroSubtitle: String {
        if hasActiveTargets == false {
            return "Use the month summary and strongest driver below to decide whether you want a monthly limit."
        }

        let expected = currency(expectedPaceSpend)
        return "Accepted spending is \(statusDescription) against an expected pace of \(expected)."
    }

    private var confidenceNote: String? {
        if hasActiveTargets == false {
            return "Create a monthly limit to compare current spending against pace."
        }
        return "Pace and targets reflect accepted expense activity."
    }

    private var statusTitle: String {
        if hasActiveTargets == false {
            return "No active targets"
        }

        switch hero?.status {
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

    private var statusDescription: String {
        switch hero?.status {
        case .underPace:
            return "under pace"
        case .onPace:
            return "on pace"
        case .overPace:
            return "over pace"
        case nil:
            return "tracking current month spend"
        }
    }

    private var statusSymbol: String {
        if hasActiveTargets == false {
            return "flag.slash"
        }

        switch hero?.status {
        case .underPace:
            return "arrow.down.circle.fill"
        case .onPace:
            return "equal.circle.fill"
        case .overPace:
            return "arrow.up.circle.fill"
        case nil:
            return "chart.line.uptrend.xyaxis.circle.fill"
        }
    }

    private var heroTint: Color {
        switch hero?.status {
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

    private func legendChip(title: String, symbol: String, tint: Color) -> some View {
        Label(title, systemImage: symbol)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.thinMaterial, in: Capsule())
            .foregroundStyle(tint)
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
