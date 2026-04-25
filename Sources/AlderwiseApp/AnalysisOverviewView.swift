import Application
import Domain
import SwiftUI

struct AnalysisOverviewView: View {
    let snapshot: AnalysisOverviewSnapshot
    @Binding var selection: AnalysisOverviewSelection?
    var inspectorPresentation: AnalysisInspectorPresentation = .persistent
    var onDismissTransientInspector: (() -> Void)?
    let onShowTransactions: (TransactionLedgerFilter) -> Void

    private var layout: OverviewLayout {
        Self.layout(for: snapshot)
    }

    nonisolated static func inspectorActionLayout(
        for _: AnalysisOverviewSelection
    ) -> AnalysisInspectorActionLayout {
        AnalysisInspectorActionLayout(
            primaryActionTitle: "Show Transactions",
            secondaryActionTitles: []
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
                heroCard(layout.hero)
                primarySections

                if let supportSection = layout.supportSection {
                    supportSectionCard(supportSection)
                }
            }
            .padding(24)
        }
    }

    @ViewBuilder
    private var primarySections: some View {
        let spendTrend = layout.primarySection(kind: .spendTrend)
        let pace = layout.primarySection(kind: .pace)
        let whatChanged = layout.primarySection(kind: .whatChanged)

        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: AnalysisTheme.SectionSpacing.group) {
                if let spendTrend {
                    primarySectionCard(spendTrend)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }

                if let pace {
                    primarySectionCard(pace)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }

            VStack(alignment: .leading, spacing: AnalysisTheme.SectionSpacing.group) {
                if let spendTrend {
                    primarySectionCard(spendTrend)
                }

                if let pace {
                    primarySectionCard(pace)
                }
            }
        }

        if let whatChanged {
            primarySectionCard(whatChanged)
        }
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
            noSelectionDescription: "Select a trend signal, driver, or support row to inspect its evidence and drill into matching transactions.",
            actionLayout: selection.map(Self.inspectorActionLayout(for:)) ?? .none
        ) { selected in
            Button {
                onShowTransactions(snapshot.transactionFilter(for: selected))
            } label: {
                Label("Show Transactions", systemImage: "list.bullet.rectangle")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func heroCard(_ hero: OverviewLayout.Hero) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Overview")
                        .font(.headline)
                    Text("A tighter read on spend, pace, and the changes driving this window.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 16)

                OverviewBadge(
                    title: comparisonBadgeTitle(hero.comparison),
                    tone: hero.comparison == .none ? .neutral : .accent
                )
            }

            Text(currency(hero.currentSpend))
                .font(.system(size: 38, weight: .semibold, design: .rounded))
                .monospacedDigit()

            Text(heroSubtitle(hero))
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                OverviewBadge(
                    title: spendDeltaBadgeTitle(hero),
                    tone: tone(for: hero.spendDirection)
                )
                OverviewBadge(
                    title: paceBadgeTitle(hero),
                    tone: tone(for: hero.paceDirection)
                )
                OverviewBadge(
                    title: trustBadgeTitle(hero),
                    tone: hero.pendingReviewCount > 0 ? .caution : .neutral
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background(heroBackground)
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(.white.opacity(0.18))
        }
    }

    private var heroBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color.accentColor.opacity(0.22),
                        Color.blue.opacity(0.10),
                        Color.orange.opacity(0.08),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }

    @ViewBuilder
    private func primarySectionCard(_ section: OverviewLayout.PrimarySection) -> some View {
        switch section.kind {
        case .spendTrend:
            spendTrendSection(section)
        case .pace:
            paceSection(section)
        case .whatChanged:
            whatChangedSection(section)
        }
    }

    private func spendTrendSection(_ section: OverviewLayout.PrimarySection) -> some View {
        VStack(alignment: .leading, spacing: AnalysisTheme.Card.contentSpacing) {
            sectionHeader(
                title: "Spend Trend",
                subtitle: spendTrendSubtitle(for: section)
            )

            if let comparisonSpend = layout.hero.comparisonSpend {
                HStack(alignment: .top, spacing: 16) {
                    trendMetric(
                        label: "Current",
                        value: currency(layout.hero.currentSpend)
                    )
                    trendMetric(
                        label: comparisonReferenceLabel(layout.hero.comparison),
                        value: currency(comparisonSpend)
                    )
                    trendMetric(
                        label: "Delta",
                        value: currency(layout.hero.currentSpend - comparisonSpend)
                    )
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text(currency(layout.hero.currentSpend))
                        .analysisSharedMetricValueStyle()
                    Text(emptyStateText(for: section.emptyStateReason))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if section.entries.isEmpty == false {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Signals")
                        .font(.subheadline.weight(.semibold))
                    ForEach(section.entries) { entry in
                        selectableEntryRow(entry)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .analysisSharedCardStyle()
    }

    private func paceSection(_ section: OverviewLayout.PrimarySection) -> some View {
        VStack(alignment: .leading, spacing: AnalysisTheme.Card.contentSpacing) {
            sectionHeader(
                title: "Pace",
                subtitle: paceSubtitle(for: section)
            )

            HStack(alignment: .top, spacing: 16) {
                trendMetric(
                    label: "Month to date",
                    value: currency(snapshot.monthlyReport.currentMonthAcceptedSpend)
                )
                trendMetric(
                    label: "Expected pace",
                    value: currency(snapshot.monthlyReport.expectedPaceSpend)
                )
                trendMetric(
                    label: "Pace delta",
                    value: currency(snapshot.monthlyReport.paceDelta)
                )
            }

            OverviewPaceMiniChart(points: snapshot.monthlyReport.paceSeries)
                .frame(height: 132)

            HStack(spacing: 10) {
                OverviewBadge(title: "Actual", tone: .accent)
                OverviewBadge(title: "Expected", tone: .neutral)
                if snapshot.monthlyReport.hasActiveTargets {
                    OverviewBadge(
                        title: snapshot.monthlyReport.paceDelta > .zero ? "Target pressure" : "Targets in view",
                        tone: snapshot.monthlyReport.paceDelta > .zero ? .caution : .positive
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .analysisSharedCardStyle()
    }

    private func whatChangedSection(_ section: OverviewLayout.PrimarySection) -> some View {
        VStack(alignment: .leading, spacing: AnalysisTheme.Card.contentSpacing) {
            sectionHeader(
                title: "What Changed",
                subtitle: whatChangedSubtitle(for: section)
            )

            if section.entries.isEmpty {
                Text(emptyStateText(for: section.emptyStateReason))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 12) {
                    ForEach(section.entries) { entry in
                        selectableEntryRow(entry)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .analysisSharedCardStyle()
    }

    private func supportSectionCard(_ section: OverviewLayout.SupportSection) -> some View {
        VStack(alignment: .leading, spacing: AnalysisTheme.Card.contentSpacing) {
            sectionHeader(
                title: supportTitle(for: section.kind),
                subtitle: section.subtitle
            )

            if let headline = section.headline {
                Text(headline)
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
            }

            if section.entries.isEmpty {
                Text(section.caption)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 12) {
                    ForEach(section.entries) { entry in
                        selectableEntryRow(entry)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .analysisSharedCardStyle()
    }

    private func sectionHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func trendMetric(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .analysisSharedMetricValueStyle()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func selectableEntryRow(_ entry: OverviewLayout.Entry) -> some View {
        let isSelected = entry.selection == selection

        Group {
            if entry.selection != nil {
                Button {
                    entry.commitSelection(into: $selection)
                } label: {
                    entryRowLabel(entry, isSelected: isSelected)
                }
                .buttonStyle(.plain)
            } else {
                entryRowLabel(entry, isSelected: false)
            }
        }
    }

    private func entryRowLabel(
        _ entry: OverviewLayout.Entry,
        isSelected: Bool
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(entry.title)
                        .font(.subheadline.weight(.semibold))

                    if isSelected {
                        Text("Selected")
                            .analysisSharedBadgeStyle()
                            .foregroundStyle(Color.accentColor)
                    }
                }
                Text(entry.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            if let value = entry.trailingValue {
                Text(value)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
            }

            if entry.selection != nil {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(14)
        .background(entryBackground(isSelected: isSelected))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    isSelected ? Color.accentColor.opacity(0.45) : Color.secondary.opacity(0.08),
                    lineWidth: isSelected ? 1.5 : 1
                )
        }
    }

    private func entryBackground(isSelected: Bool) -> some ShapeStyle {
        if isSelected {
            return AnyShapeStyle(Color.accentColor.opacity(0.12))
        }

        return AnyShapeStyle(.thinMaterial)
    }

    private func heroSubtitle(_ hero: OverviewLayout.Hero) -> String {
        switch hero.comparison {
        case .none:
            return "This view is anchored to the current analysis window without a comparison baseline."
        case .previousPeriod:
            return "Compared with the previous period, visible spend moved \(directionPhrase(hero.spendDirection))."
        case .samePeriodLastYear:
            return "Compared with the same period last year, visible spend moved \(directionPhrase(hero.spendDirection))."
        case .rollingAverage:
            return "Compared with the rolling average baseline, visible spend moved \(directionPhrase(hero.spendDirection))."
        }
    }

    private func spendTrendSubtitle(for section: OverviewLayout.PrimarySection) -> String {
        if section.emptyStateReason == .missingComparisonBaseline {
            return "Current spend is available, but this context has no comparison baseline."
        }

        switch layout.hero.comparison {
        case .none:
            return "Current spend only, with no comparison framing."
        case .previousPeriod:
            return "Use this to judge whether the current window is expanding or cooling off."
        case .samePeriodLastYear:
            return "Use this to separate seasonal shifts from recent behavior."
        case .rollingAverage:
            return "Use this to compare against the rolling average baseline."
        }
    }

    private func paceSubtitle(for section: OverviewLayout.PrimarySection) -> String {
        if section.emptyStateReason == .insufficientPaceData {
            return "The month has not accumulated enough pace points for a reliable curve yet."
        }

        switch layout.hero.paceDirection {
        case .up:
            return "Current month spend is running ahead of the expected pace."
        case .down:
            return "Current month spend is running below the expected pace."
        case .flat:
            return "Current month spend is tracking close to the expected pace."
        }
    }

    private func whatChangedSubtitle(for section: OverviewLayout.PrimarySection) -> String {
        if section.emptyStateReason == .noMaterialChanges {
            return "No major drivers or projected shifts were detected in this window."
        }

        return "The strongest category shifts stay selectable so the inspector can explain the evidence."
    }

    private func supportTitle(for kind: OverviewLayout.SupportSection.Kind) -> String {
        switch kind {
        case .recurringSummary:
            return "Recurring Summary"
        case .planningPressure:
            return "Planning Pressure"
        case .dataTrust:
            return "Data Trust"
        }
    }

    private func comparisonBadgeTitle(_ descriptor: OverviewComparisonDescriptor) -> String {
        switch descriptor {
        case .none:
            return "No comparison"
        case .previousPeriod:
            return "Previous period"
        case .samePeriodLastYear:
            return "Same period last year"
        case .rollingAverage:
            return "Rolling average"
        }
    }

    private func comparisonReferenceLabel(_ descriptor: OverviewComparisonDescriptor) -> String {
        switch descriptor {
        case .none:
            return "Baseline"
        case .previousPeriod:
            return "Previous"
        case .samePeriodLastYear:
            return "Last year"
        case .rollingAverage:
            return "Average"
        }
    }

    private func spendDeltaBadgeTitle(_ hero: OverviewLayout.Hero) -> String {
        guard let direction = hero.spendDirection else {
            return "No baseline"
        }

        return "\(directionBadgeVerb(direction)) spend"
    }

    private func paceBadgeTitle(_ hero: OverviewLayout.Hero) -> String {
        "\(directionBadgeVerb(hero.paceDirection)) pace"
    }

    private func trustBadgeTitle(_ hero: OverviewLayout.Hero) -> String {
        if hero.pendingReviewCount > 0 {
            return "\(hero.pendingReviewCount) review item(s)"
        }

        return "Data trusted"
    }

    private func directionPhrase(_ direction: OverviewDeltaDirection?) -> String {
        switch direction {
        case .up:
            return "up"
        case .down:
            return "down"
        case .flat:
            return "sideways"
        case nil:
            return "without a baseline"
        }
    }

    private func directionBadgeVerb(_ direction: OverviewDeltaDirection) -> String {
        switch direction {
        case .up:
            return "Up"
        case .down:
            return "Down"
        case .flat:
            return "On"
        }
    }

    private func emptyStateText(for reason: OverviewEmptyStateReason?) -> String {
        switch reason {
        case .missingComparisonBaseline:
            return "Add a comparison to turn this from a snapshot into a trend."
        case .insufficientPaceData:
            return "Pace will become more informative once the month has more observed spend points."
        case .noMaterialChanges:
            return "Nothing in the current data cleared the threshold for a material change callout."
        case nil:
            return ""
        }
    }

    private func tone(for direction: OverviewDeltaDirection?) -> OverviewBadge.Tone {
        switch direction {
        case .up:
            return .caution
        case .down:
            return .positive
        case .flat:
            return .neutral
        case nil:
            return .neutral
        }
    }

    private func currency(_ amount: Decimal) -> String {
        CurrencyFormatter.shared.string(from: NSDecimalNumber(decimal: amount)) ?? "\(amount)"
    }
}

extension AnalysisOverviewView {
    enum OverviewDeltaDirection: String, Equatable {
        case up
        case down
        case flat

        init(delta: Decimal) {
            if delta > .zero {
                self = .up
            } else if delta < .zero {
                self = .down
            } else {
                self = .flat
            }
        }
    }

    enum OverviewComparisonDescriptor: String, Equatable {
        case none
        case previousPeriod
        case samePeriodLastYear
        case rollingAverage
    }

    enum OverviewEmptyStateReason: String, Equatable {
        case missingComparisonBaseline
        case insufficientPaceData
        case noMaterialChanges
    }

    struct OverviewLayout: Equatable {
        struct Hero: Equatable {
            let currentSpend: Decimal
            let comparisonSpend: Decimal?
            let comparison: OverviewComparisonDescriptor
            let spendDirection: OverviewDeltaDirection?
            let expectedPaceSpend: Decimal
            let paceDirection: OverviewDeltaDirection
            let pendingReviewCount: Int
        }

        struct Entry: Identifiable, Equatable {
            let id: String
            let title: String
            let subtitle: String
            let trailingValue: String?
            let selection: AnalysisOverviewSelection?

            func commitSelection(into binding: Binding<AnalysisOverviewSelection?>) {
                guard let selection else {
                    return
                }

                binding.wrappedValue = selection
            }
        }

        struct PrimarySection: Identifiable, Equatable {
            enum Kind: String, Equatable {
                case spendTrend
                case pace
                case whatChanged
            }

            let kind: Kind
            let emptyStateReason: OverviewEmptyStateReason?
            let entries: [Entry]

            var id: String { kind.rawValue }
            var isVisible: Bool { true }
        }

        struct SupportSection: Equatable {
            enum Kind: String, Equatable {
                case recurringSummary
                case planningPressure
                case dataTrust
            }

            let kind: Kind
            let headline: String?
            let subtitle: String
            let caption: String
            let entries: [Entry]
        }

        let hero: Hero
        let primarySections: [PrimarySection]
        let supportSection: SupportSection?

        func primarySection(kind: PrimarySection.Kind) -> PrimarySection? {
            primarySections.first(where: { $0.kind == kind })
        }
    }

    nonisolated static func layout(for snapshot: AnalysisOverviewSnapshot) -> OverviewLayout {
        let hero = OverviewLayout.Hero(
            currentSpend: snapshot.report.currentSpend,
            comparisonSpend: snapshot.report.comparisonSpend,
            comparison: comparisonDescriptor(for: snapshot.context.comparison),
            spendDirection: spendDirection(for: snapshot),
            expectedPaceSpend: snapshot.monthlyReport.expectedPaceSpend,
            paceDirection: OverviewDeltaDirection(delta: snapshot.monthlyReport.paceDelta),
            pendingReviewCount: snapshot.monthlyReport.pendingReviewCount
        )

        let trendEntries = Array(snapshot.projectedInsights.prefix(2)).map { insight in
            OverviewLayout.Entry(
                id: insight.suppressionKey,
                title: insightTitle(insight),
                subtitle: insightSubtitle(insight),
                trailingValue: nil,
                selection: .insight(insight)
            )
        }

        let changeEntries = whatChangedEntries(for: snapshot)
        let primarySections: [OverviewLayout.PrimarySection] = [
            OverviewLayout.PrimarySection(
                kind: .spendTrend,
                emptyStateReason: spendTrendEmptyStateReason(for: snapshot),
                entries: trendEntries
            ),
            OverviewLayout.PrimarySection(
                kind: .pace,
                emptyStateReason: paceEmptyStateReason(for: snapshot),
                entries: []
            ),
            OverviewLayout.PrimarySection(
                kind: .whatChanged,
                emptyStateReason: whatChangedEmptyStateReason(for: changeEntries),
                entries: changeEntries
            ),
        ]

        return OverviewLayout(
            hero: hero,
            primarySections: primarySections,
            supportSection: supportSection(for: snapshot)
        )
    }

    private nonisolated static func comparisonDescriptor(
        for comparison: AnalysisComparisonMode
    ) -> OverviewComparisonDescriptor {
        switch comparison {
        case .none:
            .none
        case .previousPeriod:
            .previousPeriod
        case .samePeriodLastYear:
            .samePeriodLastYear
        case .rollingAverage:
            .rollingAverage
        }
    }

    private nonisolated static func spendDirection(
        for snapshot: AnalysisOverviewSnapshot
    ) -> OverviewDeltaDirection? {
        guard let comparisonSpend = snapshot.report.comparisonSpend else {
            return nil
        }

        return OverviewDeltaDirection(delta: snapshot.report.currentSpend - comparisonSpend)
    }

    private nonisolated static func spendTrendEmptyStateReason(
        for snapshot: AnalysisOverviewSnapshot
    ) -> OverviewEmptyStateReason? {
        snapshot.report.comparisonSpend == nil ? .missingComparisonBaseline : nil
    }

    private nonisolated static func paceEmptyStateReason(
        for snapshot: AnalysisOverviewSnapshot
    ) -> OverviewEmptyStateReason? {
        let minimumPaceSeriesPointsForTrend = 2
        return snapshot.monthlyReport.paceSeries.count < minimumPaceSeriesPointsForTrend ? .insufficientPaceData : nil
    }

    private nonisolated static func whatChangedEmptyStateReason(
        for entries: [OverviewLayout.Entry]
    ) -> OverviewEmptyStateReason? {
        entries.isEmpty ? .noMaterialChanges : nil
    }

    private nonisolated static func whatChangedEntries(
        for snapshot: AnalysisOverviewSnapshot
    ) -> [OverviewLayout.Entry] {
        if snapshot.report.drivers.isEmpty == false {
            return Array(snapshot.report.drivers.prefix(4)).map { driver in
                OverviewLayout.Entry(
                    id: overviewIdentity(for: .driver(driver)),
                    title: driver.title,
                    subtitle: "Current \(currency(driver.currentSpend)) vs \(currency(driver.comparisonSpend))",
                    trailingValue: currency(driver.delta),
                    selection: .driver(driver)
                )
            }
        }

        return snapshot.projectedInsights.compactMap { insight in
            guard case .spendDriverChange(let detail) = insight.kind else {
                return nil
            }

            return OverviewLayout.Entry(
                id: insight.suppressionKey,
                title: detail.title,
                subtitle: "Current \(currency(detail.currentSpend)) vs \(currency(detail.comparisonSpend))",
                trailingValue: currency(detail.delta),
                selection: .insight(insight)
            )
        }
    }

    private nonisolated static func supportSection(
        for snapshot: AnalysisOverviewSnapshot
    ) -> OverviewLayout.SupportSection? {
        let pressuredTargets = snapshot.monthlyReport.targets
            .filter { $0.remaining < .zero || $0.paceDelta > .zero }
            .sorted { lhs, rhs in
                if lhs.paceDelta != rhs.paceDelta {
                    return lhs.paceDelta > rhs.paceDelta
                }
                return lhs.spent > rhs.spent
            }

        if snapshot.monthlyReport.hasActiveTargets, let leadTarget = pressuredTargets.first {
            let entries = Array(pressuredTargets.prefix(3)).map { target in
                OverviewLayout.Entry(
                    id: target.id.uuidString,
                    title: target.name,
                    subtitle: "Spent \(currency(target.spent)) against \(currency(target.monthlyLimit))",
                    trailingValue: currency(target.paceDelta),
                    selection: nil
                )
            }

            return OverviewLayout.SupportSection(
                kind: .planningPressure,
                headline: "\(leadTarget.name) is carrying the most pressure.",
                subtitle: "Targets already in this snapshot show where the month is likely to tighten first.",
                caption: "No target needs attention yet.",
                entries: entries
            )
        }

        if snapshot.report.recurring.isEmpty == false {
            let entries = Array(snapshot.report.recurring.prefix(3)).map { recurring in
                OverviewLayout.Entry(
                    id: overviewIdentity(for: .recurring(recurring)),
                    title: recurring.detail.normalizedMerchantName.localizedCapitalized,
                    subtitle: "\(recurring.detail.cadence.rawValue.capitalized) cadence across \(recurring.detail.observationCount) observations",
                    trailingValue: currency(recurring.detail.amountRange.maximum),
                    selection: .recurring(recurring)
                )
            }

            return OverviewLayout.SupportSection(
                kind: .recurringSummary,
                headline: "Recurring commitments are already visible in this window.",
                subtitle: "Use this support layer to separate durable commitments from one-off spikes.",
                caption: "No recurring commitments were detected.",
                entries: entries
            )
        }

        if snapshot.monthlyReport.pendingReviewCount > 0 {
            return OverviewLayout.SupportSection(
                kind: .dataTrust,
                headline: "\(snapshot.monthlyReport.pendingReviewCount) review item(s) can still move this story.",
                subtitle: "Accepted and pending expenses are included here, so categorization work can still reshape the final picture.",
                caption: "The current view already reflects settled data.",
                entries: []
            )
        }

        return nil
    }

    private nonisolated static func insightTitle(_ insight: WorkspaceInsight) -> String {
        switch insight.kind {
        case .recurringCharge(let detail):
            "\(detail.normalizedMerchantName.localizedCapitalized) looks recurring"
        case .spendDriverChange(let detail):
            "\(detail.title) is driving the swing"
        }
    }

    private nonisolated static func insightSubtitle(_ insight: WorkspaceInsight) -> String {
        switch insight.kind {
        case .recurringCharge(let detail):
            "\(detail.observationCount) observations on a \(detail.cadence.rawValue) cadence"
        case .spendDriverChange(let detail):
            "Current \(currency(detail.currentSpend)) vs \(currency(detail.comparisonSpend))"
        }
    }

    private nonisolated static func overviewIdentity(for selection: AnalysisOverviewSelection) -> String {
        switch selection {
        case .insight(let insight):
            return "insight:\(insight.suppressionKey)"
        case .driver(let row):
            return "driver:\(row.title):\(row.scope)"
        case .recurring(let row):
            return "recurring:\(row.detail.accountID.uuidString):\(row.detail.normalizedMerchantName)"
        }
    }

    private nonisolated static func currency(_ amount: Decimal) -> String {
        CurrencyFormatter.shared.string(from: NSDecimalNumber(decimal: amount)) ?? "\(amount)"
    }
}

private struct OverviewBadge: View {
    enum Tone {
        case accent
        case positive
        case caution
        case neutral
    }

    let title: String
    let tone: Tone

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(background, in: Capsule())
    }

    private var background: some ShapeStyle {
        switch tone {
        case .accent:
            AnyShapeStyle(Color.accentColor.opacity(0.16))
        case .positive:
            AnyShapeStyle(Color.green.opacity(0.16))
        case .caution:
            AnyShapeStyle(Color.orange.opacity(0.16))
        case .neutral:
            AnyShapeStyle(.thinMaterial)
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

private struct OverviewPaceMiniChart: View {
    let points: [MonthlySpendPoint]

    var body: some View {
        GeometryReader { proxy in
            let normalizedPoints = chartPoints(in: proxy.size)

            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.quaternary.opacity(0.35))

                if normalizedPoints.count >= 2 {
                    Path { path in
                        path.move(to: normalizedPoints[0].expected)
                        for point in normalizedPoints.dropFirst() {
                            path.addLine(to: point.expected)
                        }
                    }
                    .stroke(style: StrokeStyle(lineWidth: 2, dash: [5, 4]))
                    .foregroundStyle(.secondary)

                    Path { path in
                        path.move(to: normalizedPoints[0].actual)
                        for point in normalizedPoints.dropFirst() {
                            path.addLine(to: point.actual)
                        }
                    }
                    .stroke(lineWidth: 3)
                    .foregroundStyle(Color.accentColor)
                } else {
                    Text("Pace data will appear as the month fills in.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func chartPoints(in size: CGSize) -> [(actual: CGPoint, expected: CGPoint)] {
        guard points.isEmpty == false else {
            return []
        }

        let actualValues = points.map { NSDecimalNumber(decimal: $0.actualSpend).doubleValue }
        let expectedValues = points.map { NSDecimalNumber(decimal: $0.expectedSpend).doubleValue }
        let allValues = actualValues + expectedValues
        let maxValue = max(allValues.max() ?? 1, 1)
        let width = max(size.width, 1)
        let height = max(size.height, 1)
        let minDay = points.map(\.day).min() ?? 1
        let maxDay = points.map(\.day).max() ?? minDay
        let daySpan = max(maxDay - minDay, 1)

        return points.map { point in
            let x = CGFloat(point.day - minDay) / CGFloat(daySpan) * width
            let actualY = height - (CGFloat(NSDecimalNumber(decimal: point.actualSpend).doubleValue / maxValue) * (height - 12)) - 6
            let expectedY = height - (CGFloat(NSDecimalNumber(decimal: point.expectedSpend).doubleValue / maxValue) * (height - 12)) - 6
            return (
                actual: CGPoint(x: x, y: actualY),
                expected: CGPoint(x: x, y: expectedY)
            )
        }
    }
}
