import Application
import Domain
import SwiftUI

struct CSVImportPreviewSheet: View {
    let preview: CSVImportPreview
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            mappingSummary
            previewTable
            footer
        }
        .padding(24)
        .frame(minWidth: 720, minHeight: 480)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Import Preview")
                .font(.title.bold())
            Text("\(preview.previewRows.count) rows ready for preview")
                .foregroundStyle(.secondary)
        }
    }

    private var mappingSummary: some View {
        HStack(spacing: 12) {
            MappingBadge(title: "Date", value: columnName(at: preview.mapping.dateColumnIndex))
            MappingBadge(title: "Description", value: columnName(at: preview.mapping.descriptionColumnIndex))
            MappingBadge(title: "Amount", value: amountMappingDescription)
        }
    }

    private var previewTable: some View {
        ScrollView([.horizontal, .vertical]) {
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 10) {
                GridRow {
                    Text("Line")
                    ForEach(preview.headers, id: \.columnIndex) { header in
                        Text(header.name)
                    }
                    Text("Signed Amount")
                }
                .font(.headline)

                Divider()
                    .gridCellColumns(preview.headers.count + 2)

                ForEach(preview.previewRows, id: \.sourceLineNumber) { row in
                    GridRow {
                        Text("\(row.sourceLineNumber)")
                            .foregroundStyle(.secondary)
                        ForEach(row.cells, id: \.columnIndex) { cell in
                            Text(cell.value)
                                .lineLimit(1)
                        }
                        Text(formatAmount(row.interpretedAmount))
                            .monospacedDigit()
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button("Close") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)
        }
    }

    private var amountMappingDescription: String {
        switch preview.mapping.amount {
        case .singleSignedAmount(let columnIndex):
            columnName(at: columnIndex)
        case .debitCredit(let debitColumnIndex, let creditColumnIndex):
            "\(columnName(at: debitColumnIndex)) / \(columnName(at: creditColumnIndex))"
        case nil:
            "Not detected"
        }
    }

    private func columnName(at index: Int?) -> String {
        guard let index, let header = preview.headers.first(where: { $0.columnIndex == index }) else {
            return "Not detected"
        }
        return header.name
    }

    private func formatAmount(_ amount: Decimal?) -> String {
        guard let amount else {
            return "Not detected"
        }
        return amount.formatted(.number.precision(.fractionLength(2)))
    }
}

private struct MappingBadge: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
