import Application
import AppKit
import SwiftUI

struct SettingsOverviewView: View {
    static let resetSupportNote = "A backup is created first. If that backup fails, reset won't continue."

    @ObservedObject var model: WorkspaceShellModel
    let presentation: SettingsPresentation

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Settings")
                    .font(.largeTitle.bold())

                healthSection
                primaryActionsSection
                importAutomationSection
                advancedDetailsSection
                resetSection

                Spacer(minLength: 0)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    private var healthSection: some View {
        let healthStatus = presentation.overview.healthStatus

        return SettingsSurface(
            title: presentation.overview.healthSectionTitle,
            helperText: healthStatus.detail,
            emphasis: colorEmphasis(for: healthStatus.state)
        ) {
            Label(healthStatus.title, systemImage: healthStatus.systemImage)
                .font(.headline)
        }
    }

    private var primaryActionsSection: some View {
        let section = presentation.overview.primaryActions

        return SettingsSurface(
            title: section.title,
            helperText: section.helperText,
            emphasis: section.emphasis
        ) {
            HStack(spacing: 12) {
                if let createBackupAction = section.action(id: .createBackup) {
                    Button {
                        model.createWorkspaceBackup()
                    } label: {
                        Label(createBackupAction.title, systemImage: createBackupAction.systemImage)
                    }
                    .buttonStyle(.borderedProminent)
                }

                if let restoreBackupAction = section.action(id: .restoreBackup) {
                    Button {
                        model.beginWorkspaceRestore()
                    } label: {
                        Label(restoreBackupAction.title, systemImage: restoreBackupAction.systemImage)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private var importAutomationSection: some View {
        let section = presentation.overview.secondarySections[0]

        return SettingsSurface(
            title: section.title,
            helperText: section.helperText,
            emphasis: section.emphasis
        ) {
            VStack(alignment: .leading, spacing: 10) {
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

                LabeledContent(
                    "Local suggestion layer",
                    value: model.workspacePreferences.suggestionsEnabled ? "Enabled" : "Disabled"
                )
                LabeledContent(
                    "Starter auto-accept",
                    value: model.workspacePreferences.seededHeuristicAutoAcceptEnabled
                        ? "Seeded rules and heuristics"
                        : "Seeded rules only"
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
    }

    private var advancedDetailsSection: some View {
        let section = presentation.overview.secondarySections[1]

        return SettingsSurface(
            title: section.title,
            helperText: section.helperText,
            emphasis: section.emphasis
        ) {
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                GridRow {
                    Text("Health")
                        .foregroundStyle(.secondary)
                    Text(presentation.overview.healthStatus.title)
                }
                GridRow {
                    Text("Location")
                        .foregroundStyle(.secondary)
                    Text(workspaceLocationText)
                        .textSelection(.enabled)
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

            Button {
                revealInFinder(model.workspaceMetadata?.databaseURL)
            } label: {
                Label("Reveal in Finder", systemImage: "folder")
            }
            .buttonStyle(.bordered)
            .disabled(model.workspaceMetadata?.databaseURL == nil)
        }
    }

    private var resetSection: some View {
        let section = presentation.recovery.reset

        return SettingsSurface(
            title: section.title,
            helperText: section.helperText,
            emphasis: section.emphasis
        ) {
            Text(Self.resetSupportNote)
                .foregroundStyle(.secondary)

            if let resetAction = section.action(id: .resetWorkspace) {
                Button(role: .destructive) {
                    model.beginWorkspaceResetConfirmation()
                } label: {
                    Label(resetAction.title, systemImage: resetAction.systemImage)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
        }
    }

    private var workspaceLocationText: String {
        model.workspaceMetadata?.databaseURL.path ?? "Location unavailable"
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

    private func colorEmphasis(for state: SettingsPresentation.HealthStatus.State) -> SettingsPresentation.Emphasis {
        switch state {
        case .healthy:
            return .primary
        case .checking:
            return .secondary
        case .recoveryNeeded:
            return .caution
        }
    }
}

struct SettingsSurface<Content: View>: View {
    let title: String
    let helperText: String
    let emphasis: SettingsPresentation.Emphasis
    let content: Content

    init(
        title: String,
        helperText: String,
        emphasis: SettingsPresentation.Emphasis,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.helperText = helperText
        self.emphasis = emphasis
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundStyle(headerColor)

            Text(helperText)
                .foregroundStyle(.secondary)

            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(background)
        .overlay(border)
    }

    private var headerColor: Color {
        switch emphasis {
        case .primary, .secondary:
            return .primary
        case .caution:
            return .red
        }
    }

    @ViewBuilder
    private var background: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(backgroundColor)
    }

    @ViewBuilder
    private var border: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .stroke(borderColor, lineWidth: 1)
    }

    private var backgroundColor: Color {
        switch emphasis {
        case .primary:
            return .accentColor.opacity(0.08)
        case .secondary:
            return Color.secondary.opacity(0.08)
        case .caution:
            return .red.opacity(0.08)
        }
    }

    private var borderColor: Color {
        switch emphasis {
        case .primary:
            return .accentColor.opacity(0.25)
        case .secondary:
            return Color.secondary.opacity(0.2)
        case .caution:
            return .red.opacity(0.25)
        }
    }
}
