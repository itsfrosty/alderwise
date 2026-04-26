import Application
import Domain
import Foundation
import SwiftUI
import Testing

@testable import AlderwiseApp

@Test
@MainActor
func analysisOverviewStartsWithoutSelectionWhenPresented() {
    let model = WorkspaceShellModel(store: nil, service: nil)

    model.presentAnalysisOverview()

    #expect(model.isPresentingAnalysisOverview)
    #expect(model.analysisOverviewSelection == nil)
}

@Test
func analysisReadOnlyMetadataUsesVisiblePageContext() {
    let categoriesContext = AnalysisContext(
        range: .monthToDate,
        scope: .workspace,
        comparison: .previousPeriod,
        metricBasis: .acceptedExpenses
    )
    let snapshot = AnalysisSnapshot(
        overview: AnalysisOverviewSnapshot(
            context: AnalysisContext(
                range: .monthToDate,
                scope: .workspace,
                comparison: .previousPeriod,
                metricBasis: .includedVisibleExpenses
            ),
            report: OverviewReport(
                context: AnalysisContext(),
                currentSpend: Decimal(120),
                comparisonSpend: Decimal(80),
                drivers: [],
                recurring: []
            ),
            monthlyReport: .empty,
            projectedInsights: []
        ),
        categories: AnalysisCategoriesSnapshot(
            context: categoriesContext,
            report: CategoryAnalysisReport(context: categoriesContext, rows: []),
            targetProgress: []
        )
    )

    #expect(
        AnalysisView.readOnlyMetadata(for: .overview, snapshot: snapshot)
            == AnalysisView.ReadOnlyMetadata(scopeLabel: "Workspace", basisLabel: "All visible spending")
    )
    #expect(
        AnalysisView.readOnlyMetadata(for: .categories, snapshot: snapshot)
            == AnalysisView.ReadOnlyMetadata(scopeLabel: "Workspace", basisLabel: "Accepted spending")
    )
}

@Test
@MainActor
func analysisOverviewCommitsSelectionWithoutDismissingPresentation() {
    let model = WorkspaceShellModel(store: nil, service: nil)
    let selection = AnalysisOverviewSelection.driver(
        AnalysisSpendRow(
            title: "Dining",
            scope: .category(analysisViewStateID("00000000-0000-0000-0000-000000000401")),
            currentSpend: Decimal(180),
            comparisonSpend: Decimal(40),
            delta: Decimal(140),
            evidence: InsightEvidence(
                metricBasis: .includedVisibleExpenses,
                resolvedInterval: DateInterval(
                    start: analysisViewStateUTCDate(year: 2026, month: 4, day: 1),
                    end: analysisViewStateUTCDate(year: 2026, month: 4, day: 16)
                ),
                scope: .category(analysisViewStateID("00000000-0000-0000-0000-000000000401")),
                reconciliationRule: .exactTransactionSum,
                destination: InsightEvidenceDestination(
                    scope: .category(analysisViewStateID("00000000-0000-0000-0000-000000000401")),
                    direction: .expense
                )
            )
        )
    )

    model.presentAnalysisOverview()
    model.setAnalysisOverviewSelection(selection)

    #expect(model.isPresentingAnalysisOverview)
    #expect(model.analysisOverviewSelection == selection)
}

@Test
@MainActor
func analysisOverviewSelectionSurvivesTransactionDrilldownAndReopen() {
    let model = WorkspaceShellModel(store: nil, service: nil)
    let selection = AnalysisOverviewSelection.recurring(
        MerchantRecurringReportRow(
            detail: RecurringChargeInsightDetail(
                accountID: analysisViewStateID("00000000-0000-0000-0000-000000000501"),
                normalizedMerchantName: "netflix",
                cadence: .monthly,
                observationCount: 3,
                amountRange: RecurringChargeAmountRange(minimum: Decimal(15.49), maximum: Decimal(15.49)),
                supportingTransactionIDs: [
                    analysisViewStateID("00000000-0000-0000-0000-000000000511"),
                    analysisViewStateID("00000000-0000-0000-0000-000000000512"),
                    analysisViewStateID("00000000-0000-0000-0000-000000000513"),
                ],
                firstObservedDate: analysisViewStateUTCDate(year: 2026, month: 2, day: 9),
                lastObservedDate: analysisViewStateUTCDate(year: 2026, month: 4, day: 9),
                nextExpectedDateWindow: nil
            ),
            evidence: InsightEvidence(
                metricBasis: .includedVisibleExpenses,
                resolvedInterval: DateInterval(
                    start: analysisViewStateUTCDate(year: 2026, month: 2, day: 9),
                    end: analysisViewStateUTCDate(year: 2026, month: 4, day: 10)
                ),
                scope: .merchant("netflix"),
                reconciliationRule: .recurringObservationSet,
                destination: InsightEvidenceDestination(scope: .merchant("netflix"), direction: .expense)
            )
        )
    )

    model.presentAnalysisOverview()
    model.setAnalysisOverviewSelection(selection)
    model.showTransactions(
        filter: TransactionLedgerFilter(
            normalizedMerchantName: "netflix",
            direction: .expense,
            reviewStatuses: Set([.accepted, .pending]),
            visibility: .active
        )
    )
    model.dismissAnalysisOverview()
    model.presentAnalysisOverview()

    #expect(model.pendingAppSectionNavigation == .transactions)
    #expect(model.isPresentingAnalysisOverview)
    #expect(model.analysisOverviewSelection == selection)
}

