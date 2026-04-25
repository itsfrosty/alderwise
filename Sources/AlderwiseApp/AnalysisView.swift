import Application
import Domain
import SwiftUI

struct AnalysisView: View {
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
                            showsInspector: Self.showsInspector(
                                isRequested: model.analysisToolbarState.isInspectorVisible,
                                availableWidth: proxy.size.width
                            )
                        )
                    }
                }
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

    nonisolated static func showsInspector(isRequested: Bool, availableWidth: CGFloat) -> Bool {
        isRequested && availableWidth >= inspectorVisibilityWidth
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
                    showsInspector: showsInspector,
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
                    showsInspector: showsInspector,
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
