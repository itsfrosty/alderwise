import Application
import Domain
import SwiftUI

struct AnalysisView: View {
    enum InspectorPresentation: Equatable {
        case hidden
        case persistent
        case transient
    }

    nonisolated static let inspectorVisibilityWidth = WorkspaceLayout.minimumWindowWidth - WorkspaceLayout.sidebarIdealWidth

    @ObservedObject var model: WorkspaceShellModel

    private var availablePages: [AnalysisPage] {
        Self.familyStripPages(in: model.analysisSnapshot)
    }

    private var selectedPage: AnalysisPage {
        let repairedState = model.analysisToolbarState.repaired(for: model.analysisSnapshot)
        return repairedState.selectedPage
    }

    var body: some View {
        GeometryReader { proxy in
            let inspectorPresentation = Self.inspectorPresentation(
                isRequested: model.analysisToolbarState.isInspectorVisible,
                availableWidth: proxy.size.width
            )

            Group {
                if let errorMessage = model.analysisErrorMessage {
                    ContentUnavailableView(
                        "Analysis Unavailable",
                        systemImage: AppSection.analysis.systemImage,
                        description: Text(errorMessage)
                    )
                } else if availablePages.isEmpty {
                    ContentUnavailableView(
                        "Analysis Not Ready",
                        systemImage: AppSection.analysis.systemImage,
                        description: Text("Import more transaction history to unlock Overview, Categories, and Merchants analysis.")
                    )
                } else {
                    VStack(spacing: 0) {
                        familyStrip
                        selectedPageView(
                            showsInspector: inspectorPresentation == .persistent
                        )
                    }
                }
            }
            .sheet(
                isPresented: Binding(
                    get: { inspectorPresentation == .transient },
                    set: { isPresented in
                        if isPresented == false {
                            model.setAnalysisInspectorVisible(false)
                        }
                    }
                )
            ) {
                narrowInspectorView
            }
        }
        .navigationTitle("Analysis")
        .toolbar {
            ToolbarItem {
                Button {
                    model.toggleAnalysisInspector()
                } label: {
                    Label(
                        model.analysisToolbarState.isInspectorVisible ? "Hide Inspector" : "Show Inspector",
                        systemImage: model.analysisToolbarState.isInspectorVisible ? "sidebar.right" : "sidebar.right"
                    )
                }
            }
        }
        .onAppear {
            model.ensureAnalysisLoaded()
            model.selectAnalysisPage(selectedPage)
        }
    }

    nonisolated static func familyStripPages(in snapshot: AnalysisSnapshot) -> [AnalysisPage] {
        AnalysisToolbarState.availablePages(in: snapshot)
    }

    nonisolated static func inspectorPresentation(
        isRequested: Bool,
        availableWidth: CGFloat
    ) -> InspectorPresentation {
        guard isRequested else {
            return .hidden
        }

        return availableWidth >= inspectorVisibilityWidth ? .persistent : .transient
    }

    nonisolated static func showsInspector(isRequested: Bool, availableWidth: CGFloat) -> Bool {
        inspectorPresentation(
            isRequested: isRequested,
            availableWidth: availableWidth
        ) == .persistent
    }

    static func makeTransactionsHandler(
        model: WorkspaceShellModel
    ) -> (TransactionLedgerFilter) -> Void {
        { filter in
            model.showTransactions(filter: filter, clearSelection: false)
        }
    }

