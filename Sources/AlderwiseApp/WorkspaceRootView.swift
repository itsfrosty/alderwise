import Domain
import SwiftUI
import UniformTypeIdentifiers

struct WorkspaceRootView: View {
    @ObservedObject var model: WorkspaceShellModel
    @AppStorage("selectedSidebarSection") private var selectedSectionRawValue = AppSection.home.rawValue

    private var selectedSectionBinding: Binding<AppSection?> {
        Binding(
            get: { AppSection(rawValue: selectedSectionRawValue) ?? .home },
            set: { selectedSectionRawValue = $0?.rawValue ?? AppSection.home.rawValue }
        )
    }

    var body: some View {
        NavigationSplitView {
            List(AppSection.allCases, selection: selectedSectionBinding) { section in
                Label(section.title, systemImage: section.systemImage)
                    .tag(section)
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 220)
        } detail: {
            detailView(for: AppSection(rawValue: selectedSectionRawValue) ?? .home)
        }
        .environmentObject(model)
        .toolbar {
            ToolbarItemGroup {
                Button("Review Queue") {
                    selectedSectionRawValue = AppSection.review.rawValue
                }
                .keyboardShortcut("r", modifiers: [.command])
                Button("Import CSV") {
                    model.beginCSVImport()
                }
                    .keyboardShortcut("i", modifiers: [.command])
                Button("Create Account") {
                    model.isPresentingAccountSheet = true
                }
                .keyboardShortcut("n", modifiers: [.command])
            }
        }
        .sheet(isPresented: $model.isPresentingAccountSheet) {
            AccountCreationSheet { name, kind, institutionName in
                model.createAccount(
                    name: name,
                    kind: kind,
                    institutionName: institutionName
                )
            }
        }
        .fileImporter(
            isPresented: $model.isPresentingCSVImporter,
            allowedContentTypes: [.commaSeparatedText, .plainText],
            allowsMultipleSelection: false
        ) { result in
            do {
                let urls = try result.get()
                guard let url = urls.first else {
                    throw CocoaError(.fileNoSuchFile)
                }
                model.importCSV(from: .success(url))
            } catch {
                model.importCSV(from: .failure(error))
            }
        }
        .sheet(
            isPresented: Binding(
                get: { model.isPresentingImportPreview },
                set: { isPresented in
                    if !isPresented {
                        model.dismissCSVImportPreview()
                    }
                }
            )
        ) {
            if let preview = model.csvImportPreview {
                CSVImportPreviewSheet(
                    preview: preview,
                    accounts: model.snapshot.accounts,
                    originalFilename: model.pendingCSVImport?.originalFilename ?? "CSV file",
                    onCancel: {
                        model.dismissCSVImportPreview()
                    },
                    onImport: { preview, account in
                        model.confirmCSVImport(preview: preview, account: account)
                    }
                )
            }
        }
        .alert(
            "Import Failed",
            isPresented: Binding(
                get: { model.importErrorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        model.importErrorMessage = nil
                    }
                }
            )
        ) {
            Button("OK") {
                model.importErrorMessage = nil
            }
        } message: {
            Text(model.importErrorMessage ?? "")
        }
        .alert(
            "Import Staged",
            isPresented: Binding(
                get: { model.importResultMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        model.importResultMessage = nil
                    }
                }
            )
        ) {
            Button("OK") {
                model.importResultMessage = nil
            }
        } message: {
            Text(model.importResultMessage ?? "")
        }
    }

    @ViewBuilder
    private func detailView(for section: AppSection) -> some View {
        switch model.state {
        case .failed(let message):
            ContentUnavailableView(
                "Workspace Unavailable",
                systemImage: "externaldrive.badge.exclamationmark",
                description: Text(message)
            )
        case .loading:
            ProgressView("Loading workspace…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .loaded(let snapshot):
            if section == .transactions {
                TransactionLedgerView(snapshot: snapshot, model: model)
            } else {
                SectionPlaceholderView(section: section, snapshot: snapshot)
            }
        }
    }
}
