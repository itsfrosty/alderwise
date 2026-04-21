import Domain
import SwiftUI
import UniformTypeIdentifiers

struct WorkspaceRootView: View {
    @ObservedObject var model: WorkspaceShellModel
    @AppStorage("selectedSidebarSection") private var selectedSectionRawValue = AppSection.home.rawValue

    private static let sqliteWorkspaceType = UTType(filenameExtension: "sqlite") ?? .data

    private var fileImporterContentTypes: [UTType] {
        switch model.fileImportRequest {
        case .csv:
            [.commaSeparatedText, .plainText]
        case .workspaceRestore:
            [Self.sqliteWorkspaceType]
        case nil:
            [.data]
        }
    }

    private var selectedSection: AppSection {
        AppSection(rawValue: selectedSectionRawValue) ?? .home
    }

    private var selectedSectionBinding: Binding<AppSection> {
        Binding(
            get: { selectedSection },
            set: { selectedSectionRawValue = $0.rawValue }
        )
    }

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detailView(for: selectedSection)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .environmentObject(model)
        .toolbar {
            ToolbarItemGroup {
                toolbarActions
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
        .sheet(isPresented: $model.isPresentingTargetSheet) {
            TargetCreationSheet(
                categories: model.snapshot.categories,
                categoryGroups: model.snapshot.categoryGroups,
                onCancel: {
                    model.isPresentingTargetSheet = false
                },
                onCreate: { draft in
                    model.createMonthlyTarget(draft)
                }
            )
        }
        .fileImporter(
            isPresented: $model.isPresentingFileImporter,
            allowedContentTypes: fileImporterContentTypes,
            allowsMultipleSelection: false
        ) { result in
            let request = model.fileImportRequest
            model.fileImportRequest = nil
            model.isPresentingFileImporter = false

            switch request {
            case .csv:
                model.importCSV(from: selectedFileURL(from: result))
            case .workspaceRestore:
                model.restoreWorkspace(from: selectedFileURL(from: result))
            case nil:
                break
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
        .alert(
            "Transaction Detail Unavailable",
            isPresented: Binding(
                get: { model.transactionDetailErrorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        model.transactionDetailErrorMessage = nil
                    }
                }
            )
        ) {
            Button("OK") {
                model.transactionDetailErrorMessage = nil
            }
        } message: {
            Text(model.transactionDetailErrorMessage ?? "")
        }
        .alert(
            "Review Action Failed",
            isPresented: Binding(
                get: { model.reviewErrorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        model.reviewErrorMessage = nil
                    }
                }
            )
        ) {
            Button("OK") {
                model.reviewErrorMessage = nil
            }
        } message: {
            Text(model.reviewErrorMessage ?? "")
        }
        .alert(
            "Target Not Created",
            isPresented: Binding(
                get: { model.targetErrorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        model.targetErrorMessage = nil
                    }
                }
            )
        ) {
            Button("OK") {
                model.targetErrorMessage = nil
            }
        } message: {
            Text(model.targetErrorMessage ?? "")
        }
        .alert(
            "Sample Data",
            isPresented: Binding(
                get: { model.sampleDataMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        model.sampleDataMessage = nil
                    }
                }
            )
        ) {
            Button("OK") {
                model.sampleDataMessage = nil
            }
        } message: {
            Text(model.sampleDataMessage ?? "")
        }
        .alert(
            "Workspace Updated",
            isPresented: Binding(
                get: { model.workspaceMaintenanceMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        model.workspaceMaintenanceMessage = nil
                    }
                }
            )
        ) {
            Button("OK") {
                model.workspaceMaintenanceMessage = nil
            }
        } message: {
            Text(model.workspaceMaintenanceMessage ?? "")
        }
        .alert(
            "Workspace Maintenance Failed",
            isPresented: Binding(
                get: { model.workspaceMaintenanceErrorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        model.workspaceMaintenanceErrorMessage = nil
                    }
                }
            )
        ) {
            Button("OK") {
                model.workspaceMaintenanceErrorMessage = nil
            }
        } message: {
            Text(model.workspaceMaintenanceErrorMessage ?? "")
        }
    }

    private var sidebar: some View {
        List(selection: selectedSectionBinding) {
            ForEach(AppSection.allCases) { section in
                Label(section.title, systemImage: section.systemImage)
                    .tag(section)
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 200, ideal: 220)
    }

    private func selectedFileURL(from result: Result<[URL], Error>) -> Result<URL, Error> {
        do {
            let urls = try result.get()
            guard let url = urls.first else {
                throw CocoaError(.fileNoSuchFile)
            }
            return .success(url)
        } catch {
            return .failure(error)
        }
    }

    @ViewBuilder
    private var toolbarActions: some View {
        Button {
            selectedSectionRawValue = AppSection.review.rawValue
        } label: {
            Label("Review", systemImage: "checklist")
        }
        .keyboardShortcut("r", modifiers: [.command])

        switch selectedSection {
        case .home, .transactions, .review:
            Button {
                model.beginCSVImport()
            } label: {
                Label("Import CSV", systemImage: "square.and.arrow.down")
            }
            .keyboardShortcut("i", modifiers: [.command])
        case .targets:
            Button {
                model.beginTargetCreation()
            } label: {
                Label("Create Target", systemImage: "plus")
            }
            .keyboardShortcut("t", modifiers: [.command])
        case .accounts:
            Button {
                model.isPresentingAccountSheet = true
            } label: {
                Label("Create Account", systemImage: "plus")
            }
            .keyboardShortcut("n", modifiers: [.command])
        case .settings:
            Button {
                model.createWorkspaceBackup()
            } label: {
                Label("Back Up", systemImage: "externaldrive.badge.plus")
            }
        }
    }

    @ViewBuilder
    private func detailView(for section: AppSection) -> some View {
        switch model.state {
        case .failed(let message):
            VStack(spacing: 16) {
                ContentUnavailableView(
                    "Workspace Unavailable",
                    systemImage: "externaldrive.badge.exclamationmark",
                    description: Text("Alderwise could not open the local workspace. You can restore a backup or try again after checking file access.")
                )
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 560)
                HStack(spacing: 12) {
                    Button {
                        model.reload()
                    } label: {
                        Label("Try Again", systemImage: "arrow.clockwise")
                    }
                    Button {
                        model.beginWorkspaceRestore()
                    } label: {
                        Label("Restore Backup", systemImage: "externaldrive.badge.arrowtriangle.2.circlepath")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .loading:
            ProgressView("Loading workspace…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .loaded(let snapshot):
            if section == .transactions {
                TransactionLedgerView(snapshot: snapshot, model: model)
            } else if section == .review {
                ReviewQueueView(snapshot: snapshot, model: model)
            } else if section == .settings {
                SettingsView(model: model)
            } else {
                SectionPlaceholderView(section: section, snapshot: snapshot)
            }
        }
    }
}
