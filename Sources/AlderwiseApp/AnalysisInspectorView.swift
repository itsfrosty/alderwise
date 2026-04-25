import Application
import Domain
import SwiftUI

protocol AnalysisInspectorPresentable {
    var title: String { get }
    var summaryText: String { get }
    var evidence: InsightEvidence { get }
}

struct AnalysisInspectorView<Selection: AnalysisInspectorPresentable, Actions: View>: View {
    let selection: Selection?
    let noSelectionDescription: String
    let onShowTransactions: ((Selection) -> Void)?
    @ViewBuilder let actions: (Selection) -> Actions

    static func showsPlaceholder(for selection: Selection?) -> Bool {
        selection == nil
    }

    init(
        selection: Selection?,
        noSelectionDescription: String,
        onShowTransactions: ((Selection) -> Void)? = nil,
        @ViewBuilder actions: @escaping (Selection) -> Actions
    ) {
        self.selection = selection
        self.noSelectionDescription = noSelectionDescription
        self.onShowTransactions = onShowTransactions
        self.actions = actions
    }

    init(
        selection: Selection?,
        noSelectionDescription: String,
        onShowTransactions: ((Selection) -> Void)? = nil
    ) where Actions == EmptyView {
        self.init(
            selection: selection,
            noSelectionDescription: noSelectionDescription,
            onShowTransactions: onShowTransactions
        ) { _ in
            EmptyView()
        }
    }

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
        .frame(
            minWidth: WorkspaceLayout.analysisInspectorMinimumWidth,
            idealWidth: WorkspaceLayout.analysisInspectorIdealWidth,
            maxWidth: WorkspaceLayout.analysisInspectorMaximumWidth,
            maxHeight: .infinity,
            alignment: .topLeading
        )
        .background(.thinMaterial)
    }

    private var noSelectionContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Inspector")
                .font(.headline)
            Text(noSelectionDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func selectedContent(_ selection: Selection) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Inspector")
                .font(.headline)

            Text(selection.title)
                .font(.title3.weight(.semibold))

            Text(selection.summaryText)
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

            if let onShowTransactions {
                Button {
                    onShowTransactions(selection)
                } label: {
                    Label("Show Transactions", systemImage: "list.bullet.rectangle")
                }
                .buttonStyle(.borderedProminent)
            }

            actions(selection)
        }
    }

    private func evidenceSummary(_ evidence: InsightEvidence) -> String {
        let formatter = DateIntervalFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        let intervalText = formatter.string(from: evidence.resolvedInterval.start, to: evidence.resolvedInterval.end)
        return "\(intervalText) • \(evidence.reconciliationRuleLabel)"
    }
}

extension AnalysisOverviewSelection: AnalysisInspectorPresentable {
    var title: String {
        switch self {
        case .insight(let insight):
            switch insight.kind {
            case .recurringCharge(let detail):
                detail.normalizedMerchantName.localizedCapitalized
            case .spendDriverChange(let detail):
                detail.title
            }
        case .driver(let row):
            row.title
        case .recurring(let row):
            row.detail.normalizedMerchantName.localizedCapitalized
        }
    }

    var summaryText: String {
        switch self {
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
}

extension AnalysisCategoriesSelection: AnalysisInspectorPresentable {
    var title: String {
        switch self {
        case .row(let row):
            row.title
        }
    }

    var summaryText: String {
        switch self {
        case .row(let row):
            return "Current \(currency(row.currentSpend)) vs \(currency(row.comparisonSpend)), delta \(currency(abs(row.delta)))."
        }
    }
}

extension AnalysisMerchantsSelection: AnalysisInspectorPresentable {
    var title: String {
        switch self {
        case .merchant(let row):
            row.title.localizedCapitalized
        case .recurring(let row):
            row.detail.normalizedMerchantName.localizedCapitalized
        }
    }

    var summaryText: String {
        switch self {
        case .merchant(let row):
            return "Current \(currency(row.currentSpend)) vs \(currency(row.comparisonSpend)), delta \(currency(abs(row.delta)))."
        case .recurring(let row):
            return "\(row.detail.observationCount) observations, \(row.detail.cadence.rawValue.capitalized) cadence."
        }
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

private func currency(_ amount: Decimal) -> String {
    CurrencyFormatter.shared.string(from: NSDecimalNumber(decimal: amount)) ?? "\(amount)"
}

private enum CurrencyFormatter {
    static let shared: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = Locale.current.currency?.identifier ?? "USD"
        return formatter
    }()
}
