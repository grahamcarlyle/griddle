import Cocoa

/// Draws a grid overlay with numbered cells for the HUD.
class HUDOverlayView: NSView {
    var layout: GridLayout?
    var keyLabels: [String]?
    var highlightedIndex: Int? { didSet { needsDisplay = true } }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let layout = layout, let _ = NSGraphicsContext.current?.cgContext else { return }

        let bounds = self.bounds

        // Semi-transparent dark background
        NSColor.black.withAlphaComponent(0.3).setFill()
        NSBezierPath.fill(bounds)

        let cellWidth = bounds.width / CGFloat(layout.columns)
        let cellHeight = bounds.height / CGFloat(layout.rows)

        for (index, cell) in layout.cells.enumerated() {
            // AppKit coordinates: origin is bottom-left, so flip row
            let x = bounds.origin.x + CGFloat(cell.col) * cellWidth
            let y = bounds.origin.y + bounds.height - CGFloat(cell.row + cell.rowSpan) * cellHeight
            let w = cellWidth * CGFloat(cell.colSpan)
            let h = cellHeight * CGFloat(cell.rowSpan)

            let cellRect = CGRect(x: x + 4, y: y + 4, width: w - 8, height: h - 8)
            let path = NSBezierPath(roundedRect: cellRect, xRadius: 8, yRadius: 8)

            let isHighlighted = index == highlightedIndex

            // Fill
            let fillAlpha: CGFloat = isHighlighted ? 0.45 : 0.2
            NSColor(calibratedRed: 0.2, green: 0.8, blue: 0.4, alpha: fillAlpha).setFill()
            path.fill()

            // Border
            let borderAlpha: CGFloat = isHighlighted ? 1.0 : 0.8
            NSColor(calibratedRed: 0.2, green: 0.8, blue: 0.4, alpha: borderAlpha).setStroke()
            path.lineWidth = isHighlighted ? 3 : 2
            path.stroke()

            // Cell label
            let label = (keyLabels != nil && index < keyLabels!.count) ? keyLabels![index] : "\(index + 1)"
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 48, weight: .bold),
                .foregroundColor: NSColor.white.withAlphaComponent(isHighlighted ? 1.0 : 0.9)
            ]
            let size = label.size(withAttributes: attrs)
            let labelPoint = NSPoint(
                x: cellRect.midX - size.width / 2,
                y: cellRect.midY - size.height / 2
            )
            label.draw(at: labelPoint, withAttributes: attrs)
        }
    }
}
