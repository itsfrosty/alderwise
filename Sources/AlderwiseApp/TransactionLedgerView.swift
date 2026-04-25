import Application
import Domain
import SwiftUI

struct TransactionLedgerView: View {
    struct EmptyLedgerState: Equatable {
        enum Action: Equatable {
            case showHidden
            case showActive
        }

        let title: String
        let systemImage: String
        let description: String
        let action: Action?
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
    @State private var listSelectionID: UUID?

    init(snapshot: WorkspaceSnapshot, model: WorkspaceShellModel) {
        self.snapshot = snapshot
        self.model = model
        _searchText = State(initialValue: model.transactionFilter.searchText)
        _hasStartDate = State(initialValue: model.transactionFilter.startDate != nil)
        _hasEndDate = State(initialValue: model.transactionFilter.endDate != nil)
        _startDate = State(initialValue: model.transactionFilter.startDate ?? Date())
        _endDate = State(initialValue: model.transactionFilter.endDate ?? Date())
        _draftCoordinator = State(
            initialValue: TransactionDetailDraftCoordinator(
                selectionID: model.selectedTransactionID,
                detail: model.selectedTransactionDetail
            )
        )
        _listSelectionID = State(initialValue: model.selectedTransactionID)
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
            rows: visibleTransactions,
            filter: model.transactionFilter,
            accountName: selectedAccountName,
            categoryName: selectedCategoryName,
            categoryGroupName: categoryGroupFilterName,
            importSessionName: selectedImportSessionName
        )
    }

    private var hasActiveSecondaryFilters: Bool {
        hasActiveSecondaryFilters(in: model.transactionFilter)
    }

    private var visibleTransactions: [TransactionLedgerRow] {
        model.matchingTransactions(in: snapshot.transactions)
    }

    private var secondaryFiltersExpansion: Binding<Bool> {
        Binding(
            get: { hasActiveSecondaryFilters || userExpandedSecondaryFilters },
            set: { isExpanded in
                userExpandedSecondaryFilters = hasActiveSecondaryFilters ? false : isExpanded
            }
        )
    }

    private static let headerInsets = EdgeInsets(
        top: 12,
        leading: 20,
        bottom: 12,
        trailing: 12
    )

