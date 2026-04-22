import Domain
import Foundation

public enum TransactionDrilldownFilterBuilder {
    public static func currentMonthAcceptedExpenses(monthStart: Date, scope: TargetScope) -> TransactionLedgerFilter {
        currentMonthAcceptedExpenses(
            monthStart: monthStart,
            categoryID: categoryID(for: scope),
            categoryGroupID: categoryGroupID(for: scope)
        )
    }

    public static func currentMonthAcceptedExpenses(monthStart: Date, scope: SpendingDriverScope) -> TransactionLedgerFilter {
        currentMonthAcceptedExpenses(
            monthStart: monthStart,
            categoryID: categoryID(for: scope),
            categoryGroupID: categoryGroupID(for: scope)
        )
    }

    private static func currentMonthAcceptedExpenses(
        monthStart: Date,
        categoryID: UUID?,
        categoryGroupID: UUID?
    ) -> TransactionLedgerFilter {
        TransactionLedgerFilter(
            startDate: monthStart,
            endDate: endOfMonth(monthStart),
            categoryID: categoryID,
            categoryGroupID: categoryGroupID,
            direction: .expense,
            reviewStatus: .accepted
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
        }
    }

    private static func categoryGroupID(for scope: SpendingDriverScope) -> UUID? {
        switch scope {
        case .category:
            return nil
        case .categoryGroup(let id):
            return id
        }
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
