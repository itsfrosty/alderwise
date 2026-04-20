import Domain
import SwiftUI

struct AccountCreationSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var institutionName = ""
    @State private var kind = AccountKind.checking

    let onCreate: (String, AccountKind, String?) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Create Account")
                .font(.title2.bold())

            TextField("Account name", text: $name)

            TextField("Institution name (optional)", text: $institutionName)

            Picker("Kind", selection: $kind) {
                ForEach(AccountKind.allCases, id: \.self) { kind in
                    Text(kind.title).tag(kind)
                }
            }

            HStack {
                Spacer()

                Button("Cancel") {
                    dismiss()
                }

                Button("Create") {
                    onCreate(name, kind, institutionName.isEmpty ? nil : institutionName)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 420)
    }
}
