import Application
import Domain
import SwiftUI

struct CSVImportPreviewEditorSelection: Equatable {
    var dateColumnIndex: Int?
    var descriptionColumnIndex: Int?
    var signedAmountColumnIndex: Int? {
        didSet {
            guard signedAmountColumnIndex != oldValue, signedAmountColumnIndex != nil else {
                return
            }
            debitColumnIndex = nil
            creditColumnIndex = nil
        }
    }
    var debitColumnIndex: Int? {
        didSet {
            guard debitColumnIndex != oldValue, debitColumnIndex != nil else {
                return
            }
            signedAmountColumnIndex = nil
        }
    }
    var creditColumnIndex: Int? {
        didSet {
            guard creditColumnIndex != oldValue, creditColumnIndex != nil else {
                return
            }
            signedAmountColumnIndex = nil
        }
    }

    init(mapping: CSVColumnMapping) {
        dateColumnIndex = mapping.dateColumnIndex
        descriptionColumnIndex = mapping.descriptionColumnIndex

        switch mapping.amount {
        case .singleSignedAmount(let columnIndex):
            signedAmountColumnIndex = columnIndex
            debitColumnIndex = nil
            creditColumnIndex = nil
        case .debitCredit(let debitColumnIndex, let creditColumnIndex):
            signedAmountColumnIndex = nil
            self.debitColumnIndex = debitColumnIndex
            self.creditColumnIndex = creditColumnIndex
        case nil:
            signedAmountColumnIndex = nil
            debitColumnIndex = nil
            creditColumnIndex = nil
        }
    }

    var mapping: CSVColumnMapping {
        CSVColumnMapping(
            dateColumnIndex: dateColumnIndex,
            descriptionColumnIndex: descriptionColumnIndex,
            amount: amountMapping
        )
    }

    mutating func sync(from mapping: CSVColumnMapping) {
        self = CSVImportPreviewEditorSelection(mapping: mapping)
    }

    private var amountMapping: CSVAmountMapping? {
        if let signedAmountColumnIndex {
            return .singleSignedAmount(columnIndex: signedAmountColumnIndex)
        }

        if let debitColumnIndex, let creditColumnIndex {
            return .debitCredit(debitColumnIndex: debitColumnIndex, creditColumnIndex: creditColumnIndex)
        }

        return nil
    }
}

struct CSVImportPreviewEditorContent: View {
    let preview: CSVImportPreview
    @Binding var mapping: CSVColumnMapping

    @State private var selection: CSVImportPreviewEditorSelection

