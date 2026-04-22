import Domain
import SwiftUI

struct AccountCreationSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var institutionName = ""
    @State private var kind = AccountKind.checking
    @State private var errorMessage: String?

    let onCreate: (String, AccountKind, String?) throws -> Void

    var body: some View {
        AccountDraftEditorForm(
            name: $name,
            institutionName: $institutionName,
            kind: $kind,
            title: "Create Account",
            submitTitle: "Create",
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
            try onCreate(
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

struct AccountDraftEditorForm: View {
    @Binding var name: String
    @Binding var institutionName: String
    @Binding var kind: AccountKind

    let title: String
    let submitTitle: String
    let errorMessage: String?
    let onCancel: () -> Void
    let onSubmit: () -> Void

    @FocusState private var focusedField: Field?

    private enum Field {
        case name
        case institution
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(title)
                    .font(.title2.bold())

                if let errorMessage, !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundStyle(.red)
                }

                Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 14) {
                    GridRow {
                        Text("Name")
                        TextField("Account name", text: $name)
                            .focused($focusedField, equals: .name)
                    }

                    GridRow {
                        Text("Institution")
                        TextField("Optional", text: $institutionName)
                            .focused($focusedField, equals: .institution)
                    }

                    GridRow {
                        Text("Kind")
                        Picker("Kind", selection: $kind) {
                            ForEach(AccountKind.allCases, id: \.self) { kind in
                                Text(kind.title).tag(kind)
                            }
                        }
                        .labelsHidden()
                    }
                }

                HStack {
                    Spacer()

                    Button("Cancel") {
                        onCancel()
                    }

                    Button(submitTitle) {
                        onSubmit()
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .padding(24)
        .frame(minWidth: 420, idealWidth: 480, maxWidth: 620, minHeight: 260)
        .onAppear {
            focusedField = .name
        }
    }
}
