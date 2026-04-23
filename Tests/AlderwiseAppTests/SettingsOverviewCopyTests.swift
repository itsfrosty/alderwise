import Testing

@testable import AlderwiseApp

@Test
@MainActor
func settingsOverviewResetGuidanceUsesProductLanguage() {
    #expect(
        SettingsOverviewView.resetSupportNote
            == "A backup is created first. If that backup fails, reset won't continue."
    )
}
