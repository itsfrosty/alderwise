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
    let travel = UUID(uuidString: "00000000-0000-0000-0000-000000000113")!
    let food = UUID(uuidString: "00000000-0000-0000-0000-000000000201")!
    try homeDashboardInsertCategoryGroup(databaseURL: databaseURL, id: food, name: "Food")
    try homeDashboardInsertCategory(databaseURL: databaseURL, id: groceries, name: "Groceries", kind: "expense", categoryGroupID: food)
    try homeDashboardInsertCategory(databaseURL: databaseURL, id: dining, name: "Restaurants & Bars", kind: "expense", categoryGroupID: food)
    try homeDashboardInsertCategory(databaseURL: databaseURL, id: travel, name: "Travel", kind: "expense")

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
    try homeDashboardInsertAcceptedExpense(
        databaseURL: databaseURL,
        accountID: account.id,
        categoryID: travel,
        amount: Decimal(-30),
        transactionDate: homeDashboardUTCDate(year: 2026, month: 4, day: 8)
    )
    try homeDashboardInsertAcceptedExpense(
        databaseURL: databaseURL,
        accountID: account.id,
        categoryID: travel,
        amount: Decimal(-10),
        transactionDate: homeDashboardUTCDate(year: 2026, month: 3, day: 3)
    )

    _ = try store.createMonthlyTarget(
        MonthlyTargetDraft(scope: .categoryGroup(food), monthlyLimit: Decimal(300)),
        createdAt: homeDashboardUTCDate(year: 2026, month: 4, day: 1)
    )
    let report = try store.fetchMonthlyReport(referenceDate: homeDashboardUTCDate(year: 2026, month: 4, day: 15))

    #expect(report.currentMonthAcceptedSpend == Decimal(180))
    #expect(report.lastMonthAcceptedSpend == Decimal(30))
    #expect(report.hasActiveTargets)
    #expect(report.totalMonthlyTargetLimit == Decimal(300))
    #expect(report.expectedPaceSpend == Decimal(150))
    #expect(report.paceDelta == Decimal(30))
    #expect(report.paceSeries == [
        MonthlySpendPoint(day: 1, actualSpend: Decimal(0), expectedSpend: Decimal(10)),
        MonthlySpendPoint(day: 2, actualSpend: Decimal(0), expectedSpend: Decimal(20)),
        MonthlySpendPoint(day: 3, actualSpend: Decimal(0), expectedSpend: Decimal(30)),
        MonthlySpendPoint(day: 4, actualSpend: Decimal(0), expectedSpend: Decimal(40)),
        MonthlySpendPoint(day: 5, actualSpend: Decimal(60), expectedSpend: Decimal(50)),
        MonthlySpendPoint(day: 6, actualSpend: Decimal(60), expectedSpend: Decimal(60)),
        MonthlySpendPoint(day: 7, actualSpend: Decimal(60), expectedSpend: Decimal(70)),
        MonthlySpendPoint(day: 8, actualSpend: Decimal(90), expectedSpend: Decimal(80)),
        MonthlySpendPoint(day: 9, actualSpend: Decimal(90), expectedSpend: Decimal(90)),
        MonthlySpendPoint(day: 10, actualSpend: Decimal(180), expectedSpend: Decimal(100)),
        MonthlySpendPoint(day: 11, actualSpend: Decimal(180), expectedSpend: Decimal(110)),
        MonthlySpendPoint(day: 12, actualSpend: Decimal(180), expectedSpend: Decimal(120)),
        MonthlySpendPoint(day: 13, actualSpend: Decimal(180), expectedSpend: Decimal(130)),
        MonthlySpendPoint(day: 14, actualSpend: Decimal(180), expectedSpend: Decimal(140)),
        MonthlySpendPoint(day: 15, actualSpend: Decimal(180), expectedSpend: Decimal(150)),
    ])
    #expect(report.drivers.count == 2)
    #expect(report.drivers.contains {
        $0.title == "Food"
            && $0.scope == .categoryGroup(food)
            && $0.currentPeriodSpend == Decimal(150)
            && $0.comparisonPeriodSpend == Decimal(20)
            && $0.delta == Decimal(130)
    })
    #expect(report.drivers.contains {
        $0.title == "Travel"
            && $0.scope == .category(travel)
            && $0.currentPeriodSpend == Decimal(30)
            && $0.comparisonPeriodSpend == Decimal(10)
            && $0.delta == Decimal(20)
    })
    #expect(report.biggestShift == MonthlySpendingDriver(
        title: "Food",
        scope: .categoryGroup(food),
        currentPeriodSpend: Decimal(150),
        comparisonPeriodSpend: Decimal(20),
        delta: Decimal(130)
    ))
}

