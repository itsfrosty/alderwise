import Application
import Domain
import SwiftUI

extension TransactionLedgerView {
    struct DetailInspector: View {
        let detail: TransactionDetail?
        let categories: [BudgetCategory]
        let categoryGroups: [BudgetCategoryGroup]
        var onSave: (TransactionLedgerEditDraft) -> Void
        @State private var merchantName = ""
        @State private var categoryID: UUID?
        @State private var notes = ""

        var body: some View {
            Group {
                if let detail {
                    Form {
                        Section("Editable Fields") {
                            TextField("Merchant", text: $merchantName)
                            GroupedCategoryPicker(
                                title: "Category",
                                prompt: "Uncategorized",
                                categories: categories,
                                categoryGroups: categoryGroups,
                                selection: $categoryID
                            )
                            TextField("Notes", text: $notes, axis: .vertical)
                                .lineLimit(3, reservesSpace: true)
                            Button {
                                onSave(
                                    TransactionLedgerEditDraft(
                                        merchantName: merchantName,
                                        categoryID: categoryID,
                                        notes: notes
                                    )
                                )
                            } label: {
                                Label("Save Changes", systemImage: "checkmark")
                            }
                            .keyboardShortcut("s", modifiers: [.command])
                        }

                        Section("Explanation") {
                            LabeledContent("Account", value: detail.row.accountName)
                            LabeledContent("Source", value: ReviewPresentation.sourceLabel(for: detail.decisionSource))
                            if let reference = detail.decisionSourceReference {
                                LabeledContent("Rule", value: reference)
                            }
                            if let confidence = detail.confidence {
                                LabeledContent("Confidence", value: confidence.formatted(.percent.precision(.fractionLength(0...1))))
                            }
                            LabeledContent("Review", value: detail.row.reviewStatus.rawValue.capitalized)
                            LabeledContent("Duplicate", value: detail.duplicateStatus.capitalized)
                        }

                        Section("Import Origin") {
                            if let origin = detail.importOrigin {
                                LabeledContent("File", value: origin.originalFilename)
                                LabeledContent("Imported", value: origin.importedAt.formatted(date: .abbreviated, time: .shortened))
                                LabeledContent("Session", value: "\(origin.id)")
                            } else {
                                Text("This transaction is not linked to an import session.")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .formStyle(.grouped)
                    .onAppear {
                        load(detail)
                    }
                    .onChange(of: detail) { _, newDetail in
                        load(newDetail)
                    }
                } else {
                    ContentUnavailableView(
                        "No Transaction Selected",
                        systemImage: "sidebar.right",
                        description: Text("Select a transaction to inspect its source and edit trusted fields.")
                    )
                }
            }
            .padding()
        }

        private func load(_ detail: TransactionDetail) {
            merchantName = detail.row.merchantName
            categoryID = detail.row.categoryID
            notes = detail.notes ?? ""
        }
    }
}
