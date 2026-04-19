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

    public init(
        id: UUID = UUID(),
        name: String,
        kind: AccountKind,
        institutionName: String?,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.institutionName = institutionName
        self.createdAt = createdAt
    }
}
