import Application
import Domain
import Foundation
import Testing

@testable import AlderwiseApp

@Test
func categoriesPageLayoutDefinesOrderedCardsAndSelectionStates() throws {
    let selectedCategoryID = analysisPageLayoutID("00000000-0000-0000-0000-000000002001")
    let selectedScope = InsightEvidenceScope.category(selectedCategoryID)
    let snapshot = AnalysisCategoriesSnapshot(
        context: AnalysisContext(),
        report: CategoryAnalysisReport(
            context: AnalysisContext(),
            rows: [
                analysisPageLayoutCategoryRow(title: "Food", scope: selectedScope),
                analysisPageLayoutCategoryRow(
                    title: "Transport",
                    scope: .category(analysisPageLayoutID("00000000-0000-0000-0000-000000002002"))
                ),
            ]
        ),
        targetProgress: [
            TargetProgress(
                id: analysisPageLayoutID("00000000-0000-0000-0000-000000002003"),
                name: "Food Target",
                scope: .category(selectedCategoryID),
                monthlyLimit: Decimal(400),
                spent: Decimal(180),
                remaining: Decimal(220),
                paceDelta: Decimal(-10)
            )
        ]
    )
    let selection = AnalysisCategoriesSelection.row(snapshot.report.rows[0])

    let layout = AnalysisCategoriesView.pageLayout(
        for: snapshot,
        sort: .largestCurrentSpend,
        selection: selection
    )

    #expect(layout.cards.map(\.kind) == [.contribution, .selectedCategoryTrend, .rankedGroups])
    #expect(try #require(layout.card(kind: .contribution)).visibility == .shownActionable)
    #expect(try #require(layout.card(kind: .selectedCategoryTrend)).visibility == .shownActionable)
    #expect(try #require(layout.card(kind: .selectedCategoryTrend)).footerAction.primaryTitle == "Show Transactions")
    #expect(try #require(layout.card(kind: .selectedCategoryTrend)).footerAction.secondaryTitles == ["Open Target"])
    #expect(try #require(layout.card(kind: .rankedGroups)).supportsSelection)
}

@Test
func categoriesPageLayoutDefinesNoSelectionAndNoTargetNextSteps() throws {
    let categoryID = analysisPageLayoutID("00000000-0000-0000-0000-000000002006")
    let scope = InsightEvidenceScope.category(categoryID)
    let row = analysisPageLayoutCategoryRow(title: "Food", scope: scope)
    let snapshot = AnalysisCategoriesSnapshot(
        context: AnalysisContext(),
        report: CategoryAnalysisReport(context: AnalysisContext(), rows: [row]),
        targetProgress: []
    )

    let noSelectionLayout = AnalysisCategoriesView.pageLayout(
        for: snapshot,
        sort: .largestCurrentSpend,
        selection: nil
    )
    let selectedNoTargetLayout = AnalysisCategoriesView.pageLayout(
        for: snapshot,
        sort: .largestCurrentSpend,
        selection: .row(row)
    )

    #expect(try #require(noSelectionLayout.card(kind: .contribution)).visibility == .shownEmpty)
    #expect(try #require(noSelectionLayout.card(kind: .selectedCategoryTrend)).visibility == .shownEmpty)
    #expect(try #require(noSelectionLayout.card(kind: .selectedCategoryTrend)).footerAction.primaryTitle == nil)
    #expect(try #require(selectedNoTargetLayout.card(kind: .selectedCategoryTrend)).visibility == .shownActionable)
    #expect(try #require(selectedNoTargetLayout.card(kind: .selectedCategoryTrend)).footerAction.primaryTitle == "Show Transactions")
    #expect(try #require(selectedNoTargetLayout.card(kind: .selectedCategoryTrend)).footerAction.secondaryTitles.isEmpty)
}

