import Application
import Domain
import SwiftUI

extension TransactionLedgerView {
    struct DetailInspector: View {
        let detail: TransactionDetail?
        let categories: [BudgetCategory]
        let categoryGroups: [BudgetCategoryGroup]
        let draft: TransactionLedgerEditDraft?
        let isDirty: Bool
        var onDraftChange: (TransactionLedgerEditDraft) -> Void
        var onSave: (TransactionLedgerEditDraft) -> Void
        var onViewRule: (LearnedRulesDestination.Selection) -> Void

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
                            TextField("Merchant", text: merchantNameBinding(for: detail))
                            GroupedCategoryPicker(
                                title: "Category",
                                prompt: "Uncategorized",
                                categories: categories,
                                categoryGroups: categoryGroups,
                                selection: categoryBinding(for: detail)
                            )
                            TextField("Notes", text: notesBinding(for: detail), axis: .vertical)
                                .lineLimit(3, reservesSpace: true)
                            if isDirty {
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(.orange)
                                        .frame(width: 8, height: 8)
                                    Text("Unsaved changes")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Button {
                                onSave(resolvedDraft(for: detail))
                            } label: {
                                Label("Save Changes", systemImage: "checkmark")
                            }
                            .disabled(!isDirty)
                            .keyboardShortcut("s", modifiers: [.command])
                        }

                        Section("Trust Evidence") {
                            LabeledContent(
                                "Source",
                                value: ReviewPresentation.sourceLabel(
                                    for: detail.decisionSource,
                                    ruleProvenance: detail.ruleProvenance
                                )
                            )
                            if let provenance = detail.ruleProvenance {
                                LabeledContent("Merchant Pattern", value: merchantPattern(for: provenance))
                                LabeledContent(RuleDisplayText.matchedBy, value: matchKind(for: provenance).ruleDisplayLabel)
                                LabeledContent("Assigned Category", value: categoryName(for: provenance) ?? "Unknown Category")
                                if let merchantName = merchantName(for: provenance) {
                                    LabeledContent("Merchant Name", value: merchantName)
                                }
                                if case .learnedRule(let learnedRule) = provenance,
                                   learnedRule.isDisabled,
                                   let disabledAt = learnedRule.disabledAt {
                                    LabeledContent(
                                        "Lifecycle",
                                        value: "Disabled \(disabledAt.formatted(date: .abbreviated, time: .shortened))"
                                    )
                                }
                                Button("View in \(rulesDestinationLabel(for: provenance))") {
                                    onViewRule(rulesSelection(for: provenance))
                                }
                            }
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

        private func merchantNameBinding(for detail: TransactionDetail) -> Binding<String> {
            Binding(
                get: { resolvedDraft(for: detail).merchantName },
                set: { merchantName in
                    var nextDraft = resolvedDraft(for: detail)
                    nextDraft.merchantName = merchantName
                    onDraftChange(nextDraft)
                }
            )
        }

        private func categoryBinding(for detail: TransactionDetail) -> Binding<UUID?> {
            Binding(
                get: { resolvedDraft(for: detail).categoryID },
                set: { categoryID in
                    var nextDraft = resolvedDraft(for: detail)
                    nextDraft.categoryID = categoryID
                    onDraftChange(nextDraft)
                }
            )
        }

        private func notesBinding(for detail: TransactionDetail) -> Binding<String> {
            Binding(
                get: { resolvedDraft(for: detail).notes ?? "" },
                set: { notes in
                    var nextDraft = resolvedDraft(for: detail)
                    nextDraft.notes = notes
                    onDraftChange(nextDraft)
                }
            )
        }

        private func resolvedDraft(for detail: TransactionDetail) -> TransactionLedgerEditDraft {
            draft ?? TransactionDetailDraftCoordinator.makeDraft(from: detail)
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

        private func merchantPattern(for provenance: TransactionRuleProvenance) -> String {
            switch provenance {
            case .learnedRule(let learnedRule):
                learnedRule.merchantPattern
            case .seededSource(let seededSource):
                seededSource.merchantPattern
            }
        }

        private func matchKind(for provenance: TransactionRuleProvenance) -> ClassificationRuleMatchKind {
            switch provenance {
            case .learnedRule(let learnedRule):
                learnedRule.matchKind
            case .seededSource(let seededSource):
                seededSource.matchKind
            }
        }

        private func categoryName(for provenance: TransactionRuleProvenance) -> String? {
            switch provenance {
            case .learnedRule(let learnedRule):
                learnedRule.categoryName
            case .seededSource(let seededSource):
                seededSource.categoryName
            }
        }

        private func merchantName(for provenance: TransactionRuleProvenance) -> String? {
            switch provenance {
            case .learnedRule(let learnedRule):
                normalized(learnedRule.merchantName)
            case .seededSource(let seededSource):
                normalized(seededSource.merchantName)
            }
        }

        private func rulesSelection(
            for provenance: TransactionRuleProvenance
        ) -> LearnedRulesDestination.Selection {
            switch provenance {
            case .learnedRule(let learnedRule):
                .learnedRule(learnedRule.id)
            case .seededSource(let seededSource):
                .seededSource(seededSource.id)
            }
        }

        private func rulesDestinationLabel(for provenance: TransactionRuleProvenance) -> String {
            switch provenance {
            case .learnedRule:
                RuleDisplayText.yourRules
            case .seededSource(let seededSource):
                switch seededSource.kind {
                case .deterministicRule:
                    RuleDisplayText.builtInAutoApplied
                case .curatedPrefill:
                    RuleDisplayText.builtInReviewFirst
                }
            }
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
