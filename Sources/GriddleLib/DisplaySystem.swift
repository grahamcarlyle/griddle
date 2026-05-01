import Foundation

/// Information about a display screen, decoupled from NSScreen.
public struct ScreenInfo: Identifiable, Hashable {
    public let id: String           // stable key for per-screen config (replaces screenKey)
    public let localizedName: String
    public let frame: CGRect
    public let visibleFrame: CGRect // in AX/Quartz coordinates (top-left origin)

    public init(id: String, localizedName: String, frame: CGRect, visibleFrame: CGRect) {
        self.id = id
        self.localizedName = localizedName
        self.frame = frame
        self.visibleFrame = visibleFrame
    }
}

/// Abstracts all display and window system interactions.
/// Real implementation uses AX APIs + NSScreen; simulated implementation uses a model.
public protocol DisplaySystem: AnyObject {
    // Screen enumeration
    var screens: [ScreenInfo] { get }
    var mainScreen: ScreenInfo? { get }

    // Focused window
    func screenForFocusedWindow() -> ScreenInfo?
    func isFocusedWindowFullScreen() -> Bool

    // Window movement — takes pre-computed frame
    func moveFocusedWindow(to frame: CGRect)
}

/// Delivers input events (modifier taps, key presses) to a handler.
public protocol InputSource {
    func start(handler: InputHandler)
    func stop()
    /// Cancel a pending modifier tap (e.g. when a hotkey fires before modifier release).
    func cancelModifierTap()
}

/// Receives input events from an InputSource.
public protocol InputHandler: AnyObject {
    func handleModifierTap()
    @discardableResult
    func handleKeyDown(keyCode: UInt16, shiftHeld: Bool) -> Bool
    func handleShiftFlagsChanged(held: Bool)
}

extension InputHandler {
    public func handleShiftFlagsChanged(held: Bool) {}
}