    private var familyStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(availablePages) { page in
                    Button {
                        model.selectAnalysisPage(page)
                    } label: {
                        Text(page.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(page == selectedPage ? Color.primary : Color.secondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(page == selectedPage ? Color.accentColor.opacity(0.16) : Color.secondary.opacity(0.08))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 12)
        }
        .background(.bar)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    @ViewBuilder
    private var narrowInspectorView: some View {
        switch selectedPage {
        case .overview:
            AnalysisInspectorView(
                selection: model.analysisOverviewSelection,
                noSelectionDescription: "Select a driver, recurring series, or projected insight to inspect its evidence and drill into matching transactions."
            ) { selected in
                Button {
                    Self.makeTransactionsHandler(model: model)(
                        model.analysisSnapshot.overview?.transactionFilter(for: selected) ?? .empty
                    )
                } label: {
                    Label("Show Transactions", systemImage: "list.bullet.rectangle")
                }
                .buttonStyle(.borderedProminent)
            }
        case .categories:
            AnalysisInspectorView(
                selection: model.analysisCategoriesSelection,
                noSelectionDescription: "Select a category or group to inspect its evidence, open matching transactions, or jump into its target if one exists.",
                onShowTransactions: { selected in
                    guard let snapshot = model.analysisSnapshot.categories else {
                        return
                    }
                    Self.makeTransactionsHandler(model: model)(
                        snapshot.transactionFilter(for: selected)
                    )
                }
            ) { selected in
                if let snapshot = model.analysisSnapshot.categories,
                   let targetProgress = snapshot.targetProgress(for: selected) {
                    Button {
                        model.showTarget(id: targetProgress.id)
                    } label: {
                        Label("Open Target", systemImage: "target")
                    }
                    .buttonStyle(.bordered)
                }
            }
        case .merchants:
            AnalysisInspectorView(
                selection: model.analysisMerchantsSelection,
                noSelectionDescription: "Select a merchant or recurring series to inspect its evidence, open matching transactions, or hand off to Rules for merchant cleanup."
            ) { selected in
                VStack(alignment: .leading, spacing: 10) {
                    if let snapshot = model.analysisSnapshot.merchants {
                        Button {
                            Self.makeTransactionsHandler(model: model)(
                                snapshot.transactionFilter(for: selected)
                            )
                        } label: {
                            Label("Show Transactions", systemImage: "list.bullet.rectangle")
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    if let merchantName = merchantsInspectorMerchantName(for: selected) {
                        Button {
                            model.showLearnedRules()
                        } label: {
                            Label("Open Rules", systemImage: "slider.horizontal.3")
                        }
                        .buttonStyle(.bordered)
                        .help(merchantName)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func selectedPageView(showsInspector: Bool) -> some View {
        switch selectedPage {
        case .overview:
            if let overview = model.analysisSnapshot.overview {
                AnalysisOverviewView(
                    snapshot: overview,
                    selection: Binding(
                        get: { model.analysisOverviewSelection },
                        set: { model.setAnalysisOverviewSelection($0) }
                    ),
                    showsInspector: showsInspector,
                    onShowTransactions: Self.makeTransactionsHandler(model: model)
                )
            }
        case .categories:
            if let categories = model.analysisSnapshot.categories {
                AnalysisCategoriesView(
                    snapshot: categories,
                    selection: Binding(
                        get: { model.analysisCategoriesSelection },
                        set: { model.setAnalysisCategoriesSelection($0) }
                    ),
                    showsInspector: showsInspector,
                    onShowTransactions: Self.makeTransactionsHandler(model: model),
                    onShowTarget: { targetID in
                        model.showTarget(id: targetID)
                    }
                )
            }
        case .merchants:
            if let merchants = model.analysisSnapshot.merchants {
                AnalysisMerchantsView(
                    snapshot: merchants,
                    selection: Binding(
                        get: { model.analysisMerchantsSelection },
                        set: { model.setAnalysisMerchantsSelection($0) }
                    ),
                    showsInspector: showsInspector,
                    onShowTransactions: Self.makeTransactionsHandler(model: model),
                    onShowRules: { _ in
                        model.showLearnedRules()
                    }
                )
            }
        }
    }
}

private func merchantsInspectorMerchantName(
    for selection: AnalysisMerchantsSelection
) -> String? {
    switch selection {
    case .merchant(let row):
        row.key.normalizedName
    case .recurring(let row):
        row.detail.normalizedMerchantName
    }
}
