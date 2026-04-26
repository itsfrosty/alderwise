import Application
import Domain
import SwiftUI

protocol AnalysisInspectorPresentable {
    var title: String { get }
    var summaryText: String { get }
    var evidence: InsightEvidence { get }
}

struct AnalysisInspectorPlaceholderContent: Equatable {
    var title: String
    var systemImage: String
    var description: String
    var guidance: [String]
}

struct AnalysisInspectorEvidenceGrouping: Equatable {
    struct Item: Equatable {
        var label: String
        var value: String
    }

    var title: String
    var items: [Item]
}

struct AnalysisInspectorActionLayout: Equatable {
    var primaryActionTitle: String?
    var secondaryActionTitles: [String]

    static let none = AnalysisInspectorActionLayout(
        primaryActionTitle: nil,
        secondaryActionTitles: []
    )
}

private func analysisDefaultInspectorContent<Selection: AnalysisInspectorPresentable>(
    for selection: Selection
) -> AnalysisInspectorDocument {
    let evidenceGrouping = AnalysisInspectorView<Selection, EmptyView>.evidenceGrouping(for: selection.evidence)
    return AnalysisInspectorDocument(
        title: selection.title,
        sections: [
            .summary(title: "Selection Summary", text: selection.summaryText),
            .evidenceKV(
                title: evidenceGrouping.title,
                items: evidenceGrouping.items.map { .init(label: $0.label, value: $0.value) }
            ),
        ]
    )
}

struct AnalysisInspectorView<
    Selection: AnalysisInspectorPresentable,
    Actions: View