@Test
func monthlyReportExposesAcceptedSpendReviewCountTargetsPaceAndDriversForHome() throws {
    let databaseURL = try homeDashboardTemporaryDatabaseURL()
    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()

    let account = try store.createAccount(named: "Checking", kind: .checking, institutionName: "Local Bank")
    let groceries = UUID(uuidString: "00000000-0000-0000-0000-000000000611")!
    let food = UUID(uuidString: "00000000-0000-0000-0000-000000000701")!
    try homeDashboardInsertCategoryGroup(databaseURL: databaseURL, id: food, name: "Food")
    try homeDashboardInsertCategory(databaseURL: databaseURL, id: groceries, name: "Groceries", kind: "expense", categoryGroupID: food)
    try homeDashboardInsertAcceptedExpense(
        databaseURL: databaseURL,
        accountID: account.id,
        categoryID: groceries,
        amount: Decimal(-42),
        transactionDate: homeDashboardUTCDate(year: 2026, month: 4, day: 5)
    )
    try homeDashboardInsertPendingReviewItem(
        databaseURL: databaseURL,
        createdAt: homeDashboardUTCDate(year: 2026, month: 4, day: 6)
    )

    let target = try store.createMonthlyTarget(
        MonthlyTargetDraft(scope: .categoryGroup(food), monthlyLimit: Decimal(300)),
        createdAt: homeDashboardUTCDate(year: 2026, month: 4, day: 1)
    )
    let report = try store.fetchMonthlyReport(referenceDate: homeDashboardUTCDate(year: 2026, month: 4, day: 15))

    #expect(report.monthStart == homeDashboardUTCDate(year: 2026, month: 4, day: 1))
    #expect(report.currentMonthAcceptedSpend == Decimal(42))
    #expect(report.lastMonthAcceptedSpend == Decimal(0))
    #expect(report.pendingReviewCount == 1)
    #expect(report.targets == [
        TargetProgress(
            id: target.id,
            name: "Food",
            scope: .categoryGroup(food),
            monthlyLimit: Decimal(300),
            spent: Decimal(42),
            remaining: Decimal(258),
            paceDelta: Decimal(-108)
        )
    ])
    #expect(report.hasActiveTargets)
    #expect(report.totalMonthlyTargetLimit == Decimal(300))
    #expect(report.expectedPaceSpend == Decimal(150))
    #expect(report.paceDelta == Decimal(-108))
    #expect(report.paceSeries == [
        MonthlySpendPoint(day: 1, actualSpend: Decimal(0), expectedSpend: Decimal(10)),
        MonthlySpendPoint(day: 2, actualSpend: Decimal(0), expectedSpend: Decimal(20)),
        MonthlySpendPoint(day: 3, actualSpend: Decimal(0), expectedSpend: Decimal(30)),
        MonthlySpendPoint(day: 4, actualSpend: Decimal(0), expectedSpend: Decimal(40)),
        MonthlySpendPoint(day: 5, actualSpend: Decimal(42), expectedSpend: Decimal(50)),
        MonthlySpendPoint(day: 6, actualSpend: Decimal(42), expectedSpend: Decimal(60)),
        MonthlySpendPoint(day: 7, actualSpend: Decimal(42), expectedSpend: Decimal(70)),
        MonthlySpendPoint(day: 8, actualSpend: Decimal(42), expectedSpend: Decimal(80)),
        MonthlySpendPoint(day: 9, actualSpend: Decimal(42), expectedSpend: Decimal(90)),
        MonthlySpendPoint(day: 10, actualSpend: Decimal(42), expectedSpend: Decimal(100)),
        MonthlySpendPoint(day: 11, actualSpend: Decimal(42), expectedSpend: Decimal(110)),
        MonthlySpendPoint(day: 12, actualSpend: Decimal(42), expectedSpend: Decimal(120)),
        MonthlySpendPoint(day: 13, actualSpend: Decimal(42), expectedSpend: Decimal(130)),
        MonthlySpendPoint(day: 14, actualSpend: Decimal(42), expectedSpend: Decimal(140)),
        MonthlySpendPoint(day: 15, actualSpend: Decimal(42), expectedSpend: Decimal(150)),
    ])
    #expect(report.drivers == [
        MonthlySpendingDriver(
            title: "Food",
            scope: .categoryGroup(food),
            currentPeriodSpend: Decimal(42),
            comparisonPeriodSpend: Decimal(0),
            delta: Decimal(42)
        )
    ])
    #expect(report.biggestShift == MonthlySpendingDriver(
        title: "Food",
        scope: .categoryGroup(food),
        currentPeriodSpend: Decimal(42),
        comparisonPeriodSpend: Decimal(0),
        delta: Decimal(42)
    ))
}

