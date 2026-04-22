import Application
import Domain
import SwiftUI

struct HomeDashboardView: View {
    let snapshot: WorkspaceSnapshot
    let navigate: (HomeDashboardDestination) -> Void

    @EnvironmentObject private var model: WorkspaceShellModel

    private var dashboard: HomeDashboardSnapshot? {
        snapshot.homeDashboard
    }

    private var isEmptyWorkspace: Bool {
        dashboard?.isEmptyWorkspace ?? (snapshot.summary.transactionCount == 0)
    }

    private var summaryCards: [HomeDashboardSummaryCard] {
        dashboard?.summaryCards ?? []
    }

    private var actions: [HomeDashboardAction] {
        dashboard?.actions ?? []
    }

    private var targetRows: [HomeDashboardTargetRow] {
        dashboard?.targetRows ?? []
    }

    private var driverRows: [HomeDashboardDriverRow] {
        dashboard?.driverRows ?? []
    }

    private var hasActiveTargets: Bool {
        targetRows.isEmpty == false
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if isEmptyWorkspace {
                    emptyWorkspaceState
                } else {
                    HomeDashboardHeroCard(
                        hero: dashboard?.hero,
                        qualifier: dashboard?.reviewQualifier,
                        chart: dashboard?.chart,
                        currency: currency,
                        hasActiveTargets: hasActiveTargets,
                        currentMonthAcceptedSpend: snapshot.monthlyReport.currentMonthAcceptedSpend,
                        expectedPaceSpend: snapshot.monthlyReport.expectedPaceSpend
                    )

                    HomeDashboardSections(
                        hasActiveTargets: hasActiveTargets,
                        actions: actions,
                        summaryCards: summaryCards,
                        targetRows: targetRows,
                        driverRows: driverRows,
                        perform: perform
                    )
                }
            }
            .padding(24)
        }
        .navigationTitle("Home")
    }

    private var emptyWorkspaceState: some View {
        ContentUnavailableView {
            Label("Build your local spending workspace", systemImage: "house")
        } description: {
            Text("Start with Import CSV or create an account to prepare your first import.")
        } actions: {
            Button {
                model.beginCSVImport()
            } label: {
                Label("Import CSV", systemImage: "square.and.arrow.down")
            }
            .buttonStyle(.borderedProminent)

            Button {
                model.beginAccountCreation()
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
        .frame(maxWidth: .infinity, minHeight: 360)
    }

    private func perform(_ destination: HomeDashboardDestination) {
        switch destination {
        case .review, .targets, .transactions:
            navigate(destination)
        }
    }

    private func currency(_ amount: Decimal) -> String {
        CurrencyFormatter.shared.string(from: NSDecimalNumber(decimal: amount)) ?? "\(amount)"
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
