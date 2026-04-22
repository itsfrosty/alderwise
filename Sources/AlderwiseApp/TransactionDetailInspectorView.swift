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
                        Section {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(alignment: .top, spacing: 16) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Merchant")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text(merchantLabel(for: detail.row))
                                            .font(.title3.weight(.semibold))
                                            .lineLimit(2)
                                    }

                                    Spacer(minLength: 12)

                                    VStack(alignment: .trailing, spacing: 4) {
                                        Text("Amount")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text(amountText(for: detail.row))
                                            .font(.title3.weight(.semibold))
                                            .monospacedDigit()
                                            .lineLimit(1)
                                    }
                                }

                                Divider()

                                LabeledContent("Transaction Date", value: detail.row.transactionDate.formatted(date: .abbreviated, time: .omitted))
                                LabeledContent("Account", value: accountLabel(for: detail.row))
                                LabeledContent("Category", value: categoryLabel(for: detail.row))
                                LabeledContent("Direction", value: directionLabel(detail.row.direction))

                                Text("Read-only summary")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        } header: {
                            HStack {
                                Text("Transaction Summary")
                                Spacer()
                                Text("Read-only")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .textCase(nil)
                            }
                        }

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

                        Section("Trust Evidence") {
                            LabeledContent("Source", value: ReviewPresentation.sourceLabel(for: detail.decisionSource))
                            if let confidence = detail.confidence {
                                LabeledContent("Confidence", value: confidence.formatted(.percent.precision(.fractionLength(0...1))))
                            }
                            LabeledContent("Review State", value: reviewStateLabel(detail.row.reviewStatus))
                            LabeledContent("Duplicate State", value: formattedStatusLabel(detail.duplicateStatus))
                            LabeledContent("Import Origin", value: importOriginLabel(for: detail))
                            if let origin = detail.importOrigin {
                                LabeledContent("Imported", value: origin.importedAt.formatted(date: .abbreviated, time: .shortened))
                            }
                            if let reference = descriptiveReference(for: detail) {
                                LabeledContent("Reference", value: reference)
                            } else if let reference = opaqueReference(for: detail) {
                                DisclosureGroup("Internal Reference") {
                                    Text(reference)
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                        .textSelection(.enabled)
                                }
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

        private func merchantLabel(for row: TransactionLedgerRow) -> String {
            normalized(row.merchantName) ?? normalized(row.rawDescription) ?? "Unknown Merchant"
        }

        private func amountText(for row: TransactionLedgerRow) -> String {
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencyCode = Locale.current.currency?.identifier ?? "USD"
            return formatter.string(from: NSDecimalNumber(decimal: row.amount)) ?? "\(row.amount)"
        }

        private func accountLabel(for row: TransactionLedgerRow) -> String {
            normalized(row.accountName) ?? "Unknown Account"
        }

        private func categoryLabel(for row: TransactionLedgerRow) -> String {
            if let categoryID = row.categoryID,
               let categoryName = categories.first(where: { $0.id == categoryID })?.name,
               let categoryName = normalized(categoryName) {
                return categoryName
            }
            return normalized(row.categoryName) ?? "Uncategorized"
        }

        private func directionLabel(_ direction: TransactionDirection) -> String {
            formattedStatusLabel(direction.rawValue)
        }

        private func reviewStateLabel(_ status: TransactionReviewStatus) -> String {
            formattedStatusLabel(status.rawValue)
        }

        private func importOriginLabel(for detail: TransactionDetail) -> String {
            guard let origin = detail.importOrigin else {
                return "Not linked to an import session"
            }
            return origin.originalFilename
        }

        private func descriptiveReference(for detail: TransactionDetail) -> String? {
            guard let reference = normalized(detail.decisionSourceReference),
                  UUID(uuidString: reference) == nil else {
                return nil
            }
            return reference
        }

        private func opaqueReference(for detail: TransactionDetail) -> String? {
            guard let reference = normalized(detail.decisionSourceReference),
                  UUID(uuidString: reference) != nil else {
                return nil
            }
            return reference
        }

        private func formattedStatusLabel(_ value: String) -> String {
            value
                .replacingOccurrences(of: "_", with: " ")
                .split(separator: " ")
                .map { word in
                    word.prefix(1).uppercased() + word.dropFirst()
                }
                .joined(separator: " ")
        }

        private func normalized(_ text: String?) -> String? {
            guard let text = text?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !text.isEmpty else {
                return nil
            }
            return text
        }
    }
}
