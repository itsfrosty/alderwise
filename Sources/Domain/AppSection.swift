public enum AppSection: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case home
    case transactions
    case review
    case targets
    case accounts
    case settings

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .home:
            "Home"
        case .transactions:
            "Transactions"
        case .review:
            "Review"
        case .targets:
            "Targets"
        case .accounts:
            "Accounts"
        case .settings:
            "Settings"
        }
    }

    public var systemImage: String {
        switch self {
        case .home:
            "house"
        case .transactions:
            "list.bullet.rectangle"
        case .review:
            "checklist"
        case .targets:
            "target"
        case .accounts:
            "building.columns"
        case .settings:
            "gearshape"
        }
    }

    public var emptyStateTitle: String {
        switch self {
        case .home:
            "Build your local spending workspace"
        case .transactions:
            "Import a bank CSV to build your local ledger"
        case .review:
            "Everything important has been reviewed"
        case .targets:
            "Set a monthly target for the categories you watch most"
        case .accounts:
            "Create your first account to start importing CSVs"
        case .settings:
            "Workspace and Import Settings"
        }
    }

    public var emptyStateMessage: String {
        switch self {
        case .home:
            "Start with Import CSV or create an account to prepare your first import."
        case .transactions:
            "Transactions become your canonical ledger after import."
        case .review:
            "When an import needs your attention, it will appear here with a clear next step."
        case .targets:
            "Targets compare accepted spending this month against a simple monthly limit."
        case .accounts:
            "Accounts define where imported CSV files should land in your workspace."
        case .settings:
            "Manage local suggestions, backups, and workspace recovery."
        }
    }
}
