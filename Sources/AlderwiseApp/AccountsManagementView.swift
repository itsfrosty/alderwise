import Domain
import SwiftUI

struct AccountsManagementView: View {
    let accounts: [Account]
    let permanentlyDeletableAccountIDs: Set<UUID>
    let onCreate: () -> Void
    let onSaveEdit: (UUID, String, AccountKind, String?) throws -> Void
    let onArchive: (UUID) throws -> Void
    let onRestore: (UUID) throws -> Void
    let onDeletePermanently: (UUID) throws -> Void

    @State private var editingAccount: Account?
    @State private var pendingArchiveAccount: Account?
    @State private var pendingDeleteAccount: Account?
    @State private var actionErrorMessage: String?

    private var activeAccounts: [Account] {
        accounts.filter { !$0.isArchived }
    }

    private var archivedAccounts: [Account] {
        accounts.filter(\.isArchived)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Accounts")
                    .font(.largeTitle.bold())

                if accounts.isEmpty {
                    emptyState
                } else {
                    if activeAccounts.isEmpty {
                        archivedOnlyState
                    }
                    if !activeAccounts.isEmpty {
                        accountSection(
                            title: "Active Accounts",
                            subtitle: "Available for new CSV imports.",
                            accounts: activeAccounts
                        )
                    }
                    if !archivedAccounts.isEmpty {
                        accountSection(
                            title: "Archived Accounts",
                            subtitle: "Hidden from new imports but still available in management and transaction filters.",
                            accounts: archivedAccounts
                        )
                    }
                }
            }
            .padding(24)
        }
        .navigationTitle("Accounts")
        .sheet(item: $editingAccount) { account in
            AccountEditSheet(account: account) { name, kind, institutionName in
                try onSaveEdit(account.id, name, kind, institutionName)
            }
        }
        .confirmationDialog(
            "Archive Account",
            isPresented: Binding(
                get: { pendingArchiveAccount != nil },
                set: { isPresented in
                    if !isPresented {
                        pendingArchiveAccount = nil
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            if let pendingArchiveAccount {
                Button("Archive", role: .destructive) {
                    do {
                        try onArchive(pendingArchiveAccount.id)
                        self.pendingArchiveAccount = nil
                    } catch {
                        actionErrorMessage = error.localizedDescription
                    }
                }
            }
            Button("Cancel", role: .cancel) {
                pendingArchiveAccount = nil
            }
        } message: {
            if let pendingArchiveAccount {
                Text("Archive \(pendingArchiveAccount.name)? It will be hidden from new imports, but past transactions stay available.")
            }
        }
        .confirmationDialog(
            "Delete Account Permanently",
            isPresented: Binding(
                get: { pendingDeleteAccount != nil },
                set: { isPresented in
                    if !isPresented {
                        pendingDeleteAccount = nil
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            if let pendingDeleteAccount {
                Button("Delete Permanently", role: .destructive) {
                    do {
                        try onDeletePermanently(pendingDeleteAccount.id)
                        self.pendingDeleteAccount = nil
                    } catch {
                        actionErrorMessage = error.localizedDescription
                    }
                }
            }
            Button("Cancel", role: .cancel) {
                pendingDeleteAccount = nil
            }
        } message: {
            if let pendingDeleteAccount {
                Text("Delete \(pendingDeleteAccount.name) permanently? This removes the unused account record and cannot be undone.")
            }
        }
        .alert(
            "Account Action Failed",
            isPresented: Binding(
                get: { actionErrorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        actionErrorMessage = nil
                    }
                }
            )
        ) {
            Button("OK") {
                actionErrorMessage = nil
            }
        } message: {
            Text(actionErrorMessage ?? "")
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Accounts", systemImage: AppSection.accounts.systemImage)
        } description: {
            Text("Create your first account so imported CSV files have a destination in this workspace.")
        } actions: {
            Button {
                onCreate()
            } label: {
                Label("Create Account", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var archivedOnlyState: some View {
        ContentUnavailableView(
            "All Accounts Are Archived",
            systemImage: "archivebox",
            description: Text("Restore an archived account or create a new one before importing another CSV.")
        )
    }

    private func accountSection(title: String, subtitle: String, accounts: [Account]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ForEach(accounts) { account in
                accountCard(account)
            }
        }
    }

    private func accountCard(_ account: Account) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(account.name)
                        .font(.headline)
                    Text(account.kind.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let institutionName = account.institutionName {
                        Text(institutionName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if account.isArchived {
                    Text("Archived")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.thinMaterial, in: Capsule())
                }
            }

            HStack {
                Button("Edit") {
                    editingAccount = account
                }

                if account.isArchived {
                    Button("Restore") {
                        do {
                            try onRestore(account.id)
                        } catch {
                            actionErrorMessage = error.localizedDescription
                        }
                    }
                } else {
                    Button("Archive") {
                        pendingArchiveAccount = account
                    }
                }

                if permanentlyDeletableAccountIDs.contains(account.id) {
                    Button("Delete Permanently", role: .destructive) {
                        pendingDeleteAccount = account
                    }
                }

                Spacer()
            }
            .buttonStyle(.bordered)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
