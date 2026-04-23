import Domain
import Foundation

public enum TransactionDrilldownFilterBuilder {
    public static func currentMonthAcceptedExpenses(monthStart: Date, scope: TargetScope) -> TransactionLedgerFilter {
        currentMonthIncludedExpenses(
            monthStart: monthStart,
            categoryID: categoryID(for: scope),
            categoryGroupID: categoryGroupID(for: scope),
            uncategorizedOnly: false
        )
    }

    public static func currentMonthAcceptedExpenses(monthStart: Date, scope: SpendingDriverScope) -> TransactionLedgerFilter {
        currentMonthIncludedExpenses(
            monthStart: monthStart,
            categoryID: categoryID(for: scope),
            categoryGroupID: categoryGroupID(for: scope),
            uncategorizedOnly: uncategorizedOnly(for: scope)
        )
    }

    private static func currentMonthIncludedExpenses(
        monthStart: Date,
        categoryID: UUID?,
        categoryGroupID: UUID?,
        uncategorizedOnly: Bool
    ) -> TransactionLedgerFilter {
        TransactionLedgerFilter(
            startDate: monthStart,
            endDate: endOfMonth(monthStart),
            categoryID: categoryID,
            categoryGroupID: categoryGroupID,
            uncategorizedOnly: uncategorizedOnly,
            direction: .expense
        )
    }

    private static func categoryID(for scope: TargetScope) -> UUID? {
        switch scope {
        case .category(let id):
            return id
        case .categoryGroup:
            return nil
        }
    }

    private static func categoryGroupID(for scope: TargetScope) -> UUID? {
        switch scope {
        case .category:
            return nil
        case .categoryGroup(let id):
            return id
        }
    }

    private static func categoryID(for scope: SpendingDriverScope) -> UUID? {
        switch scope {
        case .category(let id):
            return id
        case .categoryGroup:
            return nil
        case .uncategorized:
            return nil
        }
    }

    private static func categoryGroupID(for scope: SpendingDriverScope) -> UUID? {
        switch scope {
        case .category:
            return nil
        case .categoryGroup(let id):
            return id
        case .uncategorized:
            return nil
        }
    }

    private static func uncategorizedOnly(for scope: SpendingDriverScope) -> Bool {
        if case .uncategorized = scope {
            return true
        }
        return false
    }

    private static func endOfMonth(_ monthStart: Date) -> Date? {
        Calendar.alderwiseUTC.date(byAdding: DateComponents(month: 1, second: -1), to: monthStart)
    }
}

private extension Calendar {
    static var alderwiseUTC: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar
    }
}
