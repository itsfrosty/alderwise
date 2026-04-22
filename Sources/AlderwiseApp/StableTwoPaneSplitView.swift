import SwiftUI

private let stableSplitDividerThickness: CGFloat = 1
private let stableSplitDividerHitWidth: CGFloat = 10

struct StableTwoPaneSplitView<Primary: View, Secondary: View>: View {
    @Binding var primaryWidth: CGFloat
    let minPrimaryWidth: CGFloat
    let minSecondaryWidth: CGFloat
    let primary: Primary
    let secondary: Secondary

    @State private var dragStartWidth: CGFloat?

    var body: some View {
        GeometryReader { proxy in
            let availablePaneWidth = max(0, proxy.size.width - stableSplitDividerThickness)
            let clampedPrimaryWidth = TwoPaneSplitLayoutState.clampedPrimaryWidth(
                requestedWidth: primaryWidth,
                totalWidth: availablePaneWidth,
                minPrimaryWidth: minPrimaryWidth,
                minSecondaryWidth: minSecondaryWidth
            )

            HStack(spacing: 0) {
                primary
                    .frame(width: clampedPrimaryWidth)
                    .frame(maxHeight: .infinity)

                divider(totalWidth: availablePaneWidth, clampedPrimaryWidth: clampedPrimaryWidth)

                secondary
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                syncPrimaryWidth(totalWidth: availablePaneWidth)
            }
            .onChange(of: availablePaneWidth) { _, newWidth in
                syncPrimaryWidth(totalWidth: newWidth)
            }
        }
    }

    private func divider(totalWidth: CGFloat, clampedPrimaryWidth: CGFloat) -> some View {
        Rectangle()
            .fill(.separator)
            .frame(width: stableSplitDividerThickness)
            .overlay {
                Rectangle()
                    .fill(.clear)
                    .frame(width: stableSplitDividerHitWidth)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                if dragStartWidth == nil {
                                    dragStartWidth = clampedPrimaryWidth
                                }

                                let nextWidth = TwoPaneSplitLayoutState.clampedPrimaryWidth(
                                    requestedWidth: (dragStartWidth ?? clampedPrimaryWidth) + value.translation.width,
                                    totalWidth: totalWidth,
                                    minPrimaryWidth: minPrimaryWidth,
                                    minSecondaryWidth: minSecondaryWidth
                                )
                                if abs(primaryWidth - nextWidth) > 0.5 {
                                    primaryWidth = nextWidth
                                }
                            }
                            .onEnded { _ in
                                dragStartWidth = nil
                                syncPrimaryWidth(totalWidth: totalWidth)
                            }
                    )
            }
    }

    private func syncPrimaryWidth(totalWidth: CGFloat) {
        let clampedWidth = TwoPaneSplitLayoutState.clampedPrimaryWidth(
            requestedWidth: primaryWidth,
            totalWidth: totalWidth,
            minPrimaryWidth: minPrimaryWidth,
            minSecondaryWidth: minSecondaryWidth
        )

        if abs(primaryWidth - clampedWidth) > 0.5 {
            primaryWidth = clampedWidth
        }
    }
}
