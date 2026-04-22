import Foundation

public enum AccountKind: String, CaseIterable, Codable, Sendable {
    case checking
    case savings
    case creditCard
    case cash

    public var title: String {
        switch self {
        case .checking:
            "Checking"
        case .savings:
            "Savings"
        case .creditCard:
            "Credit Card"
        case .cash:
            "Cash"
        }
    }
}

public struct Account: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var name: String
    public var kind: AccountKind
    public var institutionName: String?
    public let createdAt: Date
    public var archivedAt: Date?

    public var isArchived: Bool {
        archivedAt != nil
    }

    public init(
        id: UUID = UUID(),
        name: String,
        kind: AccountKind,
        institutionName: String?,
        createdAt: Date = .now,
        archivedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.institutionName = institutionName
        self.createdAt = createdAt
        self.archivedAt = archivedAt
    }
}

public enum AccountManagementError: Error, Equatable, Sendable {
    case accountNotFound(UUID)
    case deleteBlockedByDependencies(UUID)
}
