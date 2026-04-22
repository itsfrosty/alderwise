import Application
import Domain
import SwiftUI

struct TransactionLedgerView: View {
    private enum Layout {
        static let minimumPrimaryWidth: CGFloat = 420
        static let idealPrimaryWidth: CGFloat = 560
        static let minimumSecondaryWidth: CGFloat = 320
    }

    let snapshot: WorkspaceSnapshot
    @ObservedObject var model: WorkspaceShellModel
    @State private var searchText = ""
    @State private var hasStartDate = false
    @State private var hasEndDate = false
    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var isSearchPresented = false
    @State private var isSyncingControls = false
    @State private var userExpandedSecondaryFilters = false
    @State private var draftCoordinator = TransactionDetailDraftCoordinator()
    @SceneStorage("transactionsLedgerPrimaryWidth") private var primaryPaneWidth = Double(Layout.idealPrimaryWidth)

    private var selectedIDBinding: Binding<UUID?> {
        Binding(
            get: { model.selectedTransactionID },
            set: { handleSelectionChange(to: $0) }
        )
    }

    private var isPresentingSelectionChangeConfirmation: Binding<Bool> {
        Binding(
            get: {
                draftCoordinator.isSelectionChangePromptPresented
            },
            set: { isPresented in
                if !isPresented {
                    draftCoordinator.dismissSelectionChangePrompt()
                }
            }
        )
    }

    private var headerState: TransactionLedgerHeaderState {
        TransactionLedgerHeaderState(
            rows: snapshot.transactions,
            filter: model.transactionFilter,
            accountName: selectedAccountName,
            categoryName: selectedCategoryName,
            categoryGroupName: categoryGroupFilterName,
            importSessionName: selectedImportSessionName
        )
    }

    private var primaryPaneWidthBinding: Binding<CGFloat> {
        Binding(
            get: { CGFloat(primaryPaneWidth) },
            set: { primaryPaneWidth = Double($0) }
        )
    }

    private var hasActiveSecondaryFilters: Bool {
        hasActiveSecondaryFilters(in: model.transactionFilter)
    }

    private var secondaryFiltersExpansion: Binding<Bool> {
        Binding(
            get: { hasActiveSecondaryFilters || userExpandedSecondaryFilters },
            set: { isExpanded in
                userExpandedSecondaryFilters = hasActiveSecondaryFilters ? false : isExpanded
            }
        )
    }

