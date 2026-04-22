import Application
import AppKit
import Domain
import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: WorkspaceShellModel

    var body: some View {
        Group {
            switch model.settingsDestination {
            case .overview:
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        Text("Settings")
                            .font(.largeTitle.bold())

                        workspaceSection
                        backupAndRecoverySection
                        dangerZoneSection
                        suggestionsSection
                            .padding(.top, 8)
                        learnedRulesSection

                        Spacer(minLength: 0)
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            case .learnedRules(let destination):
                LearnedRulesManagerView(
                    model: model,
                    destination: destination,
                    categories: model.snapshot.categories,
                    snapshot: model.learnedRuleManagerSnapshot
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .modifier(WorkspaceMaintenanceFeedbackModifier(model: model))
    }

    private var workspaceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Workspace")
                .font(.headline)

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                GridRow {
                    Text("Location")
                        .foregroundStyle(.secondary)
                    Text(workspaceLocationText)
                        .textSelection(.enabled)
                }
                GridRow {
                    Text("Status")
                        .foregroundStyle(.secondary)
                    statusLabel
                }
                GridRow {
                    Text("File Size")
                        .foregroundStyle(.secondary)
                    Text(byteCount(model.workspaceMetadata?.databaseSizeBytes ?? 0))
                }
                GridRow {
                    Text("Last Modified")
                        .foregroundStyle(.secondary)
                    Text(dateText(model.workspaceMetadata?.modifiedAt))
                }
            }

            HStack(spacing: 12) {
                Button {
                    revealInFinder(model.workspaceMetadata?.databaseURL)
                } label: {
                    Label("Reveal in Finder", systemImage: "folder")
                }
                .buttonStyle(.bordered)
                .disabled(model.workspaceMetadata?.databaseURL == nil)
            }
        }
    }

    private var backupAndRecoverySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Backup and Recovery")
                .font(.headline)

            Text("Create a backup before larger changes, or restore a previous workspace snapshot.")
                .foregroundStyle(.secondary)

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

    private var dangerZoneSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Danger Zone")
                .font(.headline)
                .foregroundStyle(.red)

            Text("Reset removes workspace data from this Mac and returns the workspace to a clean state.")
            Text("Reset is blocked if Alderwise cannot create the mandatory backup first.")
            Text("Reset affects workspace data only. External backup files stay where they are.")
                .foregroundStyle(.secondary)

            Button(role: .destructive) {
                model.beginWorkspaceResetConfirmation()
            } label: {
                Label("Reset Workspace", systemImage: "trash")
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.red.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.red.opacity(0.25), lineWidth: 1)
        )
    }

    private var suggestionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Suggestions")
                .font(.headline)

            Text("Lower-priority import assistance preferences for local matching and review automation.")
                .foregroundStyle(.secondary)

            Toggle(
                "Allow local suggestions when available",
                isOn: Binding(
                    get: { model.workspacePreferences.suggestionsEnabled },
                    set: { model.updateSuggestionsEnabled($0) }
                )
            )

            Toggle(
                "Auto-accept seeded heuristic matches",
                isOn: Binding(
                    get: { model.workspacePreferences.seededHeuristicAutoAcceptEnabled },
                    set: { model.updateSeededHeuristicAutoAcceptEnabled($0) }
                )
            )

            LabeledContent("Local suggestion layer", value: model.workspacePreferences.suggestionsEnabled ? "Enabled" : "Disabled")
            LabeledContent(
                "Starter auto-accept",
                value: model.workspacePreferences.seededHeuristicAutoAcceptEnabled ? "Seeded rules and heuristics" : "Seeded rules only"
            )
            LabeledContent(
                "Import behavior",
                value: model.workspacePreferences.suggestionsEnabled
                    ? "Rules, heuristics, and suggestions"
                    : "Rules and heuristics only"
            )
        }
        .foregroundStyle(.secondary)
    }

    private var learnedRulesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Rules")
                .font(.headline)

            Text("Browse learned rules alongside Alderwise's included deterministic rules and starter prefills.")
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button {
                    model.showLearnedRules()
                } label: {
                    Label("Open Rules", systemImage: "slider.horizontal.3")
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var workspaceLocationText: String {
        model.workspaceMetadata?.databaseURL.path ?? "Location unavailable"
    }

    @ViewBuilder
    private var statusLabel: some View {
        let descriptor = workspaceStatusDescriptor
        Label(descriptor.title, systemImage: descriptor.systemImage)
            .foregroundStyle(descriptor.color)
            .help(descriptor.detail)
    }

    private var workspaceStatusDescriptor: (title: String, detail: String, systemImage: String, color: Color) {
        switch model.workspaceStatus {
        case .loading:
            return (
                "Loading workspace metadata",
                "Alderwise is reading the current workspace state.",
                "clock.arrow.circlepath",
                .secondary
            )
        case .failedToOpen(let message):
            return (
                "Workspace needs recovery",
                message,
                "exclamationmark.triangle.fill",
                .red
            )
        case .available(let metadata):
            guard let metadata else {
                return (
                    "Workspace ready",
                    "The workspace opened, but metadata is still unavailable.",
                    "checkmark.circle.fill",
                    .green
                )
            }

            if metadata.databaseExists {
                return (
                    "Workspace file available",
                    "The current workspace file is present and readable.",
                    "checkmark.circle.fill",
                    .green
                )
            }

            return (
                "Workspace file missing",
                "The expected workspace path does not currently exist on disk.",
                "externaldrive.badge.exclamationmark",
                .orange
            )
        }
    }

    private func byteCount(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    private func dateText(_ date: Date?) -> String {
        guard let date else {
            return "Not available"
        }

        return date.formatted(date: .abbreviated, time: .shortened)
    }

    private func revealInFinder(_ url: URL?) {
        guard let url else {
            return
        }

        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}
