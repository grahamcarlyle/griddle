import Cocoa

/// A rectangular region of grid cells to highlight.
struct HighlightRegion: Equatable {
    var minCol: Int
    var minRow: Int
    var maxCol: Int
    var maxRow: Int

    func contains(col: Int, row: Int) -> Bool {
        col >= minCol && col <= maxCol && row >= minRow && row <= maxRow
    }
}

/// Draws a grid overlay with themed cells for the HUD.
class HUDOverlayView: NSView {
    var layout: GridLayout?
    var keyLabels: [String]?
    var theme: HUDTheme = .system
    var highlightedRegion: HighlightRegion? { didSet { needsDisplay = true } }

    /// When set, only these cell indices are reachable (prefix mode).
    /// Cells not in this set are dimmed. Each entry maps cellIndex → child key label.
    var prefixReachableCells: [Int: String]? { didSet { needsDisplay = true } }

    /// When true, shows weight percentages as a status strip.
    var showWeightStatus: Bool = false { didSet { needsDisplay = true } }

    private func themeColors() -> (cellColor: NSColor, bgAlpha: CGFloat) {
        switch theme {
        case .system:
            return (NSColor.controlAccentColor, 0.3)
        case .green:
            return (NSColor(calibratedRed: 0.2, green: 0.8, blue: 0.4, alpha: 1.0), 0.3)
        case .highContrast:
            return (NSColor.white, 0.6)
        case .purple:
            return (NSColor(calibratedRed: 0.6, green: 0.3, blue: 0.9, alpha: 1.0), 0.3)
        case .orange:
            return (NSColor(calibratedRed: 1.0, green: 0.6, blue: 0.2, alpha: 1.0), 0.3)
        }
    }

    /// When set, shows a centered message instead of the grid.
    var disabledMessage: String? { didSet { needsDisplay = true } }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let bounds = self.bounds
        let colors = themeColors()

        // Semi-transparent dark background
        NSColor.black.withAlphaComponent(colors.bgAlpha).setFill()
        NSBezierPath.fill(bounds)

        if let message = disabledMessage {
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 24, weight: .semibold),
                .foregroundColor: NSColor.white.withAlphaComponent(0.8)
            ]
            let size = message.size(withAttributes: attrs)
            let point = NSPoint(
                x: bounds.midX - size.width / 2,
                y: bounds.midY - size.height / 2
            )
            message.draw(at: point, withAttributes: attrs)
            return
        }

        guard let layout = layout, let _ = NSGraphicsContext.current?.cgContext else { return }

        let colOffsets = layout.columnOffsets()
        let rowOffsets = layout.rowOffsets()

        for (index, cell) in layout.cells.enumerated() {
            // AppKit coordinates: origin is bottom-left, so flip row
            let x = bounds.origin.x + CGFloat(colOffsets[cell.col]) * bounds.width
            let y = bounds.origin.y + bounds.height - CGFloat(rowOffsets[cell.row + cell.rowSpan]) * bounds.height
            let w = CGFloat(colOffsets[cell.col + cell.colSpan] - colOffsets[cell.col]) * bounds.width
            let h = CGFloat(rowOffsets[cell.row + cell.rowSpan] - rowOffsets[cell.row]) * bounds.height

            let cellRect = CGRect(x: x + 4, y: y + 4, width: w - 8, height: h - 8)
            let path = NSBezierPath(roundedRect: cellRect, xRadius: 8, yRadius: 8)

            let isHighlighted = highlightedRegion?.contains(col: cell.col, row: cell.row) ?? false

            // In prefix mode, dim cells that aren't reachable
            let isDimmed: Bool
            if let reachable = prefixReachableCells {
                isDimmed = reachable[index] == nil
            } else {
                isDimmed = false
            }

            // Fill
            let fillAlpha: CGFloat
            if isDimmed {
                fillAlpha = 0.05
            } else if isHighlighted {
                fillAlpha = 0.45
            } else {
                fillAlpha = 0.2
            }
            colors.cellColor.withAlphaComponent(fillAlpha).setFill()
            path.fill()

            // Border
            let borderAlpha: CGFloat = isDimmed ? 0.2 : (isHighlighted ? 1.0 : 0.8)
            colors.cellColor.withAlphaComponent(borderAlpha).setStroke()
            path.lineWidth = isHighlighted ? 3 : 2
            path.stroke()

            // Cell label — in prefix mode show only the child key; otherwise full label
            let label: String
            if let childLabel = prefixReachableCells?[index] {
                label = childLabel
            } else if let labels = keyLabels, index < labels.count {
                label = labels[index]
            } else {
                label = "\(index + 1)"
            }

            let fontSize: CGFloat = label.count > 2 ? 32 : 48
            let labelAlpha: CGFloat = isDimmed ? 0.15 : (isHighlighted ? 1.0 : 0.9)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: fontSize, weight: .bold),
                .foregroundColor: NSColor.white.withAlphaComponent(labelAlpha)
            ]
            let size = label.size(withAttributes: attrs)
            let labelPoint = NSPoint(
                x: cellRect.midX - size.width / 2,
                y: cellRect.midY - size.height / 2
            )
            label.draw(at: labelPoint, withAttributes: attrs)
        }

        if showWeightStatus {
            let colWeights = layout.normalizedColumnWeights()
            let rowWeights = layout.normalizedRowWeights()
            let colStr = colWeights.map { "\(Int(($0 * 100).rounded()))%" }.joined(separator: " / ")
            let rowStr = rowWeights.map { "\(Int(($0 * 100).rounded()))%" }.joined(separator: " / ")
            let statusText = "cols: \(colStr)   rows: \(rowStr)"

            let statusAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 18, weight: .medium),
                .foregroundColor: NSColor.white.withAlphaComponent(0.85)
            ]
            let statusSize = statusText.size(withAttributes: statusAttrs)

            let bgRect = CGRect(
                x: bounds.midX - statusSize.width / 2 - 16,
                y: bounds.maxY - statusSize.height - 24,
                width: statusSize.width + 32,
                height: statusSize.height + 12
            )
            let bgPath = NSBezierPath(roundedRect: bgRect, xRadius: 8, yRadius: 8)
            NSColor.black.withAlphaComponent(0.6).setFill()
            bgPath.fill()

            statusText.draw(
                at: NSPoint(x: bgRect.midX - statusSize.width / 2, y: bgRect.midY - statusSize.height / 2),
                withAttributes: statusAttrs
            )
        }
    }
}