@Test
func monthlyReportKeepsPendingReviewCountAvailableForVisibleSpendQualifier() throws {
    let databaseURL = try homeDashboardTemporaryDatabaseURL()
    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()

    try homeDashboardInsertPendingReviewItem(
        databaseURL: databaseURL,
        createdAt: homeDashboardUTCDate(year: 2026, month: 4, day: 6)
    )

    let report = try store.fetchMonthlyReport(referenceDate: homeDashboardUTCDate(year: 2026, month: 4, day: 15))

    #expect(report.pendingReviewCount == 1)
}

@Test
func monthlyReportCountsOnlyVisibleReviewBacklogItems() throws {
    let databaseURL = try homeDashboardTemporaryDatabaseURL()
    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()

    let account = try store.createAccount(named: "Checking", kind: .checking, institutionName: "Local Bank")
    let groceries = UUID(uuidString: "00000000-0000-0000-0000-000000000813")!
    try homeDashboardInsertCategory(databaseURL: databaseURL, id: groceries, name: "Groceries", kind: "expense")
    let hiddenPendingTransactionID = try homeDashboardInsertExpense(
        databaseURL: databaseURL,
        accountID: account.id,
        categoryID: groceries,
        amount: Decimal(-18),
        transactionDate: homeDashboardUTCDate(year: 2026, month: 4, day: 6),
        reviewStatus: "pending",
        isHidden: true
    )
    try homeDashboardInsertPendingReviewItem(
        databaseURL: databaseURL,
        transactionID: hiddenPendingTransactionID,
        createdAt: homeDashboardUTCDate(year: 2026, month: 4, day: 6)
    )
    try homeDashboardInsertPendingReviewItem(
        databaseURL: databaseURL,
        createdAt: homeDashboardUTCDate(year: 2026, month: 4, day: 7)
    )

    let report = try store.fetchMonthlyReport(referenceDate: homeDashboardUTCDate(year: 2026, month: 4, day: 15))

    #expect(report.pendingReviewCount == 1)
}

@Test
func monthlyReportLeavesDriversEmptyWhenNoPriorComparisonExists() throws {
    let databaseURL = try homeDashboardTemporaryDatabaseURL()
    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()

    let report = try store.fetchMonthlyReport(referenceDate: homeDashboardUTCDate(year: 2026, month: 4, day: 15))

    #expect(report.currentMonthAcceptedSpend == 0)
    #expect(report.lastMonthAcceptedSpend == 0)
    #expect(report.drivers.isEmpty)
    #expect(report.biggestShift == nil)
}

@Test
func monthlyReportBuildsDriversWhenCurrentMonthOnlyHasAcceptedSpend() throws {
    let databaseURL = try homeDashboardTemporaryDatabaseURL()
    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()

    let account = try store.createAccount(named: "Checking", kind: .checking, institutionName: "Local Bank")
    let groceries = UUID(uuidString: "00000000-0000-0000-0000-000000000411")!
    let food = UUID(uuidString: "00000000-0000-0000-0000-000000000501")!
    try homeDashboardInsertCategoryGroup(databaseURL: databaseURL, id: food, name: "Food")
    try homeDashboardInsertCategory(databaseURL: databaseURL, id: groceries, name: "Groceries", kind: "expense", categoryGroupID: food)
    try homeDashboardInsertAcceptedExpense(
        databaseURL: databaseURL,
        accountID: account.id,
        categoryID: groceries,
        amount: Decimal(-42),
        transactionDate: homeDashboardUTCDate(year: 2026, month: 4, day: 3)
    )

    let report = try store.fetchMonthlyReport(referenceDate: homeDashboardUTCDate(year: 2026, month: 4, day: 15))

    #expect(report.drivers == [
        MonthlySpendingDriver(
            title: "Food",
            scope: .categoryGroup(food),
            currentPeriodSpend: Decimal(42),
            comparisonPeriodSpend: Decimal(0),
            delta: Decimal(42)
        ),
    ])
    #expect(report.biggestShift == MonthlySpendingDriver(
        title: "Food",
        scope: .categoryGroup(food),
        currentPeriodSpend: Decimal(42),
        comparisonPeriodSpend: Decimal(0),
        delta: Decimal(42)
    ))
}