@Test
@MainActor
func analysisCategoriesSelectionPersistsWhenShowingTarget() {
    let model = WorkspaceShellModel(store: nil, service: nil)
    let targetID = analysisViewStateID("00000000-0000-0000-0000-000000000601")
    let selection = AnalysisCategoriesSelection.row(
        AnalysisSpendRow(
            title: "Food",
            scope: .categoryGroup(analysisViewStateID("00000000-0000-0000-0000-000000000602")),
            currentSpend: Decimal(320),
            comparisonSpend: Decimal(260),
            delta: Decimal(60),
            evidence: InsightEvidence(
                metricBasis: .includedVisibleExpenses,
                resolvedInterval: DateInterval(
                    start: analysisViewStateUTCDate(year: 2026, month: 4, day: 1),
                    end: analysisViewStateUTCDate(year: 2026, month: 4, day: 16)
                ),
                scope: .categoryGroup(analysisViewStateID("00000000-0000-0000-0000-000000000602")),
                reconciliationRule: .exactTransactionSum,
                destination: InsightEvidenceDestination(
                    scope: .categoryGroup(analysisViewStateID("00000000-0000-0000-0000-000000000602")),
                    direction: .expense
                )
            )
        )
    )

    model.setAnalysisCategoriesSelection(selection)
    model.showTarget(id: targetID)

    #expect(model.analysisCategoriesSelection == selection)
    #expect(model.selectedTargetID == targetID)
    #expect(model.pendingAppSectionNavigation == .targets)
}

@Test
@MainActor
func analysisCategorySortStateSurvivesTransactionDrilldownAndReturn() {
    let model = WorkspaceShellModel(store: nil, service: nil)

    model.showAnalysis(page: .categories)
    model.setAnalysisCategoriesSort(.largestDelta)
    model.showAnalysisTransactions(filter:
        TransactionLedgerFilter(
            categoryID: analysisViewStateID("00000000-0000-0000-0000-000000000611"),
            direction: .expense,
            reviewStatuses: Set([.accepted, .pending]),
            visibility: .active
        )
    )
    model.showAnalysis(page: .categories)

    #expect(model.analysisCategoriesSort == .largestDelta)
    #expect(model.pendingAppSectionNavigation == .analysis)
}

@Test
@MainActor
func analysisMerchantSortStateSurvivesTransactionDrilldownAndReturn() {
    let model = WorkspaceShellModel(store: nil, service: nil)

    model.showAnalysis(page: .merchants)
    model.setAnalysisMerchantsSort(.alphabetical)
    model.showAnalysisTransactions(filter:
        TransactionLedgerFilter(
            normalizedMerchantName: "blue bottle",
            direction: .expense,
            reviewStatuses: Set([.accepted, .pending]),
            visibility: .active
        )
    )
    model.showAnalysis(page: .merchants)

    #expect(model.analysisMerchantsSort == .alphabetical)
    #expect(model.pendingAppSectionNavigation == .analysis)
}

@Test
@MainActor
func analysisMerchantsSelectionSurvivesTransactionDrilldown() {
    let model = WorkspaceShellModel(store: nil, service: nil)
    let selection = AnalysisMerchantsSelection.merchant(
        MerchantAnalysisRow(
            key: MerchantReportKey(normalizedName: "blue bottle"),
            title: "blue bottle",
            currentSpend: Decimal(48),
            comparisonSpend: Decimal(12),
            delta: Decimal(36),
            evidence: InsightEvidence(
                metricBasis: .includedVisibleExpenses,
                resolvedInterval: DateInterval(
                    start: analysisViewStateUTCDate(year: 2026, month: 4, day: 1),
                    end: analysisViewStateUTCDate(year: 2026, month: 4, day: 16)
                ),
                scope: .merchant("blue bottle"),
                reconciliationRule: .exactTransactionSum,
                destination: InsightEvidenceDestination(
                    scope: .merchant("blue bottle"),
                    direction: .expense
                )
            )
        )
    )

    model.setAnalysisMerchantsSelection(selection)
    model.showTransactions(
        filter: TransactionLedgerFilter(
            normalizedMerchantName: "blue bottle",
            direction: .expense,
            reviewStatuses: Set([.accepted, .pending]),
            visibility: .active
        )
    )

    #expect(model.analysisMerchantsSelection == selection)
    #expect(model.pendingAppSectionNavigation == .transactions)
}

