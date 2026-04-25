import Application
import Domain
import SwiftUI

struct AnalysisCategoriesView: View {
    let snapshot: AnalysisCategoriesSnapshot
    @Binding var sort: AnalysisScreenState.CategoriesState.Sort
    @Binding var selection: AnalysisCategoriesSelection?
    var inspectorPresentation: AnalysisInspectorPresentation = .persistent
    var onDismissTransientInspector: (() -> Void)?
    let onShowTransactions: (TransactionLedgerFilter) -> Void
    let onShowTarget: (UUID) -> Void

    private var pageState: AnalysisScreenState.CategoriesState {
        AnalysisScreenState.CategoriesState(sort: sort, selection: selection)
    }

    private var sortedRows: [AnalysisSpendRow] {
        pageState.sortedRows(in: snapshot)
    }

    private var selectedTargetProgress: TargetProgress? {
        pageState.selectedTargetProgress(in: snapshot)
    }

    private var trackedTargetCount: Int {
        snapshot.targetProgress.count
    }

    nonisolated static func rowIdentity(for row: AnalysisSpendRow) -> RowIdentity {
        RowIdentity(scope: row.scope)
    }

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
            VStack(alignment: .leading, spacing: AnalysisTheme.SectionSpacing.group) {
                header
                contributionSection
                targetHandoffSection
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
            noSelectionDescription: "Select a category or group contribution to inspect its evidence, open matching transactions, or hand off to its linked target."
        ) { selected in
            VStack(alignment: .leading, spacing: 10) {
                Button {
                    onShowTransactions(snapshot.transactionFilter(for: selected))
                } label: {
                    Label("Show Transactions", systemImage: "list.bullet.rectangle")
                }
                .buttonStyle(.borderedProminent)

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
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: AnalysisTheme.Card.contentSpacing) {
            HStack(alignment: .top, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Categories")
                        .font(.largeTitle.weight(.semibold))
                    Text("Rank the category and group contributions behind the current analysis context, then keep the inspector and target handoff anchored to the row you selected.")
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Sort")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Picker("Sort", selection: $sort) {
                        ForEach(AnalysisScreenState.CategoriesState.Sort.allCases, id: \.self) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 300)
                }
            }

