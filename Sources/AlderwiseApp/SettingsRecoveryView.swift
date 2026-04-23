import Application
import SwiftUI

struct SettingsRecoveryView: View {
    @ObservedObject var model: WorkspaceShellModel
    let presentation: SettingsPresentation

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text(presentation.recovery.title)
                    .font(.largeTitle.bold())

                backupAndRestoreSection
                resetSection

                Spacer(minLength: 0)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    private var backupAndRestoreSection: some View {
        let section = presentation.recovery.primaryActions

        return SettingsSurface(
            title: section.title,
            helperText: section.helperText,
            emphasis: section.emphasis
        ) {
            Text("A restore creates a safety backup of the current workspace before Alderwise replaces it with the selected backup file.")
                .foregroundStyle(.secondary)

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

    private var resetSection: some View {
        let section = presentation.recovery.reset

        return SettingsSurface(
            title: section.title,
            helperText: section.helperText,
            emphasis: section.emphasis
        ) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Reset is intentionally separated from backup and restore because it removes workspace data from this Mac.")
                Text("If Alderwise cannot create the required backup first, reset stays blocked.")
                    .foregroundStyle(.secondary)
            }

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
}
