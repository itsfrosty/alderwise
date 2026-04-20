import Foundation

public enum BudgetCategoryKind: String, Codable, CaseIterable, Equatable, Sendable {
    case expense
    case income
    case transfer
}

public struct BudgetCategory: Identifiable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var kind: BudgetCategoryKind

    public init(id: UUID, name: String, kind: BudgetCategoryKind) {
        self.id = id
        self.name = name
        self.kind = kind
    }
}