@Test
@MainActor
func analysisFamilyStripRoutingRetainsPageLocalSelectionWhenSwitchingAwayAndBack() {
    let model = WorkspaceShellModel(store: nil, service: nil)
    let categoriesSelection = AnalysisCategoriesSelection.row(
        AnalysisSpendRow(
            title: "Food",
            scope: .category(analysisViewStateID("00000000-0000-0000-0000-000000000701")),
            currentSpend: Decimal(280),
            comparisonSpend: Decimal(160),
            delta: Decimal(120),
            evidence: InsightEvidence(
                metricBasis: .includedVisibleExpenses,
                resolvedInterval: DateInterval(
                    start: analysisViewStateUTCDate(year: 2026, month: 4, day: 1),
                    end: analysisViewStateUTCDate(year: 2026, month: 4, day: 16)
                ),
                scope: .category(analysisViewStateID("00000000-0000-0000-0000-000000000701")),
                reconciliationRule: .exactTransactionSum,
                destination: InsightEvidenceDestination(
                    scope: .category(analysisViewStateID("00000000-0000-0000-0000-000000000701")),
                    direction: .expense
                )
            )
        )
    )
    let merchantsSelection = AnalysisMerchantsSelection.merchant(
        MerchantAnalysisRow(
            key: MerchantReportKey(normalizedName: "blue bottle"),
            title: "blue bottle",
            currentSpend: Decimal(48),
            comparisonSpend: Decimal(12),
            delta: Decimal(36),
            evidence: InsightEvidence(
                metricBasis: .includedVisibleExpenses,
                resolvedInterval: DateInterval(
                    start: analysisViewStateUTCDate(year: 2026, month: 4, day: 1),
                    end: analysisViewStateUTCDate(year: 2026, month: 4, day: 16)
                ),
                scope: .merchant("blue bottle"),
                reconciliationRule: .exactTransactionSum,
                destination: InsightEvidenceDestination(
                    scope: .merchant("blue bottle"),
                    direction: .expense
                )
            )
        )
    )

    model.selectAnalysisPage(.categories)
    model.setAnalysisCategoriesSelection(categoriesSelection)
    model.selectAnalysisPage(.merchants)
    model.setAnalysisMerchantsSelection(merchantsSelection)
    model.selectAnalysisPage(.categories)

    #expect(model.analysisToolbarState.selectedPage == .categories)
    #expect(model.analysisCategoriesSelection == categoriesSelection)
    #expect(model.analysisMerchantsSelection == merchantsSelection)
}

@Test
func analysisFamilyStripUsesOnlyAvailableSnapshotFamilies() {
    let snapshot = AnalysisSnapshot(
        categories: AnalysisCategoriesSnapshot(
            context: AnalysisContext(),
            report: CategoryAnalysisReport(context: AnalysisContext(), rows: []),
            targetProgress: []
        ),
        merchants: AnalysisMerchantsSnapshot(
            context: AnalysisContext(),
            report: MerchantAnalysisReport(
                context: AnalysisContext(),
                merchants: [],
                recurring: []
            )
        )
    )

    #expect(AnalysisView.familyStripPages(in: snapshot) == [.categories, .merchants])
}

@Test
@MainActor
func analysisInspectorPlaceholderRemainsAvailableOnWideScreensWhenSelectionClears() {
    let model = WorkspaceShellModel(store: nil, service: nil)
    let selection = AnalysisMerchantsSelection.merchant(
        MerchantAnalysisRow(
            key: MerchantReportKey(normalizedName: "blue bottle"),
            title: "blue bottle",
            currentSpend: Decimal(48),
            comparisonSpend: Decimal(12),
            delta: Decimal(36),
            evidence: InsightEvidence(
                metricBasis: .includedVisibleExpenses,
                resolvedInterval: DateInterval(
                    start: analysisViewStateUTCDate(year: 2026, month: 4, day: 1),
                    end: analysisViewStateUTCDate(year: 2026, month: 4, day: 16)
                ),
                scope: .merchant("blue bottle"),
                reconciliationRule: .exactTransactionSum,
                destination: InsightEvidenceDestination(
                    scope: .merchant("blue bottle"),
                    direction: .expense
                )
            )
        )
    )

    model.selectAnalysisPage(.merchants)
    model.setAnalysisMerchantsSelection(selection)
    model.setAnalysisMerchantsSelection(nil)

    #expect(
        AnalysisInspectorPresentation.resolve(
            isRequested: true,
            availableWidth: AnalysisView.persistentInspectorMinimumWidth + 1
        ) == .persistent
    )
    #expect(AnalysisInspectorView<AnalysisMerchantsSelection, EmptyView>.showsPlaceholder(for: model.analysisMerchantsSelection))
}

@Test
@MainActor
func analysisSelectionDoesNotRevealInspectorWhenCommittedWhileHidden() {
    let model = WorkspaceShellModel(store: nil, service: nil)
    let selection = AnalysisOverviewSelection.driver(
        AnalysisSpendRow(
            title: "Dining",
            scope: .category(analysisViewStateID("00000000-0000-0000-0000-000000000801")),
            currentSpend: Decimal(180),
            comparisonSpend: Decimal(40),
            delta: Decimal(140),
            evidence: InsightEvidence(
                metricBasis: .includedVisibleExpenses,
                resolvedInterval: DateInterval(
                    start: analysisViewStateUTCDate(year: 2026, month: 4, day: 1),
                    end: analysisViewStateUTCDate(year: 2026, month: 4, day: 16)
                ),
                scope: .category(analysisViewStateID("00000000-0000-0000-0000-000000000801")),
                reconciliationRule: .exactTransactionSum,
                destination: InsightEvidenceDestination(
                    scope: .category(analysisViewStateID("00000000-0000-0000-0000-000000000801")),
                    direction: .expense
                )
            )
        )
    )

    model.setAnalysisInspectorVisible(false)
    model.setAnalysisOverviewSelection(selection)

    #expect(model.analysisOverviewSelection == selection)
    #expect(model.analysisToolbarState.isInspectorVisible == false)
}

