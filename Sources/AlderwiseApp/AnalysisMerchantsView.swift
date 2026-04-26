import Application
import Domain
import SwiftUI

struct AnalysisMerchantsView: View {
    enum CardKind: String, Equatable {
        case recurringCommitments
        case topMerchants
        case readiness
    }

    struct InspectorActions: Equatable {
        var showsTransactions: Bool
        var ruleHandoffMerchantName: String?
    }

    let snapshot: AnalysisMerchantsSnapshot
    @Binding var sort: AnalysisScreenState.MerchantsState.Sort
    @Binding var selection: AnalysisMerchantsSelection?
    var inspectorPresentation: AnalysisInspectorPresentation = .persistent
    var onDismissTransientInspector: (() -> Void)?
    let onShowTransactions: (TransactionLedgerFilter) -> Void
    let onShowRules: (String) -> Void

    private var pageState: AnalysisScreenState.MerchantsState {
        AnalysisScreenState.MerchantsState(sort: sort, selection: selection)
    }

    private var sortedMerchants: [MerchantAnalysisRow] {
        pageState.sortedMerchants(in: snapshot)
    }

    private var sortedRecurring: [MerchantRecurringReportRow] {
        pageState.sortedRecurring(in: snapshot)
    }

    nonisolated static func inspectorActions(
        for selection: AnalysisMerchantsSelection
    ) -> InspectorActions {
        switch selection {
        case .merchant(let row):
            InspectorActions(
                showsTransactions: true,
                ruleHandoffMerchantName: row.key.normalizedName
            )
        case .recurring(let row):
            InspectorActions(
                showsTransactions: true,
                ruleHandoffMerchantName: row.detail.normalizedMerchantName
            )
        }
    }

    nonisolated static func inspectorActionLayout(
        for selection: AnalysisMerchantsSelection
    ) -> AnalysisInspectorActionLayout {
        let actions = inspectorActions(for: selection)
        return AnalysisInspectorActionLayout(
            primaryActionTitle: actions.showsTransactions ? "Show Transactions" : nil,
            secondaryActionTitles: actions.ruleHandoffMerchantName == nil ? [] : ["Open Rules"]
        )
    }

    nonisolated static func pageLayout(
        for snapshot: AnalysisMerchantsSnapshot,
        sort: AnalysisScreenState.MerchantsState.Sort,
        selection: AnalysisMerchantsSelection?
    ) -> AnalysisPageContract<CardKind> {
        let pageState = AnalysisScreenState.MerchantsState(sort: sort, selection: selection)
        let merchants = pageState.sortedMerchants(in: snapshot)
        let recurring = pageState.sortedRecurring(in: snapshot)
        let footerAction: AnalysisCardFooterAction
        if let selection {
            let actions = inspectorActions(for: selection)
            footerAction = .init(
                primaryTitle: actions.showsTransactions ? "Show Transactions" : nil,
                secondaryTitles: actions.ruleHandoffMerchantName == nil ? [] : ["Open Rules"]
            )
        } else {
            footerAction = .none
        }

        return AnalysisPageContract(cards: [
            // Snapshot source: report.recurring.
            // Omit never. Empty fallback: shown-empty when no recurring patterns exist. Action affordances: selection + Show Transactions/Open Rules after selection.
            .init(
                kind: .recurringCommitments,
                visibility: recurring.isEmpty ? .shownEmpty : .shownActionable,
                supportsSelection: true,
                footerAction: footerAction
            ),
            // Snapshot source: report.merchants sorted by page-local sort.
            // Omit never. Empty fallback: shown-empty when no merchants exist. Action affordances: selection + Show Transactions/Open Rules after selection.
            .init(
                kind: .topMerchants,
                visibility: merchants.isEmpty ? .shownEmpty : .shownActionable,
                supportsSelection: true,
                footerAction: footerAction
            ),
            // Snapshot source: none yet in current snapshot boundaries.
            // Omit when no honest CTA exists. Empty fallback: hidden for this pass. Action affordances: none.
            .init(
                kind: .readiness,
                visibility: .hidden,
                supportsSelection: false,
                footerAction: .none
            ),
        ])
    }

