import AppKit
import Application
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
                _ = try model.createAccount(
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
                    _ = try model.createMonthlyTarget(draft)
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
                switch selectedFileURL(from: result) {
                case .success(let backupURL):
                    model.beginWorkspaceRestoreConfirmation(backupURL: backupURL)
                case .failure(let error):
                    model.recordWorkspaceRestoreSelectionFailure(error: error)
                }
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
                    accounts: model.snapshot.importEligibleAccounts,
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
                model.beginAccountCreation()
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
                        model.retryFailedWorkspaceRecovery()
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
            .modifier(WorkspaceMaintenanceFeedbackModifier(model: model))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .loading:
            ProgressView("Loading workspace…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .loaded(let snapshot):
            if section == .home {
                HomeDashboardView(
                    snapshot: snapshot,
                    navigate: routeHomeDestination
                )
            } else if WorkspaceDetailRoute.make(for: section) == .transactions {
                TransactionLedgerView(snapshot: snapshot, model: model)
            } else if WorkspaceDetailRoute.make(for: section) == .review {
                ReviewQueueView(snapshot: snapshot, model: model)
            } else if WorkspaceDetailRoute.make(for: section) == .targetsManager {
                TargetsManagementView(
                    targets: model.managedTargets,
                    categories: snapshot.categories,
                    categoryGroups: snapshot.categoryGroups,
                    monthStart: snapshot.monthlyReport.monthStart,
                    selectedTargetID: Binding(
                        get: { model.selectedTargetID },
                        set: { model.selectTarget(id: $0) }
                    ),
                    onCreate: {
                        model.beginTargetCreation()
                    },
                    onSaveEdit: { id, draft in
                        try model.updateMonthlyTarget(id: id, draft: draft)
                    },
                    onDelete: { id in
                        try model.deleteMonthlyTarget(id: id)
                    },
                    onViewTransactions: routeToTransactions
                )
            } else if WorkspaceDetailRoute.make(for: section) == .settings {
                SettingsView(model: model)
            } else if WorkspaceDetailRoute.make(for: section) == .accountsManager {
                AccountsManagementView(
                    accounts: snapshot.managementAccounts,
                    permanentlyDeletableAccountIDs: snapshot.permanentlyDeletableAccountIDs,
                    onCreate: {
                        model.beginAccountCreation()
                    },
                    onSaveEdit: { id, name, kind, institutionName in
                        try model.updateAccount(
                            id: id,
                            name: name,
                            kind: kind,
                            institutionName: institutionName
                        )
                    },
                    onArchive: { id in
                        try model.archiveAccount(id: id)
                    },
                    onRestore: { id in
                        try model.restoreAccount(id: id)
                    },
                    onDeletePermanently: { id in
                        try model.deleteAccountPermanently(id: id)
                    }
                )
            } else {
                SectionPlaceholderView(section: section, snapshot: snapshot)
            }
        }
    }

    private func routeHomeDestination(_ destination: HomeDashboardDestination) {
        route(intent: destination.workspaceNavigationIntent)
    }

    private func routeToTransactions(_ filter: TransactionLedgerFilter) {
        selectedSectionRawValue = AppSection.transactions.rawValue
        model.updateTransactionFilter(filter)
    }

    private func route(intent: WorkspaceNavigationIntent) {
        selectedSectionRawValue = intent.section.rawValue
        model.selectTarget(id: intent.targetID)
        if let filter = intent.transactionFilter {
            model.updateTransactionFilter(filter)
        }
    }
}
