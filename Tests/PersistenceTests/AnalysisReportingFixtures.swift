import Domain
import Foundation
import GRDB
import Persistence

func homeDashboardTemporaryDatabaseURL() throws -> URL {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory.appending(path: "workspace.sqlite")
}

func homeDashboardUTCDate(year: Int, month: Int, day: Int) -> Date {
    var components = DateComponents()
    components.calendar = Calendar(identifier: .gregorian)
    components.timeZone = TimeZone(secondsFromGMT: 0)
    components.year = year
    components.month = month
    components.day = day
    return components.date!
}

func homeDashboardInsertCategoryGroup(databaseURL: URL, id: UUID, name: String) throws {
    let queue = try DatabaseQueue(path: databaseURL.path)
    try queue.write { db in
        try db.execute(
            sql: "INSERT INTO category_groups (id, name) VALUES (?, ?)",
            arguments: [id.uuidString, name]
        )
    }
}

func homeDashboardInsertCategory(
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

func homeDashboardInsertAcceptedExpense(
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

func homeDashboardInsertPendingExpense(
    databaseURL: URL,
    accountID: UUID,
    categoryID: UUID,
    amount: Decimal,
    transactionDate: Date,
    isHidden: Bool = false
) throws {
    _ = try homeDashboardInsertExpense(
        databaseURL: databaseURL,
        accountID: accountID,
        categoryID: categoryID,
        amount: amount,
        transactionDate: transactionDate,
        reviewStatus: "pending",
        isHidden: isHidden
    )
}

func homeDashboardInsertRejectedExpense(
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
        reviewStatus: "rejected"
    )
}

func homeDashboardInsertHiddenAcceptedExpense(
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
        reviewStatus: "accepted",
        isHidden: true
    )
}

func homeDashboardInsertUncategorizedPendingExpense(
    databaseURL: URL,
    accountID: UUID,
    amount: Decimal,
    transactionDate: Date
) throws {
    _ = try homeDashboardInsertExpense(
        databaseURL: databaseURL,
        accountID: accountID,
        categoryID: nil,
        amount: amount,
        transactionDate: transactionDate,
        reviewStatus: "pending"
    )
}

func homeDashboardInsertIncome(
    databaseURL: URL,
    accountID: UUID,
    amount: Decimal,
    transactionDate: Date
) throws {
    _ = try homeDashboardInsertTransaction(
        databaseURL: databaseURL,
        accountID: accountID,
        categoryID: nil,
        amount: amount,
        transactionDate: transactionDate,
        direction: "income",
        reviewStatus: "accepted"
    )
}

func homeDashboardInsertTransfer(
    databaseURL: URL,
    accountID: UUID,
    amount: Decimal,
    transactionDate: Date
) throws {
    _ = try homeDashboardInsertTransaction(
        databaseURL: databaseURL,
        accountID: accountID,
        categoryID: nil,
        amount: amount,
        transactionDate: transactionDate,
        direction: "transfer",
        reviewStatus: "accepted"
    )
}

@discardableResult
func homeDashboardInsertExpense(
    databaseURL: URL,
    accountID: UUID,
    categoryID: UUID?,
    amount: Decimal,
    transactionDate: Date,
    reviewStatus: String,
    rawDescription: String = "Home dashboard test",
    normalizedMerchantName: String = "home dashboard test",
    isHidden: Bool = false
) throws -> UUID {
    try homeDashboardInsertTransaction(
        databaseURL: databaseURL,
        accountID: accountID,
        categoryID: categoryID,
        amount: amount,
        transactionDate: transactionDate,
        direction: "expense",
        reviewStatus: reviewStatus,
        rawDescription: rawDescription,
        normalizedMerchantName: normalizedMerchantName,
        isHidden: isHidden
    )
}

func homeDashboardInsertPendingReviewItem(
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

@discardableResult
private func homeDashboardInsertTransaction(
    databaseURL: URL,
    accountID: UUID,
    categoryID: UUID?,
    amount: Decimal,
    transactionDate: Date,
    direction: String,
    reviewStatus: String,
    rawDescription: String = "Home dashboard test",
    normalizedMerchantName: String = "home dashboard test",
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
                rawDescription,
                normalizedMerchantName,
                NSDecimalNumber(decimal: amount).doubleValue,
                transactionDate,
                direction,
                "user",
                1.0,
                reviewStatus,
                "none",
            ]
        )
    }
    return transactionID
}
