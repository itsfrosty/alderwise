import CoreGraphics
import Testing

@testable import AlderwiseApp

@Test
func requestedPrimaryWidthWithinBoundsIsPreserved() {
    let width = TwoPaneSplitLayoutState.clampedPrimaryWidth(
        requestedWidth: 560,
        totalWidth: 1000,
        minPrimaryWidth: 420,
        minSecondaryWidth: 320
    )

    #expect(width == 560)
}

@Test
func primaryWidthClampsUpToMinimum() {
    let width = TwoPaneSplitLayoutState.clampedPrimaryWidth(
        requestedWidth: 300,
        totalWidth: 1000,
        minPrimaryWidth: 420,
        minSecondaryWidth: 320
    )

    #expect(width == 420)
}

@Test
func primaryWidthClampsDownToLeaveSecondaryMinimumVisible() {
    let width = TwoPaneSplitLayoutState.clampedPrimaryWidth(
        requestedWidth: 900,
        totalWidth: 1000,
        minPrimaryWidth: 420,
        minSecondaryWidth: 320
    )

    #expect(width == 680)
}

@Test
func unknownTotalWidthOnlyRespectsPrimaryMinimum() {
    let width = TwoPaneSplitLayoutState.clampedPrimaryWidth(
        requestedWidth: 360,
        totalWidth: nil,
        minPrimaryWidth: 420,
        minSecondaryWidth: 320
    )

    #expect(width == 420)
}