@Test
func analysisNarrowWidthsUseTransientInspectorPresentationWhenRequested() {
    #expect(
        AnalysisInspectorPresentation.resolve(
            isRequested: true,
            availableWidth: AnalysisView.persistentInspectorMinimumWidth
        ) == .transient
    )
}

@Test
func transientInspectorPresentationIsOwnedByToolbarVisibilityRatherThanSelection() {
    #expect(
        AnalysisInspectorPresentation.transient.shouldPresentTransientInspector(hasSelection: false)
    )
    #expect(
        AnalysisInspectorPresentation.transient.shouldPresentTransientInspector(hasSelection: true)
    )
}

@Test
func analysisWideWidthsUsePersistentInspectorPresentationWhenRequested() {
    #expect(
        AnalysisInspectorPresentation.resolve(
            isRequested: true,
            availableWidth: AnalysisView.persistentInspectorMinimumWidth + 1
        ) == .persistent
    )
}

@Test
func analysisWidthTransitionKeepsInspectorInVisibleModesWhenSelectionAlreadyExists() {
    let persistent = AnalysisInspectorPresentation.resolve(
        isRequested: true,
        availableWidth: AnalysisView.persistentInspectorMinimumWidth + 1
    )
    let transient = AnalysisInspectorPresentation.resolve(
        isRequested: true,
        availableWidth: AnalysisView.persistentInspectorMinimumWidth
    )

    #expect(persistent == .persistent)
    #expect(transient == .transient)
    #expect(transient.shouldPresentTransientInspector(hasSelection: true))
}

@Test
@MainActor
func analysisDrivenMerchantDrilldownRetainsSelection() {
    let model = WorkspaceShellModel(store: nil, service: nil)
    let selection = AnalysisMerchantsSelection.merchant(
        MerchantAnalysisRow(
            key: MerchantReportKey(normalizedName: "blue bottle"),
            title: "blue bottle",
            currentSpend: Decimal(48),
            comparisonSpend: Decimal(12),
            delta: Decimal(36),
            evidence: InsightEvidence(
                metricBasis: .includedVisibleExpenses,
                resolvedInterval: DateInterval(
                    start: analysisViewStateUTCDate(year: 2026, month: 4, day: 1),
                    end: analysisViewStateUTCDate(year: 2026, month: 4, day: 16)
                ),
                scope: .merchant("blue bottle"),
                reconciliationRule: .exactTransactionSum,
                destination: InsightEvidenceDestination(
                    scope: .merchant("blue bottle"),
                    direction: .expense
                )
            )
        )
    )

    model.setAnalysisMerchantsSelection(selection)
    model.showAnalysisTransactions(filter:
        TransactionLedgerFilter(
            normalizedMerchantName: "blue bottle",
            direction: .expense,
            reviewStatuses: Set([.accepted, .pending]),
            visibility: .active
        )
    )

    #expect(model.analysisMerchantsSelection == selection)
    #expect(model.pendingAppSectionNavigation == .transactions)
}

@Test
@MainActor
func analysisDrivenRecurringOverviewDrilldownRetainsSelection() {
    let model = WorkspaceShellModel(store: nil, service: nil)
    let selection = AnalysisOverviewSelection.recurring(
        MerchantRecurringReportRow(
            detail: RecurringChargeInsightDetail(
                accountID: analysisViewStateID("00000000-0000-0000-0000-000000000841"),
                normalizedMerchantName: "netflix",
                cadence: .monthly,
                observationCount: 3,
                amountRange: RecurringChargeAmountRange(minimum: Decimal(15.49), maximum: Decimal(15.49)),
                supportingTransactionIDs: [
                    analysisViewStateID("00000000-0000-0000-0000-000000000851")
                ],
                firstObservedDate: analysisViewStateUTCDate(year: 2026, month: 2, day: 9),
                lastObservedDate: analysisViewStateUTCDate(year: 2026, month: 4, day: 9),
                nextExpectedDateWindow: nil
            ),
            evidence: InsightEvidence(
                metricBasis: .includedVisibleExpenses,
                resolvedInterval: DateInterval(
                    start: analysisViewStateUTCDate(year: 2026, month: 2, day: 9),
                    end: analysisViewStateUTCDate(year: 2026, month: 4, day: 10)
                ),
                scope: .merchant("netflix"),
                reconciliationRule: .recurringObservationSet,
                destination: InsightEvidenceDestination(
                    scope: .merchant("netflix"),
                    direction: .expense
                )
            )
        )
    )

    model.setAnalysisOverviewSelection(selection)
    model.showAnalysisTransactions(filter:
        TransactionLedgerFilter(
            normalizedMerchantName: "netflix",
            direction: .expense,
            reviewStatuses: Set([.accepted, .pending]),
            visibility: .active
        )
    )

    #expect(model.analysisOverviewSelection == selection)
    #expect(model.pendingAppSectionNavigation == .transactions)
}

