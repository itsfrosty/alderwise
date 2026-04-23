import Application
import Domain
import SwiftUI

struct ReviewQueueView: View {
    let snapshot: WorkspaceSnapshot
    @ObservedObject var model: WorkspaceShellModel
    @State private var selectedReviewItemID: UUID?

    private var selectedItem: PendingReviewItem? {
        guard let selectedReviewItemID else {
            return snapshot.pendingReviewItems.first
        }
        return snapshot.pendingReviewItems.first { $0.id == selectedReviewItemID }
    }

    private var selectedIDBinding: Binding<UUID?> {
        Binding(
            get: { selectedItem?.id },
            set: { selectedReviewItemID = $0 }
        )
    }

    var body: some View {
        let presentation = ReviewPresentation(categories: snapshot.categories)

        HSplitView {
            VStack(spacing: 0) {
                if snapshot.pendingReviewItems.isEmpty {
                    ContentUnavailableView(
                        "No Review Items",
                        systemImage: "checkmark.seal",
                        description: Text(emptyStateMessage)
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(selection: selectedIDBinding) {
                        ForEach(snapshot.pendingReviewItems) { item in
                            ReviewQueueRow(item: item, presentation: presentation)
                                .tag(item.id)
                        }
                    }
                    .listStyle(.inset)
                }
            }
            .frame(minWidth: 360, idealWidth: 420, maxWidth: .infinity, maxHeight: .infinity)

            ReviewQueueDetail(
                item: selectedItem,
                presentation: presentation,
                categories: snapshot.categories,
                categoryGroups: snapshot.categoryGroups,
                followUpAction: model.reviewCreatedLearnedRuleAction,
                onApproveClassification: { item, assignment, ruleLearning in
                    let didResolve = model.approveClassificationReviewItem(
                        id: item.id,
                        assignment: assignment,
                        ruleLearning: ruleLearning
                    )
                    if didResolve {
                        selectNextItem(after: item.id)
                    }
                },
                onKeepBoth: { item in
                    if model.keepBothLikelyDuplicateReviewItem(id: item.id) {
                        selectNextItem(after: item.id)
                    }
                },
                onManageLearnedRule: { action in
                    model.showLearnedRules(selectedLearnedRuleID: action.ruleID)
                }
            )
            .frame(idealWidth: 420, maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("Review")
        .onAppear {
            if selectedReviewItemID == nil {
                selectedReviewItemID = snapshot.pendingReviewItems.first?.id
            }
        }
        .onChange(of: snapshot.pendingReviewItems) { _, items in
            if let selectedReviewItemID,
               items.contains(where: { $0.id == selectedReviewItemID }) {
                return
            }
            selectedReviewItemID = items.first?.id
        }
        .onMoveCommand { direction in
            switch direction {
            case .down:
                selectNextItem(after: selectedItem?.id)
            case .up:
                selectPreviousItem(before: selectedItem?.id)
            default:
                break
            }
        }
    }

    private var emptyStateMessage: String {
        if snapshot.transactions.contains(where: { $0.reviewStatus == .pending }) {
            "Some transactions are still pending, but none have review details attached. Use Transactions to inspect and edit them."
        } else {
            "Accepted transactions are ready for reporting and targets."
        }
    }

    private func selectNextItem(after id: UUID?) {
        guard let id,
              let index = snapshot.pendingReviewItems.firstIndex(where: { $0.id == id }) else {
            selectedReviewItemID = snapshot.pendingReviewItems.first?.id
            return
        }
        let nextIndex = snapshot.pendingReviewItems.index(after: index)
        if nextIndex < snapshot.pendingReviewItems.endIndex {
            selectedReviewItemID = snapshot.pendingReviewItems[nextIndex].id
        } else {
            selectedReviewItemID = snapshot.pendingReviewItems.first?.id
        }
    }

    private func selectPreviousItem(before id: UUID?) {
        guard let id,
              let index = snapshot.pendingReviewItems.firstIndex(where: { $0.id == id }) else {
            selectedReviewItemID = snapshot.pendingReviewItems.first?.id
            return
        }
        if index > snapshot.pendingReviewItems.startIndex {
            selectedReviewItemID = snapshot.pendingReviewItems[snapshot.pendingReviewItems.index(before: index)].id
        } else {
            selectedReviewItemID = snapshot.pendingReviewItems.last?.id
        }
    }
}

private struct ReviewQueueRow: View {
    let item: PendingReviewItem
    let presentation: ReviewPresentation

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
                .lineLimit(1)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.vertical, 5)
    }

    private var title: String {
        switch item.type {
        case .lowConfidenceCategory:
            item.classification?.normalizedMerchantName ?? "Low Confidence Category"
        case .likelyDuplicate:
            "Likely Duplicate"
        case .conflictingRuleOutcome:
            "Conflicting Rule"
        case .malformedRow:
            "Malformed Row"
        case .recurringHint:
            "Recurring Hint"
        }
    }

    private var subtitle: String {
        presentation.queueSubtitle(for: item)
    }
}

private struct ReviewQueueDetail: View {
    let item: PendingReviewItem?
    let presentation: ReviewPresentation
    let categories: [BudgetCategory]
    let categoryGroups: [BudgetCategoryGroup]
    let followUpAction: ReviewCreatedLearnedRuleAction?
    var onApproveClassification: (PendingReviewItem, ClassificationAssignment, ReviewRuleLearningOption?) -> Void
    var onKeepBoth: (PendingReviewItem) -> Void
    var onManageLearnedRule: (ReviewCreatedLearnedRuleAction) -> Void
    @State private var selectedCategoryID: UUID?
    @State private var merchantName = ""
    @State private var createRule = true
    @State private var selectedRuleLearning: ReviewRuleLearningOption?

