import Application
import Domain
import Foundation
import Testing

@Test
func overviewHealthStatusUsesHealthyAndRecoveryNeededCopy() {
    let healthyPresentation = SettingsPresentation(
        workspaceStatus: .available(makeWorkspaceMetadata())
    )
    let recoveryPresentation = SettingsPresentation(
        workspaceStatus: .failedToOpen("The workspace file could not be opened.")
    )

    #expect(healthyPresentation.overview.healthStatus.state == .healthy)
    #expect(healthyPresentation.overview.healthStatus.title == "Workspace looks healthy")
    #expect(recoveryPresentation.overview.healthStatus.state == .recoveryNeeded)
    #expect(recoveryPresentation.overview.healthStatus.title == "Workspace needs recovery")
}

@Test
func overviewPromotesBackupAndRestoreAsPrimaryActions() {
    let presentation = SettingsPresentation(
        workspaceStatus: .available(makeWorkspaceMetadata())
    )

    #expect(presentation.overview.primaryActions.title == "Protect and recover your workspace")
    #expect(
        presentation.overview.primaryActions.actions.map(\.title) == [
            "Create Backup",
            "Restore Backup",
        ]
    )
}

@Test
func overviewKeepsAutomationAndDiagnosticsAsSecondarySections() {
    let presentation = SettingsPresentation(
        workspaceStatus: .available(makeWorkspaceMetadata())
    )

    #expect(presentation.overview.rules.title == "Rules")
    #expect(
        presentation.overview.secondarySections.map(\.title) == [
            "Import Automation",
            "Advanced Details",
        ]
    )
    #expect(presentation.overview.secondarySections.allSatisfy { $0.emphasis == .secondary })
}

@Test
func recoveryTreatsResetAsALastResortAction() {
    let presentation = SettingsPresentation(
        workspaceStatus: .available(makeWorkspaceMetadata())
    )

    #expect(
        presentation.recovery.primaryActions.actions.map(\.title) == [
            "Create Backup",
            "Restore Backup",
        ]
    )
    #expect(presentation.recovery.reset.title == "Last Resort Reset")
    #expect(presentation.recovery.reset.actions.map(\.title) == ["Reset Workspace"])
    #expect(presentation.recovery.reset.emphasis == .caution)
}

@Test
func settingsCopyDoesNotImplyDurableBackupHistory() {
    let presentation = SettingsPresentation(
        workspaceStatus: .available(makeWorkspaceMetadata())
    )

    let helperTexts = [
        presentation.overview.primaryActions.helperText,
        presentation.overview.rules.helperText,
        presentation.overview.secondarySections[0].helperText,
        presentation.overview.secondarySections[1].helperText,
        presentation.recovery.primaryActions.helperText,
        presentation.recovery.reset.helperText,
    ]

    for text in helperTexts {
        #expect(text.localizedCaseInsensitiveContains("history") == false)
        #expect(text.localizedCaseInsensitiveContains("snapshot") == false)
        #expect(text.localizedCaseInsensitiveContains("versioned") == false)
    }
}

private func makeWorkspaceMetadata() -> WorkspaceMetadata {
    WorkspaceMetadata(
        databaseURL: URL(fileURLWithPath: "/tmp/Alderwise.sqlite"),
        databaseExists: true,
        databaseSizeBytes: 4_096,
        modifiedAt: Date(timeIntervalSince1970: 1_777_363_200)
    )
}
