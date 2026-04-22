import Application
import Domain
import SwiftUI

struct HomeDashboardSections: View {
    let hasActiveTargets: Bool
    let actions: [HomeDashboardAction]
    let summaryCards: [HomeDashboardSummaryCard]
    let targetRows: [HomeDashboardTargetRow]
    let driverRows: [HomeDashboardDriverRow]
    let perform: (HomeDashboardDestination) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            nextActionsSection
            summarySection

            if hasActiveTargets == false {
                noTargetsSection
            } else {
                targetsSection
                driversSection
            }
        }
    }

    private var nextActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Next Actions")
                .font(.headline)

            if actions.isEmpty {
                Text("No immediate workflow actions right now.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(actions.enumerated()), id: \.offset) { offset, action in
                        Button {
                            perform(action.destination)
                        } label: {
                            actionRow(action, isPrimary: offset == 0 && action.prominence == .primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Summary")
                .font(.headline)

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 16) {
                    ForEach(summaryCards) { card in
                        summaryCard(for: card)
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    ForEach(summaryCards) { card in
                        summaryCard(for: card)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var noTargetsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Strongest Driver")
                .font(.headline)

            Text("Track what changed most month over month before you decide whether to add a monthly limit.")
                .foregroundStyle(.secondary)

            if driverRows.isEmpty == false {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(driverRows.prefix(1))) { driver in
                        DriverRow(driver: driver, action: {
                            perform(driver.destination)
                        })
                    }
                }
                .padding(16)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                Text("More history needed for month-over-month changes")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
                            perform(target.destination)
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
                            perform(driver.destination)
                        })
                    }
                }
                .padding(16)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func summaryCard(for card: HomeDashboardSummaryCard) -> some View {
        let cardBody = VStack(alignment: .leading, spacing: 8) {
            Text(card.title)
                .font(.headline)
            Text(card.value)
                .font(.system(size: 28, weight: .semibold))
            Text(card.detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

        if let destination = card.destination {
            Button {
                perform(destination)
            } label: {
                cardBody
            }
            .buttonStyle(.plain)
        } else {
            cardBody
        }
    }

    private func actionRow(_ action: HomeDashboardAction, isPrimary: Bool) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: actionSymbol(for: action))
                .font(.title3)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(action.title)
                    .font(.headline)
                Text(actionSubtitle(for: action))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "arrow.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            isPrimary ? Color.accentColor.opacity(0.12) : Color.clear,
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(isPrimary ? Color.accentColor.opacity(0.35) : Color.secondary.opacity(0.12))
        }
    }

    private func actionSubtitle(for action: HomeDashboardAction) -> String {
        switch action.kind {
        case .reviewBacklog(let count):
            return "\(count) item(s) still need review before month status is final."
        case .pressuredTarget:
            return "Open the most pressured limit and review its progress."
        case .spendDriver:
            return "Inspect the category or group driving month-over-month change."
        case .createFirstTarget:
            return "Set up your first monthly limit from existing accepted spend."
        }
    }

    private func actionSymbol(for action: HomeDashboardAction) -> String {
        switch action.destination {
        case .review:
            return AppSection.review.systemImage
        case .targets:
            return AppSection.targets.systemImage
        case .transactions:
            return AppSection.transactions.systemImage
        }
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

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
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
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
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
