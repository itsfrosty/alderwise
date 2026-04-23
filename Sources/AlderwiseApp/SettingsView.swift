import Application
import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: WorkspaceShellModel

    var body: some View {
        SettingsOverviewView(model: model, presentation: presentation)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .modifier(WorkspaceMaintenanceFeedbackModifier(model: model))
    }

    private var presentation: SettingsPresentation {
        SettingsPresentation(workspaceStatus: model.workspaceStatus)
    }
}
