import Domain
import Foundation

struct TransactionLedgerHeaderState: Equatable, Sendable {
    struct Formatting: Equatable, Sendable {
        var locale: Locale
        var timeZone: TimeZone
        var calendar: Calendar
        var dateStyle: DateFormatter.Style
        var dateTemplate: String?

        init(
            locale: Locale,
            timeZone: TimeZone,
            calendar: Calendar,
            dateStyle: DateFormatter.Style = .medium,
            dateTemplate: String? = nil
        ) {
            self.locale = locale
            self.timeZone = timeZone
            self.calendar = calendar
            self.dateStyle = dateStyle
            self.dateTemplate = dateTemplate
        }

        static var current: Formatting {
            let calendar = Calendar.autoupdatingCurrent
            return Formatting(
                locale: .autoupdatingCurrent,
                timeZone: .autoupdatingCurrent,
                calendar: calendar
            )
        }

        func dateText(for date: Date) -> String {
            let formatter = DateFormatter()
            formatter.locale = locale
            formatter.timeZone = timeZone
            formatter.calendar = calendar
            formatter.timeStyle = .none
            if let dateTemplate {
                formatter.setLocalizedDateFormatFromTemplate(dateTemplate)
            } else {
                formatter.dateStyle = dateStyle
            }
            return formatter.string(from: date)
        }
    }

    struct ZeroResultsState: Equatable, Sendable {
        let title: String
        let message: String
        let showsResetFilters: Bool
        let showsClearSearch: Bool
    }

    enum Chip: Equatable, Hashable, Sendable {
        case search(String)
        case ruleMatch(TransactionLedgerRuleFilterIntent.Source, String)
        case account(UUID, String)
        case category(UUID, String)
        case categoryGroup(UUID, String)
        case direction(TransactionDirection)
        case review(TransactionReviewStatus)
        case importSession(Int64, String)
        case dateRange(start: Date?, end: Date?)

        func text(using formatting: Formatting = .current) -> String {
            switch self {
            case .search(let text):
                return text
            case .ruleMatch(_, let label):
                return label
            case .account(_, let name),
                    .category(_, let name),
                    .categoryGroup(_, let name),
                    .importSession(_, let name):
                return name
            case .direction(let direction):
                return direction.rawValue.capitalized
            case .review(let status):
                return status.rawValue.capitalized
            case .dateRange(let start, let end):
                switch (start, end) {
                case let (start?, end?):
                    return "\(formatting.dateText(for: start)) - \(formatting.dateText(for: end))"
                case let (start?, nil):
                    return "From \(formatting.dateText(for: start))"
                case let (nil, end?):
                    return "Through \(formatting.dateText(for: end))"
                case (nil, nil):
                    return "Any date"
                }
            }
        }
    }

    let filteredResultCountText: String
    let scopeSummaryText: String
    let zeroResultsState: ZeroResultsState?
    let activeChips: [Chip]

    init(
        rows: [TransactionLedgerRow],
        filter: TransactionLedgerFilter,
        accountName: String? = nil,
        categoryName: String? = nil,
        categoryGroupName: String? = nil,
        importSessionName: String? = nil,
        formatting: Formatting = .current
    ) {
        let activeChips = Self.activeChips(
            for: filter,
            accountName: accountName,
            categoryName: categoryName,
            categoryGroupName: categoryGroupName,
            importSessionName: importSessionName
        )

        self.filteredResultCountText = Self.filteredResultCountText(for: rows.count)
        self.scopeSummaryText = Self.scopeSummaryText(for: activeChips, formatting: formatting)
        self.zeroResultsState = Self.zeroResultsState(for: rows, filter: filter)
        self.activeChips = activeChips
    }

    static func removing(_ chip: Chip, from filter: TransactionLedgerFilter) -> TransactionLedgerFilter {
        var nextFilter = filter

        switch chip {
        case .search:
            nextFilter.searchText = ""
        case .ruleMatch:
            nextFilter.ruleFilterIntent = nil
        case .account:
            nextFilter.accountID = nil
        case .category:
            nextFilter.categoryID = nil
        case .categoryGroup:
            nextFilter.categoryGroupID = nil
        case .direction:
            nextFilter.direction = nil
        case .review:
            nextFilter.reviewStatus = nil
        case .importSession:
            nextFilter.importSessionID = nil
        case .dateRange:
            nextFilter.startDate = nil
            nextFilter.endDate = nil
        }

        return nextFilter
    }

