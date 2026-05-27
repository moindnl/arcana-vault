import SwiftUI

/// Wrapping horizontal flow layout — children fill left-to-right,
/// wrap to a new row when they exceed available width.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        let height = rows.map(\.height).reduce(0, +) + max(0, CGFloat(rows.count - 1)) * spacing
        return CGSize(width: proposal.width ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            for subview in row.subviews {
                let size = subview.sizeThatFits(.unspecified)
                subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    // MARK: - Helpers

    private struct Row {
        var subviews: [LayoutSubview] = []
        var height: CGFloat = 0
    }

    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [Row] {
        let maxWidth = proposal.width ?? .infinity
        var rows: [Row] = []
        var current = Row()
        var currentWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let needed = currentWidth == 0 ? size.width : currentWidth + spacing + size.width
            if needed > maxWidth && !current.subviews.isEmpty {
                rows.append(current)
                current = Row()
                currentWidth = 0
            }
            current.subviews.append(subview)
            current.height = max(current.height, size.height)
            currentWidth = currentWidth == 0 ? size.width : currentWidth + spacing + size.width
        }
        if !current.subviews.isEmpty { rows.append(current) }
        return rows
    }
}
