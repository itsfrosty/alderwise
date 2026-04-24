import Application
import Domain
import SwiftUI

private enum CSVImportPreviewSheetCopy {
    static let venmoNoteGuidance = "Venmo imports keep the Note column as the raw description."
    static let categorizationPrefix = "Used for categorization:"
}

struct CSVImportPreviewSheet: View {
    private let originalPreview: CSVImportPreview
    private let accounts: [Account]
    private let originalFilename: String
    private let onCancel: () -> Void
    private let onImport: (CSVImportPreview, Account) -> Void

    @State private var workingPreview: CSVImportPreview
    @State private var selectedAccountID: Account.ID?
    @State private var dateColumnIndex: Int?
    @State private var descriptionColumnIndex: Int?
    @State private var signedAmountColumnIndex: Int?
    @State private var debitColumnIndex: Int?
    @State private var creditColumnIndex: Int?

    @Environment(\.dismiss) private var dismiss

    init(
        preview: CSVImportPreview,
        accounts: [Account],
        originalFilename: String,
        onCancel: @escaping () -> Void,
        onImport: @escaping (CSVImportPreview, Account) -> Void
    ) {
        originalPreview = preview
        self.accounts = accounts
        self.originalFilename = originalFilename
        self.onCancel = onCancel
        self.onImport = onImport
        _workingPreview = State(initialValue: preview)
        _selectedAccountID = State(initialValue: accounts.first?.id)
        _dateColumnIndex = State(initialValue: preview.mapping.dateColumnIndex)
        _descriptionColumnIndex = State(initialValue: preview.mapping.descriptionColumnIndex)

        switch preview.mapping.amount {
        case .singleSignedAmount(let columnIndex):
            _signedAmountColumnIndex = State(initialValue: columnIndex)
            _debitColumnIndex = State(initialValue: nil)
            _creditColumnIndex = State(initialValue: nil)
        case .debitCredit(let debitColumnIndex, let creditColumnIndex):
            _signedAmountColumnIndex = State(initialValue: nil)
            _debitColumnIndex = State(initialValue: debitColumnIndex)
            _creditColumnIndex = State(initialValue: creditColumnIndex)
        case nil:
            _signedAmountColumnIndex = State(initialValue: nil)
            _debitColumnIndex = State(initialValue: nil)
            _creditColumnIndex = State(initialValue: nil)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            mappingSummary
            accountPicker
            mappingControls
            validationSummary
            previewTable
            footer
        }
        .padding(24)
        .frame(minWidth: 720, minHeight: 480)
        .onChange(of: dateColumnIndex) { _, _ in applyMapping() }
        .onChange(of: descriptionColumnIndex) { _, _ in applyMapping() }
        .onChange(of: signedAmountColumnIndex) { _, newValue in
            if newValue != nil {
                debitColumnIndex = nil
                creditColumnIndex = nil
            }
            applyMapping()
        }
        .onChange(of: debitColumnIndex) { _, newValue in
            if newValue != nil {
                signedAmountColumnIndex = nil
            }
            applyMapping()
        }
        .onChange(of: creditColumnIndex) { _, newValue in
            if newValue != nil {
                signedAmountColumnIndex = nil
            }
            applyMapping()
        }
        .onChange(of: accounts.map(\.id)) { _, _ in
            guard let selectedAccountID else {
                self.selectedAccountID = accounts.first?.id
                return
            }
            if accounts.contains(where: { $0.id == selectedAccountID }) == false {
                self.selectedAccountID = accounts.first?.id
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Import Preview")
                .font(.title.bold())
            Text("\(originalFilename) · \(workingPreview.previewRows.count) rows ready for preview")
                .foregroundStyle(.secondary)
        }
    }

    private var mappingSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                MappingBadge(title: "Date", value: columnName(at: workingPreview.mapping.dateColumnIndex))
                MappingBadge(title: "Description", value: columnName(at: workingPreview.mapping.descriptionColumnIndex))
                MappingBadge(title: "Amount", value: amountMappingDescription)
            }

