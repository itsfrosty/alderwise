import SwiftUI

struct WrappingFlowLayout: Layout {
    var spacing: CGFloat = 8
    var rowSpacing: CGFloat = 8

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let rows = arrangedRows(for: subviews, in: proposal.width)
        let width = rows.map(\.width).max() ?? 0
        let height = rows.reduce(CGFloat(0)) { partialResult, row in
            partialResult + row.height
        } + CGFloat(max(0, rows.count - 1)) * rowSpacing

        return CGSize(width: width, height: height)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let rows = arrangedRows(for: subviews, in: bounds.width)
        var y = bounds.minY

        for row in rows {
            var x = bounds.minX

            for element in row.elements {
                subviews[element.index].place(
                    at: CGPoint(x: x, y: y),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(element.size)
                )
                x += element.size.width + spacing
            }

            y += row.height + rowSpacing
        }
    }

    private func arrangedRows(for subviews: Subviews, in proposedWidth: CGFloat?) -> [Row] {
        let maxWidth = proposedWidth ?? .greatestFiniteMagnitude
        var rows: [Row] = []
        var currentRow = Row()

        for (index, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)
            let proposedRowWidth = currentRow.elements.isEmpty
                ? size.width
                : currentRow.width + spacing + size.width

            if currentRow.elements.isEmpty == false, proposedRowWidth > maxWidth {
                rows.append(currentRow)
                currentRow = Row()
            }

            currentRow.elements.append(Row.Element(index: index, size: size))
            currentRow.width = currentRow.elements.count == 1
                ? size.width
                : currentRow.width + spacing + size.width
            currentRow.height = max(currentRow.height, size.height)
        }

        if currentRow.elements.isEmpty == false {
            rows.append(currentRow)
        }

        return rows
    }
}

private struct Row {
    struct Element {
        let index: Int
        let size: CGSize
    }

    var elements: [Element] = []
    var width: CGFloat = 0
    var height: CGFloat = 0
}