    nonisolated static func inspectorContent(
        for selection: AnalysisMerchantsSelection
    ) -> AnalysisInspectorDocument {
        AnalysisInspectorDocument(
            title: selection.title,
            sections: [
                .summary(title: "Selection Summary", text: selection.summaryText),
                .evidenceKV(
                    title: "Evidence",
                    items: AnalysisInspectorView<AnalysisMerchantsSelection, EmptyView>
                        .evidenceGrouping(for: selection.evidence)
                        .items
                        .map { .init(label: $0.label, value: $0.value) }
                ),
                .metricRow(title: "Metrics", items: merchantMetrics(for: selection)),
                .tagList(title: "Workflow Handoff", tags: merchantTags(for: selection)),
            ]
        )
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
            transientInspectorView
        }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AnalysisTheme.SectionSpacing.group) {
                header
                recurringCommitmentsSection
                merchantActivitySection
            }
            .padding(24)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: AnalysisTheme.Card.contentSpacing) {
            HStack(alignment: .top, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Merchants")
                        .font(.largeTitle.weight(.semibold))
                    Text("Sort merchant activity and recurring commitments without losing the selected entity, then branch cleanly into transaction review or merchant rules cleanup.")
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Sort")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Picker("Sort", selection: $sort) {
                        ForEach(AnalysisScreenState.MerchantsState.Sort.allCases, id: \.self) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 300)
                }
            }

            HStack(spacing: 10) {
                AnalysisMerchantsSummaryBadge(
                    title: "Merchants",
                    value: "\(sortedMerchants.count)",
                    systemImage: "building.2.crop.circle"
                )
                AnalysisMerchantsSummaryBadge(
                    title: "Recurring",
                    value: "\(sortedRecurring.count)",
                    systemImage: "repeat.circle"
                )
                AnalysisMerchantsSummaryBadge(
                    title: "Selection",
                    value: selection == nil ? "None" : "Active",
                    systemImage: selection == nil ? "circle.dashed" : "checkmark.circle.fill"
                )
            }
        }
        .analysisSharedCardStyle()
    }

    private var transientInspectorBinding: Binding<Bool> {
        Binding(
            get: { inspectorPresentation.shouldPresentTransientInspector(hasSelection: selection != nil) },
            set: { isPresented in
                if isPresented == false {
                    onDismissTransientInspector?()
                }
            }
        )
    }

    private var transientInspectorView: some View {
        ZStack(alignment: .topTrailing) {
            inspectorView

            Button("Done") {
                onDismissTransientInspector?()
            }
            .keyboardShortcut(.cancelAction)
            .padding()
        }
    }

    private var inspectorView: some View {
        AnalysisInspectorView(
            selection: selection,
            noSelectionDescription: "Select a merchant activity or recurring commitment row to inspect its evidence, open matching transactions, or hand off the selected merchant to Rules.",
            actionLayout: selection.map(Self.inspectorActionLayout(for:)) ?? .none,
            inspectorContent: Self.inspectorContent(for:)
        ) { selected in
            let actions = Self.inspectorActions(for: selected)

            if actions.showsTransactions {
                Button {
                    onShowTransactions(snapshot.transactionFilter(for: selected))
                } label: {
                    Label("Show Transactions", systemImage: "list.bullet.rectangle")
                }
                .buttonStyle(.borderedProminent)
            }
        } secondaryActions: { selected in
            let actions = Self.inspectorActions(for: selected)

            if let merchantName = actions.ruleHandoffMerchantName {
                Button {
                    onShowRules(merchantName)
                } label: {
                    Label("Open Rules", systemImage: "slider.horizontal.3")
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var merchantActivitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Merchant Activity")
                    .font(.headline)
                Spacer()
                Text(sort.supportingLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if sortedMerchants.isEmpty {
                Text("No merchant activity was detected for the active context.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 10) {
                    ForEach(sortedMerchants, id: \.key) { merchant in
                        Button {
                            selection = .merchant(merchant)
                        } label: {
                            merchantRow(merchant)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .analysisSharedCardStyle()
    }

    private var recurringCommitmentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recurring Commitments")
                .font(.headline)

            if sortedRecurring.isEmpty {
                Text("No recurring merchant patterns were confidently detected in this scope.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 10) {
                    ForEach(sortedRecurring, id: \.selfRecurringIdentity) { recurring in
                        Button {
                            selection = .recurring(recurring)
                        } label: {
                            recurringRow(recurring)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .analysisSharedCardStyle()
    }

    private nonisolated static func merchantMetrics(
        for selection: AnalysisMerchantsSelection
    ) -> [AnalysisInspectorMetric] {
        switch selection {
        case .merchant(let row):
            return [
                .init(label: "Current", value: analysisCurrency(row.currentSpend)),
                .init(label: "Comparison", value: analysisCurrency(row.comparisonSpend)),
                .init(label: "Delta", value: analysisCurrency(row.delta)),
            ]
        case .recurring(let row):
            return [
                .init(label: "Observations", value: "\(row.detail.observationCount)"),
                .init(label: "Cadence", value: row.detail.cadence.rawValue.capitalized),
                .init(label: "Amount", value: analysisCurrency(row.detail.amountRange.maximum)),
            ]
        }
    }

    private nonisolated static func merchantTags(
        for selection: AnalysisMerchantsSelection
    ) -> [String] {
        switch selection {
        case .merchant(let row):
            return [
                "Rules handoff: \(row.key.normalizedName)",
                "Transactions drill-down"
            ]
        case .recurring(let row):
            return [
                "Rules handoff: \(row.detail.normalizedMerchantName)",
                row.detail.cadence.rawValue.capitalized
            ]
        }
    }

    private func merchantRow(_ merchant: MerchantAnalysisRow) -> some View {
        let isSelected = selection == .merchant(merchant)

        return HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Text(merchant.title.localizedCapitalized)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    if isSelected {
                        Text("Selected")
                            .analysisSharedBadgeStyle()
                            .foregroundStyle(Color.accentColor)
                    }
                }

                Text("Merchant key • \(merchant.key.normalizedName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 8) {
                Text(currency(merchant.currentSpend))
                    .analysisSharedMetricValueStyle()
                    .foregroundStyle(.primary)

                Text("vs \(currency(merchant.comparisonSpend))")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                merchantDeltaBadge(for: merchant.delta)
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                .padding(.top, 6)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(rowBackground(isSelected: isSelected))
        .overlay(rowStroke(isSelected: isSelected))
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func recurringRow(_ recurring: MerchantRecurringReportRow) -> some View {
        let isSelected = selection == .recurring(recurring)

        return HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Text(recurring.detail.normalizedMerchantName.localizedCapitalized)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    if isSelected {
                        Text("Selected")
                            .analysisSharedBadgeStyle()
                            .foregroundStyle(Color.accentColor)
                    }
                }

                HStack(spacing: 8) {
                    recurringBadge(recurring.detail.cadence.displayTitle, systemImage: "calendar")
                    recurringBadge("\(recurring.detail.observationCount) observations", systemImage: "waveform.path.ecg")
                }
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 8) {
                Text(currency(recurring.detail.amountRange.maximum))
                    .analysisSharedMetricValueStyle()
                    .foregroundStyle(.primary)

                Text("Expected amount")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                recurringAmountRangeText(recurring.detail.amountRange)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                .padding(.top, 6)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(rowBackground(isSelected: isSelected))
        .overlay(rowStroke(isSelected: isSelected))
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func merchantDeltaBadge(for delta: Decimal) -> some View {
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

    private func recurringBadge(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .analysisSharedBadgeStyle()
            .foregroundStyle(Color.accentColor)
    }

    private func rowBackground(isSelected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(isSelected ? Color.accentColor.opacity(0.14) : Color.white.opacity(0.0001))
    }

    private func rowStroke(isSelected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(
                isSelected ? Color.accentColor.opacity(0.5) : Color.secondary.opacity(0.14),
                lineWidth: isSelected ? 1.5 : 1
            )
    }

    private func recurringAmountRangeText(_ range: RecurringChargeAmountRange) -> Text {
        if range.minimum == range.maximum {
            return Text("Range \(currency(range.maximum))")
        }

        return Text("Range \(currency(range.minimum)) to \(currency(range.maximum))")
    }

    private func deltaDirection(for delta: Decimal) -> AnalysisMerchantsDeltaDirection {
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

private struct AnalysisMerchantsSummaryBadge: View {
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

private enum AnalysisMerchantsDeltaDirection {
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

private extension AnalysisScreenState.MerchantsState.Sort {
    var title: String {
        switch self {
        case .largestCurrentSpend:
            "Largest Spend"
        case .alphabetical:
            "Alphabetical"
        }
    }

    var supportingLabel: String {
        switch self {
        case .largestCurrentSpend:
            "Leading with current visible spend, then delta."
        case .alphabetical:
            "Leading with merchant name, preserving the selected entity."
        }
    }
}

private extension RecurringChargeCadence {
    var displayTitle: String {
        rawValue.capitalized
    }
}

private extension MerchantRecurringReportRow {
    var selfRecurringIdentity: AnalysisMerchantsRecurringIdentity {
        AnalysisMerchantsRecurringIdentity(
            accountID: detail.accountID,
            normalizedMerchantName: detail.normalizedMerchantName
        )
    }
}

private struct AnalysisMerchantsRecurringIdentity: Hashable {
    let accountID: UUID
    let normalizedMerchantName: String
}

private enum AnalysisCurrencyFormatter {
    static let shared: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = Locale.current.currency?.identifier ?? "USD"
        return formatter
    }()
}
