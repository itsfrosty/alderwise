import Application
import Domain
import SwiftUI

struct LearnedRulesManagerView: View {
    @ObservedObject var model: WorkspaceShellModel
    let destination: LearnedRulesDestination
    let categories: [BudgetCategory]
    let snapshot: LearnedRuleManagerSnapshot?

    @State private var searchText = ""
    @State private var selectedRowID: RulesListRowID?
    @State private var pendingDisableRule: ManagedLearnedRuleRow?
    @State private var lastSyncedDestination: LearnedRulesDestination?

    private var learnedRows: [ManagedLearnedRuleRow] {
        snapshot?.learned.rows ?? []
    }

    private var seededRows: [SeededRuleSourceRow] {
        snapshot?.seeded.rows ?? []
    }

    private var deterministicRows: [SeededRuleSourceRow] {
        seededRows.filter { $0.sourceKind == .deterministicRule }
    }

    private var curatedPrefillRows: [SeededRuleSourceRow] {
        seededRows.filter { $0.sourceKind == .curatedPrefill }
    }

    private var categoryNamesByID: [UUID: String] {
        Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0.name) })
    }

    private var filteredLearnedRows: [ManagedLearnedRuleRow] {
        learnedRows.filter(matchesSearch)
    }

    private var filteredDeterministicRows: [SeededRuleSourceRow] {
        deterministicRows.filter(matchesSearch)
    }

    private var filteredCuratedPrefillRows: [SeededRuleSourceRow] {
        curatedPrefillRows.filter(matchesSearch)
    }

    private var visibleRowIDs: [RulesListRowID] {
        filteredLearnedRows.map { .learned($0.id) }
            + filteredDeterministicRows.map { .seeded($0.id) }
            + filteredCuratedPrefillRows.map { .seeded($0.id) }
    }

    private var selectedLearnedRule: ManagedLearnedRuleRow? {
        guard case .learned(let id)? = selectedRowID else {
            return nil
        }
        return learnedRows.first { $0.id == id }
    }

    private var selectedSeededRule: SeededRuleSourceRow? {
        guard case .seeded(let id)? = selectedRowID else {
            return nil
        }
        return seededRows.first { $0.id == id }
    }

    private var selectedLearnedRuleIsUnavailable: Bool {
        if case .learned = selectedRowID {
            return selectedLearnedRule == nil
        }
        return false
    }

    private var selectedSeededRuleIsUnavailable: Bool {
        if case .seeded = selectedRowID {
            return selectedSeededRule == nil
        }
        return false
    }

    var body: some View {
        unifiedManagerContent
    }

    private var unifiedManagerContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            if snapshot == nil {
                ContentUnavailableView(
                    "Rules Unavailable",
                    systemImage: "slider.horizontal.3",
                    description: Text("Alderwise could not load rule management for this workspace.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if learnedRows.isEmpty && seededRows.isEmpty {
                ContentUnavailableView(
                    "No Rules Yet",
                    systemImage: "slider.horizontal.3",
                    description: Text("Rules will appear here after Alderwise learns from review and loads bundled defaults.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if visibleRowIDs.isEmpty {
                ContentUnavailableView(
                    "No Results",
                    systemImage: "magnifyingglass",
                    description: Text("No rules match \"\(searchText)\".")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                managerSplitView
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .searchable(text: $searchText, placement: .toolbar, prompt: "Search rules")
        .onAppear {
            syncDestination(destination, force: true)
        }
        .onChange(of: destination) { _, newDestination in
            syncDestination(newDestination, force: false)
        }
        .onChange(of: searchText) { _, _ in
            syncSelectionToVisibleRows()
        }
        .onChange(of: trackedRowIdentityTokens) { _, _ in
            syncSelectionToVisibleRows()
        }
        .alert(
            "Learned Rule Action Failed",
            isPresented: Binding(
                get: { model.learnedRuleManagerActionErrorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        model.learnedRuleManagerActionErrorMessage = nil
                    }
                }
            )
        ) {
            Button("OK") {
                model.learnedRuleManagerActionErrorMessage = nil
            }
        } message: {
            Text(model.learnedRuleManagerActionErrorMessage ?? "")
        }
        .confirmationDialog(
            "Disable Learned Rule?",
            isPresented: Binding(
                get: { pendingDisableRule != nil },
                set: { isPresented in
                    if !isPresented {
                        pendingDisableRule = nil
                    }
                }
            ),
            titleVisibility: .visible,
            presenting: pendingDisableRule
        ) { rule in
            Button("Disable Rule", role: .destructive) {
                _ = model.disableLearnedRule(id: rule.id)
                pendingDisableRule = nil
            }

            Button("Cancel", role: .cancel) {
                pendingDisableRule = nil
            }
        } message: { _ in
            Text("Disabling this rule only changes future classifications. Accepted transactions stay unchanged.")
        }
        .sheet(item: learnedRuleDraftSheetBinding) { sheet in
            LearnedRuleDraftSheetView(
                sheet: sheet,
                categories: categories,
                draft: learnedRuleDraftBinding,
                previewPhase: model.learnedRuleDraftPreviewState?.phase,
                onCancel: {
                    model.dismissLearnedRuleDraftSheet()
                },
                onSave: {
                    _ = model.saveLearnedRuleDraft()
                }
            )
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Rules")
                        .font(.largeTitle.bold())

                    Text("\(RuleDisplayText.yourRules), \(RuleDisplayText.builtInAutoApplied), and \(RuleDisplayText.builtInReviewFirst) in one place.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: 720, alignment: .leading)
                }

                Spacer(minLength: 0)

                Button {
                    model.beginNewLearnedRule()
                } label: {
                    Label("New Rule", systemImage: "plus")
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var managerSplitView: some View {
        HSplitView {
            VStack(spacing: 0) {
                listPane
            }
            .frame(minWidth: 280, idealWidth: 320, maxWidth: 360, maxHeight: .infinity)

            detailPane
                .frame(minWidth: 520, idealWidth: 720, maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var listPane: some View {
        List(selection: selectedIDBinding) {
            if filteredLearnedRows.isEmpty == false {
                Section {
                    ForEach(filteredLearnedRows) { row in
                        LearnedRuleRowView(
                            row: row,
                            categoryName: categoryName(for: row.categoryID)
                        )
                        .tag(RulesListRowID.learned(row.id))
                    }
                } header: {
                    RulesSectionHeader(
                        title: ManagedLearnedRuleRow.sectionTitle,
                        subtitle: ManagedLearnedRuleRow.sectionSubtitle
                    )
                }
            }

            if filteredDeterministicRows.isEmpty == false {
                Section {
                    ForEach(filteredDeterministicRows) { row in
                        SeededRuleRowView(
                            row: row,
                            categoryName: categoryName(for: row.categoryID)
                        )
                        .tag(RulesListRowID.seeded(row.id))
                    }
                } header: {
                    RulesSectionHeader(
                        title: SeededRuleSourceKind.deterministicRule.sectionTitle,
                        subtitle: SeededRuleSourceKind.deterministicRule.sectionSubtitle
                    )
                }
            }

            if filteredCuratedPrefillRows.isEmpty == false {
                Section {
                    ForEach(filteredCuratedPrefillRows) { row in
                        SeededRuleRowView(
                            row: row,
                            categoryName: categoryName(for: row.categoryID)
                        )
                        .tag(RulesListRowID.seeded(row.id))
                    }
                } header: {
                    RulesSectionHeader(
                        title: SeededRuleSourceKind.curatedPrefill.sectionTitle,
                        subtitle: SeededRuleSourceKind.curatedPrefill.sectionSubtitle
                    )
                }
            }
        }
        .listStyle(.inset)
    }

    @ViewBuilder
    private var detailPane: some View {
        if let selectedLearnedRule {
            LearnedRuleDetailView(
                row: selectedLearnedRule,
                categoryName: categoryName(for: selectedLearnedRule.categoryID),
                onViewMatchingTransactions: {
                    model.showTransactions(
                        filter: selectedLearnedRule.matchingTransactionsFilter,
                        clearSelection: true
                    )
                },
                onDuplicate: {
                    _ = model.beginDuplicateLearnedRule(id: selectedLearnedRule.id)
                },
                onDisable: {
                    pendingDisableRule = selectedLearnedRule
                },
                onEnable: {
                    _ = model.enableLearnedRule(id: selectedLearnedRule.id)
                }
            )
        } else if let selectedSeededRule {
            SeededRuleDetailPanel(
                row: selectedSeededRule,
                categoryName: categoryName(for: selectedSeededRule.categoryID)
            )
        } else if selectedLearnedRuleIsUnavailable {
            ContentUnavailableView(
                "Selected Rule Unavailable",
                systemImage: "exclamationmark.triangle",
                description: Text("The selected learned rule is no longer available in the current workspace snapshot.")
            )
        } else if selectedSeededRuleIsUnavailable {
            ContentUnavailableView(
                "Selected Source Unavailable",
                systemImage: "exclamationmark.triangle",
                description: Text("The selected seeded source is no longer available in the current workspace snapshot.")
            )
        } else {
            ContentUnavailableView(
                "No Rule Selected",
                systemImage: "sidebar.left",
                description: Text("Select a rule to inspect its source, category, match scope, and lifecycle.")
            )
        }
    }

    private var selectedIDBinding: Binding<RulesListRowID?> {
        Binding(
            get: { selectedRowID },
            set: { selectedRowID = $0 }
        )
    }

    private var learnedRuleDraftSheetBinding: Binding<LearnedRuleDraftSheet?> {
        Binding(
            get: { model.learnedRuleDraftSheet },
            set: { sheet in
                if sheet == nil {
                    model.dismissLearnedRuleDraftSheet()
                }
            }
        )
    }

    private var learnedRuleDraftBinding: Binding<LearnedRuleDraft> {
        Binding(
            get: { model.learnedRuleDraftSheet?.draft ?? LearnedRuleDraft() },
            set: { draft in
                model.updateLearnedRuleDraft(draft)
            }
        )
    }

    private func syncDestination(_ destination: LearnedRulesDestination, force: Bool) {
        guard force || lastSyncedDestination != destination else {
            return
        }

        lastSyncedDestination = destination

        if let selection = destination.selection {
            switch selection {
            case .learnedRule(let id):
                searchText = LearnedRulesManagerRouteSync.revealedSearchTextForDeepLink(
                    currentSearchText: searchText,
                    selectedLearnedRuleID: id,
                    learnedRows: learnedRows,
                    categoryNamesByID: categoryNamesByID
                )
                selectedRowID = .learned(id)
            case .seededSource(let id):
                selectedRowID = .seeded(id)
            }
            return
        }

        switch destination.mode {
        case .learned:
            selectedRowID = firstAvailableLearnedRowID ?? firstVisibleRowID
        case .seeded:
            selectedRowID = firstAvailableSeededRowID ?? firstVisibleRowID
        }
    }

    private func syncSelectionToVisibleRows() {
        guard visibleRowIDs.isEmpty == false else {
            return
        }

        guard let selectedRowID else {
            self.selectedRowID = preferredVisibleRowID
            return
        }

        if visibleRowIDs.contains(selectedRowID) {
            return
        }

        if rowStillExists(selectedRowID) {
            self.selectedRowID = preferredVisibleRowID
        }
    }

    private var firstVisibleRowID: RulesListRowID? {
        visibleRowIDs.first
    }

    private var preferredVisibleRowID: RulesListRowID? {
        switch destination.mode {
        case .learned:
            return filteredLearnedRows.first.map { .learned($0.id) } ?? firstVisibleRowID
        case .seeded:
            let firstSeededID = filteredDeterministicRows.first.map { RulesListRowID.seeded($0.id) }
                ?? filteredCuratedPrefillRows.first.map { RulesListRowID.seeded($0.id) }
            return firstSeededID ?? firstVisibleRowID
        }
    }

    private var trackedRowIdentityTokens: [String] {
        learnedRows.map { "learned:\($0.id.uuidString)" }
            + seededRows.map { "seeded:\($0.id)" }
    }

    private var firstAvailableLearnedRowID: RulesListRowID? {
        learnedRows.first.map { .learned($0.id) }
    }

    private var firstAvailableSeededRowID: RulesListRowID? {
        seededRows.first.map { .seeded($0.id) }
    }

    private func rowStillExists(_ rowID: RulesListRowID) -> Bool {
        switch rowID {
        case .learned(let id):
            learnedRows.contains(where: { $0.id == id })
        case .seeded(let id):
            seededRows.contains(where: { $0.id == id })
        }
    }

    private func categoryName(for categoryID: UUID?) -> String? {
        guard let categoryID else {
            return nil
        }
        return categories.first { $0.id == categoryID }?.name
    }

    private func matchesSearch(_ row: ManagedLearnedRuleRow) -> Bool {
        LearnedRulesManagerRouteSync.matchesLearnedRule(
            row,
            searchText: searchText,
            categoryName: categoryName(for: row.categoryID)
        )
    }

    private func matchesSearch(_ row: SeededRuleSourceRow) -> Bool {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard query.isEmpty == false else {
            return true
        }

        return row.merchantPattern.lowercased().contains(query)
            || row.merchantName?.lowercased().contains(query) == true
            || row.matchKind.ruleDisplayLabel.lowercased().contains(query)
            || sourceTypeLabel(for: row).lowercased().contains(query)
            || categoryName(for: row.categoryID)?.lowercased().contains(query) == true
    }

    private func statusLabel(for row: ManagedLearnedRuleRow) -> String {
        row.isDisabled ? "Disabled" : "Active"
    }

    private func sourceTypeLabel(for row: SeededRuleSourceRow) -> String {
        row.sourceKind.sectionTitle
    }
}

enum LearnedRulesManagerRouteSync {
    static func revealedSearchTextForDeepLink(
        currentSearchText: String,
        selectedLearnedRuleID: UUID,
        learnedRows: [ManagedLearnedRuleRow],
        categoryNamesByID: [UUID: String]
    ) -> String {
        let normalizedSearchText = normalizedSearchText(currentSearchText)
        guard normalizedSearchText.isEmpty == false,
              let row = learnedRows.first(where: { $0.id == selectedLearnedRuleID }) else {
            return currentSearchText
        }

        let categoryName = row.categoryID.flatMap { categoryNamesByID[$0] }
        if matchesLearnedRule(row, searchText: currentSearchText, categoryName: categoryName) {
            return currentSearchText
        }

        return ""
    }

    static func matchesLearnedRule(
        _ row: ManagedLearnedRuleRow,
        searchText: String,
        categoryName: String?
    ) -> Bool {
        let query = normalizedSearchText(searchText)
        guard query.isEmpty == false else {
            return true
        }

        return row.merchantPattern.lowercased().contains(query)
            || row.merchantName?.lowercased().contains(query) == true
            || scopeLabel(for: row.matchKind).lowercased().contains(query)
            || statusLabel(for: row).lowercased().contains(query)
            || categoryName?.lowercased().contains(query) == true
    }

    private static func normalizedSearchText(_ searchText: String) -> String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func scopeLabel(for matchKind: ClassificationRuleMatchKind) -> String {
        switch matchKind {
        case .contains:
            "Contains"
        case .exactNormalizedMerchant:
            "Exact merchant"
        case .prefixNormalizedMerchant:
            "Shared prefix"
        }
    }

    private static func statusLabel(for row: ManagedLearnedRuleRow) -> String {
        row.isDisabled ? "Disabled" : "Active"
    }
}

private enum RulesListRowID: Hashable {
    case learned(UUID)
    case seeded(String)
}

private struct RulesSectionHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.top, 6)
    }
}

private struct LearnedRuleRowView: View {
    let row: ManagedLearnedRuleRow
    let categoryName: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(row.merchantPattern)
                    .font(.headline)
                    .lineLimit(1)

                Spacer(minLength: 8)

                Text(statusText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(row.isDisabled ? Color.secondary : Color.green)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.thinMaterial, in: Capsule())
            }

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.vertical, 3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
        .alignmentGuide(.listRowSeparatorTrailing) { dimensions in
            dimensions.width
        }
    }

    private var subtitle: String {
        var parts: [String] = [row.matchKind.ruleDisplayLabel]
        if let categoryName {
            parts.append(categoryName)
        } else {
            parts.append("No category")
        }
        if let merchantName = row.merchantName, merchantName.isEmpty == false {
            parts.append(merchantName)
        }
        return parts.joined(separator: " · ")
    }

    private var statusText: String {
        row.isDisabled ? "Disabled" : "Active"
    }
}

private struct LearnedRuleDetailView: View {
    let row: ManagedLearnedRuleRow
    let categoryName: String?
    var onViewMatchingTransactions: () -> Void
    var onDuplicate: () -> Void
    var onDisable: () -> Void
    var onEnable: () -> Void

    private var supportsDuplicateDraft: Bool {
        row.matchKind.isAdvancedManualAuthoringOption
            || LearnedRuleDraftSheet.supportsBasicManualAuthoring(matchKind: row.matchKind)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(row.merchantPattern)
                        .font(.title2.bold())
                    HStack(spacing: 8) {
                        detailBadge(title: ManagedLearnedRuleRow.sectionTitle, tint: .accentColor)
                        detailBadge(title: statusText, tint: row.isDisabled ? .secondary : .green)
                    }
                    Text(detailSummary)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: 640, alignment: .leading)
                }

                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 10) {
                    detailRow(title: "Status", value: statusText)
                    detailRow(title: RuleDisplayText.matchedBy, value: row.matchKind.ruleDisplayLabel)
                    detailRow(title: "Category", value: categoryName ?? "No category")
                    detailRow(title: "Merchant Name", value: row.merchantName ?? "Not provided")
                    detailRow(title: "Created", value: row.createdAt.formatted(date: .abbreviated, time: .shortened))
                    if let disabledAt = row.disabledAt {
                        detailRow(title: "Disabled", value: disabledAt.formatted(date: .abbreviated, time: .shortened))
                    }
                    detailRow(title: "Source", value: ManagedLearnedRuleRow.detailSourceText)
                }

                Text(effectStatement)
                    .foregroundStyle(.secondary)

                RulePrecedenceSection(precedenceExplanation: row.precedenceExplanation)

                HStack(spacing: 12) {
                    Button {
                        onViewMatchingTransactions()
                    } label: {
                        Label("View Matching Transactions", systemImage: "list.bullet.rectangle")
                    }
                    .buttonStyle(.bordered)

                    if supportsDuplicateDraft {
                        Button {
                            onDuplicate()
                        } label: {
                            Label("Duplicate Rule", systemImage: "plus.square.on.square")
                        }
                        .buttonStyle(.bordered)
                    }

                    if row.isDisabled {
                        Button {
                            onEnable()
                        } label: {
                            Label("Re-enable Rule", systemImage: "checkmark.circle")
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        Button(role: .destructive) {
                            onDisable()
                        } label: {
                            Label("Disable Rule", systemImage: "slash.circle")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    private var detailSummary: String {
        if row.isDisabled {
            "This rule is disabled and no longer affects future classifications."
        } else {
            "This rule is active and can classify future imports."
        }
    }

    private var effectStatement: String {
        if row.isDisabled {
            return "Re-enabling makes this rule eligible again for future classifications only. Accepted transactions stay unchanged."
        }

        return "Disabling this rule only changes future classifications. Accepted transactions stay unchanged."
    }

    private var statusText: String {
        row.isDisabled ? "Disabled" : "Active"
    }

    @ViewBuilder
    private func detailRow(title: String, value: String) -> some View {
        GridRow {
            Text(title)
                .foregroundStyle(.secondary)
            Text(value)
                .textSelection(.enabled)
        }
    }

    @ViewBuilder
    private func detailBadge(title: String, tint: Color) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.thinMaterial, in: Capsule())
    }
}

private struct SeededRuleDetailPanel: View {
    let row: SeededRuleSourceRow
    let categoryName: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(row.merchantPattern)
                        .font(.title2.bold())
                    HStack(spacing: 8) {
                        detailBadge(title: row.sourceKind.sectionTitle, tint: .accentColor)
                        detailBadge(title: "Read-only", tint: .secondary)
                    }
                    Text("This seeded source is read-only and cannot be edited, enabled, or disabled from this view.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: 640, alignment: .leading)
                }

                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 10) {
                    detailRow(title: "Read-only", value: "Yes")
                    detailRow(title: "Source type", value: row.sourceKind.detailSourceTypeText)
                    detailRow(title: "Merchant pattern", value: row.merchantPattern)
                    detailRow(title: RuleDisplayText.matchedBy, value: row.matchKind.ruleDisplayLabel)
                    detailRow(title: "Category", value: categoryName ?? "No category")
                    detailRow(title: "Merchant Name", value: row.merchantName ?? "Not provided")
                }

                RulePrecedenceSection(precedenceExplanation: row.precedenceExplanation)

                Spacer(minLength: 0)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    @ViewBuilder
    private func detailRow(title: String, value: String) -> some View {
        GridRow {
            Text(title)
                .foregroundStyle(.secondary)
            Text(value)
                .textSelection(.enabled)
        }
    }

    @ViewBuilder
    private func detailBadge(title: String, tint: Color) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.thinMaterial, in: Capsule())
    }
}

private struct RulePrecedenceSection: View {
    let precedenceExplanation: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Precedence")
                .font(.headline)

            Text(precedenceExplanation)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: 420, alignment: .leading)
    }
}

