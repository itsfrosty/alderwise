import Application
import Domain
import SwiftUI

struct LearnedRulesManagerView: View {
    @ObservedObject var model: WorkspaceShellModel
    let destination: LearnedRulesDestination
    let categories: [BudgetCategory]
    let snapshot: LearnedRuleManagerSnapshot?

    @State private var searchText = ""
    @State private var selectedLearnedRuleID: UUID?
    @State private var pendingDisableRule: ManagedLearnedRuleRow?
    @State private var lastSyncedDestination: LearnedRulesDestination?

    private var learnedRows: [ManagedLearnedRuleRow] {
        snapshot?.learned.rows ?? []
    }

    private var filteredRows: [ManagedLearnedRuleRow] {
        guard searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            return learnedRows
        }

        let query = searchText.lowercased()
        return learnedRows.filter { row in
            row.merchantPattern.lowercased().contains(query)
                || row.merchantName?.lowercased().contains(query) == true
                || scopeLabel(for: row.matchKind).lowercased().contains(query)
                || statusLabel(for: row).lowercased().contains(query)
                || categoryName(for: row.categoryID)?.lowercased().contains(query) == true
        }
    }

    private var selectedRule: ManagedLearnedRuleRow? {
        guard let selectedLearnedRuleID else {
            return nil
        }

        return learnedRows.first { $0.id == selectedLearnedRuleID }
    }

    private var selectedRuleIsUnavailable: Bool {
        selectedLearnedRuleID != nil && selectedRule == nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            if snapshot == nil {
                ContentUnavailableView(
                    "Learned Rules Unavailable",
                    systemImage: "slider.horizontal.3",
                    description: Text("Alderwise could not load the learned-rule manager for this workspace.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if learnedRows.isEmpty {
                ContentUnavailableView(
                    "No Learned Rules Yet",
                    systemImage: "slider.horizontal.3",
                    description: Text("Learned rules will appear here after review teaches Alderwise new classifications.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredRows.isEmpty {
                ContentUnavailableView(
                    "No Results",
                    systemImage: "magnifyingglass",
                    description: Text("No learned rules match \"\(searchText)\".")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                managerSplitView
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .searchable(text: $searchText, placement: .toolbar, prompt: "Search learned rules")
        .onAppear {
            syncDestination(destination, force: true)
        }
        .onChange(of: destination) { _, newDestination in
            syncDestination(newDestination, force: false)
        }
        .onChange(of: searchText) { _, _ in
            syncSelectionToVisibleRows()
        }
        .onChange(of: learnedRows.map(\.id)) { _, _ in
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
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                model.selectSettingsDestination(.overview)
            } label: {
                Label("Back to Settings", systemImage: "chevron.left")
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 6) {
                Text("Learned Rules")
                    .font(.largeTitle.bold())

                Text("Inspect the rules Alderwise learned from review decisions. Disable a rule to stop future imports from using it.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var managerSplitView: some View {
        HSplitView {
            VStack(spacing: 0) {
                listPane
            }
            .frame(minWidth: 360, idealWidth: 420, maxWidth: .infinity, maxHeight: .infinity)

            detailPane
                .frame(idealWidth: 460, maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var listPane: some View {
        List(selection: selectedIDBinding) {
            ForEach(filteredRows) { row in
                LearnedRuleRowView(
                    row: row,
                    categoryName: categoryName(for: row.categoryID)
                )
                .tag(row.id)
            }
        }
        .listStyle(.inset)
    }

    @ViewBuilder
    private var detailPane: some View {
        if let selectedRule {
            LearnedRuleDetailView(
                row: selectedRule,
                categoryName: categoryName(for: selectedRule.categoryID),
                onDisable: {
                    pendingDisableRule = selectedRule
                },
                onEnable: {
                    _ = model.enableLearnedRule(id: selectedRule.id)
                }
            )
        } else if selectedRuleIsUnavailable {
            ContentUnavailableView(
                "Selected Rule Unavailable",
                systemImage: "exclamationmark.triangle",
                description: Text("The selected learned rule is no longer available in the current workspace snapshot.")
            )
        } else {
            ContentUnavailableView(
                "No Learned Rule Selected",
                systemImage: "sidebar.left",
                description: Text("Select a learned rule to inspect its category, match scope, and lifecycle.")
            )
        }
    }

    private var selectedIDBinding: Binding<UUID?> {
        Binding(
            get: { selectedLearnedRuleID },
            set: { selectedLearnedRuleID = $0 }
        )
    }

    private func syncDestination(_ destination: LearnedRulesDestination, force: Bool) {
        guard force || lastSyncedDestination != destination else {
            return
        }

        lastSyncedDestination = destination
        searchText = ""

        if let selectedLearnedRuleID = destination.selectedLearnedRuleID {
            self.selectedLearnedRuleID = selectedLearnedRuleID
            return
        }

        selectedLearnedRuleID = learnedRows.first?.id
    }

    private func syncSelectionToVisibleRows() {
        guard filteredRows.isEmpty == false else {
            return
        }

        guard let selectedLearnedRuleID else {
            self.selectedLearnedRuleID = filteredRows.first?.id
            return
        }

        if filteredRows.contains(where: { $0.id == selectedLearnedRuleID }) {
            return
        }

        if learnedRows.contains(where: { $0.id == selectedLearnedRuleID }) {
            self.selectedLearnedRuleID = filteredRows.first?.id
        }
    }

    private func categoryName(for categoryID: UUID?) -> String? {
        guard let categoryID else {
            return nil
        }

        return categories.first { $0.id == categoryID }?.name
    }

    private func scopeLabel(for matchKind: ClassificationRuleMatchKind) -> String {
        switch matchKind {
        case .contains:
            "Contains"
        case .exactNormalizedMerchant:
            "Exact merchant"
        case .prefixNormalizedMerchant:
            "Shared prefix"
        }
    }

    private func statusLabel(for row: ManagedLearnedRuleRow) -> String {
        row.isDisabled ? "Disabled" : "Active"
    }
}

private struct LearnedRuleRowView: View {
    let row: ManagedLearnedRuleRow
    let categoryName: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
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
        .padding(.vertical, 5)
    }

    private var subtitle: String {
        var parts: [String] = [scopeText]
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

    private var scopeText: String {
        switch row.matchKind {
        case .contains:
            "Contains"
        case .exactNormalizedMerchant:
            "Exact merchant"
        case .prefixNormalizedMerchant:
            "Shared prefix"
        }
    }

    private var statusText: String {
        row.isDisabled ? "Disabled" : "Active"
    }
}

private struct LearnedRuleDetailView: View {
    let row: ManagedLearnedRuleRow
    let categoryName: String?
    var onDisable: () -> Void
    var onEnable: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(row.merchantPattern)
                        .font(.title.bold())
                    Text(detailSummary)
                        .foregroundStyle(.secondary)
                }

                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 12) {
                    detailRow(title: "Status", value: statusText)
                    detailRow(title: "Match Scope", value: scopeText)
                    detailRow(title: "Category", value: categoryName ?? "No category")
                    detailRow(title: "Merchant Name", value: row.merchantName ?? "Not provided")
                    detailRow(title: "Created", value: row.createdAt.formatted(date: .abbreviated, time: .shortened))
                    if let disabledAt = row.disabledAt {
                        detailRow(title: "Disabled", value: disabledAt.formatted(date: .abbreviated, time: .shortened))
                    }
                    detailRow(title: "Source", value: "Learned from Review")
                }

                Text(effectStatement)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
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

    private var scopeText: String {
        switch row.matchKind {
        case .contains:
            "Contains"
        case .exactNormalizedMerchant:
            "Exact merchant"
        case .prefixNormalizedMerchant:
            "Shared prefix"
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
}