@Test
@MainActor
func analysisSectionRoutingAfterPageChangesPreservesInspectorState() {
    let model = WorkspaceShellModel(store: nil, service: nil)

    model.showAnalysis(page: .categories)
    model.setAnalysisInspectorVisible(true)
    model.showAnalysisTransactions(filter:
        TransactionLedgerFilter(
            categoryID: analysisViewStateID("00000000-0000-0000-0000-000000000861"),
            direction: .expense,
            reviewStatuses: Set([.accepted, .pending]),
            visibility: .active
        )
    )
    model.showAnalysis(page: .merchants)

    #expect(model.pendingAppSectionNavigation == .analysis)
    #expect(model.analysisToolbarState.selectedPage == .merchants)
    #expect(model.analysisToolbarState.isInspectorVisible)
}

@Test
@MainActor
func showAnalysisLoadsAnalysisSnapshotLazilyUsingTheSharedReferenceDate() throws {
    let now = analysisViewStateUTCDate(year: 2026, month: 4, day: 15)
    let store = AnalysisLoadingWorkspaceStore(referenceDate: now)
    let service = WorkspaceService(store: store)
    let model = WorkspaceShellModel(
        store: nil,
        service: service,
        referenceDateProvider: { now }
    )

    #expect(store.fetchedAnalysisContexts.isEmpty)
    #expect(store.fetchManagedTargetsReferenceDates == [now])
    #expect(model.analysisSnapshot == .empty)

    model.showAnalysis(page: .categories)

    let context = try #require(store.fetchedAnalysisContexts.first)
    #expect(context.referenceDate == now)
    #expect(context.range == .monthToDate)
    #expect(context.scope == .workspace)
    #expect(context.comparison == .previousPeriod)
    #expect(model.analysisToolbarState.selectedPage == .categories)
    #expect(model.analysisSnapshot.categories?.report.rows.isEmpty == true)
}

@Test
@MainActor
func analysisContextChangesReloadTheVisibleAnalysisSnapshot() throws {
    let now = analysisViewStateUTCDate(year: 2026, month: 4, day: 15)
    let store = AnalysisLoadingWorkspaceStore(referenceDate: now)
    let service = WorkspaceService(store: store)
    let model = WorkspaceShellModel(
        store: nil,
        service: service,
        referenceDateProvider: { now }
    )

    model.showAnalysis(page: .categories)
    let initialFetchCount = store.fetchedAnalysisContexts.count

    model.setAnalysisRange(.yearToDate)
    let rangeReloadContexts = Array(store.fetchedAnalysisContexts.dropFirst(initialFetchCount))

    #expect(rangeReloadContexts.isEmpty == false)
    #expect(rangeReloadContexts.allSatisfy { $0.range == .yearToDate })
    #expect(model.analysisContext.range == .yearToDate)

    let postRangeFetchCount = store.fetchedAnalysisContexts.count

    model.setAnalysisComparison(.samePeriodLastYear)
    let comparisonReloadContexts = Array(store.fetchedAnalysisContexts.dropFirst(postRangeFetchCount))

    #expect(comparisonReloadContexts.isEmpty == false)
    #expect(comparisonReloadContexts.allSatisfy {
        $0.range == .yearToDate && $0.comparison == .samePeriodLastYear
    })
    #expect(model.analysisContext.comparison == .samePeriodLastYear)
}

@Test
@MainActor
func analysisContextChangesRepairPageLocalSelectionAgainstTheReloadedSnapshot() throws {
    let now = analysisViewStateUTCDate(year: 2026, month: 4, day: 15)
    let selectedScope = analysisViewStateID("00000000-0000-0000-0000-000000000911")
    let store = AnalysisLoadingWorkspaceStore(referenceDate: now)
    store.categoryReportProvider = { context in
        let selectedRow = analysisViewCategoriesRow(
            title: "Food",
            scope: .category(selectedScope),
            currentSpend: context.range == .yearToDate ? Decimal(320) : Decimal(180),
            comparisonSpend: Decimal(90)
        )
        let otherRow = analysisViewCategoriesRow(
            title: "Travel",
            scope: .category(analysisViewStateID("00000000-0000-0000-0000-000000000912")),
            currentSpend: context.range == .yearToDate ? Decimal(420) : Decimal(70),
            comparisonSpend: Decimal(40)
        )
        return CategoryAnalysisReport(
            context: context,
            rows: context.range == .yearToDate ? [otherRow, selectedRow] : [selectedRow, otherRow]
        )
    }
    let service = WorkspaceService(store: store)
    let model = WorkspaceShellModel(
        store: nil,
        service: service,
        referenceDateProvider: { now }
    )

    model.showAnalysis(page: .categories)
    model.setAnalysisCategoriesSort(.largestDelta)
    let initialSelection = try #require(model.analysisSnapshot.categories?.report.rows.first)
    model.setAnalysisCategoriesSelection(.row(initialSelection))

    model.setAnalysisRange(.yearToDate)

    let visibleRowsAfterReload = AnalysisScreenState.CategoriesState(
        sort: model.analysisCategoriesSort,
        selection: model.analysisCategoriesSelection
    )
    .sortedRows(in: model.analysisSnapshot.categories)
    let repairedSelection = try #require(model.analysisCategoriesSelection)
    let repairedRow: AnalysisSpendRow
    switch repairedSelection {
    case .row(let row):
        repairedRow = row
    }

    #expect(model.analysisCategoriesSort == .largestDelta)
    #expect(visibleRowsAfterReload.first?.scope != repairedRow.scope)
    #expect(repairedRow.scope == .category(selectedScope))
    #expect(repairedRow.currentSpend == Decimal(320))
}

