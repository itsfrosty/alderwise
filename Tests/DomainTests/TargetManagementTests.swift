import Domain
import Foundation
import Testing

@Test
func managedTargetSelectionPrefersNextTargetWhenDeletingSelectedTarget() {
    let firstID = UUID(uuidString: "00000000-0000-0000-0000-000000000701")!
    let secondID = UUID(uuidString: "00000000-0000-0000-0000-000000000702")!
    let targets = [
        ManagedMonthlyTarget(
            id: firstID,
            name: "Groceries",
            scope: .category(firstID),
            monthlyLimit: 100,
            spent: 40,
            remaining: 60,
            paceDelta: 0,
            createdAt: Date(timeIntervalSince1970: 1_775_171_200)
        ),
        ManagedMonthlyTarget(
            id: secondID,
            name: "Food",
            scope: .categoryGroup(secondID),
            monthlyLimit: 200,
            spent: 120,
            remaining: 80,
            paceDelta: 0,
            createdAt: Date(timeIntervalSince1970: 1_775_171_201)
        ),
    ]

    #expect(
        ManagedTargetSelection.nextTargetID(
            afterDeleting: firstID,
            currentSelection: firstID,
            availableTargets: targets
        ) == secondID
    )
    #expect(
        ManagedTargetSelection.nextTargetID(
            afterDeleting: firstID,
            currentSelection: secondID,
            availableTargets: targets
        ) == secondID
    )
}