@Test
func monthlyReportCountsIncludedPendingExpensesAndExcludesHiddenExpenses() throws {
    let databaseURL = try homeDashboardTemporaryDatabaseURL()
    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()

    let account = try store.createAccount(named: "Checking", kind: .checking, institutionName: "Local Bank")
    let groceries = UUID(uuidString: "00000000-0000-0000-0000-000000000811")!
    let food = UUID(uuidString: "00000000-0000-0000-0000-000000000812")!
    try homeDashboardInsertCategoryGroup(databaseURL: databaseURL, id: food, name: "Food")
    try homeDashboardInsertCategory(databaseURL: databaseURL, id: groceries, name: "Groceries", kind: "expense", categoryGroupID: food)

    _ = try homeDashboardInsertExpense(
        databaseURL: databaseURL,
        accountID: account.id,
        categoryID: groceries,
        amount: Decimal(-40),
        transactionDate: homeDashboardUTCDate(year: 2026, month: 4, day: 4),
        reviewStatus: "pending"
    )
    _ = try homeDashboardInsertExpense(
        databaseURL: databaseURL,
        accountID: account.id,
        categoryID: groceries,
        amount: Decimal(-25),
        transactionDate: homeDashboardUTCDate(year: 2026, month: 4, day: 8),
        reviewStatus: "accepted",
        isHidden: true
    )

    let report = try store.fetchMonthlyReport(referenceDate: homeDashboardUTCDate(year: 2026, month: 4, day: 15))

    #expect(report.currentMonthAcceptedSpend == Decimal(40))
    #expect(report.targets.isEmpty)
    #expect(report.drivers == [
        MonthlySpendingDriver(
            title: "Food",
            scope: .categoryGroup(food),
            currentPeriodSpend: Decimal(40),
            comparisonPeriodSpend: Decimal(0),
            delta: Decimal(40)
        ),
    ])
}

@Test
func monthlyReportSurfacesIncludedUncategorizedExpensesAsDriverRows() throws {
    let databaseURL = try homeDashboardTemporaryDatabaseURL()
    let store = try WorkspaceStore.at(databaseURL: databaseURL)
    try store.bootstrap()

    let account = try store.createAccount(named: "Checking", kind: .checking, institutionName: "Local Bank")

    _ = try homeDashboardInsertExpense(
        databaseURL: databaseURL,
        accountID: account.id,
        categoryID: nil,
        amount: Decimal(-55),
        transactionDate: homeDashboardUTCDate(year: 2026, month: 4, day: 7),
        reviewStatus: "pending"
    )

    let report = try store.fetchMonthlyReport(referenceDate: homeDashboardUTCDate(year: 2026, month: 4, day: 15))

    #expect(report.drivers == [
        MonthlySpendingDriver(
            title: "Uncategorized",
            scope: .uncategorized,
            currentPeriodSpend: Decimal(55),
            comparisonPeriodSpend: Decimal(0),
            delta: Decimal(55)
        ),
    ])
    #expect(report.biggestShift == MonthlySpendingDriver(
        title: "Uncategorized",
        scope: .uncategorized,
        currentPeriodSpend: Decimal(55),
        comparisonPeriodSpend: Decimal(0),
        delta: Decimal(55)
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
    _ = try homeDashboardInsertExpense(
        databaseURL: databaseURL,
        accountID: accountID,
        categoryID: categoryID,
        amount: amount,
        transactionDate: transactionDate,
        reviewStatus: "accepted"
    )
}

private func homeDashboardInsertExpense(
    databaseURL: URL,
    accountID: UUID,
    categoryID: UUID?,
    amount: Decimal,
    transactionDate: Date,
    reviewStatus: String,
    isHidden: Bool = false
) throws -> UUID {
    let transactionID = UUID()
    let queue = try DatabaseQueue(path: databaseURL.path)
    try queue.write { db in
        try db.execute(
            sql: """
            INSERT INTO transactions (
                id,
                account_id,
                category_id,
                is_hidden,
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
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            arguments: [
                transactionID.uuidString,
                accountID.uuidString,
                categoryID?.uuidString,
                isHidden,
                "Home dashboard test",
                "home dashboard test",
                NSDecimalNumber(decimal: amount).doubleValue,
                transactionDate,
                "expense",
                "user",
                1.0,
                reviewStatus,
                "none",
            ]
        )
    }
    return transactionID
}

private func homeDashboardInsertPendingReviewItem(
    databaseURL: URL,
    transactionID: UUID? = nil,
    createdAt: Date
) throws {
    let queue = try DatabaseQueue(path: databaseURL.path)
    try queue.write { db in
        try db.execute(
            sql: """
            INSERT INTO review_items (
                id,
                transaction_id,
                type,
                status,
                created_at
            )
            VALUES (?, ?, ?, ?, ?)
            """,
            arguments: [
                UUID().uuidString,
                transactionID?.uuidString,
                ReviewItemType.lowConfidenceCategory.rawValue,
                ReviewItemStatus.pending.rawValue,
                createdAt,
            ]
        )
    }
}
