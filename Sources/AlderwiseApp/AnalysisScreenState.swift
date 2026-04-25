import Application
import Domain
import Foundation

struct AnalysisScreenState: Equatable, Sendable {
    struct OverviewState: Equatable, Sendable {
        var selection: AnalysisOverviewSelection?
    }

    struct CategoriesState: Equatable, Sendable {
        enum Sort: String, CaseIterable, Codable, Equatable, Sendable {
            case largestCurrentSpend
            case largestDelta
        }

        var sort: Sort = .largestCurrentSpend
        var selection: AnalysisCategoriesSelection?
    }

    struct MerchantsState: Equatable, Sendable {
        enum Sort: String, CaseIterable, Codable, Equatable, Sendable {
            case largestCurrentSpend
            case alphabetical
        }

        var sort: Sort = .largestCurrentSpend
        var selection: AnalysisMerchantsSelection?
    }

    var overview = OverviewState()
    var categories = CategoriesState()
    var merchants = MerchantsState()

    mutating func setOverviewSelection(_ selection: AnalysisOverviewSelection?) {
        overview.selection = selection
    }

    mutating func setCategoriesSelection(_ selection: AnalysisCategoriesSelection?) {
        categories.selection = selection
    }

    mutating func setMerchantsSelection(_ selection: AnalysisMerchantsSelection?) {
        merchants.selection = selection
    }

    mutating func clearSelections() {
        overview.selection = nil
        categories.selection = nil
        merchants.selection = nil
    }

    mutating func clearSelection(for page: AnalysisPage) {
        switch page {
        case .overview:
            overview.selection = nil
        case .categories:
            categories.selection = nil
        case .merchants:
            merchants.selection = nil
        }
    }

    mutating func prepareForPageChange(from currentPage: AnalysisPage, to nextPage: AnalysisPage) {
        _ = currentPage
        _ = nextPage
    }

    mutating func repairSelections(for snapshot: AnalysisSnapshot) {
        overview.selection = Self.repairedOverviewSelection(
            overview.selection,
            snapshot: snapshot.overview
        )
        categories.selection = Self.repairedCategoriesSelection(
            categories.selection,
            snapshot: snapshot.categories
        )
        merchants.selection = Self.repairedMerchantsSelection(
            merchants.selection,
            snapshot: snapshot.merchants
        )
    }

    private static func repairedOverviewSelection(
        _ selection: AnalysisOverviewSelection?,
        snapshot: AnalysisOverviewSnapshot?
    ) -> AnalysisOverviewSelection? {
        guard let selection, let snapshot else {
            return nil
        }

        let selectionIdentity = overviewIdentity(for: selection)

        for insight in snapshot.projectedInsights {
            let currentSelection = AnalysisOverviewSelection.insight(insight)
            if overviewIdentity(for: currentSelection) == selectionIdentity {
                return currentSelection
            }
        }

        for driver in snapshot.report.drivers {
            let currentSelection = AnalysisOverviewSelection.driver(driver)
            if overviewIdentity(for: currentSelection) == selectionIdentity {
                return currentSelection
            }
        }

        for recurring in snapshot.report.recurring {
            let currentSelection = AnalysisOverviewSelection.recurring(recurring)
            if overviewIdentity(for: currentSelection) == selectionIdentity {
                return currentSelection
            }
        }

        return nil
    }

    private static func repairedCategoriesSelection(
        _ selection: AnalysisCategoriesSelection?,
        snapshot: AnalysisCategoriesSnapshot?
    ) -> AnalysisCategoriesSelection? {
        guard let selection, let snapshot else {
            return nil
        }

        let selectionIdentity = categoriesIdentity(for: selection)

        for row in snapshot.report.rows {
            let currentSelection = AnalysisCategoriesSelection.row(row)
            if categoriesIdentity(for: currentSelection) == selectionIdentity {
                return currentSelection
            }
        }

        return nil
    }

    private static func repairedMerchantsSelection(
        _ selection: AnalysisMerchantsSelection?,
        snapshot: AnalysisMerchantsSnapshot?
    ) -> AnalysisMerchantsSelection? {
        guard let selection, let snapshot else {
            return nil
        }

        let selectionIdentity = merchantsIdentity(for: selection)

        for merchant in snapshot.report.merchants {
            let currentSelection = AnalysisMerchantsSelection.merchant(merchant)
            if merchantsIdentity(for: currentSelection) == selectionIdentity {
                return currentSelection
            }
        }

        for recurring in snapshot.report.recurring {
            let currentSelection = AnalysisMerchantsSelection.recurring(recurring)
            if merchantsIdentity(for: currentSelection) == selectionIdentity {
                return currentSelection
            }
        }

        return nil
    }

    private enum OverviewSelectionIdentity: Equatable {
        case insightRecurring(accountID: UUID, normalizedMerchantName: String)
        case insightDriver(scope: SpendingDriverScope)
        case driver(scope: InsightEvidenceScope)
        case recurring(accountID: UUID, normalizedMerchantName: String)
    }

    private enum CategoriesSelectionIdentity: Equatable {
        case row(scope: InsightEvidenceScope)
    }

    private enum MerchantsSelectionIdentity: Equatable {
        case merchant(key: MerchantReportKey)
        case recurring(accountID: UUID, normalizedMerchantName: String)
    }

    private static func overviewIdentity(
        for selection: AnalysisOverviewSelection
    ) -> OverviewSelectionIdentity {
        switch selection {
        case .insight(let insight):
            switch insight.kind {
            case .recurringCharge(let detail):
                return .insightRecurring(
                    accountID: detail.accountID,
                    normalizedMerchantName: detail.normalizedMerchantName
                )
            case .spendDriverChange(let detail):
                return .insightDriver(scope: detail.scope)
            }
        case .driver(let row):
            return .driver(scope: row.scope)
        case .recurring(let row):
            return .recurring(
                accountID: row.detail.accountID,
                normalizedMerchantName: row.detail.normalizedMerchantName
            )
        }
    }

    private static func categoriesIdentity(
        for selection: AnalysisCategoriesSelection
    ) -> CategoriesSelectionIdentity {
        switch selection {
        case .row(let row):
            return .row(scope: row.scope)
        }
    }

    private static func merchantsIdentity(
        for selection: AnalysisMerchantsSelection
    ) -> MerchantsSelectionIdentity {
        switch selection {
        case .merchant(let row):
            return .merchant(key: row.key)
        case .recurring(let row):
            return .recurring(
                accountID: row.detail.accountID,
                normalizedMerchantName: row.detail.normalizedMerchantName
            )
        }
    }
}
