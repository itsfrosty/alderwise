import Domain
import Foundation
import GRDB
import Persistence
import Testing

@Test
func createMonthlyTargetStoresManagedTarget() throws {
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

    let created = try store.createMonthlyTarget(
        MonthlyTargetDraft(scope: .category(groceries), monthlyLimit: Decimal(125)),
        createdAt: Date(timeIntervalSince1970: 1_775_171_260)
    )
    let managedTargets = try store.fetchManagedTargets(referenceDate: Date(timeIntervalSince1970: 1_775_171_200))
    let expectedPaceDelta = Decimal(42) - (Decimal(125) * Decimal(2) / Decimal(30))

    #expect(managedTargets.count == 1)
    #expect(managedTargets.map(\.id) == [created.id])
    #expect(managedTargets.map(\.name) == ["Groceries"])
    #expect(managedTargets.map(\.scope) == [.category(groceries)])
    #expect(managedTargets.map(\.monthlyLimit) == [Decimal(125)])
    #expect(managedTargets.map(\.spent) == [Decimal(42)])
    #expect(managedTargets.map(\.remaining) == [Decimal(83)])
    #expect(managedTargets.map(\.paceDelta) == [expectedPaceDelta])
    #expect(managedTargets.map(\.createdAt) == [Date(timeIntervalSince1970: 1_775_171_260)])
}

@Test
func updateMonthlyTargetUpdatesAmount() throws {
    let databaseURL = try targetTemporaryDatabaseURL()
    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()

    let groceries = UUID(uuidString: "00000000-0000-0000-0000-000000000121")!
    try targetInsertCategory(databaseURL: databaseURL, id: groceries, name: "Groceries", kind: "expense")
    let created = try store.createMonthlyTarget(
        MonthlyTargetDraft(scope: .category(groceries), monthlyLimit: Decimal(125)),
        createdAt: Date(timeIntervalSince1970: 1_775_171_260)
    )

    let updated = try store.updateMonthlyTarget(
        id: created.id,
        MonthlyTargetDraft(scope: .category(groceries), monthlyLimit: Decimal(200))
    )
    let managedTargets = try store.fetchManagedTargets(referenceDate: Date(timeIntervalSince1970: 1_775_171_200))

    #expect(updated == MonthlyTarget(
        id: created.id,
        scope: .category(groceries),
        monthlyLimit: Decimal(200),
        createdAt: created.createdAt
    ))
    #expect(managedTargets.map(\.monthlyLimit) == [Decimal(200)])
}

@Test
func updateMonthlyTargetAllowsScopeChangesWhenNewScopeDoesNotConflict() throws {
    let databaseURL = try targetTemporaryDatabaseURL()
    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()

    let food = UUID(uuidString: "00000000-0000-0000-0000-000000000201")!
    let dining = UUID(uuidString: "00000000-0000-0000-0000-000000000202")!
    let travel = UUID(uuidString: "00000000-0000-0000-0000-000000000203")!
    try targetInsertCategoryGroup(databaseURL: databaseURL, id: food, name: "Food")
    try targetInsertCategory(databaseURL: databaseURL, id: dining, name: "Dining", kind: "expense", categoryGroupID: food)
    try targetInsertCategory(databaseURL: databaseURL, id: travel, name: "Travel", kind: "expense")
    let created = try store.createMonthlyTarget(
        MonthlyTargetDraft(scope: .category(travel), monthlyLimit: Decimal(80)),
        createdAt: Date(timeIntervalSince1970: 1_775_171_260)
    )

    let updatedToGroup = try store.updateMonthlyTarget(
        id: created.id,
        MonthlyTargetDraft(scope: .categoryGroup(food), monthlyLimit: Decimal(150))
    )
    let updatedBackToCategory = try store.updateMonthlyTarget(
        id: created.id,
        MonthlyTargetDraft(scope: .category(dining), monthlyLimit: Decimal(90))
    )
    let managedTargets = try store.fetchManagedTargets(referenceDate: Date(timeIntervalSince1970: 1_775_171_200))

    #expect(updatedToGroup.scope == .categoryGroup(food))
    #expect(updatedBackToCategory.scope == .category(dining))
    #expect(managedTargets.map(\.scope) == [.category(dining)])
    #expect(managedTargets.map(\.monthlyLimit) == [Decimal(90)])
}

