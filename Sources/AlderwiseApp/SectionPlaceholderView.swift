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
                firstRunActions
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

    @ViewBuilder
    private var firstRunActions: some View {
        if snapshot.summary.accountCount == 0 {
            HStack(spacing: 12) {
                Button("Import CSV") {}
                    .buttonStyle(.borderedProminent)

                Button("Create Account") {
                    model.isPresentingAccountSheet = true
                }
                .buttonStyle(.bordered)

                Button("Add Sample Data") {
                    model.addSampleAccount()
                }
                .buttonStyle(.bordered)
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
