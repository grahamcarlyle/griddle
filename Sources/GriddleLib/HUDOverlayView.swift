import Cocoa

/// A rectangular region of grid cells to highlight.
public struct HighlightRegion: Equatable {
    public var minCol: Int
    public var minRow: Int
    public var maxCol: Int
    public var maxRow: Int

    public init(minCol: Int, minRow: Int, maxCol: Int, maxRow: Int) {
        self.minCol = minCol
        self.minRow = minRow
        self.maxCol = maxCol
        self.maxRow = maxRow
    }

    public func contains(col: Int, row: Int) -> Bool {
        col >= minCol && col <= maxCol && row >= minRow && row <= maxRow
    }
}

/// Draws a grid overlay with themed cells for the HUD.
public class HUDOverlayView: NSView {
    public var layout: GridLayout?
    public var keyLabels: [String]?
    public var theme: HUDTheme = .system
    public var highlightedRegion: HighlightRegion? { didSet { needsDisplay = true } }

    /// When set, only these cell indices are reachable (prefix mode).
    /// Cells not in this set are dimmed. Each entry maps cellIndex → child key label.
    public var prefixReachableCells: [Int: String]? { didSet { needsDisplay = true } }

    /// When true, shows weight percentages as a status strip.
    public var showWeightStatus: Bool = false {
        didSet {
            needsDisplay = true
            repositionNameBanner()
        }
    }

    private var nameBanner: NSView?
    private var nameBannerLabel: NSTextField?
    private var nameBannerDimWorkItem: DispatchWorkItem?
    private static let nameBannerDimAlpha: CGFloat = 0.3
    /// Distance from the top of the overlay to the top of the banner pill when shown alone.
    /// Matches the weight-status pill's top inset so the two share a y-axis when only one is visible.
    private static let nameBannerTopInset: CGFloat = 12
    /// Approximate height of the weight-status pill (~22 pt 18pt-medium text + 12 pt vertical padding).
    private static let weightStatusPillHeight: CGFloat = 34
    private static let nameBannerStackGap: CGFloat = 8

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
    public var disabledMessage: String? { didSet { needsDisplay = true } }

    override public func draw(_ dirtyRect: NSRect) {
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

    public func showLayoutNameBanner(_ name: String) {
        let banner: NSView
        let label: NSTextField
        if let existing = nameBanner, let existingLabel = nameBannerLabel {
            banner = existing
            label = existingLabel
        } else {
            banner = NSView(frame: .zero)
            banner.wantsLayer = true
            banner.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.6).cgColor
            banner.layer?.cornerRadius = 8

            label = NSTextField(labelWithString: name)
            label.font = NSFont.systemFont(ofSize: 18, weight: .medium)
            label.textColor = NSColor.white.withAlphaComponent(0.95)
            label.backgroundColor = .clear
            label.isBezeled = false
            label.isEditable = false
            label.isSelectable = false
            banner.addSubview(label)

            addSubview(banner)
            self.nameBanner = banner
            self.nameBannerLabel = label
        }

        label.stringValue = name
        label.sizeToFit()

        let horizontalPadding: CGFloat = 16
        let verticalPadding: CGFloat = 6
        let bannerWidth = label.frame.width + horizontalPadding * 2
        let bannerHeight = label.frame.height + verticalPadding * 2

        banner.frame = NSRect(
            x: bounds.midX - bannerWidth / 2,
            y: 0,
            width: bannerWidth,
            height: bannerHeight
        )
        label.frame = NSRect(
            x: horizontalPadding,
            y: verticalPadding,
            width: label.frame.width,
            height: label.frame.height
        )
        repositionNameBanner()

        nameBannerDimWorkItem?.cancel()
        banner.layer?.removeAllAnimations()
        banner.alphaValue = 1.0

        let workItem = DispatchWorkItem { [weak self, weak banner] in
            guard let banner = banner else { return }
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.6
                banner.animator().alphaValue = HUDOverlayView.nameBannerDimAlpha
            }
            self?.nameBannerDimWorkItem = nil
        }
        nameBannerDimWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: workItem)
    }

    private func repositionNameBanner() {
        guard let banner = nameBanner else { return }
        let topInset = HUDOverlayView.nameBannerTopInset
            + (showWeightStatus ? HUDOverlayView.weightStatusPillHeight + HUDOverlayView.nameBannerStackGap : 0)
        let originY = bounds.maxY - topInset - banner.frame.height
        banner.frame.origin = NSPoint(x: bounds.midX - banner.frame.width / 2, y: originY)
    }

    override public func layout() {
        super.layout()
        repositionNameBanner()
    }
}
