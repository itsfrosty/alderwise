import Application
import Domain
import SwiftUI

enum ReviewQueueSelection {
    static func selectionAfterApproving(
        approvedItemID: UUID,
        items: [PendingReviewItem]
    ) -> UUID? {
        guard let index = items.firstIndex(where: { $0.id == approvedItemID }) else {
            return items.first?.id
        }
        let nextIndex = items.index(after: index)
        if nextIndex < items.endIndex {
            return items[nextIndex].id
        }
        return items.first?.id
    }

    static func selectionAfterItemsChange(
        currentSelectionID: UUID?,
        items: [PendingReviewItem]
    ) -> UUID? {
        guard let currentSelectionID else {
            return items.first?.id
        }
        guard items.contains(where: { $0.id == currentSelectionID }) else {
            return items.first?.id
        }
        return currentSelectionID
    }

    static func selectionAfterMovingDown(
        currentSelectionID: UUID?,
        items: [PendingReviewItem]
    ) -> UUID? {
        guard let currentSelectionID,
              let index = items.firstIndex(where: { $0.id == currentSelectionID }) else {
            return items.first?.id
        }
        let nextIndex = items.index(after: index)
        if nextIndex < items.endIndex {
            return items[nextIndex].id
        }
        return items.first?.id
    }

    static func selectionAfterMovingUp(
        currentSelectionID: UUID?,
        items: [PendingReviewItem]
    ) -> UUID? {
        guard let currentSelectionID,
              let index = items.firstIndex(where: { $0.id == currentSelectionID }) else {
            return items.first?.id
        }
        if index > items.startIndex {
            return items[items.index(before: index)].id
        }
        return items.last?.id
    }
}

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
        let presentation = ReviewPresentation(
            categories: snapshot.categories,
            recommendationEligibilityByReviewItemID: model.merchantRecommendationEligibilityByReviewItemID
        )

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
                model: model,
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
                        selectedReviewItemID = ReviewQueueSelection.selectionAfterApproving(
                            approvedItemID: item.id,
                            items: snapshot.pendingReviewItems
                        )
                    }
                },
                onKeepBoth: { item in
                    if model.keepBothLikelyDuplicateReviewItem(id: item.id) {
                        selectedReviewItemID = ReviewQueueSelection.selectionAfterApproving(
                            approvedItemID: item.id,
                            items: snapshot.pendingReviewItems
                        )
                    }
                },
                onManageLearnedRule: { action in
                    model.showRulesDestination(action.destination)
                }
            )
            .frame(idealWidth: 420, maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("Review")
        .onAppear {
            if selectedReviewItemID == nil {
                selectedReviewItemID = ReviewQueueSelection.selectionAfterItemsChange(
                    currentSelectionID: selectedReviewItemID,
                    items: snapshot.pendingReviewItems
                )
            }
        }
        .onChange(of: snapshot.pendingReviewItems) { _, items in
            selectedReviewItemID = ReviewQueueSelection.selectionAfterItemsChange(
                currentSelectionID: selectedReviewItemID,
                items: items
            )
        }
        .onMoveCommand { direction in
            switch direction {
            case .down:
                selectedReviewItemID = ReviewQueueSelection.selectionAfterMovingDown(
                    currentSelectionID: selectedItem?.id,
                    items: snapshot.pendingReviewItems
                )
            case .up:
                selectedReviewItemID = ReviewQueueSelection.selectionAfterMovingUp(
                    currentSelectionID: selectedItem?.id,
                    items: snapshot.pendingReviewItems
                )
            default:
                break
            }
        }
    }

    private var emptyStateMessage: String {
        if snapshot.transactions.contains(where: { $0.reviewStatus == .pending }) {
            "Some transactions are still pending, but none have review details attached. Use Transactions to inspect and edit them."
        } else {
            "Visible transactions are already reflected in reporting and targets."
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
    @ObservedObject var model: WorkspaceShellModel
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
                    refreshPreview(for: item)
                }
                .onChange(of: item) { _, newItem in
                    load(newItem)
                    refreshPreview(for: newItem)
                }
                .onChange(of: createRule) { _, _ in
                    refreshPreview(for: item)
                }
                .onChange(of: selectedRuleLearning) { _, _ in
                    refreshPreview(for: item)
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
                .onAppear {
                    model.clearReviewRulePreview()
                }
            }
        }
        .padding()
    }

    private func classificationControls(for item: PendingReviewItem) -> some View {
        let learningOptions = ruleLearningOptions(for: item)
        let resolvedRuleLearning = resolvedRuleLearning(for: item)
        let previewKey = makePreviewKey(for: item, resolvedRuleLearning: resolvedRuleLearning)
        let consequenceLines = presentation.staticConsequences(
            for: item,
            createRule: createRule,
            selectedRuleLearning: resolvedRuleLearning
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
                if let resolvedRuleLearning {
                    Text(resolvedRuleLearning.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if !consequenceLines.isEmpty {
                ReviewConsequenceSummary(lines: consequenceLines)
            }
            if let previewKey {
                ReviewRulePreviewSummary(
                    phase: model.reviewRulePreviewPhase(for: previewKey)
                )
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
                    createRule ? resolvedRuleLearning : nil
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

    private func refreshPreview(for item: PendingReviewItem?) {
        guard let item else {
            model.clearReviewRulePreview()
            return
        }
        let resolvedRuleLearning = resolvedRuleLearning(for: item)
        guard let previewKey = makePreviewKey(for: item, resolvedRuleLearning: resolvedRuleLearning) else {
            model.clearReviewRulePreview()
            return
        }

        model.scheduleReviewRulePreview(
            reviewItemID: previewKey.reviewItemID,
            createRuleEnabled: previewKey.createRuleEnabled,
            merchantPattern: previewKey.merchantPattern,
            matchKind: previewKey.matchKind
        )
    }

    private func makePreviewKey(
        for item: PendingReviewItem,
        resolvedRuleLearning: ReviewRuleLearningOption?
    ) -> WorkspaceShellModel.ReviewRulePreviewKey? {
        guard item.type == .lowConfidenceCategory else {
            return nil
        }

        return WorkspaceShellModel.ReviewRulePreviewKey(
            reviewItemID: item.id,
            createRuleEnabled: createRule,
            merchantPattern: resolvedRuleLearning?.pattern
                ?? item.classification?.normalizedMerchantName
                ?? "",
            matchKind: resolvedRuleLearning?.matchKind ?? .exactNormalizedMerchant
        )
    }
}

private struct ReviewRulePreviewSummary: View {
    let phase: WorkspaceShellModel.ReviewRulePreviewPhase

    var body: some View {
        switch phase {
        case .loading:
            previewContainer {
                ProgressView("Checking matching transactions…")
                    .font(.caption)
                    .controlSize(.small)
            }
        case .ready(let preview):
            previewContainer {
                VStack(alignment: .leading, spacing: 4) {
                    Text(readyTitle(for: preview))
                        .font(.caption.weight(.semibold))
                    if let detail = readyDetail(for: preview) {
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        case .noEligiblePreview:
            previewContainer {
                Text("Enable Learn this merchant rule to preview additional matches.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .unavailable:
            previewContainer {
                Text("Preview is unavailable in this workspace.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .error(let message):
            previewContainer {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Preview failed.")
                        .font(.caption.weight(.semibold))
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func previewContainer<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 0, content: content)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func readyTitle(for preview: LearnedRuleImpactPreview) -> String {
        if preview.matchedAcceptedTransactionCount == 0,
           preview.matchedPendingReviewItemCount == 0 {
            return "Saving this rule would not affect any other items."
        }

        return "Saving this rule would affect \(preview.matchedAcceptedTransactionCount) accepted transaction\(preview.matchedAcceptedTransactionCount == 1 ? "" : "s") and \(preview.matchedPendingReviewItemCount) pending review item\(preview.matchedPendingReviewItemCount == 1 ? "" : "s")."
    }

    private func readyDetail(for preview: LearnedRuleImpactPreview) -> String? {
        guard preview.matchedAcceptedTransactionCount != 0 || preview.matchedPendingReviewItemCount != 0 else {
            return nil
        }

        return "The current review item is excluded from this count."
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
