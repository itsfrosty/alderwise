import Application
import Domain
import SwiftUI

struct HomeDashboardHeroCard: View {
    let hero: HomeDashboardHero?
    let qualifier: HomeDashboardReviewQualifier?
    let chart: HomeDashboardChart?
    let primaryAction: HomeDashboardAction?
    let actionLabel: (HomeDashboardAction) -> String
    let perform: (HomeDashboardDestination) -> Void
    let currency: (Decimal) -> String
    let hasActiveTargets: Bool
    let currentMonthAcceptedSpend: Decimal
    let lastMonthValue: String
    let expectedPaceSpend: Decimal

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(heroHeadline)
                .font(.headline)
                .foregroundStyle(heroTint)

            Text(currency(hero?.amount ?? currentMonthAcceptedSpend))
                .font(.system(size: 34, weight: .semibold))

            Text(heroSubtitle)
                .foregroundStyle(.secondary)

            if let confidenceNote {
                Text(confidenceNote)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let chart {
                PaceMiniChart(points: chart.points)
                    .frame(height: 92)
            }

            if let primaryAction {
                Button {
                    perform(primaryAction.destination)
                } label: {
                    Label(actionLabel(primaryAction), systemImage: destinationSymbol(for: primaryAction.destination))
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var heroHeadline: String {
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

    private var heroSubtitle: String {
        if hasActiveTargets == false {
            return "Last month closed at \(lastMonthValue) on the same accepted-spend basis."
        }

        let expected = currency(expectedPaceSpend)
        let qualifierSuffix = qualifier.map { " \($0.message)" } ?? ""
        return "Expected pace is \(expected) for this point in the month.\(qualifierSuffix)"
    }

    private var confidenceNote: String? {
        if hasActiveTargets == false {
            return "Create a monthly limit to compare current spending against pace."
        }
        return qualifier == nil ? "Based on accepted expense activity only." : nil
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

    private func destinationSymbol(for destination: HomeDashboardDestination) -> String {
        switch destination {
        case .review:
            return AppSection.review.systemImage
        case .targets:
            return AppSection.targets.systemImage
        case .transactions:
            return AppSection.transactions.systemImage
        }
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
