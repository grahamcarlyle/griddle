import Testing
import CoreGraphics
@testable import GriddleLib

@Suite("HUDController input handling", .serialized)
struct HUDControllerTests {
    let screen = ScreenInfo(
        id: "Test @ 0,0",
        localizedName: "Test",
        frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
        visibleFrame: CGRect(x: 0, y: 25, width: 1920, height: 1055)
    )

    // Key codes
    let escapeKey: UInt16 = 53
    let returnKey: UInt16 = 36
    let arrowUp: UInt16 = 126
    let arrowDown: UInt16 = 125
    let arrowLeft: UInt16 = 123
    let arrowRight: UInt16 = 124
    let zeroKey: UInt16 = 29

    private func makeController(columns: Int = 2, rows: Int = 2) -> (HUDController, SimulatedDisplaySystem, ScriptedInputSource) {
        let sim = SimulatedDisplaySystem(screens: [screen], windows: [
            SimWindow(title: "Safari", appName: "Safari",
                      frame: CGRect(x: 100, y: 100, width: 600, height: 400), isFocused: true)
        ])
        let input = ScriptedInputSource()
        let config = GriddleConfig.default
        let controller = HUDController(config: config, displaySystem: sim, inputSource: input, presenter: NullHUDPresenter())
        return (controller, sim, input)
    }

    /// Key codes for cells in a spatial grid layout.
    private func cellKeyCodes(columns: Int, rows: Int) -> [UInt16] {
        HotkeyManager.keyCodes(for: .spatial, columns: columns, rows: rows)
    }

    // MARK: - Modifier tap toggle

    @Test("modifier tap shows HUD")
    func modifierTapShowsHUD() {
        let (controller, _, _) = makeController()
        controller.handleModifierTap()
        #expect(controller.isHUDVisible == true)
    }

    @Test("second modifier tap dismisses HUD")
    func modifierTapDismissesHUD() {
        let (controller, _, _) = makeController()
        controller.handleModifierTap() // show
        controller.handleModifierTap() // dismiss
        #expect(controller.isHUDVisible == false)
    }

    // MARK: - Escape

    @Test("escape dismisses HUD")
    func escapeDismisses() {
        let (controller, _, _) = makeController()
        controller.handleModifierTap()
        let consumed = controller.handleKeyDown(keyCode: escapeKey, shiftHeld: false)
        #expect(consumed == true)
        #expect(controller.isHUDVisible == false)
    }

    @Test("keys are not consumed when HUD is hidden")
    func keysNotConsumedWhenHidden() {
        let (controller, _, _) = makeController()
        let consumed = controller.handleKeyDown(keyCode: escapeKey, shiftHeld: false)
        #expect(consumed == false)
    }

    // MARK: - Single cell selection

    @Test("pressing two cell keys moves focused window to bounding box")
    func singleCellSelection() {
        let (controller, sim, _) = makeController()
        let keys = cellKeyCodes(columns: 2, rows: 2)
        controller.handleModifierTap()

        // Press Q (top-left) — first key sets anchor, enters expanding
        controller.handleKeyDown(keyCode: keys[0], shiftHeld: false)
        // Press S (bottom-right) — second key commits the selection
        controller.handleKeyDown(keyCode: keys[3], shiftHeld: false)

        #expect(controller.isHUDVisible == false)
        // Window should span from top-left to bottom-right = full screen
        let window = sim.focusedWindow!
        #expect(abs(window.frame.width - 1920) < 1.0)
        #expect(abs(window.frame.height - 1055) < 1.0)
    }

    @Test("pressing same cell key twice tiles to that single cell")
    func sameCellTwice() {
        let (controller, sim, _) = makeController()
        let keys = cellKeyCodes(columns: 2, rows: 2)
        controller.handleModifierTap()

        // Press Q twice — anchor then confirm at top-left
        controller.handleKeyDown(keyCode: keys[0], shiftHeld: false)
        controller.handleKeyDown(keyCode: keys[0], shiftHeld: false)

        #expect(controller.isHUDVisible == false)
        let window = sim.focusedWindow!
        #expect(abs(window.frame.width - 960) < 1.0)    // half of 1920
        #expect(abs(window.frame.height - 527.5) < 1.0) // half of 1055
    }

    // MARK: - Arrow key navigation

    @Test("arrow keys navigate cursor and return confirms anchor")
    func arrowNavigation() {
        let (controller, sim, _) = makeController()
        controller.handleModifierTap()

        // Arrow right reveals cursor at (0,0), then moves to (1,0)
        controller.handleKeyDown(keyCode: arrowRight, shiftHeld: false) // reveal
        controller.handleKeyDown(keyCode: arrowRight, shiftHeld: false) // move to col 1
        // Return confirms anchor at (1,0)
        controller.handleKeyDown(keyCode: returnKey, shiftHeld: false)
        // Return again confirms single-cell selection at (1,0)
        controller.handleKeyDown(keyCode: returnKey, shiftHeld: false)

        #expect(controller.isHUDVisible == false)
        let window = sim.focusedWindow!
        // Top-right cell of 2x2: x=960, width=960
        #expect(abs(window.frame.origin.x - 960) < 1.0)
        #expect(abs(window.frame.width - 960) < 1.0)
    }

