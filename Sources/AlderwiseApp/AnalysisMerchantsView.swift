import Application
import Domain
import SwiftUI

struct AnalysisMerchantsView: View {
    let snapshot: AnalysisMerchantsSnapshot
    @Binding var selection: AnalysisMerchantsSelection?
    var showsInspector: Bool = true
    let onShowTransactions: (TransactionLedgerFilter) -> Void
    let onShowRules: (String) -> Void

    var body: some View {
        Group {
            if showsInspector {
                HStack(spacing: 0) {
                    content

                    Divider()

                    AnalysisInspectorView(
                        selection: selection,
                        noSelectionDescription: "Select a merchant or recurring series to inspect its evidence, open matching transactions, or hand off to Rules for merchant cleanup."
                    ) { selected in
                        VStack(alignment: .leading, spacing: 10) {
                            Button {
                                onShowTransactions(snapshot.transactionFilter(for: selected))
                            } label: {
                                Label("Show Transactions", systemImage: "list.bullet.rectangle")
                            }
                            .buttonStyle(.borderedProminent)

                            if let merchantName = merchantName(for: selected) {
                                Button {
                                    onShowRules(merchantName)
                                } label: {
                                    Label("Open Rules", systemImage: "slider.horizontal.3")
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                }
            } else {
                content
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                merchantsSection
                recurringSection
            }
            .padding(24)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Merchants Preview")
                .font(.largeTitle.weight(.semibold))
            Text("Inspect the merchants and recurring commitments behind visible spend, then drill into transactions or hand off to Rules for cleanup.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var merchantsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Top Merchants")
                .font(.headline)

            if snapshot.report.merchants.isEmpty {
                Text("No merchant activity was detected for the active context.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(snapshot.report.merchants.enumerated()), id: \.offset) { _, merchant in
                    Button {
                        selection = .merchant(merchant)
                    } label: {
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(merchant.title.localizedCapitalized)
                                    .font(.subheadline.weight(.semibold))
                                Text("Key \(merchant.key.normalizedName)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 4) {
                                Text(currency(merchant.currentSpend))
                                    .font(.subheadline.monospacedDigit())
                                Text("Delta \(currency(abs(merchant.delta)))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .analysisCardStyle()
    }

    private var recurringSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recurring Commitments")
                .font(.headline)

            if snapshot.report.recurring.isEmpty {
                Text("No recurring merchant patterns were confidently detected in this scope.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(snapshot.report.recurring.enumerated()), id: \.offset) { _, recurring in
                    Button {
                        selection = .recurring(recurring)
                    } label: {
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(recurring.detail.normalizedMerchantName.localizedCapitalized)
                                    .font(.subheadline.weight(.semibold))
                                Text("\(recurring.detail.cadence.rawValue.capitalized) • \(recurring.detail.observationCount) observations")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Text(currency(recurring.detail.amountRange.maximum))
                                .font(.subheadline.monospacedDigit())
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .analysisCardStyle()
    }

    private func merchantName(for selection: AnalysisMerchantsSelection) -> String? {
        switch selection {
        case .merchant(let row):
            row.key.normalizedName
        case .recurring(let row):
            row.detail.normalizedMerchantName
        }
    }

    private func currency(_ amount: Decimal) -> String {
        AnalysisCurrencyFormatter.shared.string(from: NSDecimalNumber(decimal: amount)) ?? "\(amount)"
    }
}

private extension View {
    func analysisCardStyle() -> some View {
        frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private enum AnalysisCurrencyFormatter {
    static let shared: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = Locale.current.currency?.identifier ?? "USD"
        return formatter
    }()
}
