import Foundation

public struct ManagedMonthlyTarget: Identifiable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var scope: TargetScope
    public var monthlyLimit: Decimal
    public var spent: Decimal
    public var remaining: Decimal
    public var paceDelta: Decimal
    public var createdAt: Date

    public init(
        id: UUID,
        name: String,
        scope: TargetScope,
        monthlyLimit: Decimal,
        spent: Decimal,
        remaining: Decimal,
        paceDelta: Decimal,
        createdAt: Date
    ) {
        self.id = id
        self.name = name
        self.scope = scope
        self.monthlyLimit = monthlyLimit
        self.spent = spent
        self.remaining = remaining
        self.paceDelta = paceDelta
        self.createdAt = createdAt
    }
}

public enum MonthlyTargetConflict: Error, Equatable, Sendable {
    case duplicateScope(TargetScope)
    case categoryGroupOverlap(categoryID: UUID, categoryGroupID: UUID)
}

public enum MonthlyTargetManagementError: Error, Equatable, Sendable {
    case conflict(MonthlyTargetConflict)
    case invalidLimit(Decimal)
    case targetNotFound(UUID)
}

extension MonthlyTargetManagementError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .conflict(.duplicateScope):
            "A target already exists for that scope."
        case .conflict(.categoryGroupOverlap):
            "Targets cannot overlap a category group and one of its member categories."
        case .invalidLimit:
            "Monthly targets must be greater than zero."
        case .targetNotFound:
            "The selected monthly target no longer exists."
        }
    }
}
