import Application
import Domain
import SwiftUI

struct AnalysisView: View {
    @ObservedObject var model: WorkspaceShellModel

    private var availablePages: [AnalysisPage] {
        AnalysisToolbarState.availablePages(in: model.analysisSnapshot)
    }

    private var selectedPage: AnalysisPage {
        let repairedState = model.analysisToolbarState.repaired(for: model.analysisSnapshot)
        return repairedState.selectedPage
    }

    var body: some View {
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
                selectedPageView
            }
        }
        .navigationTitle("Analysis")
        .toolbar {
            ToolbarItem {
                Picker("Analysis Page", selection: Binding(
                    get: { selectedPage },
                    set: { model.selectAnalysisPage($0) }
                )) {
                    ForEach(availablePages) { page in
                        Text(page.title).tag(page)
                    }
                }
                .pickerStyle(.segmented)
                .frame(
                    minWidth: WorkspaceLayout.analysisPagePickerMinimumWidth,
                    idealWidth: WorkspaceLayout.analysisPagePickerIdealWidth
                )
            }

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

    @ViewBuilder
    private var selectedPageView: some View {
        switch selectedPage {
        case .overview:
            if let overview = model.analysisSnapshot.overview {
                AnalysisOverviewView(
                    snapshot: overview,
                    selection: Binding(
                        get: { model.analysisOverviewSelection },
                        set: { model.setAnalysisOverviewSelection($0) }
                    ),
                    showsInspector: model.analysisToolbarState.isInspectorVisible,
                    onShowTransactions: { filter in
                        model.showTransactions(filter: filter, clearSelection: filter.clearsSelectionOnNavigation)
                    }
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
                    showsInspector: model.analysisToolbarState.isInspectorVisible,
                    onShowTransactions: { filter in
                        model.showTransactions(filter: filter, clearSelection: filter.clearsSelectionOnNavigation)
                    },
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
                    showsInspector: model.analysisToolbarState.isInspectorVisible,
                    onShowTransactions: { filter in
                        model.showTransactions(filter: filter, clearSelection: filter.clearsSelectionOnNavigation)
                    },
                    onShowRules: { _ in
                        model.showLearnedRules()
                    }
                )
            }
        }
    }
}

private extension TransactionLedgerFilter {
    var clearsSelectionOnNavigation: Bool {
        ruleFilterIntent != nil || normalizedMerchantName != nil
    }
}