@Test
@MainActor
func analysisOverviewContextChangesRepairCommittedSelectionAgainstTheReloadedSnapshot() throws {
    let now = analysisViewStateUTCDate(year: 2026, month: 4, day: 15)
    let selectedScope = analysisViewStateID("00000000-0000-0000-0000-000000000971")
    let store = AnalysisLoadingWorkspaceStore(referenceDate: now)
    store.overviewReportProvider = { context in
        let selectedRow = AnalysisSpendRow(
            title: "Dining",
            scope: .category(selectedScope),
            currentSpend: context.range == .yearToDate ? Decimal(320) : Decimal(180),
            comparisonSpend: Decimal(110),
            delta: context.range == .yearToDate ? Decimal(210) : Decimal(70),
            evidence: InsightEvidence(
                metricBasis: .includedVisibleExpenses,
                resolvedInterval: DateInterval(
                    start: analysisViewStateUTCDate(year: 2026, month: 4, day: 1),
                    end: analysisViewStateUTCDate(year: 2026, month: 4, day: 16)
                ),
                scope: .category(selectedScope),
                reconciliationRule: .exactTransactionSum,
                destination: InsightEvidenceDestination(
                    scope: .category(selectedScope),
                    direction: .expense
                )
            )
        )
        return OverviewReport(
            context: context,
            currentSpend: Decimal(420),
            comparisonSpend: Decimal(310),
            drivers: [
                selectedRow,
                AnalysisSpendRow(
                    title: "Travel",
                    scope: .category(analysisViewStateID("00000000-0000-0000-0000-000000000972")),
                    currentSpend: Decimal(90),
                    comparisonSpend: Decimal(60),
                    delta: Decimal(30),
                    evidence: InsightEvidence(
                        metricBasis: .includedVisibleExpenses,
                        resolvedInterval: DateInterval(
                            start: analysisViewStateUTCDate(year: 2026, month: 4, day: 1),
                            end: analysisViewStateUTCDate(year: 2026, month: 4, day: 16)
                        ),
                        scope: .category(analysisViewStateID("00000000-0000-0000-0000-000000000972")),
                        reconciliationRule: .exactTransactionSum,
                        destination: InsightEvidenceDestination(
                            scope: .category(analysisViewStateID("00000000-0000-0000-0000-000000000972")),
                            direction: .expense
                        )
                    )
                ),
            ],
            recurring: []
        )
    }
    let service = WorkspaceService(store: store)
    let model = WorkspaceShellModel(
        store: nil,
        service: service,
        referenceDateProvider: { now }
    )

    model.showAnalysis(page: .overview)
    let initialSelection = try #require(model.analysisSnapshot.overview?.report.drivers.first)
    model.setAnalysisOverviewSelection(.driver(initialSelection))

    model.setAnalysisRange(.yearToDate)

    let repairedSelection = try #require(model.analysisOverviewSelection)

    switch repairedSelection {
    case .driver(let row):
        #expect(row.scope == .category(selectedScope))
        #expect(row.currentSpend == Decimal(320))
    case .insight, .recurring:
        Issue.record("Expected a driver selection after repairing the overview selection.")
    }
}

@Test
func analysisOverviewSelectionRepairKeepsRecurringSelectionAcrossSnapshotContextChange() throws {
    let accountID = analysisViewStateID("00000000-0000-0000-0000-000000000981")
    var state = AnalysisScreenState()
    let initialSnapshot = analysisViewOverviewSnapshot(
        range: .monthToDate,
        recurring: [
            analysisViewRecurringOverviewRow(
                accountID: accountID,
                name: "netflix",
                amount: Decimal(15.49)
            )
        ]
    )

    let initialSelection = try #require(initialSnapshot.report.recurring.first)
    state.setOverviewSelection(.recurring(initialSelection))

    state.repairSelections(for: AnalysisSnapshot(
        overview: analysisViewOverviewSnapshot(
            range: .yearToDate,
            recurring: [
                analysisViewRecurringOverviewRow(
                    accountID: accountID,
                    name: "netflix",
                    amount: Decimal(18.99)
                )
            ]
        )
    ))

    let repairedSelection = try #require(state.overview.selection)

    switch repairedSelection {
    case .recurring(let row):
        #expect(row.detail.accountID == accountID)
        #expect(row.detail.amountRange.maximum == Decimal(18.99))
    case .insight, .driver:
        Issue.record("Expected a recurring selection after repairing the overview selection.")
    }
}

