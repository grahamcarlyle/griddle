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
    var config: GriddleConfig
    var desktopView: SimulatedDesktopView?
    var displaySystem: SimulatedDisplaySystem
    var presenter: DemoHUDPresenter?
    var inputSource: ScriptedInputSource?
    var hudController: HUDController?

    private let initialWindows: [SimWindow] = [
        SimWindow(title: "Welcome to Safari", appName: "Safari",
                  frame: CGRect(x: 80, y: 80, width: 700, height: 500), isFocused: true),
        SimWindow(title: "Terminal — zsh", appName: "Terminal",
                  frame: CGRect(x: 300, y: 200, width: 600, height: 400)),
        SimWindow(title: "Notes", appName: "Notes",
                  frame: CGRect(x: 500, y: 120, width: 500, height: 450)),
    ]

    // Carbon key codes
    private let kEscape: UInt16 = 53
    private let kReturn: UInt16 = 36
    private let kArrowUp: UInt16 = 126
    private let kArrowDown: UInt16 = 125
    private let kArrowLeft: UInt16 = 123
    private let kArrowRight: UInt16 = 124

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

        let presenter = DemoHUDPresenter(parentView: desktopView)
        let input = ScriptedInputSource()
        let controller = HUDController(config: config, displaySystem: displaySystem, inputSource: input, presenter: presenter)
        input.start(handler: controller)
        self.presenter = presenter
        self.inputSource = input
        self.hudController = controller

        for sequence in DemoSequence.all {
            runSequence(sequence)
        }

        renderSettingsScreenshot()

        NSLog("GriddleDemo: All sequences complete — output in \(outputDir)")
    }

    private func runSequence(_ sequence: DemoSequence) {
        var frames: [(CGImage, TimeInterval)] = []

        for step in sequence.steps {
            for action in step.actions {
                apply(action)
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

    private func apply(_ action: DemoAction) {
        switch action {
        case .resetWindows:
            dismissControllerHUD()
            displaySystem.windows = initialWindows
            desktopView?.needsDisplay = true

        case .showHUD(let layoutID, let theme):
            dismissControllerHUD()
            config.activeLayoutID = layoutID
            config.hudTheme = theme
            hudController?.update(config: config)
            inputSource?.sendModifierTap()

        case .cellKey(let col, let row):
            guard let layout = activeLayout() else { return }
            let cellIndex = row * layout.columns + col
            let keyMap = KeyMap.build(for: config.keyStyle, columns: layout.columns, rows: layout.rows)
            guard let keyCode = keyMap.bindings.first(where: {
                if case .direct(let idx) = $0.value { return idx == cellIndex }
                return false
            })?.key else {
                NSLog("GriddleDemo: no direct key binding for cell (\(col),\(row))")
                return
            }
            inputSource?.sendKeyDown(keyCode: keyCode, shiftHeld: false)

        case .arrowKey(let direction):
            inputSource?.sendKeyDown(keyCode: arrowKeyCode(direction), shiftHeld: false)

        case .pressEnter:
            inputSource?.sendKeyDown(keyCode: kReturn, shiftHeld: false)

        case .shiftHold(let held):
            inputSource?.sendShiftFlagsChanged(held: held)

        case .shiftArrow(let direction):
            inputSource?.sendKeyDown(keyCode: arrowKeyCode(direction), shiftHeld: true)
        }
    }

    private func activeLayout() -> GridLayout? {
        config.layouts.first(where: { $0.id == config.activeLayoutID })
    }

    private func arrowKeyCode(_ direction: ArrowDirection) -> UInt16 {
        switch direction {
        case .up: return kArrowUp
        case .down: return kArrowDown
        case .left: return kArrowLeft
        case .right: return kArrowRight
        }
    }

    private func dismissControllerHUD() {
        guard let controller = hudController, controller.isHUDVisible else { return }
        inputSource?.sendKeyDown(keyCode: kEscape, shiftHeld: false)
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
            proportionsExpanded: true,
            hotkeysExpanded: true
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