@Test
func createMonthlyTargetRejectsExactScopeDuplicates() throws {
    let databaseURL = try targetTemporaryDatabaseURL()
    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()

    let groceries = UUID(uuidString: "00000000-0000-0000-0000-000000000301")!
    try targetInsertCategory(databaseURL: databaseURL, id: groceries, name: "Groceries", kind: "expense")
    _ = try store.createMonthlyTarget(
        MonthlyTargetDraft(scope: .category(groceries), monthlyLimit: Decimal(125)),
        createdAt: Date(timeIntervalSince1970: 1_775_171_260)
    )

    #expect(throws: MonthlyTargetManagementError.conflict(.duplicateScope(.category(groceries)))) {
        try store.createMonthlyTarget(
            MonthlyTargetDraft(scope: .category(groceries), monthlyLimit: Decimal(200)),
            createdAt: Date(timeIntervalSince1970: 1_775_171_300)
        )
    }
}

@Test
func updateMonthlyTargetRejectsExactScopeDuplicates() throws {
    let databaseURL = try targetTemporaryDatabaseURL()
    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()

    let groceries = UUID(uuidString: "00000000-0000-0000-0000-000000000401")!
    let dining = UUID(uuidString: "00000000-0000-0000-0000-000000000402")!
    try targetInsertCategory(databaseURL: databaseURL, id: groceries, name: "Groceries", kind: "expense")
    try targetInsertCategory(databaseURL: databaseURL, id: dining, name: "Dining", kind: "expense")
    _ = try store.createMonthlyTarget(
        MonthlyTargetDraft(scope: .category(groceries), monthlyLimit: Decimal(125)),
        createdAt: Date(timeIntervalSince1970: 1_775_171_260)
    )
    let diningTarget = try store.createMonthlyTarget(
        MonthlyTargetDraft(scope: .category(dining), monthlyLimit: Decimal(80)),
        createdAt: Date(timeIntervalSince1970: 1_775_171_261)
    )

    #expect(throws: MonthlyTargetManagementError.conflict(.duplicateScope(.category(groceries)))) {
        try store.updateMonthlyTarget(
            id: diningTarget.id,
            MonthlyTargetDraft(scope: .category(groceries), monthlyLimit: Decimal(90))
        )
    }
}

@Test
func createMonthlyTargetRejectsCategoryGroupOverlap() throws {
    let databaseURL = try targetTemporaryDatabaseURL()
    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()

    let food = UUID(uuidString: "00000000-0000-0000-0000-000000000501")!
    let groceries = UUID(uuidString: "00000000-0000-0000-0000-000000000502")!
    try targetInsertCategoryGroup(databaseURL: databaseURL, id: food, name: "Food")
    try targetInsertCategory(databaseURL: databaseURL, id: groceries, name: "Groceries", kind: "expense", categoryGroupID: food)
    _ = try store.createMonthlyTarget(
        MonthlyTargetDraft(scope: .categoryGroup(food), monthlyLimit: Decimal(250)),
        createdAt: Date(timeIntervalSince1970: 1_775_171_260)
    )

    #expect(throws: MonthlyTargetManagementError.conflict(.categoryGroupOverlap(categoryID: groceries, categoryGroupID: food))) {
        try store.createMonthlyTarget(
            MonthlyTargetDraft(scope: .category(groceries), monthlyLimit: Decimal(90)),
            createdAt: Date(timeIntervalSince1970: 1_775_171_261)
        )
    }
}

@Test
func updateMonthlyTargetRejectsCategoryGroupOverlap() throws {
    let databaseURL = try targetTemporaryDatabaseURL()
    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()

    let food = UUID(uuidString: "00000000-0000-0000-0000-000000000601")!
    let groceries = UUID(uuidString: "00000000-0000-0000-0000-000000000602")!
    let travel = UUID(uuidString: "00000000-0000-0000-0000-000000000603")!
    try targetInsertCategoryGroup(databaseURL: databaseURL, id: food, name: "Food")
    try targetInsertCategory(databaseURL: databaseURL, id: groceries, name: "Groceries", kind: "expense", categoryGroupID: food)
    try targetInsertCategory(databaseURL: databaseURL, id: travel, name: "Travel", kind: "expense")
    _ = try store.createMonthlyTarget(
        MonthlyTargetDraft(scope: .category(groceries), monthlyLimit: Decimal(125)),
        createdAt: Date(timeIntervalSince1970: 1_775_171_260)
    )
    let travelTarget = try store.createMonthlyTarget(
        MonthlyTargetDraft(scope: .category(travel), monthlyLimit: Decimal(80)),
        createdAt: Date(timeIntervalSince1970: 1_775_171_261)
    )

    #expect(throws: MonthlyTargetManagementError.conflict(.categoryGroupOverlap(categoryID: groceries, categoryGroupID: food))) {
        try store.updateMonthlyTarget(
            id: travelTarget.id,
            MonthlyTargetDraft(scope: .categoryGroup(food), monthlyLimit: Decimal(180))
        )
    }
}

