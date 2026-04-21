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
                Button("Create Backup") {
                    model.createWorkspaceBackup()
                }
                .buttonStyle(.borderedProminent)

                Button("Restore Backup") {
                    model.beginWorkspaceRestore()
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var suggestionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Suggestions")
                .font(.headline)
            LabeledContent("Local suggestion layer", value: "Unavailable")
            LabeledContent("Import behavior", value: "Rules and heuristics only")
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
