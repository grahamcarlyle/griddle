import Testing
import CoreGraphics
@testable import GriddleLib

final class RecordingHUDPresenter: HUDPresenter {
    var lastPreview: ResizePreview? = nil
    var previewUpdates: [ResizePreview?] = []

    func showOverlay(on screen: ScreenInfo, layout: GridLayout, keyLabels: [String], theme: HUDTheme) {}
    func showDisabledOverlay(on screen: ScreenInfo, message: String, theme: HUDTheme) {}
    func dismiss() {}
    func updateHighlight(_ region: HighlightRegion?) {}
    func updateResizePreview(_ preview: ResizePreview?) {
        lastPreview = preview
        previewUpdates.append(preview)
    }
    func updateLayout(_ layout: GridLayout) {}
    func showWeightStatus() {}
    func enterPrefixMode(reachableCells: [Int: String]) {}
    func exitPrefixMode() {}
    func showLayoutNameBanner(_ name: String) {}
}

@Suite("ResizePreview on Shift hold", .serialized)
struct ResizePreviewTests {
    let screen = ScreenInfo(
        id: "Test @ 0,0",
        localizedName: "Test",
        frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
        visibleFrame: CGRect(x: 0, y: 25, width: 1920, height: 1055)
    )

    let arrowUp: UInt16 = 126
    let arrowDown: UInt16 = 125
    let arrowLeft: UInt16 = 123
    let arrowRight: UInt16 = 124
    let returnKey: UInt16 = 36

    private func makeController(resizeMode: ResizeMode = .classic, layoutID: String = "3x3")
        -> (HUDController, RecordingHUDPresenter)
    {
        let sim = SimulatedDisplaySystem(screens: [screen], windows: [
            SimWindow(title: "Safari", appName: "Safari",
                      frame: CGRect(x: 100, y: 100, width: 600, height: 400), isFocused: true)
        ])
        let input = ScriptedInputSource()
        var config = GriddleConfig.default
        config.activeLayoutID = layoutID
        config.resizeMode = resizeMode
        let presenter = RecordingHUDPresenter()
        let controller = HUDController(config: config, displaySystem: sim, inputSource: input, presenter: presenter)
        return (controller, presenter)
    }

    /// Open HUD and reveal cursor at (col, row) on a 3×3.
    private func showHUDAndMoveTo(_ controller: HUDController, col: Int, row: Int) {
        controller.handleModifierTap()
        // First arrow reveals cursor at (0,0) without moving.
        controller.handleKeyDown(keyCode: arrowDown, shiftHeld: false)
        for _ in 0..<row { controller.handleKeyDown(keyCode: arrowDown, shiftHeld: false) }
        for _ in 0..<col { controller.handleKeyDown(keyCode: arrowRight, shiftHeld: false) }
    }

    @Test("shift held with cursor at (0,0) highlights bottom + right borders only")
    func cornerTopLeft() {
        let (controller, presenter) = makeController()
        showHUDAndMoveTo(controller, col: 0, row: 0)
        controller.handleShiftFlagsChanged(held: true)
        let preview = presenter.lastPreview
        #expect(preview != nil)
        #expect(preview?.topRowBorder == nil)
        #expect(preview?.bottomRowBorder == 0)
        #expect(preview?.leftColBorder == nil)
        #expect(preview?.rightColBorder == 0)
    }

    @Test("shift held with cursor at (2,2) highlights top + left borders only")
    func cornerBottomRight() {
        let (controller, presenter) = makeController()
        showHUDAndMoveTo(controller, col: 2, row: 2)
        controller.handleShiftFlagsChanged(held: true)
        let preview = presenter.lastPreview
        #expect(preview?.topRowBorder == 2)
        #expect(preview?.bottomRowBorder == nil)
        #expect(preview?.leftColBorder == 2)
        #expect(preview?.rightColBorder == nil)
    }

    @Test("shift held with cursor at (1,1) highlights all four borders")
    func centerCell() {
        let (controller, presenter) = makeController()
        showHUDAndMoveTo(controller, col: 1, row: 1)
        controller.handleShiftFlagsChanged(held: true)
        let preview = presenter.lastPreview
        #expect(preview?.topRowBorder == 1)
        #expect(preview?.bottomRowBorder == 1)
        #expect(preview?.leftColBorder == 1)
        #expect(preview?.rightColBorder == 1)
    }

    @Test("shift held with cursor at (2,0) highlights bottom row + left col")
    func cornerTopRight() {
        let (controller, presenter) = makeController()
        showHUDAndMoveTo(controller, col: 2, row: 0)
        controller.handleShiftFlagsChanged(held: true)
        let preview = presenter.lastPreview
        #expect(preview?.topRowBorder == nil)
        #expect(preview?.bottomRowBorder == 0)
        #expect(preview?.leftColBorder == 2)
        #expect(preview?.rightColBorder == nil)
    }

