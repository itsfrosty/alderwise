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

            TransactionDetailView(
                detail: model.selectedTransactionDetail,
                categories: snapshot.categories,
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
            if model.selectedTransactionID == nil {
                model.selectTransaction(id: snapshot.transactions.first?.id)
            }
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
                    ForEach(snapshot.accounts) { account in
                        Text(account.name).tag(Optional(account.id))
                    }
                }

                Picker("Category", selection: categorySelection) {
                    Text("All Categories").tag(Optional<UUID>.none)
                    ForEach(snapshot.categories) { category in
                        Text(category.name).tag(Optional(category.id))
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

    private func applyFilters() {
        var filter = model.transactionFilter
        filter.searchText = searchText
        filter.startDate = hasStartDate ? startDate : nil
        filter.endDate = hasEndDate ? endDate : nil
        model.updateTransactionFilter(filter)
    }
}

private struct TransactionLedgerRowView: View {
    let transaction: TransactionLedgerRow

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(transaction.merchantName)
                    .font(.headline)
                    .lineLimit(1)
                Text(transaction.rawDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(amountText)
                    .font(.headline)
                Text(transaction.transactionDate, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 5)
    }

    private var amountText: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = Locale.current.currency?.identifier ?? "USD"
        return formatter.string(from: NSDecimalNumber(decimal: transaction.amount)) ?? "\(transaction.amount)"
    }
}

private struct TransactionDetailView: View {
    let detail: TransactionDetail?
    let categories: [BudgetCategory]
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
                        Picker("Category", selection: $categoryID) {
                            Text("Uncategorized").tag(Optional<UUID>.none)
                            ForEach(categories) { category in
                                Text(category.name).tag(Optional(category.id))
                            }
                        }
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
                        LabeledContent("Source", value: detail.decisionSource?.rawValue.capitalized ?? "Unclassified")
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
