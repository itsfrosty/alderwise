import Application
import Domain
import SwiftUI

enum AnalysisInspectorPresentation: Equatable {
    enum LayoutAvailability: Equatable {
        case persistent
        case transient
    }

    case hidden
    case persistent
    case transient

    static func layoutAvailability(availableWidth: CGFloat) -> LayoutAvailability {
        availableWidth > AnalysisView.persistentInspectorMinimumWidth ? .persistent : .transient
    }

    static func resolve(
        isRequested: Bool,
        layoutAvailability: LayoutAvailability
    ) -> AnalysisInspectorPresentation {
        guard isRequested else {
            return .hidden
        }

        switch layoutAvailability {
        case .persistent:
            return .persistent
        case .transient:
            return .transient
        }
    }

    static func resolve(
        isRequested: Bool,
        availableWidth: CGFloat
    ) -> AnalysisInspectorPresentation {
        resolve(
            isRequested: isRequested,
            layoutAvailability: layoutAvailability(availableWidth: availableWidth)
        )
    }

    var presentsTransientSheet: Bool {
        self == .transient
    }

    func shouldPresentTransientInspector(isExplicitlyPresented: Bool) -> Bool {
        presentsTransientSheet && isExplicitlyPresented
    }
}

struct AnalysisView: View {
    nonisolated static let persistentInspectorMinimumWidth = WorkspaceLayout.minimumWindowWidth - WorkspaceLayout.sidebarIdealWidth

    struct InspectorToolbarState: Equatable {
        let title: String
        let systemImage: String
        let isPresented: Bool
    }

    struct InspectorToggleResult: Equatable {
        let isInspectorRequested: Bool
        let isTransientInspectorPresented: Bool
    }

    struct ReadOnlyMetadata: Equatable {
        let scopeLabel: String?
        let basisLabel: String?
    }

    @ObservedObject var model: WorkspaceShellModel
    @State private var isTransientInspectorPresented = false

    private var availablePages: [AnalysisPage] {
        Self.familyStripPages(in: model.analysisSnapshot)
    }

    private var selectedPage: AnalysisPage {
        let repairedState = model.analysisToolbarState.repaired(for: model.analysisSnapshot)
        return repairedState.selectedPage
    }

    var body: some View {
        GeometryReader { proxy in
            let layoutAvailability = AnalysisInspectorPresentation.layoutAvailability(
                availableWidth: proxy.size.width
            )
            let inspectorPresentation = AnalysisInspectorPresentation.resolve(
                isRequested: model.analysisToolbarState.isInspectorVisible,
                layoutAvailability: layoutAvailability
            )
            let toolbarState = Self.inspectorToolbarState(
                layoutAvailability: layoutAvailability,
                isInspectorRequested: model.analysisToolbarState.isInspectorVisible,
                isTransientInspectorPresented: isTransientInspectorPresented
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
                        contextMetadata
                        selectedPageView(
                            inspectorPresentation: inspectorPresentation
                        )
                    }
                }
            }
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
                        toggleInspectorPresentation(layoutAvailability: layoutAvailability)
                    } label: {
                        Label(toolbarState.title, systemImage: toolbarState.systemImage)
                    }
                }
            }
            .onChange(of: layoutAvailability, initial: true) { _, availability in
                if availability != .transient {
                    isTransientInspectorPresented = false
                }
            }
        }
        .navigationTitle("Analysis")
        .onAppear {
            model.ensureAnalysisLoaded()
            model.selectAnalysisPage(selectedPage)
        }
        .onChange(of: model.analysisToolbarState.selectedPage) { _, _ in
            isTransientInspectorPresented = false
        }
        .onDisappear {
            isTransientInspectorPresented = false
        }
    }

    nonisolated static func familyStripPages(in snapshot: AnalysisSnapshot) -> [AnalysisPage] {
        AnalysisToolbarState.availablePages(in: snapshot)
    }

    nonisolated static func inspectorToolbarState(
        layoutAvailability: AnalysisInspectorPresentation.LayoutAvailability,
        isInspectorRequested: Bool,
        isTransientInspectorPresented: Bool
    ) -> InspectorToolbarState {
        switch layoutAvailability {
        case .persistent:
            InspectorToolbarState(
                title: isInspectorRequested ? "Hide Inspector" : "Show Inspector",
                systemImage: "sidebar.right",
                isPresented: isInspectorRequested
            )
        case .transient:
            InspectorToolbarState(
                title: isTransientInspectorPresented ? "Hide Details" : "Show Details",
                systemImage: "sidebar.right",
                isPresented: isTransientInspectorPresented
            )
        }
    }

    nonisolated static func inspectorToggleResult(
        layoutAvailability: AnalysisInspectorPresentation.LayoutAvailability,
        isInspectorRequested: Bool,
        isTransientInspectorPresented: Bool
    ) -> InspectorToggleResult {
        switch layoutAvailability {
        case .persistent:
            InspectorToggleResult(
                isInspectorRequested: !isInspectorRequested,
                isTransientInspectorPresented: false
            )
        case .transient:
            InspectorToggleResult(
                isInspectorRequested: true,
                isTransientInspectorPresented: !isTransientInspectorPresented
            )
        }
    }

    nonisolated static func dismissTransientInspector(
        setTransientInspectorPresented: @escaping (Bool) -> Void
    ) -> () -> Void {
        {
            setTransientInspectorPresented(false)
        }
    }

    nonisolated static func readOnlyMetadata(
        for page: AnalysisPage,
        snapshot: AnalysisSnapshot
    ) -> ReadOnlyMetadata {
        ReadOnlyMetadata(
            scopeLabel: AnalysisContextControls.scopeLabel(for: page, snapshot: snapshot),
            basisLabel: AnalysisContextControls.metricBasisLabel(for: page, snapshot: snapshot)
        )
    }

    @MainActor
    private func toggleInspectorPresentation(
        layoutAvailability: AnalysisInspectorPresentation.LayoutAvailability
    ) {
        let result = Self.inspectorToggleResult(
            layoutAvailability: layoutAvailability,
            isInspectorRequested: model.analysisToolbarState.isInspectorVisible,
            isTransientInspectorPresented: isTransientInspectorPresented
        )

        model.setAnalysisInspectorVisible(result.isInspectorRequested)
        isTransientInspectorPresented = result.isTransientInspectorPresented
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
    private var contextMetadata: some View {
        let metadata = Self.readOnlyMetadata(for: selectedPage, snapshot: model.analysisSnapshot)

        if metadata.scopeLabel != nil || metadata.basisLabel != nil {
            HStack(spacing: 16) {
                if let scopeLabel = metadata.scopeLabel {
                    metadataChip(title: "Scope", value: scopeLabel)
                }

                if let basisLabel = metadata.basisLabel {
                    metadataChip(title: "Basis", value: basisLabel)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .background(.bar)
            .overlay(alignment: .bottom) {
                Divider()
            }
        }
    }

    private func metadataChip(title: String, value: String) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .foregroundStyle(.secondary)
            Text(value)
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.quinary, in: Capsule())
        .accessibilityElement(children: .combine)
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
                        Self.dismissTransientInspector(
                            setTransientInspectorPresented: { isTransientInspectorPresented = $0 }
                        )()
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
                        Self.dismissTransientInspector(
                            setTransientInspectorPresented: { isTransientInspectorPresented = $0 }
                        )()
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
                        Self.dismissTransientInspector(
                            setTransientInspectorPresented: { isTransientInspectorPresented = $0 }
                        )()
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