    @Test("arrow keys expand selection after anchor is set")
    func arrowExpand() {
        let (controller, sim, _) = makeController()
        controller.handleModifierTap()

        // Reveal cursor at (0,0)
        controller.handleKeyDown(keyCode: arrowRight, shiftHeld: false)
        // Return sets anchor at (0,0)
        controller.handleKeyDown(keyCode: returnKey, shiftHeld: false)
        // Arrow right expands extent to (1,0)
        controller.handleKeyDown(keyCode: arrowRight, shiftHeld: false)
        // Arrow down expands extent to (1,1)
        controller.handleKeyDown(keyCode: arrowDown, shiftHeld: false)
        // Return confirms — full screen
        controller.handleKeyDown(keyCode: returnKey, shiftHeld: false)

        #expect(controller.isHUDVisible == false)
        let window = sim.focusedWindow!
        #expect(abs(window.frame.width - 1920) < 1.0)
        #expect(abs(window.frame.height - 1055) < 1.0)
    }

    // MARK: - Weight editing

    @Test("shift+arrow edits weights and onLayoutEdited fires")
    func shiftArrowEditsWeights() {
        let (controller, _, _) = makeController()
        var editedLayout: GridLayout?
        controller.onLayoutEdited = { layout in
            editedLayout = layout
        }
        controller.handleModifierTap()

        let keys = cellKeyCodes(columns: 2, rows: 2)
        // Select top-left cell (anchor)
        controller.handleKeyDown(keyCode: keys[0], shiftHeld: false)
        // Now in expanding mode — shift+right to widen left column
        controller.handleKeyDown(keyCode: arrowRight, shiftHeld: true)
        // Confirm selection to commit weights
        controller.handleKeyDown(keyCode: returnKey, shiftHeld: false)

        #expect(editedLayout != nil)
        #expect(editedLayout?.columnWeights != nil)
        // Left column should be wider than right
        if let weights = editedLayout?.columnWeights {
            #expect(weights[0] > weights[1])
        }
    }

    @Test("shift+0 resets weights")
    func shiftZeroResetsWeights() {
        let (controller, _, _) = makeController()
        var editedLayout: GridLayout?
        controller.onLayoutEdited = { layout in
            editedLayout = layout
        }
        controller.handleModifierTap()

        let keys = cellKeyCodes(columns: 2, rows: 2)
        // Select cell, enter expanding mode
        controller.handleKeyDown(keyCode: keys[0], shiftHeld: false)
        // Shift+right to add weights
        controller.handleKeyDown(keyCode: arrowRight, shiftHeld: true)
        // Shift+0 to reset
        controller.handleKeyDown(keyCode: zeroKey, shiftHeld: true)
        // Confirm
        controller.handleKeyDown(keyCode: returnKey, shiftHeld: false)

        #expect(editedLayout != nil)
        #expect(editedLayout?.columnWeights == nil)
        #expect(editedLayout?.rowWeights == nil)
    }

    // MARK: - Full-screen guard

    @Test("showHUD shows disabled message when window is full screen")
    func fullScreenGuard() {
        let sim = SimulatedDisplaySystem(screens: [screen], windows: [
            SimWindow(title: "Safari", appName: "Safari",
                      frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
                      isFocused: true, isFullScreen: true)
        ])
        let input = ScriptedInputSource()
        let controller = HUDController(config: .default, displaySystem: sim, inputSource: input, presenter: NullHUDPresenter())

        controller.handleModifierTap()
        // HUD shows but in disabled mode — it auto-dismisses after a delay.
        // The key point: it doesn't crash and isHUDVisible is set.
        #expect(controller.isHUDVisible == true)
    }

    // MARK: - Unrecognised keys pass through

    @Test("unrecognised key is not consumed")
    func unrecognisedKeyPassesThrough() {
        let (controller, _, _) = makeController()
        controller.handleModifierTap()

        // Key code 999 doesn't map to anything
        let consumed = controller.handleKeyDown(keyCode: 999, shiftHeld: false)
        #expect(consumed == false)
        #expect(controller.isHUDVisible == true) // HUD stays open
    }

    // MARK: - ScriptedInputSource integration

    @Test("ScriptedInputSource sendModifierTap toggles HUD via handler")
    func scriptedInputSourceIntegration() {
        let (controller, _, input) = makeController()
        // Start the input source with the controller as handler
        input.start(handler: controller)

        input.sendModifierTap()
        #expect(controller.isHUDVisible == true)

        input.sendModifierTap()
        #expect(controller.isHUDVisible == false)
    }

    @Test("ScriptedInputSource sendKeyDown returns consumed status")
    func scriptedInputSourceKeyDown() {
        let (controller, _, input) = makeController()
        input.start(handler: controller)

        input.sendModifierTap() // show HUD
        let consumed = input.sendKeyDown(keyCode: escapeKey)
        #expect(consumed == true)
        #expect(controller.isHUDVisible == false)
    }
}
