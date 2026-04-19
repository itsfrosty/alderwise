import Domain
import SwiftUI

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
        .toolbar {
            ToolbarItemGroup {
                Button("Import CSV") {}
                    .keyboardShortcut("i", modifiers: [.command])
                Button("Create Account") {
                    model.addSampleAccount()
                }
                .keyboardShortcut("n", modifiers: [.command])
            }
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