private struct LearnedRuleDraftSheetView: View {
    let sheet: LearnedRuleDraftSheet
    let categories: [BudgetCategory]
    @Binding var draft: LearnedRuleDraft
    let previewPhase: WorkspaceShellModel.ReviewRulePreviewPhase?
    var onCancel: () -> Void
    var onSave: () -> Void

    @State private var isAdvancedExpanded = false

    private var currentSheet: LearnedRuleDraftSheet {
        var current = sheet
        current.draft = draft
        return current
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Rule") {
                    TextField("Merchant Pattern", text: $draft.merchantPattern, axis: .vertical)
                        .lineLimit(2, reservesSpace: true)

                    if draft.matchKind.isAdvancedManualAuthoringOption {
                        LabeledContent("Match Scope", value: draft.matchKind.ruleDisplayLabel)
                    } else {
                        Picker("Match Scope", selection: $draft.matchKind) {
                            ForEach(currentSheet.allowedMatchKinds, id: \.self) { matchKind in
                                Text(matchKind.ruleDisplayLabel).tag(matchKind)
                            }
                        }
                    }

                    Text(matchScopeHelpText)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    DisclosureGroup("Advanced", isExpanded: advancedDisclosureBinding) {
                        Button {
                            draft.matchKind = .contains
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(ClassificationRuleMatchKind.contains.ruleDisplayLabel)
                                    Text(ClassificationRuleMatchKind.contains.manualAuthoringHelpText)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if draft.matchKind == .contains {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if draft.matchKind.isAdvancedManualAuthoringOption {
                            Button("Switch back to Exact merchant") {
                                draft.matchKind = .exactNormalizedMerchant
                            }
                            .font(.caption)
                        }
                    }

                    if draft.matchKind == .contains {
                        LearnedRuleDraftContainsPreviewView(
                            warningText: draft.matchKind.manualAuthoringWarningText,
                            previewPhase: previewPhase
                        )
                    }
                }

                Section("Assignment") {
                    Picker("Category", selection: $draft.categoryID) {
                        Text("Choose Category").tag(UUID?.none)
                        ForEach(categories) { category in
                            Text(category.name).tag(Optional(category.id))
                        }
                    }

                    TextField("Merchant Name", text: merchantNameBinding, axis: .vertical)
                        .lineLimit(2, reservesSpace: true)

                    Text("Saving creates a new learned rule. Existing learned rules and built-in sources stay read-only here.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            .navigationTitle(currentSheet.title)
            .frame(minWidth: 520, minHeight: 340)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(currentSheet.confirmationTitle) {
                        onSave()
                    }
                    .disabled(canSave == false)
                }
            }
        }
    }