    @Test("shift held with selection (0,0)→(1,0) highlights bottom of row 0 and right of col 1")
    func expandedSelection() {
        let (controller, presenter) = makeController()
        controller.handleModifierTap()
        // Reveal cursor and confirm anchor at (0,0).
        controller.handleKeyDown(keyCode: arrowDown, shiftHeld: false)
        controller.handleKeyDown(keyCode: returnKey, shiftHeld: false)
        // Expand extent to (1,0).
        controller.handleKeyDown(keyCode: arrowRight, shiftHeld: false)
        controller.handleShiftFlagsChanged(held: true)
        let preview = presenter.lastPreview
        #expect(preview?.topRowBorder == nil)
        #expect(preview?.bottomRowBorder == 0)
        #expect(preview?.leftColBorder == nil)
        #expect(preview?.rightColBorder == 1)
    }

    @Test("shift held with full-grid selection emits nil preview")
    func fullGridSelection() {
        let (controller, presenter) = makeController()
        controller.handleModifierTap()
        controller.handleKeyDown(keyCode: arrowDown, shiftHeld: false)  // reveal at (0,0)
        controller.handleKeyDown(keyCode: returnKey, shiftHeld: false)  // anchor
        // Expand to (2,2)
        controller.handleKeyDown(keyCode: arrowRight, shiftHeld: false)
        controller.handleKeyDown(keyCode: arrowRight, shiftHeld: false)
        controller.handleKeyDown(keyCode: arrowDown, shiftHeld: false)
        controller.handleKeyDown(keyCode: arrowDown, shiftHeld: false)
        controller.handleShiftFlagsChanged(held: true)
        #expect(presenter.lastPreview == nil)
    }

    @Test("shift held with full-row top selection emits row-only preview")
    func fullRowTopSelection() {
        let (controller, presenter) = makeController()
        controller.handleModifierTap()
        controller.handleKeyDown(keyCode: arrowDown, shiftHeld: false)  // reveal at (0,0)
        controller.handleKeyDown(keyCode: returnKey, shiftHeld: false)  // anchor
        controller.handleKeyDown(keyCode: arrowRight, shiftHeld: false) // extent → (1,0)
        controller.handleKeyDown(keyCode: arrowRight, shiftHeld: false) // extent → (2,0)
        controller.handleShiftFlagsChanged(held: true)
        let preview = presenter.lastPreview
        #expect(preview?.topRowBorder == nil)
        #expect(preview?.bottomRowBorder == 0)
        #expect(preview?.leftColBorder == nil)
        #expect(preview?.rightColBorder == nil)
    }

    @Test("shift release clears preview")
    func shiftRelease() {
        let (controller, presenter) = makeController()
        showHUDAndMoveTo(controller, col: 1, row: 1)
        controller.handleShiftFlagsChanged(held: true)
        #expect(presenter.lastPreview != nil)
        controller.handleShiftFlagsChanged(held: false)
        #expect(presenter.lastPreview == nil)
    }

    @Test("cursor movement while shift held updates preview")
    func cursorMoveWhileShiftHeld() {
        let (controller, presenter) = makeController()
        controller.handleModifierTap()
        controller.handleKeyDown(keyCode: arrowDown, shiftHeld: false)  // reveal at (0,0)
        controller.handleShiftFlagsChanged(held: true)
        #expect(presenter.lastPreview?.bottomRowBorder == 0)
        // Move cursor to (0,1).
        controller.handleKeyDown(keyCode: arrowDown, shiftHeld: false)
        #expect(presenter.lastPreview?.topRowBorder == 1)
        #expect(presenter.lastPreview?.bottomRowBorder == 1)
    }

    @Test("shift held while HUD dismissed emits no preview")
    func shiftHeldWhileHidden() {
        let (controller, presenter) = makeController()
        controller.handleShiftFlagsChanged(held: true)
        #expect(presenter.lastPreview == nil)
    }

    @Test("directional mode: middle cell highlights only the after-side borders")
    func directionalMiddle() {
        let (controller, presenter) = makeController(resizeMode: .directional)
        showHUDAndMoveTo(controller, col: 1, row: 1)
        controller.handleShiftFlagsChanged(held: true)
        let preview = presenter.lastPreview
        #expect(preview?.topRowBorder == nil)
        #expect(preview?.bottomRowBorder == 1)
        #expect(preview?.leftColBorder == nil)
        #expect(preview?.rightColBorder == 1)
    }

    @Test("directional mode: bottom-right cell falls back to before-side borders")
    func directionalBottomRightFallback() {
        let (controller, presenter) = makeController(resizeMode: .directional)
        showHUDAndMoveTo(controller, col: 2, row: 2)
        controller.handleShiftFlagsChanged(held: true)
        let preview = presenter.lastPreview
        #expect(preview?.topRowBorder == 2)
        #expect(preview?.bottomRowBorder == nil)
        #expect(preview?.leftColBorder == 2)
        #expect(preview?.rightColBorder == nil)
    }

    @Test("directional mode: top-left cell highlights only after-side borders (no fallback)")
    func directionalTopLeft() {
        let (controller, presenter) = makeController(resizeMode: .directional)
        showHUDAndMoveTo(controller, col: 0, row: 0)
        controller.handleShiftFlagsChanged(held: true)
        let preview = presenter.lastPreview
        #expect(preview?.topRowBorder == nil)
        #expect(preview?.bottomRowBorder == 0)
        #expect(preview?.leftColBorder == nil)
        #expect(preview?.rightColBorder == 0)
    }
}
