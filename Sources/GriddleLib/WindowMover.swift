import Cocoa
import ApplicationServices

/// Moves and resizes the currently focused window to fit a grid cell on the display.
public struct WindowMover {

    /// Positions the focused window according to `cell` within `layout` on the screen
    /// containing the focused window.
    public static func moveFocusedWindow(to cell: GridCell, in layout: GridLayout) {
        guard let window = focusedWindow() else { return }
        guard let screenFrame = screenFrame(for: window) else { return }

        let cellWidth = screenFrame.width / CGFloat(layout.columns)
        let cellHeight = screenFrame.height / CGFloat(layout.rows)

        let targetFrame = CGRect(
            x: screenFrame.origin.x + CGFloat(cell.col) * cellWidth,
            y: screenFrame.origin.y + CGFloat(cell.row) * cellHeight,
            width: cellWidth * CGFloat(cell.colSpan),
            height: cellHeight * CGFloat(cell.rowSpan)
        )

        setFrame(targetFrame, for: window)
    }

    /// Computes the bounding GridCell that spans from cell1 to cell2.
    public static func boundingCell(from cell1: GridCell, to cell2: GridCell) -> GridCell {
        let minCol = min(cell1.col, cell2.col)
        let minRow = min(cell1.row, cell2.row)
        let maxCol = max(cell1.col + cell1.colSpan, cell2.col + cell2.colSpan)
        let maxRow = max(cell1.row + cell1.rowSpan, cell2.row + cell2.rowSpan)
        return GridCell(col: minCol, row: minRow, colSpan: maxCol - minCol, rowSpan: maxRow - minRow)
    }

    /// Returns the NSScreen containing the focused window (in AppKit coordinates).
    public static func screenForFocusedWindow() -> NSScreen? {
        guard let window = focusedWindow() else { return nil }
        var posValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &posValue) == .success,
              let posVal = posValue else { return nil }
        var pos = CGPoint.zero
        AXValueGetValue(posVal as! AXValue, .cgPoint, &pos)
        let screens = NSScreen.screens
        return screens.first(where: { $0.frame.contains(pos) }) ?? NSScreen.main ?? screens.first
    }

    // MARK: - Private helpers

    /// Returns whether the currently focused window is in native macOS full-screen mode.
    public static func isFocusedWindowFullScreen() -> Bool {
        guard let window = focusedWindow() else { return false }
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, "AXFullScreen" as CFString, &value) == .success,
              let isFullScreen = value as? Bool else {
            return false
        }
        return isFullScreen
    }

    private static func focusedWindow() -> AXUIElement? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        var focusedWindow: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedWindow) == .success else {
            return nil
        }
        return (focusedWindow as! AXUIElement)
    }

    /// Returns the application AXUIElement that owns the given window.
    private static func applicationElement(for window: AXUIElement) -> AXUIElement? {
        var pid: pid_t = 0
        guard AXUIElementGetPid(window, &pid) == .success else { return nil }
        return AXUIElementCreateApplication(pid)
    }

    private static func screenFrame(for window: AXUIElement) -> CGRect? {
        // Get window position in screen coordinates
        var posValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &posValue) == .success,
              let posVal = posValue else { return nil }
        var pos = CGPoint.zero
        AXValueGetValue(posVal as! AXValue, .cgPoint, &pos)

        // Find the screen that contains this point
        let screens = NSScreen.screens
        let screen = screens.first(where: { $0.frame.contains(pos) }) ?? NSScreen.main ?? screens[0]

        // Convert from AppKit coordinates (bottom-left origin) to screen coordinates (top-left origin)
        // AX uses top-left origin matching Quartz display coordinates
        let displayBounds = CGDisplayBounds(CGMainDisplayID())

        // The visible frame minus dock/menu bar
        let visibleAppKit = screen.visibleFrame

        // Convert AppKit visibleFrame to AX/Quartz coordinate space (flip Y)
        let flippedY = displayBounds.height - visibleAppKit.origin.y - visibleAppKit.height
        return CGRect(
            x: visibleAppKit.origin.x,
            y: flippedY,
            width: visibleAppKit.width,
            height: visibleAppKit.height
        )
    }

    private static func setFrame(_ frame: CGRect, for window: AXUIElement) {
        var pos = frame.origin
        var size = frame.size

        // Some apps (JetBrains IDEs, Electron apps) enable AXEnhancedUserInterface
        // which causes AX attribute sets to behave erratically. Temporarily disable it.
        let appElement = applicationElement(for: window)
        var enhancedUI = false
        if let appElement = appElement {
            var value: CFTypeRef?
            if AXUIElementCopyAttributeValue(appElement, "AXEnhancedUserInterface" as CFString, &value) == .success,
               let boolValue = value as? Bool, boolValue {
                enhancedUI = true
                AXUIElementSetAttributeValue(appElement, "AXEnhancedUserInterface" as CFString, false as CFBoolean)
            }
        }

        // Size, position, size: the standard pattern used by Rectangle, Loop, and Yabai.
        // First size handles pre-move screen constraints, second size handles post-move
        // constraints when the position change moves the window to a different screen.
        if let sizeValue = AXValueCreate(.cgSize, &size) {
            AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
        }
        if let posValue = AXValueCreate(.cgPoint, &pos) {
            AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, posValue)
        }
        if let sizeValue = AXValueCreate(.cgSize, &size) {
            AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
        }

        if enhancedUI, let appElement = appElement {
            AXUIElementSetAttributeValue(appElement, "AXEnhancedUserInterface" as CFString, true as CFBoolean)
        }
    }
}
