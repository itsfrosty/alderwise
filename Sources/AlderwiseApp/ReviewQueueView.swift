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
                            ReviewQueueRow(item: item)
                                .tag(item.id)
                        }
                    }
                    .listStyle(.inset)
                }
            }
            .frame(minWidth: 360, idealWidth: 420, maxWidth: .infinity, maxHeight: .infinity)

            ReviewQueueDetail(
                item: selectedItem,
                categories: snapshot.categories,
                onApproveClassification: { item, assignment, createRule in
                    let didResolve = model.approveClassificationReviewItem(
                        id: item.id,
                        assignment: assignment,
                        createRule: createRule
                    )
                    if didResolve {
                        selectNextItem(after: item.id)
                    }
                },
                onKeepBoth: { item in
                    if model.keepBothLikelyDuplicateReviewItem(id: item.id) {
                        selectNextItem(after: item.id)
                    }
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
    }

    private var emptyStateMessage: String {
        if snapshot.transactions.contains(where: { $0.reviewStatus == .pending }) {
            "Some transactions are still pending, but none have review details attached. Use Transactions to inspect and edit them."
        } else {
            "Accepted transactions are ready for reporting and targets."
        }
    }

    private func selectNextItem(after id: UUID) {
        guard let index = snapshot.pendingReviewItems.firstIndex(where: { $0.id == id }) else {
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
}

private struct ReviewQueueRow: View {
    let item: PendingReviewItem

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
        [
            item.sourceFile.originalFilename,
            "Row \(item.sourceRow.sourceLineNumber)",
            item.reason,
        ]
        .compactMap { $0 }
        .joined(separator: " · ")
    }
}

private struct ReviewQueueDetail: View {
    let item: PendingReviewItem?
    let categories: [BudgetCategory]
    var onApproveClassification: (PendingReviewItem, ClassificationAssignment, Bool) -> Void
    var onKeepBoth: (PendingReviewItem) -> Void
    @State private var selectedCategoryID: UUID?
    @State private var merchantName = ""
    @State private var createRule = true

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
                        case .conflictingRuleOutcome, .malformedRow, .recurringHint:
                            Text("This review type is not editable in this build.")
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
                ContentUnavailableView(
                    "No Review Item Selected",
                    systemImage: "sidebar.right",
                    description: Text("Select a review item to inspect its source and record a decision.")
                )
            }
        }
        .padding()
    }

    private func classificationControls(for item: PendingReviewItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Merchant", text: $merchantName)
            Picker("Category", selection: $selectedCategoryID) {
                Text("Choose Category").tag(Optional<UUID>.none)
                ForEach(categories) { category in
                    Text(category.name).tag(Optional(category.id))
                }
            }
            Toggle("Learn this merchant rule", isOn: $createRule)
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
                    createRule
                )
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedCategoryID == nil)
        }
    }

    private func load(_ item: PendingReviewItem) {
        selectedCategoryID = item.classification?.prefill?.categoryID
        merchantName = item.classification?.prefill?.merchantName
            ?? item.classification?.normalizedMerchantName
            ?? ""
        createRule = true
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
