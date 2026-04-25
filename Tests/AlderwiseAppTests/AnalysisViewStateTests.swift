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
func analysisFamilyStripRoutingClearsThePreviousFamilySelection() {
    let model = WorkspaceShellModel(store: nil, service: nil)
    let selection = AnalysisCategoriesSelection.row(
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

    model.selectAnalysisPage(.categories)
    model.setAnalysisCategoriesSelection(selection)
    model.selectAnalysisPage(.merchants)

    #expect(model.analysisToolbarState.selectedPage == .merchants)
    #expect(model.analysisCategoriesSelection == nil)
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

    #expect(AnalysisView.showsInspector(isRequested: true, availableWidth: AnalysisView.inspectorVisibilityWidth) == true)
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
func analysisNarrowWidthsCollapseTheInspectorEvenWhenRequested() {
    #expect(AnalysisView.showsInspector(
        isRequested: true,
        availableWidth: AnalysisView.inspectorVisibilityWidth - 1
    ) == false)
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
        return OverviewReport(
            context: context,
            currentSpend: Decimal(120),
            comparisonSpend: Decimal(80),
            drivers: [],
            recurring: []
        )
    }

    func fetchCategoryAnalysisReport(context: AnalysisContext) throws -> CategoryAnalysisReport {
        fetchedAnalysisContexts.append(context)
        return CategoryAnalysisReport(context: context, rows: [])
    }

    func fetchMerchantAnalysisReport(context: AnalysisContext) throws -> MerchantAnalysisReport {
        fetchedAnalysisContexts.append(context)
        return MerchantAnalysisReport(context: context, merchants: [], recurring: [])
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
