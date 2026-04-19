import Application
import Domain
import Foundation
import Testing

private struct StubWorkspaceStore: WorkspaceStoring {
    var summary: WorkspaceSummary
    var accounts: [Account]

    func fetchSummary() throws -> WorkspaceSummary {
        summary
    }

    func fetchAccounts() throws -> [Account] {
        accounts
    }

    func createAccount(named: String, kind: AccountKind, institutionName: String?) throws -> Account {
        Account(
            name: named,
            kind: kind,
            institutionName: institutionName
        )
    }
}

@Test
func loadSnapshotReturnsSummaryAndAccountsFromStore() throws {
    let store = StubWorkspaceStore(
        summary: WorkspaceSummary(
            accountCount: 1,
            transactionCount: 24,
            reviewCount: 3,
            targetCount: 2
        ),
        accounts: [
            Account(name: "Checking", kind: .checking, institutionName: "Local Bank"),
        ]
    )

    let service = WorkspaceService(store: store)
    let snapshot = try service.loadSnapshot()

    #expect(snapshot.summary.accountCount == 1)
    #expect(snapshot.summary.reviewCount == 3)
    #expect(snapshot.accounts.map(\.name) == ["Checking"])
}
