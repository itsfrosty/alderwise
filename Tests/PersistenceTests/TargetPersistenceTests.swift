import Domain
import Foundation
import GRDB
import Persistence
import Testing

@Test
func createMonthlyCategoryTargetAppearsInMonthlyReport() throws {
    let databaseURL = try targetTemporaryDatabaseURL()
    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()

    let account = try store.createAccount(named: "Checking", kind: .checking, institutionName: "Local Bank")
    let groceries = UUID(uuidString: "00000000-0000-0000-0000-000000000111")!
    try targetInsertCategory(databaseURL: databaseURL, id: groceries, name: "Groceries", kind: "expense")
    try targetInsertLedgerTransaction(
        databaseURL: databaseURL,
        accountID: account.id,
        categoryID: groceries,
        amount: Decimal(-42),
        reviewStatus: "accepted"
    )
    try targetInsertLedgerTransaction(
        databaseURL: databaseURL,
        accountID: account.id,
        categoryID: groceries,
        amount: Decimal(-100),
        reviewStatus: "pending"
    )

    let created = try store.createMonthlyTarget(
        MonthlyTargetDraft(scope: .category(groceries), monthlyLimit: Decimal(125)),
        createdAt: Date(timeIntervalSince1970: 1_775_171_260)
    )
    let report = try store.fetchMonthlyReport(referenceDate: Date(timeIntervalSince1970: 1_775_171_200))

    #expect(report.targets.map(\.id) == [created.id])
    #expect(report.targets.map(\.name) == ["Groceries"])
    #expect(report.targets.map(\.spent) == [Decimal(42)])
    #expect(report.targets.map(\.remaining) == [Decimal(83)])
    #expect(report.targets.map(\.monthlyLimit) == [Decimal(125)])
}

@Test
func createMonthlyCategoryGroupTargetAppearsInMonthlyReport() throws {
    let databaseURL = try targetTemporaryDatabaseURL()
    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()

    let account = try store.createAccount(named: "Checking", kind: .checking, institutionName: "Local Bank")
    let food = UUID(uuidString: "00000000-0000-0000-0000-000000000201")!
    let groceries = UUID(uuidString: "00000000-0000-0000-0000-000000000211")!
    let dining = UUID(uuidString: "00000000-0000-0000-0000-000000000212")!
    try targetInsertCategoryGroup(databaseURL: databaseURL, id: food, name: "Food")
    try targetInsertCategory(databaseURL: databaseURL, id: groceries, name: "Groceries", kind: "expense", categoryGroupID: food)
    try targetInsertCategory(databaseURL: databaseURL, id: dining, name: "Dining", kind: "expense", categoryGroupID: food)
    try targetInsertLedgerTransaction(
        databaseURL: databaseURL,
        accountID: account.id,
        categoryID: groceries,
        amount: Decimal(-40),
        reviewStatus: "accepted"
    )
    try targetInsertLedgerTransaction(
        databaseURL: databaseURL,
        accountID: account.id,
        categoryID: dining,
        amount: Decimal(-35),
        reviewStatus: "accepted"
    )

    let created = try store.createMonthlyTarget(
        MonthlyTargetDraft(scope: .categoryGroup(food), monthlyLimit: Decimal(150)),
        createdAt: Date(timeIntervalSince1970: 1_775_171_260)
    )
    let report = try store.fetchMonthlyReport(referenceDate: Date(timeIntervalSince1970: 1_775_171_200))

    #expect(report.targets.map(\.id) == [created.id])
    #expect(report.targets.map(\.name) == ["Food"])
    #expect(report.targets.map(\.spent) == [Decimal(75)])
    #expect(report.targets.map(\.remaining) == [Decimal(75)])
}

@Test
func createMonthlyTargetRejectsNonPositiveLimits() throws {
    let databaseURL = try targetTemporaryDatabaseURL()
    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()

    let groceries = UUID(uuidString: "00000000-0000-0000-0000-000000000111")!
    try targetInsertCategory(databaseURL: databaseURL, id: groceries, name: "Groceries", kind: "expense")

    #expect(throws: (any Error).self) {
        try store.createMonthlyTarget(
            MonthlyTargetDraft(scope: .category(groceries), monthlyLimit: Decimal(0)),
            createdAt: Date(timeIntervalSince1970: 1_775_171_260)
        )
    }
    #expect(throws: (any Error).self) {
        try store.createMonthlyTarget(
            MonthlyTargetDraft(scope: .category(groceries), monthlyLimit: Decimal(-25)),
            createdAt: Date(timeIntervalSince1970: 1_775_171_260)
        )
    }
    #expect(try targetCount(databaseURL: databaseURL) == 0)
}

private func targetTemporaryDatabaseURL() throws -> URL {
    try targetTemporaryDirectoryURL().appending(path: "workspace.sqlite")
}

private func targetTemporaryDirectoryURL() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func targetInsertCategoryGroup(databaseURL: URL, id: UUID, name: String) throws {
    let queue = try DatabaseQueue(path: databaseURL.path)
    try queue.write { db in
        try db.execute(
            sql: "INSERT INTO category_groups (id, name) VALUES (?, ?)",
            arguments: [id.uuidString, name]
        )
    }
}

private func targetInsertCategory(
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

private func targetInsertLedgerTransaction(
    databaseURL: URL,
    accountID: UUID,
    categoryID: UUID,
    amount: Decimal,
    reviewStatus: String
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
                "Target test",
                "target test",
                NSDecimalNumber(decimal: amount).doubleValue,
                Date(timeIntervalSince1970: 1_775_171_200),
                amount < 0 ? "expense" : "income",
                "user",
                1.0,
                reviewStatus,
                "none",
            ]
        )
    }
}

private func targetCount(databaseURL: URL) throws -> Int {
    let queue = try DatabaseQueue(path: databaseURL.path)
    return try queue.read { db in
        try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM targets") ?? 0
    }
}
