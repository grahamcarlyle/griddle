import Cocoa
import ApplicationServices

/// Real implementation of DisplaySystem using Accessibility APIs and NSScreen.
public class RealDisplaySystem: DisplaySystem {

    public init() {}

    // MARK: - Screen enumeration

    public var screens: [ScreenInfo] {
        NSScreen.screens.map { screenInfo(from: $0) }
    }

    public var mainScreen: ScreenInfo? {
        NSScreen.main.map { screenInfo(from: $0) }
    }

    // MARK: - Focused window

    public func screenForFocusedWindow() -> ScreenInfo? {
        guard let window = focusedWindow() else { return nil }
        var posValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &posValue) == .success,
              let posVal = posValue else { return nil }
        var pos = CGPoint.zero
        AXValueGetValue(posVal as! AXValue, .cgPoint, &pos)
        let screens = NSScreen.screens
        let screen = screens.first(where: { $0.frame.contains(pos) }) ?? NSScreen.main ?? screens.first
        return screen.map { screenInfo(from: $0) }
    }

    public func isFocusedWindowFullScreen() -> Bool {
        guard let window = focusedWindow() else { return false }
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, "AXFullScreen" as CFString, &value) == .success,
              let isFullScreen = value as? Bool else {
            return false
        }
        return isFullScreen
    }

    // MARK: - Window movement

    public func moveFocusedWindow(to frame: CGRect) {
        guard let window = focusedWindow() else { return }
        setFrame(frame, for: window)
    }

    // MARK: - Private helpers

    private func focusedWindow() -> AXUIElement? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        var focusedWindow: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedWindow) == .success else {
            return nil
        }
        return (focusedWindow as! AXUIElement)
    }

    private func applicationElement(for window: AXUIElement) -> AXUIElement? {
        var pid: pid_t = 0
        guard AXUIElementGetPid(window, &pid) == .success else { return nil }
        return AXUIElementCreateApplication(pid)
    }

    private func setFrame(_ frame: CGRect, for window: AXUIElement) {
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

    // MARK: - NSScreen → ScreenInfo conversion

    private func screenInfo(from screen: NSScreen) -> ScreenInfo {
        let name = screen.localizedName
        let origin = screen.frame.origin
        let id = "\(name) @ \(Int(origin.x)),\(Int(origin.y))"

        // Convert AppKit visibleFrame (bottom-left origin) to AX/Quartz (top-left origin)
        let displayBounds = CGDisplayBounds(CGMainDisplayID())
        let visibleAppKit = screen.visibleFrame
        let flippedY = displayBounds.height - visibleAppKit.origin.y - visibleAppKit.height
        let visibleFrame = CGRect(
            x: visibleAppKit.origin.x,
            y: flippedY,
            width: visibleAppKit.width,
            height: visibleAppKit.height
        )

        return ScreenInfo(
            id: id,
            localizedName: name,
            frame: screen.frame,
            visibleFrame: visibleFrame
        )
    }
}
