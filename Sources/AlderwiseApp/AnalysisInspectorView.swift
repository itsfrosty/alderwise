import Application
import Domain
import SwiftUI

struct AnalysisInspectorView: View {
    let snapshot: AnalysisOverviewSnapshot
    let selection: AnalysisOverviewSelection?
    let onShowTransactions: (TransactionLedgerFilter) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let selection {
                selectedContent(selection)
            } else {
                noSelectionContent
            }
            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(minWidth: 280, idealWidth: 320, maxWidth: 360, maxHeight: .infinity, alignment: .topLeading)
        .background(.thinMaterial)
    }

    private var noSelectionContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Inspector")
                .font(.headline)
            Text("Select a driver, recurring series, or projected insight to inspect its evidence and drill into matching transactions.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func selectedContent(_ selection: AnalysisOverviewSelection) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Inspector")
                .font(.headline)

            Text(selection.title)
                .font(.title3.weight(.semibold))

            Text(selectionSummary(selection))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                Text("Evidence")
                    .font(.subheadline.weight(.semibold))
                Text(evidenceSummary(selection.evidence))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            Button {
                onShowTransactions(snapshot.transactionFilter(for: selection))
            } label: {
                Label("Show Transactions", systemImage: "list.bullet.rectangle")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func selectionSummary(_ selection: AnalysisOverviewSelection) -> String {
        switch selection {
        case .insight(let insight):
            switch insight.kind {
            case .recurringCharge(let detail):
                return "\(detail.observationCount) observations, \(detail.cadence.rawValue.capitalized) cadence."
            case .spendDriverChange(let detail):
                return "Current \(currency(detail.currentSpend)) vs \(currency(detail.comparisonSpend)), delta \(currency(abs(detail.delta)))."
            }
        case .driver(let row):
            return "Current \(currency(row.currentSpend)) vs \(currency(row.comparisonSpend)), delta \(currency(abs(row.delta)))."
        case .recurring(let row):
            return "\(row.detail.observationCount) observations, \(row.detail.cadence.rawValue.capitalized) cadence."
        }
    }

    private func evidenceSummary(_ evidence: InsightEvidence) -> String {
        let formatter = DateIntervalFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        let intervalText = formatter.string(from: evidence.resolvedInterval.start, to: evidence.resolvedInterval.end)
        return "\(intervalText) • \(evidence.reconciliationRuleLabel)"
    }

    private func currency(_ amount: Decimal) -> String {
        CurrencyFormatter.shared.string(from: NSDecimalNumber(decimal: amount)) ?? "\(amount)"
    }
}

private extension InsightEvidence {
    var reconciliationRuleLabel: String {
        switch reconciliationRule {
        case .exactTransactionSum:
            "Exact transaction sum"
        case .recurringObservationSet:
            "Recurring observation set"
        }
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