    private var merchantNameBinding: Binding<String> {
        Binding(
            get: { draft.merchantName ?? "" },
            set: { newValue in
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                draft.merchantName = trimmed.isEmpty ? nil : newValue
            }
        )
    }

    private var matchScopeHelpText: String {
        draft.matchKind.manualAuthoringHelpText
    }

    private var canSave: Bool {
        currentSheet.canSave
    }

    private var advancedDisclosureBinding: Binding<Bool> {
        Binding(
            get: { isAdvancedExpanded || draft.matchKind.isAdvancedManualAuthoringOption },
            set: { isExpanded in
                isAdvancedExpanded = isExpanded || draft.matchKind.isAdvancedManualAuthoringOption
            }
        )
    }
}

private struct LearnedRuleDraftContainsPreviewView: View {
    let warningText: String?
    let previewPhase: WorkspaceShellModel.ReviewRulePreviewPhase?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let warningText {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                    Text(warningText)
                        .font(.caption)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if let previewPhase {
                previewSummary(for: previewPhase)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    @ViewBuilder
    private func previewSummary(
        for previewPhase: WorkspaceShellModel.ReviewRulePreviewPhase
    ) -> some View {
        switch previewPhase {
        case .loading:
            ProgressView("Checking matching transactions…")
                .font(.caption)
                .controlSize(.small)
        case .ready(let preview):
            VStack(alignment: .leading, spacing: 4) {
                Text(readyTitle(for: preview))
                    .font(.caption.weight(.semibold))
                Text("Preview counts accepted transactions and pending review items that would match after saving.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .noEligiblePreview:
            Text("Enter a merchant pattern to preview broader matches before saving.")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .unavailable:
            Text("Preview is unavailable in this workspace.")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .error(let message):
            VStack(alignment: .leading, spacing: 4) {
                Text("Preview failed.")
                    .font(.caption.weight(.semibold))
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func readyTitle(for preview: LearnedRuleImpactPreview) -> String {
        if preview.matchedAcceptedTransactionCount == 0,
           preview.matchedPendingReviewItemCount == 0 {
            return "This rule would not match any existing items right now."
        }

        return "This rule currently matches \(preview.matchedAcceptedTransactionCount) accepted transaction\(preview.matchedAcceptedTransactionCount == 1 ? "" : "s") and \(preview.matchedPendingReviewItemCount) pending review item\(preview.matchedPendingReviewItemCount == 1 ? "" : "s")."
    }
}
