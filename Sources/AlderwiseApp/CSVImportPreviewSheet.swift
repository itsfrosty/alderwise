import Application
import Domain
import SwiftUI

struct CSVImportPreviewSheet: View {
    private let originalPreview: CSVImportPreview
    private let accounts: [Account]
    private let originalFilename: String
    private let onCancel: () -> Void
    private let onImport: (CSVImportPreview, Account) -> Void

    @State private var workingPreview: CSVImportPreview
    @State private var selectedAccountID: Account.ID?
    @State private var workingMapping: CSVColumnMapping

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
        _workingMapping = State(initialValue: preview.mapping)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            accountPicker
            CSVImportPreviewEditorContent(preview: workingPreview, mapping: $workingMapping)
            footer
        }
        .padding(24)
        .frame(minWidth: 720, minHeight: 480)
        .onChange(of: workingMapping) { _, newValue in
            workingPreview = originalPreview.applying(mapping: newValue)
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

    private func resetMapping() {
        workingPreview = originalPreview
        workingMapping = originalPreview.mapping
    }
}
