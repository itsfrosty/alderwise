import Domain
import Persistence
import Testing

@Test
func bootstrapCreatesSchemaAndReturnsEmptySummary() throws {
    let store = try WorkspaceStore.inMemory()

    try store.bootstrap()

    let summary = try store.fetchSummary()
    let accounts = try store.fetchAccounts()

    #expect(summary == .empty)
    #expect(accounts.isEmpty)
}

@Test
func createdAccountsAppearInSummaryAndFetchResults() throws {
    let store = try WorkspaceStore.inMemory()
    try store.bootstrap()

    _ = try store.createAccount(named: "Checking", kind: .checking, institutionName: "Local Bank")
    _ = try store.createAccount(named: "Card", kind: .creditCard, institutionName: "Visa")

    let summary = try store.fetchSummary()
    let accounts = try store.fetchAccounts()

    #expect(summary.accountCount == 2)
    #expect(accounts.map(\.name) == ["Card", "Checking"])
}
