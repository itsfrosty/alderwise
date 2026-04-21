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
        amount: Decimal(-40),
        transactionDate: Date(timeIntervalSince1970: 1_775_171_200)
    )
    try homeDashboardInsertAcceptedExpense(
        databaseURL: databaseURL,
        accountID: account.id,
        categoryID: dining,
        amount: Decimal(-65),
        transactionDate: Date(timeIntervalSince1970: 1_775_344_000)
    )
    try homeDashboardInsertAcceptedExpense(
        databaseURL: databaseURL,
        accountID: account.id,
        categoryID: groceries,
        amount: Decimal(-20),
        transactionDate: Date(timeIntervalSince1970: 1_772_492_400)
    )

    _ = try store.createMonthlyTarget(
        MonthlyTargetDraft(scope: .categoryGroup(food), monthlyLimit: Decimal(200)),
        createdAt: Date(timeIntervalSince1970: 1_775_171_260)
    )
    let report = try store.fetchMonthlyReport(referenceDate: Date(timeIntervalSince1970: 1_775_430_400))

    #expect(report.currentMonthAcceptedSpend == Decimal(105))
    #expect(report.hasActiveTargets)
    #expect(report.totalMonthlyTargetLimit == Decimal(200))
    #expect(report.expectedPaceSpend > 0)
    #expect(report.paceDelta == report.currentMonthAcceptedSpend - report.expectedPaceSpend)
    #expect(report.paceSeries.isEmpty == false)
    #expect(report.drivers.count == 2)
    #expect(report.drivers.first?.title == "Restaurants & Bars")
    #expect(report.biggestShift?.title == "Restaurants & Bars")
}

private func homeDashboardTemporaryDatabaseURL() throws -> URL {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory.appending(path: "workspace.sqlite")
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
