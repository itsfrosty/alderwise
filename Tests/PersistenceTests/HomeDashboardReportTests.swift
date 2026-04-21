import Domain
import Foundation
import GRDB
import Persistence
import Testing

@Test
func monthlyReportBuildsPaceSeriesDriversAndBiggestShiftForHomeDashboard() throws {
    let databaseURL = try homeDashboardTemporaryDatabaseURL()
    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()

    let account = try store.createAccount(named: "Checking", kind: .checking, institutionName: "Local Bank")
    let groceries = UUID(uuidString: "00000000-0000-0000-0000-000000000111")!
    let dining = UUID(uuidString: "00000000-0000-0000-0000-000000000112")!
    let food = UUID(uuidString: "00000000-0000-0000-0000-000000000201")!
    try homeDashboardInsertCategoryGroup(databaseURL: databaseURL, id: food, name: "Food")
    try homeDashboardInsertCategory(databaseURL: databaseURL, id: groceries, name: "Groceries", kind: "expense", categoryGroupID: food)
    try homeDashboardInsertCategory(databaseURL: databaseURL, id: dining, name: "Restaurants & Bars", kind: "expense", categoryGroupID: food)

    try homeDashboardInsertAcceptedExpense(
        databaseURL: databaseURL,
        accountID: account.id,
        categoryID: groceries,
        amount: Decimal(-60),
        transactionDate: homeDashboardUTCDate(year: 2026, month: 4, day: 5)
    )
    try homeDashboardInsertAcceptedExpense(
        databaseURL: databaseURL,
        accountID: account.id,
        categoryID: dining,
        amount: Decimal(-90),
        transactionDate: homeDashboardUTCDate(year: 2026, month: 4, day: 10)
    )
    try homeDashboardInsertAcceptedExpense(
        databaseURL: databaseURL,
        accountID: account.id,
        categoryID: groceries,
        amount: Decimal(-20),
        transactionDate: homeDashboardUTCDate(year: 2026, month: 3, day: 12)
    )

    _ = try store.createMonthlyTarget(
        MonthlyTargetDraft(scope: .categoryGroup(food), monthlyLimit: Decimal(300)),
        createdAt: homeDashboardUTCDate(year: 2026, month: 4, day: 1)
    )
    let report = try store.fetchMonthlyReport(referenceDate: homeDashboardUTCDate(year: 2026, month: 4, day: 15))

    #expect(report.currentMonthAcceptedSpend == Decimal(150))
    #expect(report.lastMonthAcceptedSpend == Decimal(20))
    #expect(report.hasActiveTargets)
    #expect(report.totalMonthlyTargetLimit == Decimal(300))
    #expect(report.expectedPaceSpend == Decimal(150))
    #expect(report.paceDelta == Decimal(0))
    #expect(report.paceSeries == [
        MonthlySpendPoint(day: 5, actualSpend: Decimal(60), expectedSpend: Decimal(50)),
        MonthlySpendPoint(day: 10, actualSpend: Decimal(150), expectedSpend: Decimal(100)),
    ])
    #expect(report.drivers.count == 2)
    #expect(report.drivers.contains {
        $0.title == "Groceries"
            && $0.scope == .category(groceries)
            && $0.currentPeriodSpend == Decimal(60)
            && $0.comparisonPeriodSpend == Decimal(20)
            && $0.delta == Decimal(40)
    })
    #expect(report.drivers.contains {
        $0.title == "Restaurants & Bars"
            && $0.scope == .category(dining)
            && $0.currentPeriodSpend == Decimal(90)
            && $0.comparisonPeriodSpend == Decimal(0)
            && $0.delta == Decimal(90)
    })
    #expect(report.biggestShift == MonthlySpendingDriver(
        title: "Restaurants & Bars",
        scope: .category(dining),
        currentPeriodSpend: Decimal(90),
        comparisonPeriodSpend: Decimal(0),
        delta: Decimal(90)
    ))
}

private func homeDashboardTemporaryDatabaseURL() throws -> URL {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory.appending(path: "workspace.sqlite")
}

private func homeDashboardUTCDate(year: Int, month: Int, day: Int) -> Date {
    var components = DateComponents()
    components.calendar = Calendar(identifier: .gregorian)
    components.timeZone = TimeZone(secondsFromGMT: 0)
    components.year = year
    components.month = month
    components.day = day
    return components.date!
}

private func homeDashboardInsertCategoryGroup(databaseURL: URL, id: UUID, name: String) throws {
    let queue = try DatabaseQueue(path: databaseURL.path)
    try queue.write { db in
        try db.execute(
            sql: "INSERT INTO category_groups (id, name) VALUES (?, ?)",
            arguments: [id.uuidString, name]
        )
    }
}

private func homeDashboardInsertCategory(
    databaseURL: URL,
    id: UUID,
    name: String,
    kind: String,
    categoryGroupID: UUID? = nil
) throws {
    let queue = try DatabaseQueue(path: databaseURL.path)
    try queue.write { db in
        try db.execute(
            sql: "INSERT INTO categories (id, name, kind, category_group_id) VALUES (?, ?, ?, ?)",
            arguments: [id.uuidString, name, kind, categoryGroupID?.uuidString]
        )
    }
}

private func homeDashboardInsertAcceptedExpense(
    databaseURL: URL,
    accountID: UUID,
    categoryID: UUID,
    amount: Decimal,
    transactionDate: Date
) throws {
    let queue = try DatabaseQueue(path: databaseURL.path)
    try queue.write { db in
        try db.execute(
            sql: """
            INSERT INTO transactions (
                id,
                account_id,
                category_id,
                raw_description,
                normalized_merchant_name,
                amount,
                transaction_date,
                direction,
                decision_source,
                confidence,
                review_status,
                duplicate_status
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            arguments: [
                UUID().uuidString,
                accountID.uuidString,
                categoryID.uuidString,
                "Home dashboard test",
                "home dashboard test",
                NSDecimalNumber(decimal: amount).doubleValue,
                transactionDate,
                "expense",
                "user",
                1.0,
                "accepted",
                "none",
            ]
        )
    }
}
