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

        func sortedRows(in snapshot: AnalysisCategoriesSnapshot?) -> [AnalysisSpendRow] {
            guard let snapshot else {
                return []
            }

            return snapshot.report.rows.sorted(by: sort.areInIncreasingDisplayOrder(lhs:rhs:))
        }

        func selectedTargetProgress(in snapshot: AnalysisCategoriesSnapshot?) -> TargetProgress? {
            guard let snapshot, let selection else {
                return nil
            }

            return snapshot.targetProgress(for: selection)
        }
    }

    struct MerchantsState: Equatable, Sendable {
        enum Sort: String, CaseIterable, Codable, Equatable, Sendable {
            case largestCurrentSpend
            case alphabetical
        }

        var sort: Sort = .largestCurrentSpend
        var selection: AnalysisMerchantsSelection?

        func sortedMerchants(in snapshot: AnalysisMerchantsSnapshot?) -> [MerchantAnalysisRow] {
            guard let snapshot else {
                return []
            }

            return snapshot.report.merchants.sorted(by: sort.areMerchantsInIncreasingDisplayOrder(lhs:rhs:))
        }

        func sortedRecurring(in snapshot: AnalysisMerchantsSnapshot?) -> [MerchantRecurringReportRow] {
            guard let snapshot else {
                return []
            }

            return snapshot.report.recurring.sorted(by: sort.areRecurringInIncreasingDisplayOrder(lhs:rhs:))
        }

        var selectedRuleHandoffMerchantName: String? {
            guard case .merchant(let row) = selection else {
                return nil
            }

            return row.key.normalizedName
        }
    }

    var overview = OverviewState()
    var categories = CategoriesState()
    var merchants = MerchantsState()

    // Family switches retain each page's last valid selection for the lifetime of the window.
    // Selection is only repaired or cleared when the underlying snapshot changes.

    mutating func setOverviewSelection(_ selection: AnalysisOverviewSelection?) {
        overview.selection = selection
    }

    mutating func setCategoriesSelection(_ selection: AnalysisCategoriesSelection?) {
        categories.selection = selection
    }

    mutating func setCategoriesSort(_ sort: CategoriesState.Sort) {
        categories.sort = sort
    }

    mutating func setMerchantsSelection(_ selection: AnalysisMerchantsSelection?) {
        merchants.selection = selection
    }

    mutating func setMerchantsSort(_ sort: MerchantsState.Sort) {
        merchants.sort = sort
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

private extension AnalysisScreenState.CategoriesState.Sort {
    func areInIncreasingDisplayOrder(lhs: AnalysisSpendRow, rhs: AnalysisSpendRow) -> Bool {
        switch self {
        case .largestCurrentSpend:
            if decimalCompare(lhs.currentSpend, rhs.currentSpend) != .orderedSame {
                return decimalCompare(lhs.currentSpend, rhs.currentSpend) == .orderedDescending
            }
            if decimalCompare(abs(lhs.delta), abs(rhs.delta)) != .orderedSame {
                return decimalCompare(abs(lhs.delta), abs(rhs.delta)) == .orderedDescending
            }
        case .largestDelta:
            if decimalCompare(abs(lhs.delta), abs(rhs.delta)) != .orderedSame {
                return decimalCompare(abs(lhs.delta), abs(rhs.delta)) == .orderedDescending
            }
            if decimalCompare(lhs.currentSpend, rhs.currentSpend) != .orderedSame {
                return decimalCompare(lhs.currentSpend, rhs.currentSpend) == .orderedDescending
            }
        }

        return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
    }

    private func decimalCompare(_ lhs: Decimal, _ rhs: Decimal) -> ComparisonResult {
        NSDecimalNumber(decimal: lhs).compare(NSDecimalNumber(decimal: rhs))
    }
}

private extension AnalysisScreenState.MerchantsState.Sort {
    func areMerchantsInIncreasingDisplayOrder(lhs: MerchantAnalysisRow, rhs: MerchantAnalysisRow) -> Bool {
        switch self {
        case .largestCurrentSpend:
            if decimalCompare(lhs.currentSpend, rhs.currentSpend) != .orderedSame {
                return decimalCompare(lhs.currentSpend, rhs.currentSpend) == .orderedDescending
            }
            if decimalCompare(abs(lhs.delta), abs(rhs.delta)) != .orderedSame {
                return decimalCompare(abs(lhs.delta), abs(rhs.delta)) == .orderedDescending
            }
        case .alphabetical:
            let titleOrder = lhs.title.localizedCaseInsensitiveCompare(rhs.title)
            if titleOrder != .orderedSame {
                return titleOrder == .orderedAscending
            }
            if decimalCompare(lhs.currentSpend, rhs.currentSpend) != .orderedSame {
                return decimalCompare(lhs.currentSpend, rhs.currentSpend) == .orderedDescending
            }
        }

        return lhs.key.normalizedName.localizedCaseInsensitiveCompare(rhs.key.normalizedName) == .orderedAscending
    }

    func areRecurringInIncreasingDisplayOrder(lhs: MerchantRecurringReportRow, rhs: MerchantRecurringReportRow) -> Bool {
        switch self {
        case .largestCurrentSpend:
            if decimalCompare(lhs.detail.amountRange.maximum, rhs.detail.amountRange.maximum) != .orderedSame {
                return decimalCompare(lhs.detail.amountRange.maximum, rhs.detail.amountRange.maximum) == .orderedDescending
            }
            if lhs.detail.observationCount != rhs.detail.observationCount {
                return lhs.detail.observationCount > rhs.detail.observationCount
            }
        case .alphabetical:
            let nameOrder = lhs.detail.normalizedMerchantName.localizedCaseInsensitiveCompare(
                rhs.detail.normalizedMerchantName
            )
            if nameOrder != .orderedSame {
                return nameOrder == .orderedAscending
            }
            if decimalCompare(lhs.detail.amountRange.maximum, rhs.detail.amountRange.maximum) != .orderedSame {
                return decimalCompare(lhs.detail.amountRange.maximum, rhs.detail.amountRange.maximum) == .orderedDescending
            }
        }

        return lhs.detail.accountID.uuidString < rhs.detail.accountID.uuidString
    }

    private func decimalCompare(_ lhs: Decimal, _ rhs: Decimal) -> ComparisonResult {
        NSDecimalNumber(decimal: lhs).compare(NSDecimalNumber(decimal: rhs))
    }
}
