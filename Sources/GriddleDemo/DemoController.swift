import Cocoa
import SwiftUI
import GriddleLib

// Disambiguate from SwiftUI.GridLayout (macOS 13+)
typealias GridLayout = GriddleLib.GridLayout

/// Orchestrates a demo sequence, capturing screenshots at each step.
class DemoController {
    let displaySystem: SimulatedDisplaySystem
    let config: GriddleConfig
    let outputDir: String
    var panel: NSPanel?
    var desktopView: SimulatedDesktopView?
    var overlayView: HUDOverlayView?
    var stepIndex = 0

    init(outputDir: String) {
        self.outputDir = outputDir
        self.config = GriddleConfig.default
        let sim = SimulatedDisplaySystem()
        sim.windows = [
            SimWindow(title: "Welcome to Safari", appName: "Safari",
                      frame: CGRect(x: 80, y: 80, width: 700, height: 500), isFocused: true),
            SimWindow(title: "Terminal — zsh", appName: "Terminal",
                      frame: CGRect(x: 300, y: 200, width: 600, height: 400)),
            SimWindow(title: "Notes", appName: "Notes",
                      frame: CGRect(x: 500, y: 120, width: 500, height: 450)),
        ]
        self.displaySystem = sim
    }

    func run() {
        // Create output directory
        try? FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

        guard let screen = displaySystem.mainScreen else {
            NSLog("GriddleDemo: No screen available")
            NSApplication.shared.terminate(nil)
            return
        }

        // Create the desktop panel (full-screen, floating)
        let screenFrame = screen.frame
        let panel = NSPanel(
            contentRect: screenFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = true
        panel.backgroundColor = .black
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let desktopView = SimulatedDesktopView(displaySystem: displaySystem, screenInfo: screen)
        panel.contentView = desktopView
        panel.orderFrontRegardless()

        self.panel = panel
        self.desktopView = desktopView

        // Run the demo sequence with delays
        runNextStep()
    }

    private func runNextStep() {
        guard let screen = displaySystem.mainScreen else { return }
        let layout = config.layouts.first(where: { $0.id == config.activeLayoutID }) ?? config.layouts[0]

        switch stepIndex {
        case 0:
            // Screenshot 1: Desktop with scattered windows (no HUD)
            captureAfterDelay(name: "01-desktop")

        case 1:
            // Screenshot 2: HUD overlay showing 3x2 grid
            showOverlay(layout: layout, screen: screen)
            captureAfterDelay(name: "02-hud-grid")

        case 2:
            // Screenshot 3: Cell highlighted (cursor on top-left)
            overlayView?.highlightedRegion = HighlightRegion(minCol: 0, minRow: 0, maxCol: 0, maxRow: 0)
            captureAfterDelay(name: "03-cell-selected")

        case 3:
            // Screenshot 4: Multi-cell selection (spanning top two cells)
            overlayView?.highlightedRegion = HighlightRegion(minCol: 0, minRow: 0, maxCol: 1, maxRow: 0)
            captureAfterDelay(name: "04-multi-cell")

        case 4:
            // Screenshot 5: Window tiled into top-left cell
            removeOverlay()
            let cell = layout.cells[0]
            let frame = WindowMover.frame(for: cell, in: layout, on: screen)
            displaySystem.moveFocusedWindow(to: frame)
            desktopView?.needsDisplay = true
            captureAfterDelay(name: "05-window-tiled")

        case 5:
            // Screenshot 6: Show HUD with different theme (green)
            var greenConfig = config
            greenConfig.hudTheme = .green
            let greenLayout = greenConfig.layouts.first(where: { $0.id == greenConfig.activeLayoutID }) ?? greenConfig.layouts[0]
            showOverlay(layout: greenLayout, screen: screen, theme: .green)
            captureAfterDelay(name: "06-theme-green")

        case 6:
            // Screenshot 7: Purple theme
            removeOverlay()
            let purpleLayout = layout
            showOverlay(layout: purpleLayout, screen: screen, theme: .purple)
            captureAfterDelay(name: "07-theme-purple")

        case 7:
            // Screenshot 8: Show settings view
            removeOverlay()
            showSettings()
            captureAfterDelay(name: "08-settings")

        default:
            // Done
            NSLog("GriddleDemo: All screenshots captured to \(outputDir)")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                NSApplication.shared.terminate(nil)
            }
            return
        }

        stepIndex += 1
    }

    private func showOverlay(layout: GridLayout, screen: ScreenInfo, theme: HUDTheme = .system) {
        removeOverlay()

        let keyMap = KeyMap.build(for: config.keyStyle, columns: layout.columns, rows: layout.rows)
        let overlayView = HUDOverlayView(frame: NSRect(origin: .zero, size: screen.frame.size))
        overlayView.layout = layout
        overlayView.keyLabels = keyMap.labels
        overlayView.theme = theme

        // Add overlay as a subview on top of the desktop
        desktopView?.addSubview(overlayView)
        self.overlayView = overlayView
    }

    private func removeOverlay() {
        overlayView?.removeFromSuperview()
        overlayView = nil
    }

    private func showSettings() {
        let configStore = ConfigStore()
        let hotkeyManager = HotkeyManager(config: configStore.config, displaySystem: displaySystem, inputSource: ScriptedInputSource())

        let settingsWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 520),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        settingsWindow.title = "Griddle"
        settingsWindow.center()

        let hostingController = NSHostingController(
            rootView: SettingsView(configStore: configStore, hotkeyManager: hotkeyManager, screens: displaySystem.screens)
        )
        settingsWindow.contentViewController = hostingController
        settingsWindow.orderFrontRegardless()
    }

    private func captureAfterDelay(name: String) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.captureScreenshot(name: name)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                self?.runNextStep()
            }
        }
    }

    private func captureScreenshot(name: String) {
        let path = "\(outputDir)/\(name).png"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-x", path]
        try? process.run()
        process.waitUntilExit()
        NSLog("GriddleDemo: Captured \(path)")
    }
}
