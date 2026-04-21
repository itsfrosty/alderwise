import Domain
import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: WorkspaceShellModel

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Settings")
                .font(.largeTitle.bold())

            workspaceSection
            suggestionsSection

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var workspaceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Workspace")
                .font(.headline)

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                GridRow {
                    Text("Database")
                        .foregroundStyle(.secondary)
                    Text(model.workspaceMetadata?.databaseURL.path ?? "Unavailable")
                        .textSelection(.enabled)
                }
                GridRow {
                    Text("Size")
                        .foregroundStyle(.secondary)
                    Text(byteCount(model.workspaceMetadata?.databaseSizeBytes ?? 0))
                }
                GridRow {
                    Text("Modified")
                        .foregroundStyle(.secondary)
                    Text(dateText(model.workspaceMetadata?.modifiedAt))
                }
            }

            HStack(spacing: 12) {
                Button {
                    model.createWorkspaceBackup()
                } label: {
                    Label("Create Backup", systemImage: "externaldrive.badge.plus")
                }
                .buttonStyle(.borderedProminent)

                Button {
                    model.beginWorkspaceRestore()
                } label: {
                    Label("Restore Backup", systemImage: "externaldrive.badge.arrowtriangle.2.circlepath")
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var suggestionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Suggestions")
                .font(.headline)

            Toggle(
                "Allow local suggestions when available",
                isOn: Binding(
                    get: { model.workspacePreferences.suggestionsEnabled },
                    set: { model.updateSuggestionsEnabled($0) }
                )
            )

            LabeledContent("Local suggestion layer", value: model.workspacePreferences.suggestionsEnabled ? "Enabled" : "Disabled")
            LabeledContent("Import behavior", value: model.workspacePreferences.suggestionsEnabled ? "Rules, heuristics, and suggestions" : "Rules and heuristics only")
        }
    }

    private func byteCount(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    private func dateText(_ date: Date?) -> String {
        guard let date else {
            return "Unavailable"
        }

        return date.formatted(date: .abbreviated, time: .shortened)
    }
}