    var body: some View {
        Group {
            if let item {
                Form {
                    Section("Source") {
                        LabeledContent("File", value: item.sourceFile.originalFilename)
                        LabeledContent("Row", value: "\(item.sourceRow.sourceLineNumber)")
                        if let reason = item.reason {
                            LabeledContent("Reason", value: reason)
                        }
                    }

                    Section("Review") {
                        switch item.type {
                        case .lowConfidenceCategory:
                            classificationControls(for: item)
                        case .likelyDuplicate:
                            Text("This row resembles an existing transaction. Keeping both preserves both records and records the decision.")
                                .foregroundStyle(.secondary)
                            Button("Keep Both") {
                                onKeepBoth(item)
                            }
                            .buttonStyle(.borderedProminent)
                            .keyboardShortcut(.return, modifiers: [.command])
                        case .conflictingRuleOutcome, .malformedRow, .recurringHint:
                            Text("This review type is not editable in this build.")
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let followUpAction {
                        Section("Follow Up") {
                            Button("Manage Rule: \(followUpAction.merchantLabel)") {
                                onManageLearnedRule(followUpAction)
                            }
                            Text("The review approval created a learned rule. You can inspect or disable it from Settings.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Section("Raw Row") {
                        Text(item.sourceRow.rawPayload)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                    }
                }
                .formStyle(.grouped)
                .onAppear {
                    load(item)
                }
                .onChange(of: item) { _, newItem in
                    load(newItem)
                }
            } else {
                VStack(spacing: 16) {
                    ContentUnavailableView(
                        "No Review Item Selected",
                        systemImage: "sidebar.right",
                        description: Text("Select a review item to inspect its source and record a decision.")
                    )
                    if let followUpAction {
                        Button("Manage Rule: \(followUpAction.merchantLabel)") {
                            onManageLearnedRule(followUpAction)
                        }
                    }
                }
            }
        }
        .padding()
    }

    private func classificationControls(for item: PendingReviewItem) -> some View {
        let learningOptions = ruleLearningOptions(for: item)
        let consequenceLines = presentation.staticConsequences(
            for: item,
            createRule: createRule,
            selectedRuleLearning: selectedRuleLearning
        )

        return VStack(alignment: .leading, spacing: 12) {
            TextField("Merchant", text: $merchantName)
            GroupedCategoryPicker(
                title: "Category",
                prompt: "Choose Category",
                categories: categories,
                categoryGroups: categoryGroups,
                selection: $selectedCategoryID
            )
            Toggle("Learn this merchant rule", isOn: $createRule)
            if createRule, learningOptions.count > 1 {
                Picker("Learn As", selection: $selectedRuleLearning) {
                    ForEach(learningOptions, id: \.self) { option in
                        Text(optionPickerLabel(option)).tag(Optional(option))
                    }
                }
                if let selectedRuleLearning {
                    Text(selectedRuleLearning.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if !consequenceLines.isEmpty {
                ReviewConsequenceSummary(lines: consequenceLines)
            }
            Button("Approve Category") {
                guard let selectedCategoryID else {
                    return
                }
                onApproveClassification(
                    item,
                    ClassificationAssignment(
                        categoryID: selectedCategoryID,
                        merchantName: merchantName.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                    ),
                    createRule ? resolvedRuleLearning(for: item) : nil
                )
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.return, modifiers: [.command])
            .disabled(selectedCategoryID == nil)
        }
    }

    private func load(_ item: PendingReviewItem) {
        selectedCategoryID = item.classification?.prefill?.categoryID
        merchantName = item.classification?.prefill?.merchantName
            ?? item.classification?.normalizedMerchantName
            ?? ""
        createRule = presentation.initialCreateRuleValue(for: item)
        selectedRuleLearning = presentation.initialRuleLearningSelection(for: item)
    }

    private func ruleLearningOptions(for item: PendingReviewItem) -> [ReviewRuleLearningOption] {
        ReviewRuleLearningOption.options(
            forNormalizedMerchantName: item.classification?.normalizedMerchantName ?? ""
        )
    }

    private func resolvedRuleLearning(for item: PendingReviewItem) -> ReviewRuleLearningOption? {
        presentation.resolvedRuleLearningSelection(
            for: item,
            selectedRuleLearning: selectedRuleLearning
        )
    }

    private func optionPickerLabel(_ option: ReviewRuleLearningOption) -> String {
        switch option {
        case .exactNormalizedMerchant(let pattern):
            "Exact: \(pattern)"
        case .prefixNormalizedMerchant(let pattern):
            "Shared prefix: \(pattern)"
        }
    }
}

private struct ReviewConsequenceSummary: View {
    let lines: [ReviewPresentation.ConsequenceLine]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: iconName(for: line))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(iconColor(for: line))
                    Text(line.text)
                        .font(.caption)
                        .foregroundStyle(textColor(for: line))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func iconName(for line: ReviewPresentation.ConsequenceLine) -> String {
        switch line.emphasis {
        case .neutral:
            "checklist"
        case .warning:
            "exclamationmark.triangle.fill"
        }
    }

    private func iconColor(for line: ReviewPresentation.ConsequenceLine) -> Color {
        switch line.emphasis {
        case .neutral:
            .secondary
        case .warning:
            .orange
        }
    }

    private func textColor(for line: ReviewPresentation.ConsequenceLine) -> Color {
        switch line.emphasis {
        case .neutral:
            .secondary
        case .warning:
            .primary
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
