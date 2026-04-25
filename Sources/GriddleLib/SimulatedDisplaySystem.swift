import Foundation

/// A simulated window for use in demos and tests.
public struct SimWindow {
    public var title: String
    public var appName: String
    public var frame: CGRect
    public var isFocused: Bool
    public var isFullScreen: Bool

    public init(title: String, appName: String, frame: CGRect, isFocused: Bool = false, isFullScreen: Bool = false) {
        self.title = title
        self.appName = appName
        self.frame = frame
        self.isFocused = isFocused
        self.isFullScreen = isFullScreen
    }
}

/// Simulated display system for demos and tests. No Accessibility permission needed.
public class SimulatedDisplaySystem: DisplaySystem {
    public var simulatedScreens: [ScreenInfo]
    public var windows: [SimWindow]

    public init(screens: [ScreenInfo], windows: [SimWindow] = []) {
        self.simulatedScreens = screens
        self.windows = windows
    }

    /// Convenience initializer for a single screen setup.
    public convenience init(screenSize: CGSize = CGSize(width: 1920, height: 1080), menuBarHeight: CGFloat = 25) {
        let frame = CGRect(origin: .zero, size: screenSize)
        let visibleFrame = CGRect(x: 0, y: menuBarHeight, width: screenSize.width, height: screenSize.height - menuBarHeight)
        let screen = ScreenInfo(
            id: "Built-in Retina Display @ 0,0",
            localizedName: "Built-in Retina Display",
            frame: frame,
            visibleFrame: visibleFrame
        )
        self.init(screens: [screen])
    }

    // MARK: - DisplaySystem conformance

    public var screens: [ScreenInfo] { simulatedScreens }

    public var mainScreen: ScreenInfo? { simulatedScreens.first }

    public func screenForFocusedWindow() -> ScreenInfo? {
        guard let focused = windows.first(where: \.isFocused) else { return mainScreen }
        return simulatedScreens.first { $0.frame.contains(focused.frame.origin) } ?? mainScreen
    }

    public func isFocusedWindowFullScreen() -> Bool {
        windows.first(where: \.isFocused)?.isFullScreen ?? false
    }

    public func moveFocusedWindow(to frame: CGRect) {
        if let i = windows.firstIndex(where: \.isFocused) {
            windows[i].frame = frame
        }
    }

    // MARK: - Helpers for demos/tests

    public func focusWindow(at index: Int) {
        for i in windows.indices {
            windows[i].isFocused = (i == index)
        }
    }

    public var focusedWindow: SimWindow? {
        windows.first(where: \.isFocused)
    }
}
