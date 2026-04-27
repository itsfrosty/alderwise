import Application
import Domain
import SwiftUI

struct BatchCSVImportPreflightSheet: View {
    @ObservedObject var session: BatchCSVImportSession
    let accounts: [Account]
    let onCreateAccount: (UUID) -> Void
    let onCancel: () -> Void
    let onImportAll: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            NavigationSplitView {
                List(selection: selectionBinding) {
                    ForEach(session.draft.items) { item in
                        sidebarRow(for: item)
                            .tag(Optional(item.id))
                    }
                }
                .navigationSplitViewColumnWidth(min: 240, ideal: 280)
            } detail: {
                detailPane
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }

            Divider()
            footer
        }
        .frame(minWidth: 920, minHeight: 620)
    }

    private var accountsByID: [UUID: Account] {
        Dictionary(uniqueKeysWithValues: accounts.map { ($0.id, $0) })
    }

    private var selectionBinding: Binding<UUID?> {
        Binding(
            get: { session.draft.selectedItemID },
            set: { session.selectItem(id: $0) }
        )
    }

    @ViewBuilder
    private func sidebarRow(for item: BatchCSVImportItemDraft) -> some View {
        let detailPresentation = item.sidebarDetailPresentation(using: accountsByID)

        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(item.originalFilename)
                    .font(.body.weight(.medium))
                    .lineLimit(1)

                Spacer(minLength: 8)
                Text(item.statusText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(statusColor(for: item))
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                HStack(spacing: 4) {
                    Text(detailPresentation.accountLabel)
                    if let confidenceLabel = detailPresentation.confidenceLabel {
                        Text("·")
                        Text(confidenceLabel)
                            .fontWeight(.semibold)
                    }
                }
                .lineLimit(1)

                Spacer(minLength: 8)

                Text(detailPresentation.trailingSummary)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var detailPane: some View {
        if let item = session.draft.selectedItem {
            switch item.content {
            case .loaded(_, let preview):
                loadedDetail(for: item, preview: preview)
            case .loadFailed(let message):
                loadFailureDetail(for: item, message: message)
            }
        } else {
            ContentUnavailableView(
                "No File Selected",
                systemImage: "doc.text",
                description: Text("Choose a CSV from the batch to review its mapping and validation details.")
            )
        }
    }

    private func loadedDetail(for item: BatchCSVImportItemDraft, preview: CSVImportPreview) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                detailHeader(for: item)
                accountSection(for: item)
                CSVImportPreviewEditorContent(
                    preview: currentPreview(for: item) ?? preview,
                    mapping: mappingBinding(for: item, preview: preview)
                )
            }
            .padding(24)
        }
    }

    private func loadFailureDetail(for item: BatchCSVImportItemDraft, message: String) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            detailHeader(for: item)

            VStack(alignment: .leading, spacing: 12) {
                Label("This file could not be loaded.", systemImage: "exclamationmark.triangle")
                    .font(.headline)
                    .foregroundStyle(.orange)
                Text(message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            Button("Remove From Batch", role: .destructive) {
                removeItem(item.id)
            }

            Spacer()
        }
        .padding(24)
    }

    private func detailHeader(for item: BatchCSVImportItemDraft) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text(item.originalFilename)
                    .font(.title2.bold())
                Text(item.statusText)
                    .font(.subheadline)
                    .foregroundStyle(statusColor(for: item))
            }

            Spacer(minLength: 16)

            Button("Remove From Batch", role: .destructive) {
                removeItem(item.id)
            }
        }
    }

    private func accountSection(for item: BatchCSVImportItemDraft) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Destination Account")
                    .font(.headline)
                Spacer()
                Button("Create Account") {
                    onCreateAccount(item.id)
                }
            }

            Picker("Account", selection: accountBinding(for: item)) {
                Text("Choose Account").tag(nil as UUID?)
                ForEach(accounts) { account in
                    Text(accountLabel(for: account)).tag(account.id as UUID?)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)

            if let confidenceLabel = item.confidenceLabel {
                Text(confidenceLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            if let inferenceExplanationText = item.inferenceExplanationText {
                Text(inferenceExplanationText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if accounts.isEmpty {
                Text("Create an account before importing this file.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            } else if item.selectedAccountID == nil {
                Text("Select an account for this file.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var footer: some View {
        HStack {
            if session.importPhase == .staging {
                ProgressView()
                    .controlSize(.small)
            }

            Spacer()

            Button("Cancel") {
                onCancel()
                dismiss()
            }
            .keyboardShortcut(.cancelAction)

            if canImportAll {
                Button {
                    onImportAll()
                } label: {
                    Label("Import All", systemImage: "tray.and.arrow.down")
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            } else {
                Button {
                    onImportAll()
                } label: {
                    Label("Import All", systemImage: "tray.and.arrow.down")
                }
                .buttonStyle(.borderedProminent)
                .disabled(true)
            }
        }
        .padding(20)
    }

    private var canImportAll: Bool {
        session.draft.isReadyForImport && session.importPhase != .staging
    }

    private func currentPreview(for item: BatchCSVImportItemDraft) -> CSVImportPreview? {
        session.draft.items.first(where: { $0.id == item.id })?.preview
    }

    private func accountBinding(for item: BatchCSVImportItemDraft) -> Binding<UUID?> {
        Binding(
            get: { session.draft.items.first(where: { $0.id == item.id })?.selectedAccountID },
            set: { newValue in
                _ = session.setSelectedAccount(id: newValue, forItemID: item.id)
            }
        )
    }

    private func mappingBinding(for item: BatchCSVImportItemDraft, preview: CSVImportPreview) -> Binding<CSVColumnMapping> {
        Binding(
            get: { session.draft.items.first(where: { $0.id == item.id })?.preview?.mapping ?? preview.mapping },
            set: { newValue in
                _ = session.updateMapping(newValue, forItemID: item.id)
            }
        )
    }
    private func statusColor(for item: BatchCSVImportItemDraft) -> Color {
        switch item.statusText {
        case "Ready":
            return .green
        case "Error":
            return .orange
        default:
            return .secondary
        }
    }

    private func accountLabel(for account: Account) -> String {
        if let institutionName = account.institutionName {
            return "\(account.name) · \(institutionName)"
        }

        return account.name
    }

    private func removeItem(_ itemID: UUID) {
        _ = session.removeItem(id: itemID)
        if session.draft.items.isEmpty {
            onCancel()
            dismiss()
        }
    }
}
