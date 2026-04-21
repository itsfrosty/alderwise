import Application
import Domain
import SwiftUI

struct SectionPlaceholderView: View {
    let section: AppSection
    let snapshot: WorkspaceSnapshot
    @EnvironmentObject private var model: WorkspaceShellModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(section.title)
                .font(.largeTitle.bold())

            if section == .home {
                summaryGrid
                monthlySnapshot
                firstRunActions
            }

            if section == .targets, snapshot.monthlyReport.targets.isEmpty {
                targetsEmptyState
            } else if shouldShowEmptyState {
                ContentUnavailableView(
                    section.emptyStateTitle,
                    systemImage: section.systemImage,
                    description: Text(section.emptyStateMessage)
                )
            }

            if section == .accounts, !snapshot.accounts.isEmpty {
                accountList
            }

            if section == .targets, !snapshot.monthlyReport.targets.isEmpty {
                targetList
            }

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var summaryGrid: some View {
        HStack(spacing: 16) {
            SummaryCard(title: "Accounts", value: "\(snapshot.summary.accountCount)")
            SummaryCard(title: "Transactions", value: "\(snapshot.summary.transactionCount)")
            SummaryCard(title: "To Review", value: "\(snapshot.summary.reviewCount)")
            SummaryCard(title: "Targets", value: "\(snapshot.summary.targetCount)")
        }
    }

    private var monthlySnapshot: some View {
        HStack(spacing: 16) {
            SummaryCard(
                title: "This Month",
                value: currency(snapshot.monthlyReport.currentMonthAcceptedSpend),
                detail: "Accepted expenses"
            )
            SummaryCard(
                title: "Last Month",
                value: currency(snapshot.monthlyReport.lastMonthAcceptedSpend),
                detail: "Same accepted-spend basis"
            )
            SummaryCard(
                title: "Remaining Targets",
                value: currency(snapshot.monthlyReport.targets.reduce(Decimal(0)) { $0 + max($1.remaining, Decimal(0)) }),
                detail: "\(snapshot.monthlyReport.targets.count) active"
            )
        }
    }

    private var accountList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Accounts in Workspace")
                .font(.headline)

            ForEach(snapshot.accounts) { account in
                HStack {
                    Text(account.name)
                    Spacer()
                    Text(account.kind.title)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var targetList: some View {
        TargetProgressList(items: snapshot.monthlyReport.targets, currency: currency)
    }

    private var targetsEmptyState: some View {
        ContentUnavailableView {
            Label("No Targets", systemImage: section.systemImage)
        } description: {
            Text("Create a monthly category target to track accepted spending.")
        } actions: {
            Button {
                model.beginTargetCreation()
            } label: {
                Label("Create Target", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    @ViewBuilder
    private var firstRunActions: some View {
        if snapshot.summary.accountCount == 0 {
            HStack(spacing: 12) {
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
        }
    }

    private var shouldShowEmptyState: Bool {
        switch section {
        case .home:
            snapshot.summary.transactionCount == 0
        case .targets:
            snapshot.monthlyReport.targets.isEmpty
        case .accounts:
            snapshot.accounts.isEmpty
        case .transactions, .review, .settings:
            true
        }
    }

    private func currency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = Locale.current.currency?.identifier ?? "USD"
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "\(amount)"
    }
}

private struct SummaryCard: View {
    let title: String
    let value: String
    var detail: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(value)
                .font(.system(size: 28, weight: .semibold))
            if let detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct TargetProgressList: View {
    let items: [TargetProgress]
    let currency: (Decimal) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Target Progress")
                .font(.headline)

            TargetProgressRows(items: items, currency: currency)
        }
    }
}

private struct TargetProgressRows: View {
    let items: [TargetProgress]
    let currency: (Decimal) -> String

    var body: AnyView {
        guard let target = items.first else {
            return AnyView(EmptyView())
        }

        return AnyView(
            VStack(alignment: .leading, spacing: 0) {
                TargetProgressRow(target: target, currency: currency)
                TargetProgressRows(items: Swift.Array(items.dropFirst()), currency: currency)
            }
        )
    }
}

private struct TargetProgressRow: View {
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
        .padding(.vertical, 6)
    }
}
