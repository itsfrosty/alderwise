import Application
import Domain
import SwiftUI

struct SeededRuleRowView: View {
    let row: SeededRuleSourceRow
    let categoryName: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
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
        var parts: [String] = [scopeText, categoryName ?? "No category"]
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

    @ViewBuilder
    private func badge(title: String, systemImage: String, tint: Color) -> some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.thinMaterial, in: Capsule())
    }
}

struct SeededRuleDetailView: View {
    let row: SeededRuleSourceRow
    let categoryName: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(row.merchantPattern)
                        .font(.title2.bold())
                    HStack(spacing: 8) {
                        detailBadge(title: "Included with App", tint: .accentColor)
                        detailBadge(title: "Read-only", tint: .secondary)
                    }
                    Text("This seeded source is read-only and cannot be edited, enabled, or disabled from this view.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: 640, alignment: .leading)
                }

                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 10) {
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
