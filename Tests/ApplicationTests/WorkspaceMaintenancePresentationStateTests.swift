import Application
import Domain
import Foundation
import Testing

@Test
func workspaceMaintenanceAlertStateFormatsBackupSuccess() {
    let backupURL = URL(fileURLWithPath: "/tmp/test-backup.sqlite")
    let state = WorkspaceMaintenanceAlertState.current(
        outcome: .backupCreated(
            WorkspaceBackup(
                fileURL: backupURL,
                createdAt: Date(timeIntervalSince1970: 1_775_171_200),
                sizeBytes: 4096
            )
        ),
        failure: nil
    )

    #expect(state?.title == "Workspace Updated")
    #expect(state?.message == "Backup created:\n\(backupURL.path)")
    #expect(state?.revealURL == backupURL)
}

@Test
func workspaceMaintenanceAlertStateFormatsFailures() {
    let state = WorkspaceMaintenanceAlertState.current(
        outcome: nil,
        failure: WorkspaceMaintenanceFailure(
            operation: .backup,
            message: "Disk is full."
        )
    )

    #expect(state?.title == "Workspace Maintenance Failed")
    #expect(state?.message == "Disk is full.")
    #expect(state?.revealURL == nil)
}

@Test
func workspaceMaintenanceConfirmationStateFormatsResetAction() {
    let state = WorkspaceMaintenanceConfirmationState.current(action: .reset)

    #expect(state?.title == "Reset Workspace?")
    #expect(state?.confirmLabel == "Reset Workspace")
    #expect(state?.message.contains("mandatory backup") == true)
}

@Test
func workspaceMaintenanceConfirmationStateFormatsRestoreAction() {
    let backupURL = URL(fileURLWithPath: "/tmp/incoming-backup.sqlite")
    let state = WorkspaceMaintenanceConfirmationState.current(action: .restoreBackup(backupURL))

    #expect(state?.title == "Restore Workspace Backup?")
    #expect(state?.confirmLabel == "Overwrite Workspace")
    #expect(state?.message.contains(backupURL.lastPathComponent) == true)
}
