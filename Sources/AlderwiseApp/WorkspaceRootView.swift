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
        .sheet(isPresented: $model.isPresentingImportPreview) {
            if let preview = model.csvImportPreview {
                CSVImportPreviewSheet(preview: preview)
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
            SectionPlaceholderView(section: section, snapshot: snapshot)
        }
    }
}
