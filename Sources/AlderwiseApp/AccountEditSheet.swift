import Domain
import SwiftUI

struct AccountEditSheet: View {
    @Environment(\.dismiss) private var dismiss

    let account: Account
    let onSave: (String, AccountKind, String?) throws -> Void

    @State private var name: String
    @State private var institutionName: String
    @State private var kind: AccountKind
    @State private var errorMessage: String?

    init(
        account: Account,
        onSave: @escaping (String, AccountKind, String?) throws -> Void
    ) {
        self.account = account
        self.onSave = onSave
        _name = State(initialValue: account.name)
        _institutionName = State(initialValue: account.institutionName ?? "")
        _kind = State(initialValue: account.kind)
    }

    var body: some View {
        AccountDraftEditorForm(
            name: $name,
            institutionName: $institutionName,
            kind: $kind,
            title: "Edit Account",
            submitTitle: "Save",
            errorMessage: errorMessage,
            onCancel: {
                dismiss()
            },
            onSubmit: submit
        )
    }

    private func submit() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = "Enter an account name."
            return
        }

        do {
            try onSave(
                trimmedName,
                kind,
                optionalTrimmedInstitutionName
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private var optionalTrimmedInstitutionName: String? {
        let trimmed = institutionName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