    static func removing<S: Sequence>(_ chips: S, from filter: TransactionLedgerFilter) -> TransactionLedgerFilter where S.Element == Chip {
        chips.reduce(filter) { partialFilter, chip in
            removing(chip, from: partialFilter)
        }
    }

    private static func filteredResultCountText(for count: Int) -> String {
        count == 1 ? "1 transaction" : "\(count) transactions"
    }

    private static func scopeSummaryText(for chips: [Chip], formatting: Formatting) -> String {
        guard let chip = chips.only, chips.count == 1 else {
            return chips.isEmpty ? "All transactions" : "Filtered transactions"
        }

        switch chip {
        case .search(let text):
            return "Search: \"\(text)\""
        case .ruleMatch(_, let label):
            return "Matching rule: \(label)"
        case .account(_, let name):
            return "Account: \(name)"
        case .category(_, let name):
            return "Category: \(name)"
        case .categoryGroup(_, let name):
            return "Category group: \(name)"
        case .direction(let direction):
            return "Direction: \(direction.rawValue.capitalized)"
        case .review(let status):
            return "Review: \(status.rawValue.capitalized)"
        case .importSession(_, let name):
            return "Import: \(name)"
        case .dateRange:
            return "Date: \(chip.text(using: formatting))"
        }
    }

    private static func zeroResultsState(
        for rows: [TransactionLedgerRow],
        filter: TransactionLedgerFilter
    ) -> ZeroResultsState? {
        guard rows.isEmpty, filter.hasActiveCriteria else {
            return nil
        }

        let showsClearSearch = filter.hasSearchText
        let showsResetFilters = filter.hasNonSearchCriteria

        let message: String
        switch (showsResetFilters, showsClearSearch) {
        case (true, true):
            message = "Try removing a filter or clearing the current search to broaden the ledger."
        case (true, false):
            message = "Try removing one or more filters to broaden the ledger."
        case (false, true):
            message = "Try clearing the current search to broaden the ledger."
        case (false, false):
            message = "Try broadening the current filters to see more transactions."
        }

        return ZeroResultsState(
            title: "No transactions match these filters",
            message: message,
            showsResetFilters: showsResetFilters,
            showsClearSearch: showsClearSearch
        )
    }

    private static func activeChips(
        for filter: TransactionLedgerFilter,
        accountName: String?,
        categoryName: String?,
        categoryGroupName: String?,
        importSessionName: String?
    ) -> [Chip] {
        var chips: [Chip] = []

        if filter.hasSearchText {
            chips.append(.search(filter.trimmedSearchText))
        }
        if let ruleFilterIntent = filter.ruleFilterIntent {
            chips.append(.ruleMatch(ruleFilterIntent.source, ruleFilterIntent.merchantLabel))
        }
        if let accountID = filter.accountID {
            chips.append(.account(accountID, accountName ?? "Selected account"))
        }
        if let categoryID = filter.categoryID {
            chips.append(.category(categoryID, categoryName ?? "Selected category"))
        }
        if let categoryGroupID = filter.categoryGroupID {
            chips.append(.categoryGroup(categoryGroupID, categoryGroupName ?? "Selected group"))
        }
        if let direction = filter.direction {
            chips.append(.direction(direction))
        }
        if let reviewStatus = filter.reviewStatus {
            chips.append(.review(reviewStatus))
        }
        if let importSessionID = filter.importSessionID {
            chips.append(.importSession(importSessionID, importSessionName ?? "Import \(importSessionID)"))
        }
        if filter.startDate != nil || filter.endDate != nil {
            chips.append(.dateRange(start: filter.startDate, end: filter.endDate))
        }

        return chips
    }
}

private extension TransactionLedgerFilter {
    var trimmedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var hasSearchText: Bool {
        !trimmedSearchText.isEmpty
    }

    var hasNonSearchCriteria: Bool {
        startDate != nil ||
        endDate != nil ||
        ruleFilterIntent != nil ||
        accountID != nil ||
        categoryID != nil ||
        categoryGroupID != nil ||
        direction != nil ||
        reviewStatus != nil ||
        importSessionID != nil
    }

    var hasActiveCriteria: Bool {
        hasSearchText || hasNonSearchCriteria
    }
}

private extension Array {
    var only: Element? {
        count == 1 ? first : nil
    }
}