    var body: some View {
        StableTwoPaneSplitView(
            primaryWidth: primaryPaneWidthBinding,
            minPrimaryWidth: Layout.minimumPrimaryWidth,
            minSecondaryWidth: Layout.minimumSecondaryWidth,
            primary: VStack(spacing: 0) {
                ledgerHeader
                    .padding(12)

                Divider()

                ledgerContent
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity),
            secondary: TransactionLedgerView.DetailInspector(
                detail: model.selectedTransactionDetail,
                categories: snapshot.categories,
                categoryGroups: snapshot.categoryGroups,
                draft: draftCoordinator.currentDraft,
                isDirty: draftCoordinator.isDirty,
                onDraftChange: { draftCoordinator.updateDraft($0) },
                onSave: handleSave
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        )
        .alert(
            "Save changes before switching transactions?",
            isPresented: isPresentingSelectionChangeConfirmation
        ) {
            Button("Save Changes") {
                saveAndApplyPendingSelection()
            }
            Button("Discard Changes", role: .destructive) {
                discardChangesAndApplyPendingSelection()
            }
            Button("Cancel", role: .cancel) {
                draftCoordinator.cancelPendingSelectionChange()
            }
        } message: {
            Text("You have unsaved edits in the inspector. Save them before switching transactions.")
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
            syncDraftCoordinator()
            if model.selectedTransactionID == nil {
                model.selectTransaction(
                    id: TransactionLedgerSelectionState.selectionAfterReload(
                        currentSelectionID: nil,
                        visibleRows: snapshot.transactions
                    )
                )
            }
        }
        .onChange(of: model.transactionFilter) { oldFilter, newFilter in
            if hasActiveSecondaryFilters(in: oldFilter), !hasActiveSecondaryFilters(in: newFilter) {
                userExpandedSecondaryFilters = false
            }
            syncControlsFromFilter()
        }
        .onChange(of: model.selectedTransactionDetail) { _, _ in
            syncDraftCoordinator()
        }
    }

    private var ledgerHeader: some View {
        VStack(alignment: .leading, spacing: 14) {
            TransactionLedgerHeaderView(
                state: headerState,
                onRemoveChip: clear
            )

            primaryFilterControls

            DisclosureGroup(isExpanded: secondaryFiltersExpansion) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .center, spacing: 12) {
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

                        Spacer(minLength: 0)
                    }

                    HStack(alignment: .center, spacing: 12) {
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

                        Spacer(minLength: 0)
                    }
                }
                .padding(.top, 10)
            } label: {
                Text(secondaryFiltersLabel)
                    .font(.subheadline.weight(.medium))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var primaryFilterControls: some View {
        HStack(alignment: .center, spacing: 12) {
            Picker("Account", selection: accountSelection) {
                Text("All Accounts").tag(Optional<UUID>.none)
                ForEach(snapshot.ledgerFilterAccounts) { account in
                    Text(accountFilterLabel(for: account)).tag(Optional(account.id))
                }
            }
            .frame(minWidth: 180)
            .layoutPriority(1)

            GroupedCategoryPicker(
                title: "Category",
                prompt: "All Categories",
                categories: snapshot.categories,
                categoryGroups: snapshot.categoryGroups,
                selection: categorySelection
            )
            .frame(minWidth: 220)
            .layoutPriority(1)

            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var ledgerContent: some View {
        if let zeroResultsState = headerState.zeroResultsState {
            zeroResultsView(state: zeroResultsState)
        } else if snapshot.transactions.isEmpty {
            ContentUnavailableView(
                "No transactions yet",
                systemImage: "tray",
                description: Text("Imported and accepted transactions appear here as the ledger grows.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            transactionList
        }
    }

    private var transactionList: some View {
        List(selection: selectedIDBinding) {
            ForEach(snapshot.transactions) { transaction in
                TransactionLedgerView.Row(transaction: transaction)
                    .tag(transaction.id)
            }
        }
        .listStyle(.inset)
    }

    private var accountSelection: Binding<UUID?> {
        Binding(
            get: { model.transactionFilter.accountID },
            set: { newValue in
                var filter = model.transactionFilter
                filter.accountID = newValue
                updateTransactionFilter(filter)
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
                updateTransactionFilter(filter)
            }
        )
    }

    private var reviewSelection: Binding<TransactionReviewStatus?> {
        Binding(
            get: { model.transactionFilter.reviewStatus },
            set: { newValue in
                var filter = model.transactionFilter
                filter.reviewStatus = newValue
                updateTransactionFilter(filter)
            }
        )
    }

    private var directionSelection: Binding<TransactionDirection?> {
        Binding(
            get: { model.transactionFilter.direction },
            set: { newValue in
                var filter = model.transactionFilter
                filter.direction = newValue
                updateTransactionFilter(filter)
            }
        )
    }

    private var importSessionSelection: Binding<Int64?> {
        Binding(
            get: { model.transactionFilter.importSessionID },
            set: { newValue in
                var filter = model.transactionFilter
                filter.importSessionID = newValue
                updateTransactionFilter(filter)
            }
        )
    }

    private var importOrigins: [TransactionImportOrigin] {
        snapshot.transactionImportOrigins
    }

    private var selectedAccountName: String? {
        guard let accountID = model.transactionFilter.accountID else {
            return nil
        }

        guard let account = snapshot.ledgerFilterAccounts.first(where: { $0.id == accountID }) else {
            return nil
        }

        return accountFilterLabel(for: account)
    }

    private var selectedCategoryName: String? {
        guard let categoryID = model.transactionFilter.categoryID else {
            return nil
        }

        return snapshot.categories.first(where: { $0.id == categoryID })?.name
    }

    private var selectedImportSessionName: String? {
        guard let importSessionID = model.transactionFilter.importSessionID else {
            return nil
        }

        return snapshot.transactionImportOrigins.first(where: { $0.id == importSessionID })?.originalFilename
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

    private var secondaryFiltersLabel: String {
        let count = headerState.activeChips.filter(\.matchesSecondaryControls).count
        return count == 0 ? "More Filters" : "More Filters (\(count))"
    }

    private func hasActiveSecondaryFilters(in filter: TransactionLedgerFilter) -> Bool {
        filter.direction != nil ||
            filter.reviewStatus != nil ||
            filter.importSessionID != nil ||
            filter.startDate != nil ||
            filter.endDate != nil
    }

    private func zeroResultsView(state: TransactionLedgerHeaderState.ZeroResultsState) -> some View {
        ContentUnavailableView {
            Label(state.title, systemImage: "line.3.horizontal.decrease.circle")
        } description: {
            Text(state.message)
        } actions: {
            if state.showsResetFilters {
                Button("Reset Filters") {
                    clear(chips: headerState.activeChips.filter { !$0.isSearchChip })
                }
            }

            if state.showsClearSearch {
                Button("Clear Search") {
                    clear(chips: headerState.activeChips.filter(\.isSearchChip))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func syncDraftCoordinator() {
        switch draftCoordinator.reloadDecision(
            for: model.selectedTransactionID,
            detail: model.selectedTransactionDetail
        ) {
        case .applyLoadedSelection:
            break
        case .preserveCurrentDraftAndPrompt:
            if model.selectedTransactionID != draftCoordinator.currentSelectionID {
                model.selectTransaction(id: draftCoordinator.currentSelectionID)
            }
        }
    }

    private func handleSelectionChange(to selectionID: UUID?) {
        switch draftCoordinator.selectionChangeDecision(for: selectionID) {
        case .proceed:
            model.selectTransaction(id: selectionID)
        case .promptToSaveDiscardOrCancel:
            break
        }
    }

    private func handleSave(_ draft: TransactionLedgerEditDraft) {
        let didSave = model.updateSelectedTransaction(draft: draft)
        applyPendingSelectionChange(draftCoordinator.completeSave(didSucceed: didSave))
    }

    private func saveAndApplyPendingSelection() {
        guard let draft = draftCoordinator.currentDraft else {
            return
        }

        handleSave(draft)
    }

    private func discardChangesAndApplyPendingSelection() {
        applyPendingSelectionChange(draftCoordinator.discardChanges())
    }

    private func applyPendingSelectionChange(_ pendingSelection: TransactionDetailDraftCoordinator.PendingSelectionChange) {
        switch pendingSelection {
        case .none:
            break
        case let .selection(selectionID):
            if selectionID != model.selectedTransactionID {
                model.selectTransaction(id: selectionID)
            }
        }
    }

    private func clear(_ chip: TransactionLedgerHeaderState.Chip) {
        clear(chips: [chip])
    }

    private func clear(chips: [TransactionLedgerHeaderState.Chip]) {
        guard !chips.isEmpty else {
            return
        }

        let nextFilter = TransactionLedgerHeaderState.removing(chips, from: model.transactionFilter)
        updateTransactionFilter(nextFilter)
    }

    private func updateTransactionFilter(_ nextFilter: TransactionLedgerFilter) {
        if hasActiveSecondaryFilters && !hasActiveSecondaryFilters(in: nextFilter) {
            userExpandedSecondaryFilters = false
        }

        model.updateTransactionFilter(nextFilter)
    }

    private func applyFilters() {
        guard !isSyncingControls else {
            return
        }

        var filter = model.transactionFilter
        filter.searchText = searchText
        filter.startDate = hasStartDate ? startDate : nil
        filter.endDate = hasEndDate ? endDate : nil
        updateTransactionFilter(filter)
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
}

private extension TransactionLedgerHeaderState.Chip {
    var isSearchChip: Bool {
        if case .search = self {
            return true
        }

        return false
    }

    var matchesSecondaryControls: Bool {
        switch self {
        case .direction, .review, .importSession, .dateRange:
            return true
        case .search, .account, .category, .categoryGroup:
            return false
        }
    }
}
