import Application
import Domain
import SwiftUI

struct TransactionLedgerView: View {
    let snapshot: WorkspaceSnapshot
    @ObservedObject var model: WorkspaceShellModel
    @State private var searchText = ""
    @State private var hasStartDate = false
    @State private var hasEndDate = false
    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var isSearchPresented = false
    @State private var isSyncingControls = false

    private var selectedIDBinding: Binding<UUID?> {
        Binding(
            get: { model.selectedTransactionID },
            set: { model.selectTransaction(id: $0) }
        )
    }

    var body: some View {
        HSplitView {
            VStack(spacing: 0) {
                filterBar
                    .padding(12)

                if snapshot.transactions.isEmpty {
                    ContentUnavailableView(
                        "No transactions match these filters",
                        systemImage: "line.3.horizontal.decrease.circle",
                        description: Text("Imported and accepted transactions appear here as the ledger grows.")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    transactionList
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            TransactionDetailInspectorView(
                detail: model.selectedTransactionDetail,
                categories: snapshot.categories,
                categoryGroups: snapshot.categoryGroups,
                onSave: model.updateSelectedTransaction(draft:)
            )
            .frame(idealWidth: 360, maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("Transactions")
        .searchable(text: $searchText, isPresented: $isSearchPresented, placement: .toolbar, prompt: "Search transactions")
        .onSubmit(of: .search) {
            applyFilters()
        }
        .onChange(of: searchText) { _, _ in
            applyFilters()
        }
        .onAppear {
            syncControlsFromFilter()
            if model.selectedTransactionID == nil {
                model.selectTransaction(id: snapshot.transactions.first?.id)
            }
        }
        .onChange(of: model.transactionFilter) { _, _ in
            syncControlsFromFilter()
        }
    }

    private var transactionList: some View {
        List(selection: selectedIDBinding) {
            ForEach(snapshot.transactions) { transaction in
                TransactionLedgerRowView(transaction: transaction)
                    .tag(transaction.id)
            }
        }
        .listStyle(.inset)
    }

    private var filterBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Button {
                    isSearchPresented = true
                } label: {
                    Label("Search", systemImage: "magnifyingglass")
                }
                .keyboardShortcut("f", modifiers: [.command])

                Picker("Account", selection: accountSelection) {
                    Text("All Accounts").tag(Optional<UUID>.none)
                    ForEach(snapshot.ledgerFilterAccounts) { account in
                        Text(accountFilterLabel(for: account)).tag(Optional(account.id))
                    }
                }

                GroupedCategoryPicker(
                    title: "Category",
                    prompt: "All Categories",
                    categories: snapshot.categories,
                    categoryGroups: snapshot.categoryGroups,
                    selection: categorySelection
                )

                Picker("Direction", selection: directionSelection) {
                    Text("All Directions").tag(Optional<TransactionDirection>.none)
                    ForEach(TransactionDirection.allCases, id: \.self) { direction in
                        Text(direction.rawValue.capitalized).tag(Optional(direction))
                    }
                }

                Picker("Review", selection: reviewSelection) {
                    Text("All Review States").tag(Optional<TransactionReviewStatus>.none)
                    ForEach(TransactionReviewStatus.allCases, id: \.self) { status in
                        Text(status.rawValue.capitalized).tag(Optional(status))
                    }
                }

                Picker("Import", selection: importSessionSelection) {
                    Text("All Imports").tag(Optional<Int64>.none)
                    ForEach(importOrigins, id: \.id) { origin in
                        Text(origin.originalFilename).tag(Optional(origin.id))
                    }
                }
            }

            if let categoryGroupFilterName {
                HStack {
                    Button {
                        clearCategoryGroupFilter()
                    } label: {
                        HStack(spacing: 6) {
                            Label("Group: \(categoryGroupFilterName)", systemImage: "line.3.horizontal.decrease.circle.fill")
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.regularMaterial, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
            }

            HStack {
                Toggle("From", isOn: $hasStartDate)
                    .onChange(of: hasStartDate) { _, _ in applyFilters() }
                DatePicker("", selection: $startDate, displayedComponents: .date)
                    .labelsHidden()
                    .disabled(!hasStartDate)
                    .onChange(of: startDate) { _, _ in applyFilters() }

                Toggle("To", isOn: $hasEndDate)
                    .onChange(of: hasEndDate) { _, _ in applyFilters() }
                DatePicker("", selection: $endDate, displayedComponents: .date)
                    .labelsHidden()
                    .disabled(!hasEndDate)
                    .onChange(of: endDate) { _, _ in applyFilters() }

                Spacer()
                Button {
                    searchText = ""
                    hasStartDate = false
                    hasEndDate = false
                    model.updateTransactionFilter(.empty)
                } label: {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                }
            }
        }
    }

    private var accountSelection: Binding<UUID?> {
        Binding(
            get: { model.transactionFilter.accountID },
            set: { newValue in
                var filter = model.transactionFilter
                filter.accountID = newValue
                model.updateTransactionFilter(filter)
            }
        )
    }

    private var categorySelection: Binding<UUID?> {
        Binding(
            get: { model.transactionFilter.categoryID },
            set: { newValue in
                var filter = model.transactionFilter
                filter.categoryID = newValue
                filter.categoryGroupID = nil
                model.updateTransactionFilter(filter)
            }
        )
    }

    private var reviewSelection: Binding<TransactionReviewStatus?> {
        Binding(
            get: { model.transactionFilter.reviewStatus },
            set: { newValue in
                var filter = model.transactionFilter
                filter.reviewStatus = newValue
                model.updateTransactionFilter(filter)
            }
        )
    }

    private var directionSelection: Binding<TransactionDirection?> {
        Binding(
            get: { model.transactionFilter.direction },
            set: { newValue in
                var filter = model.transactionFilter
                filter.direction = newValue
                model.updateTransactionFilter(filter)
            }
        )
    }

    private var importSessionSelection: Binding<Int64?> {
        Binding(
            get: { model.transactionFilter.importSessionID },
            set: { newValue in
                var filter = model.transactionFilter
                filter.importSessionID = newValue
                model.updateTransactionFilter(filter)
            }
        )
    }

    private var importOrigins: [TransactionImportOrigin] {
        snapshot.transactionImportOrigins
    }

    private func accountFilterLabel(for account: Account) -> String {
        account.isArchived ? "\(account.name) (Archived)" : account.name
    }

    private var categoryGroupFilterName: String? {
        guard let categoryGroupID = model.transactionFilter.categoryGroupID else {
            return nil
        }
        return snapshot.categoryGroups.first(where: { $0.id == categoryGroupID })?.name ?? "Filtered group"
    }

    private func applyFilters() {
        guard !isSyncingControls else {
            return
        }
        var filter = model.transactionFilter
        filter.searchText = searchText
        filter.startDate = hasStartDate ? startDate : nil
        filter.endDate = hasEndDate ? endDate : nil
        model.updateTransactionFilter(filter)
    }

    private func syncControlsFromFilter() {
        isSyncingControls = true
        defer {
            Task { @MainActor in
                isSyncingControls = false
            }
        }

        let filter = model.transactionFilter

        let nextHasStartDate = filter.startDate != nil
        if hasStartDate != nextHasStartDate {
            hasStartDate = nextHasStartDate
        }
        if let filterStartDate = filter.startDate, startDate != filterStartDate {
            startDate = filterStartDate
        }

        let nextHasEndDate = filter.endDate != nil
        if hasEndDate != nextHasEndDate {
            hasEndDate = nextHasEndDate
        }
        if let filterEndDate = filter.endDate, endDate != filterEndDate {
            endDate = filterEndDate
        }

        if searchText != filter.searchText {
            searchText = filter.searchText
        }
    }

    private func clearCategoryGroupFilter() {
        var filter = model.transactionFilter
        filter.categoryGroupID = nil
        model.updateTransactionFilter(filter)
    }
}
