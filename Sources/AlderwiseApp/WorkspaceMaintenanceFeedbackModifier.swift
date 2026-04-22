import AppKit
import Application
import SwiftUI

struct WorkspaceMaintenanceFeedbackModifier: ViewModifier {
    @ObservedObject var model: WorkspaceShellModel

    func body(content: Content) -> some View {
        let confirmationState = WorkspaceMaintenanceConfirmationState.current(action: model.pendingMaintenanceAction)
        let alertState = WorkspaceMaintenanceAlertState.current(
            outcome: model.latestMaintenanceOutcome,
            failure: model.latestMaintenanceFailure
        )

        return content
            .confirmationDialog(
                confirmationState?.title ?? "Workspace",
                isPresented: Binding(
                    get: { confirmationState != nil },
                    set: { isPresented in
                        if !isPresented {
                            model.cancelPendingMaintenanceAction()
                        }
                    }
                ),
                titleVisibility: .visible,
                presenting: confirmationState
            ) { state in
                Button("Cancel", role: .cancel) {
                    model.cancelPendingMaintenanceAction()
                }

                Button(state.confirmLabel, role: .destructive) {
                    model.confirmPendingMaintenanceAction()
                }
            } message: { state in
                Text(verbatim: state.message)
            }
            .alert(
                alertState?.title ?? "Workspace",
                isPresented: Binding(
                    get: { alertState != nil },
                    set: { isPresented in
                        if !isPresented {
                            dismissAlert()
                        }
                    }
                ),
                presenting: alertState
            ) { state in
                if let revealURL = state.revealURL {
                    Button("Reveal in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([revealURL])
                        dismissAlert()
                    }
                }

                Button("OK") {
                    dismissAlert()
                }
            } message: { state in
                Text(verbatim: state.message)
            }
    }

    private func dismissAlert() {
        if model.latestMaintenanceFailure != nil {
            model.dismissLatestMaintenanceFailure()
        } else if model.latestMaintenanceOutcome != nil {
            model.dismissLatestMaintenanceOutcome()
        }
    }
}
