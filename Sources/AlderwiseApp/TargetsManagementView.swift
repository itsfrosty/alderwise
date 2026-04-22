import Application
import Domain
import SwiftUI

struct TargetsManagementView: View {
    let targets: [ManagedMonthlyTarget]
    let categories: [BudgetCategory]
    let categoryGroups: [BudgetCategoryGroup]
    let monthStart: Date
    @Binding var selectedTargetID: UUID?
    var onCreate: () -> Void
    var onSaveEdit: (UUID, MonthlyTargetDraft) throws -> Void
    var onDelete: (UUID) throws -> Void
    var onViewTransactions: (TransactionLedgerFilter) -> Void

    @State private var editingTarget: ManagedMonthlyTarget?
    @State private var pendingDeleteTarget: ManagedMonthlyTarget?
    @State private var deleteErrorMessage: String?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Targets")
                        .font(.largeTitle.bold())

                    if targets.isEmpty {
                        ContentUnavailableView {
                            Label("No Targets", systemImage: AppSection.targets.systemImage)
                        } description: {
                            Text("Create a monthly limit to track accepted spending for a category or group.")
                        } actions: {
                            Button {
                                onCreate()
                            } label: {
                                Label("Create Target", systemImage: "plus")
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    } else {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(targets) { target in
                                targetCard(target)
                                    .id(target.id)
                            }
                        }
                    }
                }
                .padding(24)
            }
            .navigationTitle("Targets")
            .onAppear {
                scrollToSelection(using: proxy)
            }
            .onChange(of: selectedTargetID) { _, _ in
                scrollToSelection(using: proxy)
            }
        }
        .sheet(item: $editingTarget) { target in
            TargetEditSheet(
                target: target,
                categories: categories,
                categoryGroups: categoryGroups,
                onCancel: {
                    editingTarget = nil
                },
                onSave: { draft in
                    try onSaveEdit(target.id, draft)
                    editingTarget = nil
                }
            )
        }
        .confirmationDialog(
            "Delete Target",
            isPresented: Binding(
                get: { pendingDeleteTarget != nil },
                set: { isPresented in
                    if !isPresented {
                        pendingDeleteTarget = nil
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            if let pendingDeleteTarget {
                Button("Delete", role: .destructive) {
                    do {
                        try onDelete(pendingDeleteTarget.id)
                        self.pendingDeleteTarget = nil
                    } catch {
                        deleteErrorMessage = error.localizedDescription
                    }
                }
            }
            Button("Cancel", role: .cancel) {
                pendingDeleteTarget = nil
            }
        } message: {
            if let pendingDeleteTarget {
                Text("Delete the \(pendingDeleteTarget.name) target? This keeps past transactions and removes the monthly limit.")
            }
        }
        .alert(
            "Target Not Deleted",
            isPresented: Binding(
                get: { deleteErrorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        deleteErrorMessage = nil
                    }
                }
            )
        ) {
            Button("OK") {
                deleteErrorMessage = nil
            }
        } message: {
            Text(deleteErrorMessage ?? "")
        }
    }

    private func targetCard(_ target: ManagedMonthlyTarget) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(target.name)
                        .font(.headline)
                    Text(scopeLabel(for: target.scope))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(currency(target.monthlyLimit))
                        .font(.headline)
                    Text("Monthly limit")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 16) {
                metric(title: "Spent", value: currency(target.spent))
                metric(
                    title: "Remaining",
                    value: currency(target.remaining),
                    tint: target.remaining < 0 ? .red : .secondary
                )
            }

            HStack {
                Button("Edit") {
                    selectedTargetID = target.id
                    editingTarget = target
                }

                Button("View Transactions") {
                    selectedTargetID = target.id
                    onViewTransactions(transactionFilter(for: target))
                }

                Button("Delete", role: .destructive) {
                    selectedTargetID = target.id
                    pendingDeleteTarget = target
                }

                Spacer()
            }
            .buttonStyle(.bordered)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(selectedTargetID == target.id ? Color.accentColor : Color.clear, lineWidth: 2)
        }
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onTapGesture {
            selectedTargetID = target.id
        }
    }

    private func metric(title: String, value: String, tint: Color = .secondary) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func scrollToSelection(using proxy: ScrollViewProxy) {
        guard let selectedTargetID else {
            return
        }
        withAnimation {
            proxy.scrollTo(selectedTargetID, anchor: .center)
        }
    }

    private func scopeLabel(for scope: TargetScope) -> String {
        switch scope {
        case .category:
            "Category target"
        case .categoryGroup:
            "Group target"
        }
    }

    private func transactionFilter(for target: ManagedMonthlyTarget) -> TransactionLedgerFilter {
        TransactionDrilldownFilterBuilder.currentMonthAcceptedExpenses(
            monthStart: monthStart,
            scope: target.scope
        )
    }

    private func currency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = Locale.current.currency?.identifier ?? "USD"
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "\(amount)"
    }
}
