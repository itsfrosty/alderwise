import Domain
import SwiftUI

struct AccountCreationSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var institutionName = ""
    @State private var kind = AccountKind.checking
    @FocusState private var focusedField: Field?

    let onCreate: (String, AccountKind, String?) -> Void

    private enum Field {
        case name
        case institution
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Create Account")
                    .font(.title2.bold())

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
                        dismiss()
                    }

                    Button {
                        onCreate(name, kind, institutionName.isEmpty ? nil : institutionName)
                        dismiss()
                    } label: {
                        Label("Create", systemImage: "plus")
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
