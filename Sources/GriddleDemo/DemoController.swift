import Cocoa
import SwiftUI
import ImageIO
import UniformTypeIdentifiers
import GriddleLib

// Disambiguate from SwiftUI.GridLayout (macOS 13+)
typealias GridLayout = GriddleLib.GridLayout

/// Orchestrates demo sequences, rendering each to individual PNGs and per-sequence APNGs.
class DemoController {
    let outputDir: String
    let config: GriddleConfig
    var desktopView: SimulatedDesktopView?
    var overlayView: HUDOverlayView?
    var displaySystem: SimulatedDisplaySystem

    private let initialWindows: [SimWindow] = [
        SimWindow(title: "Welcome to Safari", appName: "Safari",
                  frame: CGRect(x: 80, y: 80, width: 700, height: 500), isFocused: true),
        SimWindow(title: "Terminal — zsh", appName: "Terminal",
                  frame: CGRect(x: 300, y: 200, width: 600, height: 400)),
        SimWindow(title: "Notes", appName: "Notes",
                  frame: CGRect(x: 500, y: 120, width: 500, height: 450)),
    ]

    // Track state applied during a sequence
    private var activeWeights: (columnWeights: [Double]?, rowWeights: [Double]?) = (nil, nil)
    private var activeLayoutID: String?

    init(outputDir: String) {
        self.outputDir = outputDir
        self.config = GriddleConfig.default
        let sim = SimulatedDisplaySystem()
        sim.windows = initialWindows
        self.displaySystem = sim
    }

    func run() {
        try? FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

        guard let screen = displaySystem.mainScreen else {
            NSLog("GriddleDemo: No screen available")
            return
        }

        let desktopView = SimulatedDesktopView(displaySystem: displaySystem, screenInfo: screen)
        desktopView.setFrameSize(screen.frame.size)
        self.desktopView = desktopView

        for sequence in DemoSequence.all {
            runSequence(sequence, screen: screen)
        }

        renderSettingsScreenshot()

        NSLog("GriddleDemo: All sequences complete — output in \(outputDir)")
    }

    private func runSequence(_ sequence: DemoSequence, screen: ScreenInfo) {
        var frames: [(CGImage, TimeInterval)] = []

        for step in sequence.steps {
            for action in step.actions {
                apply(action, screen: screen)
            }

            desktopView?.needsDisplay = true
            desktopView?.displayIfNeeded()

            guard let image = renderViewToBitmap(desktopView!) else {
                NSLog("GriddleDemo: Failed to render \(sequence.name)/\(step.description)")
                continue
            }

            frames.append((image, step.hold))
        }

        if !frames.isEmpty {
            composeAPNG(frames: frames, name: sequence.name)
            // Save individual frame PNGs for snapshot testing
            let framesDir = "\(outputDir)/frames"
            try? FileManager.default.createDirectory(atPath: framesDir, withIntermediateDirectories: true)
            for (index, (image, _)) in frames.enumerated() {
                savePNG(image: image, to: "\(framesDir)/\(sequence.name)-\(index).png")
            }
            NSLog("GriddleDemo: \(sequence.name).png (\(frames.count) frames)")
        }
    }

    // MARK: - Action Interpreter

    private func apply(_ action: DemoAction, screen: ScreenInfo) {
        switch action {
        case .showDesktop:
            removeOverlay()

        case .showHUD(let layoutID, let theme):
            guard let layout = config.layouts.first(where: { $0.id == layoutID }) else { return }
            activeLayoutID = layoutID
            var displayLayout = layout
            if let cw = activeWeights.columnWeights { displayLayout.columnWeights = cw }
            if let rw = activeWeights.rowWeights { displayLayout.rowWeights = rw }
            showOverlay(layout: displayLayout, screen: screen, theme: theme)

        case .highlight(let col, let row):
            overlayView?.highlightedRegion = HighlightRegion(minCol: col, minRow: row, maxCol: col, maxRow: row)

        case .highlightRegion(let minCol, let minRow, let maxCol, let maxRow):
            overlayView?.highlightedRegion = HighlightRegion(minCol: minCol, minRow: minRow, maxCol: maxCol, maxRow: maxRow)

        case .tileWindow(let windowIndex, let cellIndex):
            let lid = activeLayoutID ?? config.activeLayoutID
            guard var layout = config.layouts.first(where: { $0.id == lid }),
                  cellIndex < layout.cells.count,
                  windowIndex < displaySystem.windows.count else { return }
            if let cw = activeWeights.columnWeights { layout.columnWeights = cw }
            if let rw = activeWeights.rowWeights { layout.rowWeights = rw }
            displaySystem.focusWindow(at: windowIndex)
            let cell = layout.cells[cellIndex]
            let frame = WindowMover.frame(for: cell, in: layout, on: screen)
            displaySystem.moveFocusedWindow(to: frame)
            desktopView?.needsDisplay = true

        case .tileWindowToRegion(let windowIndex, let minCol, let minRow, let maxCol, let maxRow):
            let lid = activeLayoutID ?? config.activeLayoutID
            guard var layout = config.layouts.first(where: { $0.id == lid }),
                  windowIndex < displaySystem.windows.count else { return }
            if let cw = activeWeights.columnWeights { layout.columnWeights = cw }
            if let rw = activeWeights.rowWeights { layout.rowWeights = rw }
            displaySystem.focusWindow(at: windowIndex)
            let anchor = GridCell(col: minCol, row: minRow, colSpan: 1, rowSpan: 1)
            let extent = GridCell(col: maxCol, row: maxRow, colSpan: 1, rowSpan: 1)
            let target = WindowMover.boundingCell(from: anchor, to: extent)
            let frame = WindowMover.frame(for: target, in: layout, on: screen)
            displaySystem.moveFocusedWindow(to: frame)
            desktopView?.needsDisplay = true

        case .dismissHUD:
            removeOverlay()

        case .resetWindows:
            displaySystem.windows = initialWindows
            activeWeights = (nil, nil)
            activeLayoutID = nil
            removeOverlay()
            desktopView?.needsDisplay = true

        case .setWeights(let columnWeights, let rowWeights):
            activeWeights = (columnWeights, rowWeights)
            if var layout = overlayView?.layout {
                layout.columnWeights = columnWeights
                layout.rowWeights = rowWeights
                overlayView?.layout = layout
                overlayView?.needsDisplay = true
            }

        case .showWeightStatus:
            overlayView?.showWeightStatus = true
            overlayView?.needsDisplay = true
        }
    }