            HStack(spacing: 10) {
                AnalysisCategoriesSummaryBadge(
                    title: "Rows",
                    value: "\(sortedRows.count)",
                    systemImage: "chart.bar.doc.horizontal"
                )
                AnalysisCategoriesSummaryBadge(
                    title: "Targets",
                    value: "\(trackedTargetCount)",
                    systemImage: "target"
                )
                AnalysisCategoriesSummaryBadge(
                    title: "Selection",
                    value: selection == nil ? "None" : "Active",
                    systemImage: selection == nil ? "circle.dashed" : "checkmark.circle.fill"
                )
            }
        }
        .analysisSharedCardStyle()
    }

    private var contributionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Contribution")
                    .font(.headline)
                Spacer()
                Text(sort.supportingLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if sortedRows.isEmpty {
                Text("No category or group contributions were detected for the active context.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 10) {
                    ForEach(sortedRows, id: \.selfRowIdentity) { row in
                        Button {
                            selection = .row(row)
                        } label: {
                            contributionRow(row)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .analysisSharedCardStyle()
    }

    private var targetHandoffSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Target Handoff")
                .font(.headline)

            if let selection, let targetProgress = selectedTargetProgress {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top, spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(selection.title)
                                .font(.title3.weight(.semibold))
                            Text(targetProgress.name)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text(currency(targetProgress.spent))
                            .analysisSharedMetricValueStyle()
                    }

                    HStack(spacing: 10) {
                        targetMetricBadge(
                            title: "Limit",
                            value: currency(targetProgress.monthlyLimit)
                        )
                        targetMetricBadge(
                            title: "Remaining",
                            value: currency(targetProgress.remaining)
                        )
                        targetMetricBadge(
                            title: "Pace",
                            value: currency(targetProgress.paceDelta)
                        )
                    }

                    Button {
                        onShowTarget(targetProgress.id)
                    } label: {
                        Label("Open Target", systemImage: "target")
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else if let selection {
                Text("\(selection.title) does not currently map to a monthly target. Use the inspector to review evidence or jump into transactions instead.")
                    .foregroundStyle(.secondary)
            } else {
                Text("Select a contribution row to inspect its target alignment and hand off to Targets from the current selection.")
                    .foregroundStyle(.secondary)
            }
        }
        .analysisSharedCardStyle()
    }

    private func contributionRow(_ row: AnalysisSpendRow) -> some View {
        let isSelected = selection == .row(row)
        let targetProgress = snapshot.targetProgress(for: .row(row))

        return HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Text(row.title)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    if isSelected {
                        Text("Selected")
                            .analysisSharedBadgeStyle()
                            .foregroundStyle(Color.accentColor)
                    }

                    if targetProgress != nil {
                        Label("Target", systemImage: "target")
                            .analysisSharedBadgeStyle()
                            .foregroundStyle(Color.accentColor)
                    }
                }

                Text(changeSummary(row))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 8) {
                Text(currency(row.currentSpend))
                    .analysisSharedMetricValueStyle()
                    .foregroundStyle(.primary)

                Text("vs \(currency(row.comparisonSpend))")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                deltaBadge(for: row.delta)
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                .padding(.top, 6)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.14) : Color.white.opacity(0.0001))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isSelected ? Color.accentColor.opacity(0.5) : Color.secondary.opacity(0.14), lineWidth: isSelected ? 1.5 : 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func deltaBadge(for delta: Decimal) -> some View {
        let direction = deltaDirection(for: delta)

        return HStack(spacing: 6) {
            Image(systemName: direction.symbol)
                .font(.caption.weight(.semibold))
            Text("Delta \(currency(abs(delta)))")
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(direction.color.opacity(0.12), in: Capsule())
        .foregroundStyle(direction.color)
    }

    private func targetMetricBadge(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.quinary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func changeSummary(_ row: AnalysisSpendRow) -> String {
        "\(scopeLabel(for: row.scope)) • Current \(currency(row.currentSpend)) vs \(currency(row.comparisonSpend))"
    }

    private func scopeLabel(for scope: InsightEvidenceScope) -> String {
        switch scope {
        case .category:
            "Category"
        case .categoryGroup:
            "Group"
        case .workspace:
            "Workspace"
        case .merchant:
            "Merchant"
        case .uncategorized:
            "Uncategorized"
        case .account:
            "Account"
        }
    }

    private func deltaDirection(for delta: Decimal) -> AnalysisCategoriesDeltaDirection {
        if delta > .zero {
            return .up
        }
        if delta < .zero {
            return .down
        }
        return .flat
    }

    private func currency(_ amount: Decimal) -> String {
        AnalysisCurrencyFormatter.shared.string(from: NSDecimalNumber(decimal: amount)) ?? "\(amount)"
    }
}

extension AnalysisSpendRow {
    fileprivate var selfRowIdentity: AnalysisCategoriesView.RowIdentity {
        AnalysisCategoriesView.rowIdentity(for: self)
    }
}

private struct AnalysisCategoriesSummaryBadge: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline.weight(.semibold))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

extension AnalysisCategoriesView {
    struct RowIdentity: Hashable {
        private let base: Base

        init(scope: InsightEvidenceScope) {
            switch scope {
            case .workspace:
                base = .workspace
            case .category(let id):
                base = .category(id)
            case .categoryGroup(let id):
                base = .categoryGroup(id)
            case .merchant(let name):
                base = .merchant(name)
            case .uncategorized:
                base = .uncategorized
            case .account(let id):
                base = .account(id)
            }
        }

        private enum Base: Hashable {
            case workspace
            case category(UUID)
            case categoryGroup(UUID)
            case merchant(String)
            case uncategorized
            case account(UUID)
        }
    }
}

private enum AnalysisCategoriesDeltaDirection {
    case up
    case down
    case flat

    var color: Color {
        switch self {
        case .up:
            Color.orange
        case .down:
            Color.mint
        case .flat:
            Color.secondary
        }
    }

    var symbol: String {
        switch self {
        case .up:
            "arrow.up.forward"
        case .down:
            "arrow.down.forward"
        case .flat:
            "minus"
        }
    }
}

private extension AnalysisScreenState.CategoriesState.Sort {
    var title: String {
        switch self {
        case .largestCurrentSpend:
            "Largest Spend"
        case .largestDelta:
            "Largest Delta"
        }
    }

    var supportingLabel: String {
        switch self {
        case .largestCurrentSpend:
            "Ordered by current spend"
        case .largestDelta:
            "Ordered by delta magnitude"
        }
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
