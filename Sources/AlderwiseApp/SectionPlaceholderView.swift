import Application
import Domain
import SwiftUI

struct SectionPlaceholderView: View {
    let section: AppSection
    let snapshot: WorkspaceSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(section.title)
                .font(.largeTitle.bold())

            if shouldShowEmptyState {
                ContentUnavailableView(
                    section.emptyStateTitle,
                    systemImage: section.systemImage,
                    description: Text(section.emptyStateMessage)
                )
            }

            if section == .accounts, !snapshot.accounts.isEmpty {
                accountList
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

    private var shouldShowEmptyState: Bool {
        switch section {
        case .home:
            false
        case .accounts:
            snapshot.accounts.isEmpty
        case .transactions, .review, .targets, .settings:
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
