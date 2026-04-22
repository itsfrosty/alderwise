import CoreGraphics

enum TwoPaneSplitLayoutState {
    static func clampedPrimaryWidth(
        requestedWidth: CGFloat,
        totalWidth: CGFloat?,
        minPrimaryWidth: CGFloat,
        minSecondaryWidth: CGFloat
    ) -> CGFloat {
        let minimumWidth = minPrimaryWidth

        guard let totalWidth, totalWidth > 0 else {
            return max(minimumWidth, requestedWidth)
        }

        let maximumWidth = max(minimumWidth, totalWidth - minSecondaryWidth)
        return min(max(minimumWidth, requestedWidth), maximumWidth)
    }
}
