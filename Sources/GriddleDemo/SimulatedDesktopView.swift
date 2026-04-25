import Cocoa
import GriddleLib

/// Renders simulated windows with realistic macOS window chrome onto a desktop background.
class SimulatedDesktopView: NSView {
    var displaySystem: SimulatedDisplaySystem
    var screenInfo: ScreenInfo

    init(displaySystem: SimulatedDisplaySystem, screenInfo: ScreenInfo) {
        self.displaySystem = displaySystem
        self.screenInfo = screenInfo
        super.init(frame: NSRect(origin: .zero, size: screenInfo.frame.size))
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let bounds = self.bounds

        // Desktop background — dark gradient
        let gradient = NSGradient(
            starting: NSColor(calibratedRed: 0.15, green: 0.12, blue: 0.25, alpha: 1.0),
            ending: NSColor(calibratedRed: 0.08, green: 0.10, blue: 0.20, alpha: 1.0)
        )
        gradient?.draw(in: bounds, angle: -90)

        // Menu bar
        let menuBarHeight: CGFloat = 25
        let menuBarRect = NSRect(x: 0, y: bounds.height - menuBarHeight, width: bounds.width, height: menuBarHeight)
        NSColor(calibratedWhite: 0.15, alpha: 0.85).setFill()
        menuBarRect.fill()

        // Menu bar text
        let menuFont = NSFont.systemFont(ofSize: 13, weight: .semibold)
        let menuAttrs: [NSAttributedString.Key: Any] = [
            .font: menuFont,
            .foregroundColor: NSColor.white
        ]
        let appleSymbol = "" // Apple logo placeholder
        appleSymbol.draw(at: NSPoint(x: 14, y: bounds.height - 20), withAttributes: menuAttrs)

        let menuLightAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13),
            .foregroundColor: NSColor.white.withAlphaComponent(0.9)
        ]
        "Finder  File  Edit  View  Go  Window  Help".draw(at: NSPoint(x: 36, y: bounds.height - 20), withAttributes: menuLightAttrs)

        // Draw each simulated window (AX coordinates: top-left origin → flip to AppKit bottom-left)
        for window in displaySystem.windows {
            drawWindow(window, in: bounds)
        }
    }

    private func drawWindow(_ window: SimWindow, in bounds: NSRect) {
        // Convert from AX/Quartz coords (top-left origin) to AppKit coords (bottom-left origin)
        let flippedY = bounds.height - window.frame.origin.y - window.frame.height
        let windowRect = NSRect(
            x: window.frame.origin.x,
            y: flippedY,
            width: window.frame.width,
            height: window.frame.height
        )

        let titleBarHeight: CGFloat = 28
        let cornerRadius: CGFloat = 10

        // Window shadow
        let shadow = NSShadow()
        shadow.shadowOffset = NSSize(width: 0, height: -4)
        shadow.shadowBlurRadius = 15
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.4)

        NSGraphicsContext.saveGraphicsState()
        shadow.set()

        // Window background (rounded rect)
        let windowPath = NSBezierPath(roundedRect: windowRect, xRadius: cornerRadius, yRadius: cornerRadius)
        NSColor(calibratedWhite: 0.18, alpha: 1.0).setFill()
        windowPath.fill()

        NSGraphicsContext.restoreGraphicsState()

        // Title bar
        let titleBarRect = NSRect(
            x: windowRect.origin.x,
            y: windowRect.origin.y + windowRect.height - titleBarHeight,
            width: windowRect.width,
            height: titleBarHeight
        )

        // Title bar background with top corners rounded
        let titleBarPath = NSBezierPath()
        titleBarPath.move(to: NSPoint(x: titleBarRect.minX, y: titleBarRect.minY))
        titleBarPath.line(to: NSPoint(x: titleBarRect.minX, y: titleBarRect.maxY - cornerRadius))
        titleBarPath.appendArc(
            withCenter: NSPoint(x: titleBarRect.minX + cornerRadius, y: titleBarRect.maxY - cornerRadius),
            radius: cornerRadius, startAngle: 180, endAngle: 90, clockwise: true
        )
        titleBarPath.line(to: NSPoint(x: titleBarRect.maxX - cornerRadius, y: titleBarRect.maxY))
        titleBarPath.appendArc(
            withCenter: NSPoint(x: titleBarRect.maxX - cornerRadius, y: titleBarRect.maxY - cornerRadius),
            radius: cornerRadius, startAngle: 90, endAngle: 0, clockwise: true
        )
        titleBarPath.line(to: NSPoint(x: titleBarRect.maxX, y: titleBarRect.minY))
        titleBarPath.close()

        NSColor(calibratedWhite: 0.22, alpha: 1.0).setFill()
        titleBarPath.fill()

        // Title bar separator line
        NSColor(calibratedWhite: 0.15, alpha: 1.0).setFill()
        NSRect(x: titleBarRect.minX, y: titleBarRect.minY, width: titleBarRect.width, height: 1).fill()

        // Traffic lights
        let trafficLightY = titleBarRect.midY
        let trafficLightStartX = titleBarRect.minX + 14
        let lightRadius: CGFloat = 6

        let colors: [NSColor] = [
            NSColor(calibratedRed: 1.0, green: 0.38, blue: 0.34, alpha: 1.0),  // close (red)
            NSColor(calibratedRed: 1.0, green: 0.78, blue: 0.24, alpha: 1.0),  // minimize (yellow)
            NSColor(calibratedRed: 0.30, green: 0.84, blue: 0.40, alpha: 1.0), // zoom (green)
        ]

        for (i, color) in colors.enumerated() {
            let cx = trafficLightStartX + CGFloat(i) * 20
            let lightRect = NSRect(x: cx - lightRadius, y: trafficLightY - lightRadius, width: lightRadius * 2, height: lightRadius * 2)
            color.setFill()
            NSBezierPath(ovalIn: lightRect).fill()
        }

        // Title text
        let titleFont = NSFont.systemFont(ofSize: 12, weight: .medium)
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: NSColor.white.withAlphaComponent(0.8)
        ]
        let titleSize = (window.title as NSString).size(withAttributes: titleAttrs)
        let titleX = titleBarRect.midX - titleSize.width / 2
        let titleY = titleBarRect.midY - titleSize.height / 2
        (window.title as NSString).draw(at: NSPoint(x: titleX, y: titleY), withAttributes: titleAttrs)

        // Content area — subtle color based on app name
        let contentRect = NSRect(
            x: windowRect.origin.x,
            y: windowRect.origin.y,
            width: windowRect.width,
            height: windowRect.height - titleBarHeight
        )

        let contentColor: NSColor
        switch window.appName.lowercased() {
        case "safari":
            contentColor = NSColor(calibratedRed: 0.14, green: 0.14, blue: 0.16, alpha: 1.0)
        case "terminal":
            contentColor = NSColor(calibratedRed: 0.05, green: 0.05, blue: 0.07, alpha: 1.0)
        case "notes":
            contentColor = NSColor(calibratedRed: 0.20, green: 0.18, blue: 0.12, alpha: 1.0)
        case "finder":
            contentColor = NSColor(calibratedRed: 0.16, green: 0.16, blue: 0.18, alpha: 1.0)
        default:
            contentColor = NSColor(calibratedWhite: 0.18, alpha: 1.0)
        }

        // Bottom corners rounded
        let contentPath = NSBezierPath()
        contentPath.move(to: NSPoint(x: contentRect.minX, y: contentRect.maxY))
        contentPath.line(to: NSPoint(x: contentRect.minX, y: contentRect.minY + cornerRadius))
        contentPath.appendArc(
            withCenter: NSPoint(x: contentRect.minX + cornerRadius, y: contentRect.minY + cornerRadius),
            radius: cornerRadius, startAngle: 180, endAngle: 270
        )
        contentPath.line(to: NSPoint(x: contentRect.maxX - cornerRadius, y: contentRect.minY))
        contentPath.appendArc(
            withCenter: NSPoint(x: contentRect.maxX - cornerRadius, y: contentRect.minY + cornerRadius),
            radius: cornerRadius, startAngle: 270, endAngle: 360
        )
        contentPath.line(to: NSPoint(x: contentRect.maxX, y: contentRect.maxY))
        contentPath.close()

        contentColor.setFill()
        contentPath.fill()

        // App name label in content area
        let appFont = NSFont.systemFont(ofSize: 14, weight: .light)
        let appAttrs: [NSAttributedString.Key: Any] = [
            .font: appFont,
            .foregroundColor: NSColor.white.withAlphaComponent(0.3)
        ]
        let appSize = (window.appName as NSString).size(withAttributes: appAttrs)
        let appX = contentRect.midX - appSize.width / 2
        let appY = contentRect.midY - appSize.height / 2
        (window.appName as NSString).draw(at: NSPoint(x: appX, y: appY), withAttributes: appAttrs)
    }
}