@Test
@MainActor
func analysisContextChangesDoNotChangeInspectorVisibility() {
    let now = analysisViewStateUTCDate(year: 2026, month: 4, day: 15)
    let store = AnalysisLoadingWorkspaceStore(referenceDate: now)
    let service = WorkspaceService(store: store)
    let model = WorkspaceShellModel(
        store: nil,
        service: service,
        referenceDateProvider: { now }
    )

    model.showAnalysis(page: .merchants)
    model.setAnalysisInspectorVisible(false)

    model.setAnalysisComparison(.samePeriodLastYear)

    #expect(model.analysisToolbarState.isInspectorVisible == false)
}

private func analysisViewStateUTCDate(year: Int, month: Int, day: Int) -> Date {
    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = day
    components.calendar = analysisViewStateUTCCalendar
    return components.date!
}

private let analysisViewStateUTCCalendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
    return calendar
}()

private func analysisViewStateID(_ value: String) -> UUID {
    UUID(uuidString: value)!
}

private final class AnalysisLoadingWorkspaceStore: WorkspaceStoring, StagedImportWriting, ImportDecisionReading, AnalysisReportReading, ReportingReading, TargetManaging, @unchecked Sendable {
    let referenceDate: Date
    var fetchedAnalysisContexts: [AnalysisContext] = []
    var fetchManagedTargetsReferenceDates: [Date] = []
    var overviewReportProvider: (AnalysisContext) -> OverviewReport = { context in
        OverviewReport(
            context: context,
            currentSpend: Decimal(120),
            comparisonSpend: Decimal(80),
            drivers: [],
            recurring: []
        )
    }
    var categoryReportProvider: (AnalysisContext) -> CategoryAnalysisReport = { context in
        CategoryAnalysisReport(context: context, rows: [])
    }
    var merchantReportProvider: (AnalysisContext) -> MerchantAnalysisReport = { context in
        MerchantAnalysisReport(context: context, merchants: [], recurring: [])
    }

    init(referenceDate: Date) {
        self.referenceDate = referenceDate
    }

    func fetchSummary() throws -> WorkspaceSummary { .empty }
    func fetchAccounts() throws -> [Account] { [] }
    func fetchManagementAccounts() throws -> [Account] { [] }
    func fetchImportEligibleAccounts() throws -> [Account] { [] }
    func fetchLedgerFilterAccounts() throws -> [Account] { [] }
    func fetchPermanentlyDeletableAccountIDs() throws -> Set<UUID> { [] }
    func fetchCategories() throws -> [BudgetCategory] { [] }
    func fetchCategoryGroups() throws -> [BudgetCategoryGroup] { [] }
    func createAccount(named: String, kind: AccountKind, institutionName: String?) throws -> Account {
        Account(name: named, kind: kind, institutionName: institutionName)
    }
    func updateAccount(id: UUID, named: String, kind: AccountKind, institutionName: String?) throws -> Account {
        Account(id: id, name: named, kind: kind, institutionName: institutionName)
    }
    func archiveAccount(id: UUID, archivedAt: Date) throws -> Account {
        Account(id: id, name: "Archived", kind: .checking, institutionName: nil, archivedAt: archivedAt)
    }
    func restoreAccount(id: UUID) throws -> Account {
        Account(id: id, name: "Restored", kind: .checking, institutionName: nil)
    }
    func deleteAccountPermanently(id: UUID) throws {}

    func createStagedImportSession(_ draft: StagedImportSessionDraft) throws -> StagedImportSession {
        StagedImportSession(
            id: 1,
            sourceFile: StagedSourceFile(
                id: 1,
                accountID: draft.accountID,
                originalFilename: draft.originalFilename,
                contentHash: draft.contentHash,
                importedAt: draft.importedAt,
                rowCount: draft.rows.count
            ),
            mapping: draft.mapping,
            validRowCount: draft.validRowCount,
            invalidRowCount: draft.invalidRowCount,
            status: draft.status,
            rows: []
        )
    }

    func fetchExistingSourceRowHashes(accountID: UUID, rowHashes: Set<String>) throws -> Set<String> { [] }
    func fetchExistingSourceRowHashCounts(accountID: UUID, rowHashes: Set<String>) throws -> [String : Int] { [:] }
    func fetchLikelyDuplicateTransactions(
        accountID: UUID,
        candidates: [NormalizedImportCandidate]
    ) throws -> [LikelyDuplicateCandidate] { [] }

    func fetchOverviewReport(context: AnalysisContext) throws -> OverviewReport {
        fetchedAnalysisContexts.append(context)
        return overviewReportProvider(context)
    }

    func fetchCategoryAnalysisReport(context: AnalysisContext) throws -> CategoryAnalysisReport {
        fetchedAnalysisContexts.append(context)
        return categoryReportProvider(context)
    }

