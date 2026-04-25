public enum AppSection: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case home
    case analysis
    case transactions
    case review
    case rules
    case targets
    case accounts
    case settings

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .home:
            "Home"
        case .analysis:
            "Analysis"
        case .transactions:
            "Transactions"
        case .review:
            "Review"
        case .rules:
            "Rules"
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
        case .analysis:
            "chart.bar.xaxis"
        case .transactions:
            "list.bullet.rectangle"
        case .review:
            "checklist"
        case .rules:
            "slider.horizontal.3"
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
        case .analysis:
            "Analysis becomes available once Alderwise can explain your spending history"
        case .transactions:
            "Import a bank CSV to build your local ledger"
        case .review:
            "Everything important has been reviewed"
        case .rules:
            "Inspect the rules Alderwise uses on this Mac"
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
        case .analysis:
            "Analysis brings together trends, category drivers, and merchant commitments once your workspace has activity."
        case .transactions:
            "Transactions become your canonical ledger after import."
        case .review:
            "When an import needs your attention, it will appear here with a clear next step."
        case .rules:
            "Review learned rules alongside Alderwise's included deterministic rules and starter prefills."
        case .targets:
            "Targets compare visible spending this month against a simple monthly limit."
        case .accounts:
            "Accounts define where imported CSV files should land in your workspace."
        case .settings:
            "Manage local suggestions, backups, and workspace recovery."
        }
    }
}
