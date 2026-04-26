import Application
import Domain
import SwiftUI

enum AnalysisInspectorPresentation: Equatable {
    case hidden
    case persistent
    case transient

    static func resolve(
        isRequested: Bool,
        availableWidth: CGFloat
    ) -> AnalysisInspectorPresentation {
        guard isRequested else {
            return .hidden
        }

        return availableWidth > AnalysisView.persistentInspectorMinimumWidth ? .persistent : .transient
    }

    var presentsTransientSheet: Bool {
        self == .transient
    }

    func shouldPresentTransientInspector(hasSelection: Bool) -> Bool {
        presentsTransientSheet && hasSelection
    }
}

struct AnalysisView: View {
    nonisolated static let persistentInspectorMinimumWidth = WorkspaceLayout.minimumWindowWidth - WorkspaceLayout.sidebarIdealWidth

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
            let inspectorPresentation = AnalysisInspectorPresentation.resolve(
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
                            inspectorPresentation: inspectorPresentation
                        )
                    }
                }
            }
        }
        .navigationTitle("Analysis")
        .toolbar {
            AnalysisContextControls(
                page: selectedPage,
                context: model.analysisContext,
                snapshot: model.analysisSnapshot,
                setRange: model.setAnalysisRange,
                setComparison: model.setAnalysisComparison
            )

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
    private func selectedPageView(inspectorPresentation: AnalysisInspectorPresentation) -> some View {
        switch selectedPage {
        case .overview:
            if let overview = model.analysisSnapshot.overview {
                AnalysisOverviewView(
                    snapshot: overview,
                    selection: Binding(
                        get: { model.analysisOverviewSelection },
                        set: { model.setAnalysisOverviewSelection($0) }
                    ),
                    inspectorPresentation: inspectorPresentation,
                    onDismissTransientInspector: {
                        model.setAnalysisInspectorVisible(false)
                    },
                    onShowTransactions: {
                        model.showAnalysisTransactions(filter: $0)
                    }
                )
            }
        case .categories:
            if let categories = model.analysisSnapshot.categories {
                AnalysisCategoriesView(
                    snapshot: categories,
                    sort: Binding(
                        get: { model.analysisCategoriesSort },
                        set: { model.setAnalysisCategoriesSort($0) }
                    ),
                    selection: Binding(
                        get: { model.analysisCategoriesSelection },
                        set: { model.setAnalysisCategoriesSelection($0) }
                    ),
                    inspectorPresentation: inspectorPresentation,
                    onDismissTransientInspector: {
                        model.setAnalysisInspectorVisible(false)
                    },
                    onShowTransactions: {
                        model.showAnalysisTransactions(filter: $0)
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
                    sort: Binding(
                        get: { model.analysisMerchantsSort },
                        set: { model.setAnalysisMerchantsSort($0) }
                    ),
                    selection: Binding(
                        get: { model.analysisMerchantsSelection },
                        set: { model.setAnalysisMerchantsSelection($0) }
                    ),
                    inspectorPresentation: inspectorPresentation,
                    onDismissTransientInspector: {
                        model.setAnalysisInspectorVisible(false)
                    },
                    onShowTransactions: {
                        model.showAnalysisTransactions(filter: $0)
                    },
                    onShowRules: { merchantPattern in
                        model.showLearnedRules(merchantPattern: merchantPattern)
                    }
                )
            }
        }
    }
}