    func fetchMerchantAnalysisReport(context: AnalysisContext) throws -> MerchantAnalysisReport {
        fetchedAnalysisContexts.append(context)
        return merchantReportProvider(context)
    }

    func fetchMonthlyReport(referenceDate: Date) throws -> MonthlyReport {
        MonthlyReport(
            monthStart: analysisViewStateUTCDate(year: 2026, month: 4, day: 1),
            currentMonthAcceptedSpend: 0,
            lastMonthAcceptedSpend: 0,
            expenseBasis: .includedVisibleExpenses,
            pendingReviewCount: 0,
            targets: [],
            hasActiveTargets: false,
            totalMonthlyTargetLimit: 0,
            expectedPaceSpend: 0,
            paceDelta: 0,
            paceSeries: [],
            drivers: [],
            biggestShift: nil
        )
    }

    func fetchManagedTargets(referenceDate: Date) throws -> [ManagedMonthlyTarget] {
        fetchManagedTargetsReferenceDates.append(referenceDate)
        return []
    }

    func createMonthlyTarget(_ draft: MonthlyTargetDraft, createdAt: Date) throws -> MonthlyTarget {
        MonthlyTarget(id: UUID(), scope: draft.scope, monthlyLimit: draft.monthlyLimit, createdAt: createdAt)
    }

    func updateMonthlyTarget(id: UUID, _ draft: MonthlyTargetDraft) throws -> MonthlyTarget {
        MonthlyTarget(id: id, scope: draft.scope, monthlyLimit: draft.monthlyLimit, createdAt: referenceDate)
    }

    func deleteMonthlyTarget(id: UUID) throws {}
}

private func analysisViewCategoriesRow(
    title: String,
    scope: InsightEvidenceScope,
    currentSpend: Decimal,
    comparisonSpend: Decimal
) -> AnalysisSpendRow {
    AnalysisSpendRow(
        title: title,
        scope: scope,
        currentSpend: currentSpend,
        comparisonSpend: comparisonSpend,
        delta: currentSpend - comparisonSpend,
        evidence: InsightEvidence(
            metricBasis: .includedVisibleExpenses,
            resolvedInterval: DateInterval(
                start: analysisViewStateUTCDate(year: 2026, month: 4, day: 1),
                end: analysisViewStateUTCDate(year: 2026, month: 4, day: 16)
            ),
            scope: scope,
            reconciliationRule: .exactTransactionSum,
            destination: InsightEvidenceDestination(
                scope: scope,
                direction: .expense
            )
        )
    )
}

private func analysisViewOverviewSnapshot(
    range: AnalysisRange,
    recurring: [MerchantRecurringReportRow]
) -> AnalysisOverviewSnapshot {
    let context = AnalysisContext(
        range: range,
        referenceDate: analysisViewStateUTCDate(year: 2026, month: 4, day: 15),
        scope: .workspace,
        comparison: .previousPeriod,
        metricBasis: .includedVisibleExpenses
    )
    return AnalysisOverviewSnapshot(
        context: context,
        report: OverviewReport(
            context: context,
            currentSpend: Decimal(420),
            comparisonSpend: Decimal(310),
            drivers: [],
            recurring: recurring
        ),
        monthlyReport: MonthlyReport(
            monthStart: analysisViewStateUTCDate(year: 2026, month: 4, day: 1),
            currentMonthAcceptedSpend: Decimal(420),
            lastMonthAcceptedSpend: Decimal(310),
            expenseBasis: .includedVisibleExpenses,
            pendingReviewCount: 0,
            targets: [],
            hasActiveTargets: false,
            totalMonthlyTargetLimit: 0,
            expectedPaceSpend: Decimal(390),
            paceDelta: Decimal(30),
            paceSeries: [],
            drivers: [],
            biggestShift: nil
        ),
        projectedInsights: []
    )
}

private func analysisViewRecurringOverviewRow(
    accountID: UUID,
    name: String,
    amount: Decimal
) -> MerchantRecurringReportRow {
    MerchantRecurringReportRow(
        detail: RecurringChargeInsightDetail(
            accountID: accountID,
            normalizedMerchantName: name,
            cadence: .monthly,
            observationCount: 4,
            amountRange: RecurringChargeAmountRange(minimum: amount, maximum: amount),
            supportingTransactionIDs: [
                analysisViewStateID("00000000-0000-0000-0000-000000000982")
            ],
            firstObservedDate: analysisViewStateUTCDate(year: 2026, month: 1, day: 9),
            lastObservedDate: analysisViewStateUTCDate(year: 2026, month: 4, day: 9),
            nextExpectedDateWindow: nil
        ),
        evidence: InsightEvidence(
            metricBasis: .includedVisibleExpenses,
            resolvedInterval: DateInterval(
                start: analysisViewStateUTCDate(year: 2026, month: 1, day: 9),
                end: analysisViewStateUTCDate(year: 2026, month: 4, day: 10)
            ),
            scope: .merchant(name),
            reconciliationRule: .recurringObservationSet,
            destination: InsightEvidenceDestination(
                scope: .merchant(name),
                direction: .expense
            )
        )
    )
}