    var body: some View {
        HSplitView {
            VStack(spacing: 0) {
                ledgerHeader
                    .padding(Self.headerInsets)

                Divider()

                ledgerContent
            }
            .frame(idealWidth: 560, maxWidth: .infinity, maxHeight: .infinity)

            TransactionLedgerView.DetailInspector(
                detail: model.selectedTransactionDetail,
                categories: snapshot.categories,
                categoryGroups: snapshot.categoryGroups,
                draft: draftCoordinator.currentDraft,
                isDirty: draftCoordinator.isDirty,
                onDraftChange: { draftCoordinator.updateDraft($0) },
                onSave: handleSave,
                onSetHidden: { model.setSelectedTransactionHidden($0) },
                onViewRule: handleViewRule
            )
                .frame(idealWidth: 420, maxWidth: .infinity, maxHeight: .infinity)
        }
        .alert(
            "Save changes before leaving this transaction?",
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
            Text("You have unsaved edits in the inspector. Save them before switching transactions or opening Rules.")
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
            if model.selectedTransactionID == nil, model.transactionFilter.ruleFilterIntent == nil {
                model.selectTransaction(
                    id: TransactionLedgerSelectionState.selectionAfterReload(
                        currentSelectionID: nil,
                        visibleRows: visibleTransactions
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
        .onChange(of: listSelectionID) { _, newSelectionID in
            guard newSelectionID != model.selectedTransactionID else {
                return
            }
            handleSelectionChange(to: newSelectionID)
        }
        .onChange(of: model.selectedTransactionID) { _, _ in
            syncListSelectionFromModel()
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
                        Picker("Visibility", selection: visibilitySelection) {
                            Text("Active").tag(TransactionVisibilityFilter.active)
                            Text("Hidden").tag(TransactionVisibilityFilter.hidden)
                            Text("All").tag(TransactionVisibilityFilter.all)
                        }
                        .frame(minWidth: 140)
                        .layoutPriority(1)

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
        VStack(alignment: .leading, spacing: 12) {
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
    }

    @ViewBuilder
    private var ledgerContent: some View {
        if let zeroResultsState = headerState.zeroResultsState {
            zeroResultsView(state: zeroResultsState)
        } else if snapshot.transactions.isEmpty {
            emptyLedgerView
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(visibleTransactions) { transaction in
                            Button {
                                listSelectionID = transaction.id
                            } label: {
                                TransactionLedgerView.Row(transaction: transaction)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 4)
                                    .background(rowBackground(for: transaction.id))
                            }
                            .buttonStyle(.plain)
                            .contentShape(Rectangle())
                            .contextMenu {
                                Button(transaction.isHidden ? "Unhide Transaction" : "Hide Transaction") {
                                    _ = model.setTransactionHidden(id: transaction.id, isHidden: !transaction.isHidden)
                                }
                                .disabled(
                                    transaction.id == model.selectedTransactionID && draftCoordinator.isDirty
                                )
                            }
                            .id(transaction.id)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                }
                .background(.background)
                .onAppear {
                    syncListSelectionFromModel()
                    scrollSelectionIfNeeded(with: proxy, animated: false)
                }
                .onChange(of: model.selectedTransactionID) { _, _ in
                    scrollSelectionIfNeeded(with: proxy, animated: true)
                }
                .onMoveCommand { direction in
                    switch direction {
                    case .down:
                        moveSelection(by: 1)
                    case .up:
                        moveSelection(by: -1)
                    default:
                        break
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func rowBackground(for transactionID: UUID) -> some View {
        if listSelectionID == transactionID {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.accentColor.opacity(0.16))
        } else {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.clear)
        }
    }

    private var visibilitySelection: Binding<TransactionVisibilityFilter> {
        Binding(
            get: { model.transactionFilter.visibility ?? .active },
            set: { newValue in
                var filter = model.transactionFilter
                filter.visibility = newValue == .active ? nil : newValue
                updateTransactionFilter(filter)
            }
        )
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
                updateTransactionFilter(
                    Self.applyingCategorySelection(newValue, to: model.transactionFilter)
                )
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

    private var currentVisibility: TransactionVisibilityFilter {
        model.transactionFilter.visibility ?? .active
    }

    private var secondaryFiltersLabel: String {
        let count = headerState.activeChips.filter(\.matchesSecondaryControls).count
        return count == 0 ? "More Filters" : "More Filters (\(count))"
    }

    private func hasActiveSecondaryFilters(in filter: TransactionLedgerFilter) -> Bool {
        filter.visibility == .hidden ||
            filter.visibility == .all ||
            filter.direction != nil ||
            filter.reviewStatus != nil ||
            filter.importSessionID != nil
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

    @ViewBuilder
    private var emptyLedgerView: some View {
        let state = Self.emptyLedgerState(for: currentVisibility, summary: snapshot.summary)
        ContentUnavailableView {
            Label(state.title, systemImage: state.systemImage)
        } description: {
            Text(state.description)
        } actions: {
            switch state.action {
            case .showHidden:
                Button("Show Hidden") {
                    visibilitySelection.wrappedValue = .hidden
                }
            case .showActive:
                Button("Show Active") {
                    visibilitySelection.wrappedValue = .active
                }
            case nil:
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    static func applyingCategorySelection(_ categoryID: UUID?, to filter: TransactionLedgerFilter) -> TransactionLedgerFilter {
        var nextFilter = filter
        nextFilter.categoryID = categoryID
        nextFilter.categoryGroupID = nil
        nextFilter.uncategorizedOnly = false
        return nextFilter
    }

    static func emptyLedgerState(
        for visibility: TransactionVisibilityFilter,
        summary: WorkspaceSummary
    ) -> EmptyLedgerState {
        switch visibility {
        case .active:
            return EmptyLedgerState(
                title: "No active transactions",
                systemImage: "tray",
                description: summary.hiddenTransactionCount > 0
                    ? "Imported transactions appear here as the ledger grows. Hidden transactions only appear in Hidden or All."
                    : "Imported transactions appear here as the ledger grows.",
                action: summary.hiddenTransactionCount > 0 ? .showHidden : nil
            )
        case .hidden:
            return EmptyLedgerState(
                title: "No hidden transactions",
                systemImage: "eye.slash",
                description: "Hidden transactions stay out of reporting until you unhide them.",
                action: .showActive
            )
        case .all:
            return EmptyLedgerState(
                title: "No transactions yet",
                systemImage: "tray",
                description: "Imported transactions appear here as the ledger grows.",
                action: nil
            )
        }
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
            syncListSelectionFromModel()
            break
        }
    }

    private func handleSave(_ draft: TransactionLedgerEditDraft) {
        let didSave = model.updateSelectedTransaction(draft: draft)
        applyPendingSelectionChange(draftCoordinator.completeSave(didSucceed: didSave))
    }

    private func handleViewRule(_ selection: LearnedRulesDestination.Selection) {
        switch draftCoordinator.ruleNavigationDecision(for: selection) {
        case .proceed:
            model.showLearnedRules(selection: selection)
        case .promptToSaveDiscardOrCancel:
            break
        }
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
        case let .rules(selection):
            model.showLearnedRules(selection: selection)
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

    private func syncListSelectionFromModel() {
        if listSelectionID != model.selectedTransactionID {
            listSelectionID = model.selectedTransactionID
        }
    }

    private func moveSelection(by offset: Int) {
        guard visibleTransactions.isEmpty == false else {
            return
        }

        let currentSelectionID = listSelectionID ?? model.selectedTransactionID
        let currentIndex = if let currentSelectionID,
                              let index = visibleTransactions.firstIndex(where: { $0.id == currentSelectionID }) {
            index
        } else if offset > 0 {
            visibleTransactions.startIndex
        } else {
            visibleTransactions.index(before: visibleTransactions.endIndex)
        }

        let nextIndex = min(
            max(currentIndex + offset, visibleTransactions.startIndex),
            visibleTransactions.index(before: visibleTransactions.endIndex)
        )
        listSelectionID = visibleTransactions[nextIndex].id
    }

    private func scrollSelectionIfNeeded(with proxy: ScrollViewProxy, animated: Bool) {
        guard let selectedTransactionID = model.selectedTransactionID else {
            return
        }

        let scroll = {
            proxy.scrollTo(selectedTransactionID, anchor: .center)
        }

        if animated {
            withAnimation(.easeInOut(duration: 0.16)) {
                scroll()
            }
        } else {
            scroll()
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
        case .visibility, .direction, .review, .importSession:
            return true
        case .search, .merchant, .ruleMatch, .account, .category, .categoryGroup, .uncategorized, .dateRange:
            return false
        }
    }
}