@Test
func deleteMonthlyTargetRemovesManagedTarget() throws {
    let databaseURL = try targetTemporaryDatabaseURL()
    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()

    let groceries = UUID(uuidString: "00000000-0000-0000-0000-000000000701")!
    try targetInsertCategory(databaseURL: databaseURL, id: groceries, name: "Groceries", kind: "expense")
    let created = try store.createMonthlyTarget(
        MonthlyTargetDraft(scope: .category(groceries), monthlyLimit: Decimal(125)),
        createdAt: Date(timeIntervalSince1970: 1_775_171_260)
    )

    try store.deleteMonthlyTarget(id: created.id)

    #expect(try store.fetchManagedTargets(referenceDate: Date(timeIntervalSince1970: 1_775_171_200)).isEmpty)
    #expect(try targetCount(databaseURL: databaseURL) == 0)
}

@Test
func managedTargetHistorySkipsThePartialMonthWhenTargetWasCreatedMidMonth() throws {
    let databaseURL = try targetTemporaryDatabaseURL()
    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()

    let account = try store.createAccount(named: "Checking", kind: .checking, institutionName: "Local Bank")
    let groceries = UUID(uuidString: "00000000-0000-0000-0000-000000000731")!
    try targetInsertCategory(databaseURL: databaseURL, id: groceries, name: "Groceries", kind: "expense")

    try targetInsertLedgerTransaction(
        databaseURL: databaseURL,
        accountID: account.id,
        categoryID: groceries,
        amount: Decimal(-110),
        reviewStatus: "accepted",
        transactionDate: targetUTCDate(year: 2026, month: 1, day: 12)
    )
    try targetInsertLedgerTransaction(
        databaseURL: databaseURL,
        accountID: account.id,
        categoryID: groceries,
        amount: Decimal(-125),
        reviewStatus: "accepted",
        transactionDate: targetUTCDate(year: 2026, month: 2, day: 12)
    )
    try targetInsertLedgerTransaction(
        databaseURL: databaseURL,
        accountID: account.id,
        categoryID: groceries,
        amount: Decimal(-140),
        reviewStatus: "accepted",
        transactionDate: targetUTCDate(year: 2026, month: 3, day: 12)
    )
    try targetInsertLedgerTransaction(
        databaseURL: databaseURL,
        accountID: account.id,
        categoryID: groceries,
        amount: Decimal(-60),
        reviewStatus: "accepted",
        transactionDate: targetUTCDate(year: 2026, month: 4, day: 10)
    )

    _ = try store.createMonthlyTarget(
        MonthlyTargetDraft(scope: .category(groceries), monthlyLimit: Decimal(100)),
        createdAt: targetUTCDate(year: 2026, month: 1, day: 20)
    )

    let managedTarget = try #require(
        try store.fetchManagedTargets(referenceDate: targetUTCDate(year: 2026, month: 4, day: 15)).first
    )

    #expect(managedTarget.history.months.map(\.monthStart) == [
        targetUTCDate(year: 2026, month: 2, day: 1),
        targetUTCDate(year: 2026, month: 3, day: 1),
    ])
    #expect(managedTarget.history.months.map(\.spent) == [Decimal(125), Decimal(140)])
    #expect(managedTarget.calibrationSuggestion == nil)
}

@Test
func createMonthlyTargetRejectsNonPositiveLimits() throws {
    let databaseURL = try targetTemporaryDatabaseURL()
    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()

    let groceries = UUID(uuidString: "00000000-0000-0000-0000-000000000111")!
    try targetInsertCategory(databaseURL: databaseURL, id: groceries, name: "Groceries", kind: "expense")

    #expect(throws: MonthlyTargetManagementError.invalidLimit(Decimal(0))) {
        try store.createMonthlyTarget(
            MonthlyTargetDraft(scope: .category(groceries), monthlyLimit: Decimal(0)),
            createdAt: Date(timeIntervalSince1970: 1_775_171_260)
        )
    }
    #expect(throws: MonthlyTargetManagementError.invalidLimit(Decimal(-25))) {
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

private func targetUTCDate(
    year: Int,
    month: Int,
    day: Int
) -> Date {
    var components = DateComponents()
    components.calendar = Calendar(identifier: .gregorian)
    components.timeZone = TimeZone(secondsFromGMT: 0)
    components.year = year
    components.month = month
    components.day = day
    return components.date!
}

private func targetInsertLedgerTransaction(
    databaseURL: URL,
    accountID: UUID,
    categoryID: UUID,
    amount: Decimal,
    reviewStatus: String,
    transactionDate: Date = Date(timeIntervalSince1970: 1_775_171_200)
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
                transactionDate,
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