    // MARK: - Overlay Management

    private func showOverlay(layout: GridLayout, screen: ScreenInfo, theme: HUDTheme = .system) {
        removeOverlay()

        let keyMap = KeyMap.build(for: config.keyStyle, columns: layout.columns, rows: layout.rows)
        let overlayView = HUDOverlayView(frame: NSRect(origin: .zero, size: screen.frame.size))
        overlayView.layout = layout
        overlayView.keyLabels = keyMap.labels
        overlayView.theme = theme

        desktopView?.addSubview(overlayView)
        self.overlayView = overlayView
    }

    private func removeOverlay() {
        overlayView?.removeFromSuperview()
        overlayView = nil
    }

    // MARK: - Settings Screenshot

    private func renderSettingsScreenshot() {
        // Set up a config with multiple layouts and custom weights for a richer screenshot
        var settingsConfig = config
        var layout3x2 = settingsConfig.layouts.first(where: { $0.id == "3x2" })!
        layout3x2.columnWeights = [1.5, 1.0, 0.8]
        layout3x2.rowWeights = [1.2, 1.0]
        settingsConfig.layouts = settingsConfig.layouts.map { $0.id == "3x2" ? layout3x2 : $0 }
        settingsConfig.activeLayoutID = "3x2"

        let configStore = ConfigStore(config: settingsConfig)
        let inputSource = ScriptedInputSource()
        let hotkeyManager = HotkeyManager(config: settingsConfig, displaySystem: displaySystem, inputSource: inputSource)

        let settingsView = SettingsView(
            configStore: configStore,
            hotkeyManager: hotkeyManager,
            screens: displaySystem.screens,
            manageLayoutsExpanded: true,
            proportionsExpanded: true
        )
        let hostingView = NSHostingView(rootView: settingsView)

        // Size the view to its intrinsic content size
        let fittingSize = hostingView.fittingSize
        hostingView.frame = NSRect(origin: .zero, size: fittingSize)

        // Force layout
        hostingView.layoutSubtreeIfNeeded()

        if let image = renderViewToBitmap(hostingView) {
            savePNG(image: image, to: "\(outputDir)/settings.png")
            // Also save as a frame for snapshot testing
            let framesDir = "\(outputDir)/frames"
            try? FileManager.default.createDirectory(atPath: framesDir, withIntermediateDirectories: true)
            savePNG(image: image, to: "\(framesDir)/settings-0.png")
            NSLog("GriddleDemo: settings.png")
        }
    }

    // MARK: - Bitmap Rendering

    private func renderViewToBitmap(_ view: NSView) -> CGImage? {
        let bounds = view.bounds
        guard let bitmapRep = view.bitmapImageRepForCachingDisplay(in: bounds) else { return nil }
        view.cacheDisplay(in: bounds, to: bitmapRep)
        return bitmapRep.cgImage
    }

    // MARK: - APNG Composition

    private func composeAPNG(frames: [(CGImage, TimeInterval)], name: String) {
        let path = "\(outputDir)/\(name).png"
        let url = URL(fileURLWithPath: path)

        guard let dest = CGImageDestinationCreateWithURL(
            url as CFURL,
            UTType.png.identifier as CFString,
            frames.count,
            nil
        ) else {
            NSLog("GriddleDemo: Failed to create APNG destination for \(name)")
            return
        }

        let fileProperties: [CFString: Any] = [
            kCGImagePropertyAPNGLoopCount: 0
        ]
        CGImageDestinationSetProperties(dest, fileProperties as CFDictionary)

        for (image, hold) in frames {
            let frameProperties: [CFString: Any] = [
                kCGImagePropertyAPNGDelayTime: hold
            ]
            let properties: [CFString: Any] = [
                kCGImagePropertyPNGDictionary: frameProperties
            ]
            CGImageDestinationAddImage(dest, image, properties as CFDictionary)
        }

        CGImageDestinationFinalize(dest)
    }

    private func savePNG(image: CGImage, to path: String) {
        let url = URL(fileURLWithPath: path)
        guard let dest = CGImageDestinationCreateWithURL(
            url as CFURL,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else { return }
        CGImageDestinationAddImage(dest, image, nil)
        CGImageDestinationFinalize(dest)
    }
}
