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

    private var shouldShowEmptyState: Bool {
        switch section {
        case .home:
            false
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

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(items) { target in
                TargetProgressRow(target: target, currency: currency)
            }
        }
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
