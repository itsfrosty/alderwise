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

            if section == .home {
                summaryGrid
            }

            ContentUnavailableView(
                section.emptyStateTitle,
                systemImage: section.systemImage,
                description: Text(section.emptyStateMessage)
            )

            if section == .accounts, !snapshot.accounts.isEmpty {
                accountList
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
}

private struct SummaryCard: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(value)
                .font(.system(size: 28, weight: .semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