>: View {
    let selection: Selection?
    let noSelectionDescription: String
    let actionLayout: AnalysisInspectorActionLayout
    let inspectorContent: (Selection) -> AnalysisInspectorDocument
    @ViewBuilder let primaryActions: (Selection) -> Actions
    let secondaryActions: (Selection) -> AnyView

    nonisolated static func showsPlaceholder(for selection: Selection?) -> Bool {
        selection == nil
    }

    nonisolated static func placeholderContent(description: String) -> AnalysisInspectorPlaceholderContent {
        AnalysisInspectorPlaceholderContent(
            title: "Nothing Selected",
            systemImage: "sidebar.right",
            description: description,
            guidance: [
                "Select a row in the canvas to lock the inspector to that signal.",
                "Use the primary action here to continue into transactions or the next workflow.",
            ]
        )
    }

    nonisolated static func evidenceGrouping(for evidence: InsightEvidence) -> AnalysisInspectorEvidenceGrouping {
        AnalysisInspectorEvidenceGrouping(
            title: "Evidence",
            items: [
                .init(
                    label: "Window",
                    value: evidenceIntervalText(evidence.resolvedInterval)
                ),
                .init(
                    label: "Reconciled By",
                    value: evidence.reconciliationRuleLabel
                ),
            ]
        )
    }

    init(
        selection: Selection?,
        noSelectionDescription: String,
        actionLayout: AnalysisInspectorActionLayout = .none,
        inspectorContent: ((Selection) -> AnalysisInspectorDocument)? = nil,
        @ViewBuilder primaryActions: @escaping (Selection) -> Actions,
        @ViewBuilder secondaryActions: @escaping (Selection) -> some View
    ) {
        self.selection = selection
        self.noSelectionDescription = noSelectionDescription
        self.actionLayout = actionLayout
        self.inspectorContent = inspectorContent ?? analysisDefaultInspectorContent(for:)
        self.primaryActions = primaryActions
        self.secondaryActions = { selection in
            AnyView(secondaryActions(selection))
        }
    }

    init(
        selection: Selection?,
        noSelectionDescription: String
    ) where Actions == EmptyView {
        self.init(
            selection: selection,
            noSelectionDescription: noSelectionDescription
        ) { _ in
            EmptyView()
        } secondaryActions: { _ in
            EmptyView()
        }
    }

    init(
        selection: Selection?,
        noSelectionDescription: String,
        actionLayout: AnalysisInspectorActionLayout,
        inspectorContent: @escaping (Selection) -> AnalysisInspectorDocument,
        @ViewBuilder primaryActions: @escaping (Selection) -> Actions
    ) {
        self.init(
            selection: selection,
            noSelectionDescription: noSelectionDescription,
            actionLayout: actionLayout,
            inspectorContent: inspectorContent,
            primaryActions: primaryActions
        ) { _ in
            EmptyView()
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                inspectorHeader

                if let selection {
                    selectedContent(selection)
                } else {
                    noSelectionContent
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(
            minWidth: WorkspaceLayout.analysisInspectorMinimumWidth,
            idealWidth: WorkspaceLayout.analysisInspectorIdealWidth,
            maxWidth: WorkspaceLayout.analysisInspectorMaximumWidth,
            maxHeight: .infinity,
            alignment: .topLeading
        )
        .background(.thinMaterial)
    }

    private var inspectorHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Inspector")
                .font(.headline)
            Text(selection == nil ? "Select a signal to inspect its evidence and next step." : "The canvas selection and next workflow stay anchored here.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var noSelectionContent: some View {
        let placeholder = Self.placeholderContent(description: noSelectionDescription)

        return VStack(alignment: .leading, spacing: 16) {
            Label(placeholder.title, systemImage: placeholder.systemImage)
                .font(.title3.weight(.semibold))

            Text(placeholder.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 10) {
                Text("How To Use This")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                ForEach(placeholder.guidance, id: \.self) { step in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "arrow.turn.down.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.accentColor)
                            .padding(.top, 2)
                        Text(step)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    Color.accentColor.opacity(0.12),
                    Color.orange.opacity(0.08),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.white.opacity(0.18))
        )
    }

    @ViewBuilder
    private func selectedContent(_ selection: Selection) -> some View {
        let document = inspectorContent(selection)

        ForEach(Array(document.sections.enumerated()), id: \.offset) { _, section in
            inspectorSection(section, documentTitle: document.title)
        }

        if actionLayout.primaryActionTitle != nil {
            actionSection(
                title: "Primary Action",
                subtitle: actionLayout.primaryActionTitle
            ) {
                primaryActions(selection)
            }
        }

        if actionLayout.secondaryActionTitles.isEmpty == false {
            actionSection(
                title: "Workflow Handoffs",
                subtitle: actionLayout.secondaryActionTitles.joined(separator: " • ")
            ) {
                secondaryActions(selection)
            }
        }
    }

    @ViewBuilder
    private func inspectorSection(
        _ section: AnalysisInspectorSection,
        documentTitle: String
    ) -> some View {
        switch section.kind {
        case .summary:
            summarySection(section, documentTitle: documentTitle)
        case .evidenceKV:
            keyValueSection(section)
        case .metricRow:
            metricSection(section)
        case .bulletList:
            bulletSection(section)
        case .tagList:
            tagSection(section)
        }
    }

    private func summarySection(
        _ section: AnalysisInspectorSection,
        documentTitle: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(section.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(documentTitle)
                        .font(.title3.weight(.semibold))
                }

                Spacer(minLength: 12)

                Text("Canvas selected")
                    .analysisSharedBadgeStyle()
                    .foregroundStyle(Color.accentColor)
            }

            if let summary = section.summary {
                Text(summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.accentColor.opacity(0.35), lineWidth: 1)
        )
    }

    private func keyValueSection(_ section: AnalysisInspectorSection) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(section.title)
                .font(.subheadline.weight(.semibold))

            ForEach(section.keyValues, id: \.label) { item in
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.label)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(item.value)
                        .font(.subheadline)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func metricSection(_ section: AnalysisInspectorSection) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(section.title)
                .font(.subheadline.weight(.semibold))

            ForEach(section.metrics, id: \.label) { metric in
                HStack {
                    Text(metric.label)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(metric.value)
                        .font(.subheadline.monospacedDigit())
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func bulletSection(_ section: AnalysisInspectorSection) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(section.title)
                .font(.subheadline.weight(.semibold))

            ForEach(section.bullets, id: \.self) { bullet in
                HStack(alignment: .top, spacing: 8) {
                    Text("•")
                    Text(bullet)
                }
                .font(.subheadline)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func tagSection(_ section: AnalysisInspectorSection) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(section.title)
                .font(.subheadline.weight(.semibold))

            HStack(spacing: 8) {
                ForEach(section.tags, id: \.self) { tag in
                    Text(tag)
                        .analysisSharedBadgeStyle()
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func actionSection<Content: View>(
        title: String,
        subtitle: String?,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.subheadline.weight(.semibold))

            if let subtitle, subtitle.isEmpty == false {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quinary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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

private func evidenceIntervalText(_ interval: DateInterval) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .none
    formatter.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
    let start = formatter.string(from: interval.start)
    let end = formatter.string(from: interval.end)
    return "\(start)\u{2009}\u{2013}\u{2009}\(end)"
}

private func currency(_ amount: Decimal) -> String {
    analysisCurrency(amount)
}

private enum CurrencyFormatter {
    static let shared: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = Locale.current.currency?.identifier ?? "USD"
        return formatter
    }()
}
