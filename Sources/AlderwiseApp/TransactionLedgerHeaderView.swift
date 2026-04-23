import SwiftUI

struct TransactionLedgerHeaderView: View {
    let state: TransactionLedgerHeaderState
    let onRemoveChip: (TransactionLedgerHeaderState.Chip) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(state.filteredResultCountText)
                    .font(.headline)

                Text(state.scopeSummaryText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if !state.activeChips.isEmpty {
                WrappingFlowLayout(spacing: 8, rowSpacing: 8) {
                    ForEach(state.activeChips, id: \.self) { chip in
                        Button {
                            onRemoveChip(chip)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: chipIconName(for: chip))
                                    .foregroundStyle(.secondary)
                                Text(chipLabel(for: chip))
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .font(.caption.weight(.medium))
                            .lineLimit(1)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.regularMaterial, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 2)
                .padding(.trailing, 6)
            }
        }
    }

    private func chipLabel(for chip: TransactionLedgerHeaderState.Chip) -> String {
        switch chip {
        case .search(let text):
            return "Search: \(text)"
        case .visibility:
            return "Visibility: \(chip.text())"
        case .account(_, let name):
            return "Account: \(name)"
        case .category(_, let name):
            return "Category: \(name)"
        case .categoryGroup(_, let name):
            return "Group: \(name)"
        case .uncategorized:
            return "Category: Uncategorized"
        case .direction:
            return chip.text()
        case .review:
            return "Review: \(chip.text())"
        case .importSession(_, let name):
            return "Import: \(name)"
        case .dateRange:
            return chip.text()
        }
    }

    private func chipIconName(for chip: TransactionLedgerHeaderState.Chip) -> String {
        switch chip {
        case .search:
            return "magnifyingglass"
        case .visibility(let visibility):
            return switch visibility {
            case .active:
                "eye"
            case .hidden:
                "eye.slash"
            case .all:
                "tray.full"
            }
        case .account:
            return "building.columns"
        case .category:
            return "tag"
        case .categoryGroup:
            return "square.stack.3d.up"
        case .uncategorized:
            return "questionmark.circle"
        case .direction:
            return "arrow.left.arrow.right"
        case .review:
            return "checkmark.circle"
        case .importSession:
            return "tray.and.arrow.down"
        case .dateRange:
            return "calendar"
        }
    }
}