@Test
func merchantsPageLayoutDefinesRecurringFirstAndHidesReadinessWithoutCTA() throws {
    let snapshot = AnalysisMerchantsSnapshot(
        context: AnalysisContext(),
        report: MerchantAnalysisReport(
            context: AnalysisContext(),
            merchants: [
                analysisPageLayoutMerchantRow(name: "Blue Bottle", normalizedName: "blue bottle")
            ],
            recurring: [
                analysisPageLayoutRecurringRow(name: "netflix", normalizedName: "netflix")
            ]
        )
    )

    let selectedMerchant = AnalysisMerchantsSelection.merchant(snapshot.report.merchants[0])
    let layout = AnalysisMerchantsView.pageLayout(
        for: snapshot,
        sort: .largestCurrentSpend,
        selection: selectedMerchant
    )

    #expect(layout.cards.map(\.kind) == [.recurringCommitments, .topMerchants, .readiness])
    #expect(try #require(layout.card(kind: .recurringCommitments)).visibility == .shownActionable)
    #expect(try #require(layout.card(kind: .recurringCommitments)).footerAction.primaryTitle == "Show Transactions")
    #expect(try #require(layout.card(kind: .recurringCommitments)).footerAction.secondaryTitles == ["Open Rules"])
    #expect(try #require(layout.card(kind: .topMerchants)).visibility == .shownActionable)
    #expect(try #require(layout.card(kind: .topMerchants)).footerAction.primaryTitle == "Show Transactions")
    #expect(try #require(layout.card(kind: .topMerchants)).footerAction.secondaryTitles == ["Open Rules"])
    #expect(try #require(layout.card(kind: .readiness)).visibility == .hidden)
}

@Test
func merchantsPageLayoutRemovesFooterActionsWithoutSelection() throws {
    let snapshot = AnalysisMerchantsSnapshot(
        context: AnalysisContext(),
        report: MerchantAnalysisReport(
            context: AnalysisContext(),
            merchants: [
                analysisPageLayoutMerchantRow(name: "Blue Bottle", normalizedName: "blue bottle")
            ],
            recurring: [
                analysisPageLayoutRecurringRow(name: "netflix", normalizedName: "netflix")
            ]
        )
    )

    let layout = AnalysisMerchantsView.pageLayout(
        for: snapshot,
        sort: .largestCurrentSpend,
        selection: nil
    )

    #expect(try #require(layout.card(kind: .recurringCommitments)).footerAction.primaryTitle == nil)
    #expect(try #require(layout.card(kind: .topMerchants)).footerAction.primaryTitle == nil)
    #expect(try #require(layout.card(kind: .readiness)).visibility == .hidden)
}

private func analysisPageLayoutCategoryRow(
    title: String,
    scope: InsightEvidenceScope
) -> AnalysisSpendRow {
    AnalysisSpendRow(
        title: title,
        scope: scope,
        currentSpend: Decimal(180),
        comparisonSpend: Decimal(120),
        delta: Decimal(60),
        evidence: analysisPageLayoutEvidence(scope: scope)
    )
}

private func analysisPageLayoutMerchantRow(
    name: String,
    normalizedName: String
) -> MerchantAnalysisRow {
    MerchantAnalysisRow(
        key: MerchantReportKey(normalizedName: normalizedName),
        title: name,
        currentSpend: Decimal(84),
        comparisonSpend: Decimal(36),
        delta: Decimal(48),
        evidence: analysisPageLayoutEvidence(scope: .merchant(normalizedName))
    )
}

private func analysisPageLayoutRecurringRow(
    name: String,
    normalizedName: String
) -> MerchantRecurringReportRow {
    MerchantRecurringReportRow(
        detail: RecurringChargeInsightDetail(
            accountID: analysisPageLayoutID("00000000-0000-0000-0000-000000002004"),
            normalizedMerchantName: normalizedName,
            cadence: .monthly,
            observationCount: 3,
            amountRange: RecurringChargeAmountRange(minimum: Decimal(15), maximum: Decimal(15)),
            supportingTransactionIDs: [analysisPageLayoutID("00000000-0000-0000-0000-000000002005")],
            firstObservedDate: analysisPageLayoutUTCDate(year: 2026, month: 2, day: 1),
            lastObservedDate: analysisPageLayoutUTCDate(year: 2026, month: 4, day: 1),
            nextExpectedDateWindow: nil
        ),
        evidence: analysisPageLayoutEvidence(scope: .merchant(name))
    )
}

private func analysisPageLayoutEvidence(scope: InsightEvidenceScope) -> InsightEvidence {
    InsightEvidence(
        metricBasis: .includedVisibleExpenses,
        resolvedInterval: DateInterval(
            start: analysisPageLayoutUTCDate(year: 2026, month: 4, day: 1),
            end: analysisPageLayoutUTCDate(year: 2026, month: 4, day: 15)
        ),
        scope: scope,
        reconciliationRule: .exactTransactionSum,
        destination: InsightEvidenceDestination(
            scope: scope,
            direction: .expense
        )
    )
}

private func analysisPageLayoutUTCDate(year: Int, month: Int, day: Int) -> Date {
    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = day
    components.calendar = analysisPageLayoutUTCCalendar
    return components.date!
}

private let analysisPageLayoutUTCCalendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
    return calendar
}()

private func analysisPageLayoutID(_ value: String) -> UUID {
    UUID(uuidString: value)!
}
