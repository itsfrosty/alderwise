import Application
import Domain
import SwiftUI

struct SeededRulesListView: View {
    @ObservedObject var model: WorkspaceShellModel
    let categories: [BudgetCategory]
    let snapshot: LearnedRuleManagerSnapshot?

    @State private var selectedSeededRuleID: String?

    private var seededRows: [SeededRuleSourceRow] {
        snapshot?.seeded.rows ?? []
    }

    private var deterministicRows: [SeededRuleSourceRow] {
        seededRows.filter { $0.sourceKind == .deterministicRule }
    }

    private var curatedPrefillRows: [SeededRuleSourceRow] {
        seededRows.filter { $0.sourceKind == .curatedPrefill }
    }

    private var allRows: [SeededRuleSourceRow] {
        deterministicRows + curatedPrefillRows
    }

    private var selectedRow: SeededRuleSourceRow? {
        guard let selectedSeededRuleID else {
            return nil
        }

        return allRows.first { $0.id == selectedSeededRuleID }
    }

    private var selectedRowIsUnavailable: Bool {
        selectedSeededRuleID != nil && selectedRow == nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            if snapshot == nil {
                ContentUnavailableView(
                    "Seeded Sources Unavailable",
                    systemImage: "slider.horizontal.3",
                    description: Text("Alderwise could not load the seeded classification sources for this workspace.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if allRows.isEmpty {
                ContentUnavailableView(
                    "No Seeded Sources Yet",
                    systemImage: "slider.horizontal.3",
                    description: Text("This workspace snapshot does not include seeded classification sources.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                managerSplitView
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            syncSelection(force: true)
        }
        .onChange(of: allRows.map(\.id)) { _, _ in
            syncSelection(force: false)
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
                Text("Seeded Classification Sources")
                    .font(.largeTitle.bold())

                Text("Review the deterministic rules and curated starter prefills bundled with Alderwise. This view is read-only, and seeded heuristics are intentionally excluded.")
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
            seededSection(
                title: "Deterministic Rules",
                rows: deterministicRows
            )

            seededSection(
                title: "Curated Starter Prefills",
                rows: curatedPrefillRows
            )
        }
        .listStyle(.inset)
    }

    @ViewBuilder
    private func seededSection(title: String, rows: [SeededRuleSourceRow]) -> some View {
        if rows.isEmpty == false {
            Section(title) {
                ForEach(rows) { row in
                    SeededRuleRowView(
                        row: row,
                        categoryName: categoryName(for: row.categoryID)
                    )
                    .tag(row.id)
                }
            }
        }
    }

    @ViewBuilder
    private var detailPane: some View {
        if let selectedRow {
            SeededRuleDetailView(
                row: selectedRow,
                categoryName: categoryName(for: selectedRow.categoryID)
            )
        } else if selectedRowIsUnavailable {
            ContentUnavailableView(
                "Selected Source Unavailable",
                systemImage: "exclamationmark.triangle",
                description: Text("The selected seeded source is no longer available in the current workspace snapshot.")
            )
        } else {
            ContentUnavailableView(
                "No Seeded Source Selected",
                systemImage: "sidebar.left",
                description: Text("Select a seeded source to inspect its category, source type, and match scope.")
            )
        }
    }

    private var selectedIDBinding: Binding<String?> {
        Binding(
            get: { selectedSeededRuleID },
            set: { selectedSeededRuleID = $0 }
        )
    }

    private func syncSelection(force: Bool) {
        guard force || selectedRow == nil else {
            return
        }

        selectedSeededRuleID = allRows.first?.id
    }

    private func categoryName(for categoryID: UUID) -> String? {
        categories.first { $0.id == categoryID }?.name
    }
}

private struct SeededRuleRowView: View {
    let row: SeededRuleSourceRow
    let categoryName: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(row.merchantPattern)
                    .font(.headline)
                    .lineLimit(1)

                Spacer(minLength: 8)

                badge(
                    title: "Read-only",
                    systemImage: "lock.fill",
                    tint: .secondary
                )
            }

            HStack(spacing: 8) {
                badge(
                    title: sourceTypeLabel,
                    systemImage: sourceTypeSystemImage,
                    tint: sourceTypeTint
                )

                badge(
                    title: scopeText,
                    systemImage: "arrow.left.and.right",
                    tint: .accentColor
                )
            }

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.vertical, 5)
    }

    private var subtitle: String {
        var parts: [String] = [categoryName ?? "No category"]
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

    private var sourceTypeLabel: String {
        switch row.sourceKind {
        case .deterministicRule:
            "Deterministic rule"
        case .curatedPrefill:
            "Curated starter prefill"
        }
    }

    private var sourceTypeSystemImage: String {
        switch row.sourceKind {
        case .deterministicRule:
            "checkmark.seal"
        case .curatedPrefill:
            "sparkles"
        }
    }

    private var sourceTypeTint: Color {
        switch row.sourceKind {
        case .deterministicRule:
            .green
        case .curatedPrefill:
            .orange
        }
    }

    @ViewBuilder
    private func badge(title: String, systemImage: String, tint: Color) -> some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.thinMaterial, in: Capsule())
    }
}

private struct SeededRuleDetailView: View {
    let row: SeededRuleSourceRow
    let categoryName: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(row.merchantPattern)
                        .font(.title.bold())
                    Text("This seeded source is read-only and cannot be edited, enabled, or disabled from this view.")
                        .foregroundStyle(.secondary)
                }

                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 12) {
                    detailRow(title: "Read-only", value: "Yes")
                    detailRow(title: "Source type", value: sourceTypeLabel)
                    detailRow(title: "Merchant pattern", value: row.merchantPattern)
                    detailRow(title: "Match scope", value: scopeText)
                    detailRow(title: "Category", value: categoryName ?? "No category")
                    detailRow(title: "Merchant Name", value: row.merchantName ?? "Not provided")
                }

                Spacer(minLength: 0)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
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

    private var sourceTypeLabel: String {
        switch row.sourceKind {
        case .deterministicRule:
            "Deterministic rule"
        case .curatedPrefill:
            "Curated starter prefill"
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
