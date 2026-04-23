import Application
import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: WorkspaceShellModel

    var body: some View {
        Group {
            switch model.settingsDestination {
            case .overview:
                SettingsOverviewView(model: model, presentation: presentation)
            case .backupsAndRecovery:
                SettingsRecoveryView(model: model, presentation: presentation)
            case .rules(let destination):
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

    private var presentation: SettingsPresentation {
        SettingsPresentation(workspaceStatus: model.workspaceStatus)
    }
}