    init(preview: CSVImportPreview, mapping: Binding<CSVColumnMapping>) {
        self.preview = preview
        _mapping = mapping
        _selection = State(initialValue: CSVImportPreviewEditorSelection(mapping: mapping.wrappedValue))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            mappingSummary
            mappingControls
            validationSummary
            validationIssueList
            previewTable
        }
        .onChange(of: selection) { _, newValue in
            let newMapping = newValue.mapping
            if mapping != newMapping {
                mapping = newMapping
            }
        }
        .onChange(of: mapping) { _, newValue in
            if selection.mapping != newValue {
                selection.sync(from: newValue)
            }
        }
    }

    private var mappingSummary: some View {
        HStack(spacing: 12) {
            MappingBadge(title: "Date", value: columnName(at: selection.dateColumnIndex))
            MappingBadge(title: "Description", value: columnName(at: selection.descriptionColumnIndex))
            MappingBadge(title: "Amount", value: amountMappingDescription)
        }
    }

    private var mappingControls: some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 12) {
            GridRow {
                Text("Date")
                columnPicker(selection: dateColumnBinding)
                Text("Description")
                columnPicker(selection: descriptionColumnBinding)
            }

            GridRow {
                Text("Signed Amount")
                columnPicker(selection: signedAmountColumnBinding)
                Text("Debit")
                columnPicker(selection: debitColumnBinding)
            }

            GridRow {
                Text("")
                Text("")
                Text("Credit")
                columnPicker(selection: creditColumnBinding)
            }
        }
        .font(.subheadline)
    }

    private var validationSummary: some View {
        HStack(spacing: 16) {
            Label("\(preview.validation.validRowCount) valid", systemImage: "checkmark.circle")
                .foregroundStyle(.green)
            if preview.validation.invalidRowCount == 0 {
                Label("\(preview.validation.invalidRowCount) invalid", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.secondary)
            } else {
                Label("\(preview.validation.invalidRowCount) invalid", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            }

            if !preview.validation.missingRequiredFields.isEmpty {
                Text("Missing: \(missingFieldsDescription)")
                    .foregroundStyle(.orange)
            }
        }
        .font(.subheadline)
    }

    private var previewTable: some View {
        ScrollView([.horizontal, .vertical]) {
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 10) {
                GridRow {
                    Text("Line")
                    ForEach(preview.headers, id: \.columnIndex) { header in
                        headerCell(for: header)
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

    @ViewBuilder
    private var validationIssueList: some View {
        if !preview.validation.rowIssues.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Validation Issues")
                    .font(.subheadline.weight(.semibold))

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(preview.validation.rowIssues.prefix(5).enumerated()), id: \.offset) { _, issue in
                        Text("Line \(issue.sourceLineNumber): \(issue.message)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    if preview.validation.rowIssues.count > 5 {
                        Text("+\(preview.validation.rowIssues.count - 5) more issues")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
    }

    private var amountMappingDescription: String {
        switch selection.mapping.amount {
        case .singleSignedAmount(let columnIndex):
            columnName(at: columnIndex)
        case .debitCredit(let debitColumnIndex, let creditColumnIndex):
            "\(columnName(at: debitColumnIndex)) / \(columnName(at: creditColumnIndex))"
        case nil:
            "Not detected"
        }
    }

    private var missingFieldsDescription: String {
        preview.validation.missingRequiredFields
            .map(\.rawValue)
            .map { $0.capitalized }
            .joined(separator: ", ")
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

    private func headerCell(for header: CSVColumn) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(header.name)
                .lineLimit(1)
            if let target = mappingTargetDescription(for: header.columnIndex) {
                Text(target)
                    .font(.caption)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(mappingColor(for: target), in: Capsule())
            }
        }
    }

    private func columnPicker(selection: Binding<Int?>) -> some View {
        Picker("", selection: selection) {
            Text("Not detected").tag(nil as Int?)
            ForEach(preview.headers, id: \.columnIndex) { header in
                Text(header.name).tag(header.columnIndex as Int?)
            }
        }
        .labelsHidden()
        .frame(minWidth: 160)
    }

    private func mappingTargetDescription(for columnIndex: Int) -> String? {
        if selection.dateColumnIndex == columnIndex {
            return "Date"
        }
        if selection.descriptionColumnIndex == columnIndex {
            return "Description"
        }

        switch selection.mapping.amount {
        case .singleSignedAmount(let amountColumnIndex):
            return amountColumnIndex == columnIndex ? "Amount" : nil
        case .debitCredit(let debitColumnIndex, let creditColumnIndex):
            if debitColumnIndex == columnIndex {
                return "Debit"
            }
            if creditColumnIndex == columnIndex {
                return "Credit"
            }
            return nil
        case nil:
            return nil
        }
    }

    private func mappingColor(for target: String) -> Color {
        switch target {
        case "Date":
            .blue
        case "Description":
            .teal
        case "Amount", "Debit", "Credit":
            .purple
        default:
            .secondary
        }
    }

    private var dateColumnBinding: Binding<Int?> {
        Binding(
            get: { selection.dateColumnIndex },
            set: { selection.dateColumnIndex = $0 }
        )
    }

    private var descriptionColumnBinding: Binding<Int?> {
        Binding(
            get: { selection.descriptionColumnIndex },
            set: { selection.descriptionColumnIndex = $0 }
        )
    }

    private var signedAmountColumnBinding: Binding<Int?> {
        Binding(
            get: { selection.signedAmountColumnIndex },
            set: { selection.signedAmountColumnIndex = $0 }
        )
    }

    private var debitColumnBinding: Binding<Int?> {
        Binding(
            get: { selection.debitColumnIndex },
            set: { selection.debitColumnIndex = $0 }
        )
    }

    private var creditColumnBinding: Binding<Int?> {
        Binding(
            get: { selection.creditColumnIndex },
            set: { selection.creditColumnIndex = $0 }
        )
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