            if let descriptionSemanticsHint {
                Text(descriptionSemanticsHint)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var accountPicker: some View {
        HStack(spacing: 12) {
            Text("Account")
                .font(.subheadline)
            Picker("", selection: $selectedAccountID) {
                if accounts.isEmpty {
                    Text("No active accounts available").tag(nil as Account.ID?)
                }
                ForEach(accounts) { account in
                    Text(accountPickerLabel(for: account)).tag(account.id as Account.ID?)
                }
            }
            .labelsHidden()
            .frame(width: 240)

            if accounts.isEmpty {
                Text("Restore an archived account or create a new one before importing.")
                    .font(.subheadline)
                    .foregroundStyle(.orange)
            }
        }
    }

    private var mappingControls: some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 12) {
            GridRow {
                Text("Date")
                columnPicker(selection: $dateColumnIndex)
                Text("Description")
                columnPicker(selection: $descriptionColumnIndex)
            }

            GridRow {
                Text("Signed Amount")
                columnPicker(selection: $signedAmountColumnIndex)
                Text("Debit")
                columnPicker(selection: $debitColumnIndex)
            }

            GridRow {
                Text("")
                Text("")
                Text("Credit")
                columnPicker(selection: $creditColumnIndex)
            }
        }
        .font(.subheadline)
    }

    private var validationSummary: some View {
        HStack(spacing: 16) {
            Label("\(workingPreview.validation.validRowCount) valid", systemImage: "checkmark.circle")
                .foregroundStyle(.green)
            if workingPreview.validation.invalidRowCount == 0 {
                Label("\(workingPreview.validation.invalidRowCount) invalid", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.secondary)
            } else {
                Label("\(workingPreview.validation.invalidRowCount) invalid", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            }

            if !workingPreview.validation.missingRequiredFields.isEmpty {
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
                    ForEach(workingPreview.headers, id: \.columnIndex) { header in
                        headerCell(for: header)
                    }
                    Text("Signed Amount")
                }
                .font(.headline)

                Divider()
                    .gridCellColumns(workingPreview.headers.count + 2)

                ForEach(workingPreview.previewRows, id: \.sourceLineNumber) { row in
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
            Button("Reset Mapping") {
                resetMapping()
            }

            Spacer()
            Button("Close") {
                onCancel()
                dismiss()
            }
            .keyboardShortcut(.cancelAction)

            Button {
                guard let selectedAccount else {
                    return
                }
                onImport(workingPreview, selectedAccount)
            } label: {
                Label("Import", systemImage: "tray.and.arrow.down")
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .disabled(!canImport)
        }
    }

    private var selectedAccount: Account? {
        guard let selectedAccountID else {
            return nil
        }
        return accounts.first { $0.id == selectedAccountID }
    }

    private var canImport: Bool {
        workingPreview.validation.isReadyForImport && selectedAccount != nil
    }

    private func accountPickerLabel(for account: Account) -> String {
        if let institutionName = account.institutionName {
            return "\(account.name) · \(institutionName)"
        }
        return account.name
    }

    private var amountMappingDescription: String {
        switch workingPreview.mapping.amount {
        case .singleSignedAmount(let columnIndex):
            columnName(at: columnIndex)
        case .debitCredit(let debitColumnIndex, let creditColumnIndex):
            "\(columnName(at: debitColumnIndex)) / \(columnName(at: creditColumnIndex))"
        case nil:
            "Not detected"
        }
    }

    private var descriptionSemanticsHint: String? {
        var lines: [String] = []

        if workingPreview.profile == .venmoStatement {
            lines.append(CSVImportPreviewSheetCopy.venmoNoteGuidance)
        }
        if let derivedMerchant = workingPreview.previewRows.first(where: {
            $0.derivedMerchant.isEmpty == false
        })?.derivedMerchant {
            lines.append("\(CSVImportPreviewSheetCopy.categorizationPrefix) \(derivedMerchant)")
        }

        guard lines.isEmpty == false else {
            return nil
        }

        return lines.joined(separator: " ")
    }

    private var missingFieldsDescription: String {
        workingPreview.validation.missingRequiredFields
            .map(\.rawValue)
            .map { $0.capitalized }
            .joined(separator: ", ")
    }

    private func columnName(at index: Int?) -> String {
        guard let index, let header = workingPreview.headers.first(where: { $0.columnIndex == index }) else {
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
            ForEach(workingPreview.headers, id: \.columnIndex) { header in
                Text(header.name).tag(header.columnIndex as Int?)
            }
        }
        .labelsHidden()
        .frame(minWidth: 160)
    }

    private func mappingTargetDescription(for columnIndex: Int) -> String? {
        if workingPreview.mapping.dateColumnIndex == columnIndex {
            return "Date"
        }
        if workingPreview.mapping.descriptionColumnIndex == columnIndex {
            return "Description"
        }

        switch workingPreview.mapping.amount {
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

    private func applyMapping() {
        workingPreview = workingPreview.applying(
            mapping: CSVColumnMapping(
                dateColumnIndex: dateColumnIndex,
                descriptionColumnIndex: descriptionColumnIndex,
                amount: selectedAmountMapping
            )
        )
    }

    private func resetMapping() {
        workingPreview = originalPreview
        dateColumnIndex = originalPreview.mapping.dateColumnIndex
        descriptionColumnIndex = originalPreview.mapping.descriptionColumnIndex

        switch originalPreview.mapping.amount {
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

    private var selectedAmountMapping: CSVAmountMapping? {
        if let signedAmountColumnIndex {
            return .singleSignedAmount(columnIndex: signedAmountColumnIndex)
        }

        if let debitColumnIndex, let creditColumnIndex {
            return .debitCredit(debitColumnIndex: debitColumnIndex, creditColumnIndex: creditColumnIndex)
        }

        return nil
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
