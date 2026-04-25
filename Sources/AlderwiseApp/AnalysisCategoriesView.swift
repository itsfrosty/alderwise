import Application
import Domain
import SwiftUI

struct AnalysisCategoriesView: View {
    let snapshot: AnalysisCategoriesSnapshot
    @Binding var selection: AnalysisCategoriesSelection?
    var inspectorPresentation: AnalysisInspectorPresentation = .persistent
    var onDismissTransientInspector: (() -> Void)?
    let onShowTransactions: (TransactionLedgerFilter) -> Void
    let onShowTarget: (UUID) -> Void

    var body: some View {
        Group {
            if inspectorPresentation == .persistent {
                HStack(spacing: 0) {
                    content

                    Divider()

                    inspectorView
                }
            } else {
                content
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .sheet(isPresented: transientInspectorBinding) {
            inspectorView
        }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                contributionSection
                targetAlignmentSection
            }
            .padding(24)
        }
    }

    private var transientInspectorBinding: Binding<Bool> {
        Binding(
            get: { inspectorPresentation == .transient },
            set: { isPresented in
                if isPresented == false {
                    onDismissTransientInspector?()
                }
            }
        )
    }

    private var inspectorView: some View {
        AnalysisInspectorView(
            selection: selection,
            noSelectionDescription: "Select a category or group to inspect its evidence, open matching transactions, or jump into its target if one exists.",
            onShowTransactions: { selected in
                onShowTransactions(snapshot.transactionFilter(for: selected))
            }
        ) { selected in
            if let targetProgress = snapshot.targetProgress(for: selected) {
                Button {
                    onShowTarget(targetProgress.id)
                } label: {
                    Label("Open Target", systemImage: "target")
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Categories Preview")
                .font(.largeTitle.weight(.semibold))
            Text("Review the category groups driving visible spend, then drill into transactions or hand off to Targets for monthly limit details.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var contributionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Contribution")
                .font(.headline)

            if snapshot.report.rows.isEmpty {
                Text("No category or group contributions were detected for the active context.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(snapshot.report.rows.enumerated()), id: \.offset) { _, row in
                    Button {
                        selection = .row(row)
                    } label: {
                        HStack(alignment: .center, spacing: 16) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(row.title)
                                    .font(.subheadline.weight(.semibold))
                                Text(changeSummary(row))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if hasTarget(for: row) {
                                Label("Target", systemImage: "target")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color.accentColor)
                            }

                            Text(currency(row.currentSpend))
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

    private var targetAlignmentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Target Alignment")
                .font(.headline)

            if snapshot.targetProgress.isEmpty {
                Text("No monthly targets exist for the current category scopes.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(snapshot.targetProgress) { target in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(target.name)
                                .font(.subheadline.weight(.semibold))
                            Text(targetScopeLabel(target.scope))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 4) {
                            Text(currency(target.spent))
                                .font(.subheadline.monospacedDigit())
                            Text("of \(currency(target.monthlyLimit))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .analysisCardStyle()
    }

    private func hasTarget(for row: AnalysisSpendRow) -> Bool {
        snapshot.targetProgress.contains { target in
            switch (target.scope, row.scope) {
            case (.category(let lhs), .category(let rhs)):
                return lhs == rhs
            case (.categoryGroup(let lhs), .categoryGroup(let rhs)):
                return lhs == rhs
            default:
                return false
            }
        }
    }

    private func changeSummary(_ row: AnalysisSpendRow) -> String {
        "Current \(currency(row.currentSpend)) vs \(currency(row.comparisonSpend)) • Delta \(currency(abs(row.delta)))"
    }

    private func targetScopeLabel(_ scope: TargetScope) -> String {
        switch scope {
        case .category:
            "Category target"
        case .categoryGroup:
            "Group target"
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
