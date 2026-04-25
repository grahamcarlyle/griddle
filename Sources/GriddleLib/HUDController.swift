import Foundation

/// Manages the HUD grid overlay: tap-toggle activation, two-stage cell selection.
public class HUDController: InputHandler {
    private var config: GriddleConfig
    private let displaySystem: DisplaySystem
    private let inputSource: InputSource
    private let presenter: HUDPresenter
    public private(set) var isHUDVisible = false
    private var activeLayout: GridLayout?
    private var activeKeyMap: KeyMap?
    private var activeScreen: ScreenInfo?

    // Prefix key state
    private struct PrefixState {
        let prefixKeyCode: UInt16
        let children: [KeyChild]
    }
    private var prefixState: PrefixState?

    // Selection state
    private enum SelectionStage { case choosingAnchor, expanding }
    private var selectionStage: SelectionStage = .choosingAnchor
    private var cursorRevealed: Bool = false
    private var cursorCol: Int = 0
    private var cursorRow: Int = 0
    private var anchorCol: Int = 0
    private var anchorRow: Int = 0
    private var extentCol: Int = 0
    private var extentRow: Int = 0

    // Weight editing state
    private var editedLayout: GridLayout?
    private var weightsDirty: Bool = false
    public var onLayoutEdited: ((GridLayout) -> Void)?

    private static let escapeKeyCode: UInt16 = 53
    private static let returnKeyCode: UInt16 = 36
    private static let arrowUp: UInt16 = 126
    private static let arrowDown: UInt16 = 125
    private static let arrowLeft: UInt16 = 123
    private static let arrowRight: UInt16 = 124
    private static let zeroKeyCode: UInt16 = 29

    public init(config: GriddleConfig, displaySystem: DisplaySystem, inputSource: InputSource, presenter: HUDPresenter = PanelHUDPresenter()) {
        self.config = config
        self.displaySystem = displaySystem
        self.inputSource = inputSource
        self.presenter = presenter
    }

    public func update(config: GriddleConfig) {
        self.config = config
        if isHUDVisible {
            dismissHUD()
        }
    }

    // MARK: - InputHandler

    public func handleModifierTap() {
        if isHUDVisible {
            dismissHUD()
        } else {
            showHUD()
        }
    }

    @discardableResult
    public func handleKeyDown(keyCode: UInt16, shiftHeld: Bool) -> Bool {
        guard isHUDVisible else { return false }

        if keyCode == Self.escapeKeyCode {
            dismissHUD()
            return true
        }

        if keyCode == Self.returnKeyCode {
            handleReturn()
            return true
        }

        if keyCode == Self.arrowUp || keyCode == Self.arrowDown || keyCode == Self.arrowLeft || keyCode == Self.arrowRight {
            if shiftHeld {
                handleShiftArrowKey(keyCode: keyCode)
            } else {
                handleArrowKey(keyCode: keyCode)
            }
            return true
        }

        // Shift+0 resets weights
        if keyCode == Self.zeroKeyCode && shiftHeld {
            handleResetWeights()
            return true
        }

        // Prefix state: check if this key resolves a pending prefix
        if let prefix = prefixState {
            prefixState = nil
            if let child = prefix.children.first(where: { $0.keyCode == keyCode }) {
                exitPrefixMode()
                handleCellSelected(index: child.cellIndex)
                return true
            }
            // Not a valid child — clear prefix mode and fall through to handle as new top-level key
            exitPrefixMode()
        }

        // Top-level key lookup via KeyMap
        if let keyMap = activeKeyMap, let binding = keyMap.bindings[keyCode] {
            switch binding {
            case .direct(let cellIndex):
                handleCellSelected(index: cellIndex)
                return true
            case .prefix(let children):
                prefixState = PrefixState(prefixKeyCode: keyCode, children: children)
                enterPrefixMode(children: children)
                return true
            }
        }

        return false
    }

    // MARK: - Show/Dismiss HUD

    public func showHUD() {
        guard !isHUDVisible else { return }

        // In native full-screen, tiling can't work — show a brief message instead
        if displaySystem.isFocusedWindowFullScreen() {
            showDisabledHUD(message: "Exit full screen to tile")
            return
        }

        guard let screen = displaySystem.screenForFocusedWindow() ?? displaySystem.mainScreen else { return }
        guard let layout = config.layoutForScreen(key: screen.id) else { return }

        let keyMap = KeyMap.build(for: config.keyStyle, columns: layout.columns, rows: layout.rows)

        presenter.showOverlay(on: screen, layout: layout, keyLabels: keyMap.labels, theme: config.hudTheme)

        self.isHUDVisible = true
        self.activeKeyMap = keyMap
        self.activeScreen = screen
        self.selectionStage = .choosingAnchor
        self.cursorRevealed = false
        self.cursorCol = 0
        self.cursorRow = 0
        self.activeLayout = layout
        self.editedLayout = layout
        self.weightsDirty = false

        inputSource.start(handler: self)
    }

    private func showDisabledHUD(message: String) {
        guard let screen = displaySystem.mainScreen else { return }

        presenter.showDisabledOverlay(on: screen, message: message, theme: config.hudTheme)
        self.isHUDVisible = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.dismissHUD()
        }
    }

    private func dismissHUD() {
        prefixState = nil
        selectionStage = .choosingAnchor
        editedLayout = nil
        weightsDirty = false
        activeScreen = nil
        inputSource.stop()
        presenter.dismiss()
        activeKeyMap = nil
        isHUDVisible = false
    }

    // MARK: - Selection Logic

    private func handleCellSelected(index: Int) {
        guard let layout = activeLayout, index < layout.cells.count else { return }
        let cell = layout.cells[index]

        switch selectionStage {
        case .choosingAnchor:
            anchorCol = cell.col
            anchorRow = cell.row
            extentCol = cell.col
            extentRow = cell.row
            selectionStage = .expanding
            updateHighlight()

        case .expanding:
            let anchor = GridCell(col: anchorCol, row: anchorRow, colSpan: 1, rowSpan: 1)
            let target = WindowMover.boundingCell(from: anchor, to: cell)
            let resolvedLayout = editedLayout ?? layout
            commitWeightsIfNeeded()
            if let screen = activeScreen {
                let frame = WindowMover.frame(for: target, in: resolvedLayout, on: screen)
                displaySystem.moveFocusedWindow(to: frame)
            }
            dismissHUD()
        }
    }

    private func handleArrowKey(keyCode: UInt16) {
        guard let layout = activeLayout else { return }
        let maxCol = layout.columns - 1
        let maxRow = layout.rows - 1

        switch selectionStage {
        case .choosingAnchor:
            if !cursorRevealed {
                // First arrow press: just reveal cursor at (0,0) without moving
                cursorRevealed = true
            } else {
                switch keyCode {
                case Self.arrowUp:    cursorRow = max(0, cursorRow - 1)
                case Self.arrowDown:  cursorRow = min(maxRow, cursorRow + 1)
                case Self.arrowLeft:  cursorCol = max(0, cursorCol - 1)
                case Self.arrowRight: cursorCol = min(maxCol, cursorCol + 1)
                default: break
                }
            }
            updateHighlight()

        case .expanding:
            switch keyCode {
            case Self.arrowUp:    extentRow = max(0, extentRow - 1)
            case Self.arrowDown:  extentRow = min(maxRow, extentRow + 1)
            case Self.arrowLeft:  extentCol = max(0, extentCol - 1)
            case Self.arrowRight: extentCol = min(maxCol, extentCol + 1)
            default: break
            }
            updateHighlight()
        }
    }

    private func handleShiftArrowKey(keyCode: UInt16) {
        guard selectionStage == .expanding, var layout = editedLayout else { return }

        let minCol = min(anchorCol, extentCol)
        let maxCol = max(anchorCol, extentCol)
        let minRow = min(anchorRow, extentRow)
        let maxRow = max(anchorRow, extentRow)

        let step = 0.1

        switch keyCode {
        case Self.arrowRight, Self.arrowLeft:
            if layout.columnWeights == nil {
                layout.columnWeights = Array(repeating: 1.0, count: layout.columns)
            }
            let selectedCount = maxCol - minCol + 1
            let nonSelectedCount = layout.columns - selectedCount
            // Equalize selected columns: same weight, preserving their combined total
            let selectedTotal = (minCol...maxCol).reduce(0.0) { $0 + layout.columnWeights![$1] }
            let uniform = selectedTotal / Double(selectedCount)
            for c in minCol...maxCol {
                layout.columnWeights![c] = uniform
            }
            let delta = keyCode == Self.arrowRight ? step : -step
            for c in minCol...maxCol {
                layout.columnWeights![c] = max(0.1, layout.columnWeights![c] + delta)
            }
            if nonSelectedCount > 0 {
                let compensation = delta * Double(selectedCount) / Double(nonSelectedCount)
                for c in 0..<layout.columns where c < minCol || c > maxCol {
                    layout.columnWeights![c] = max(0.1, layout.columnWeights![c] - compensation)
                }
            }
        case Self.arrowUp, Self.arrowDown:
            if layout.rowWeights == nil {
                layout.rowWeights = Array(repeating: 1.0, count: layout.rows)
            }
            let selectedCount = maxRow - minRow + 1
            let nonSelectedCount = layout.rows - selectedCount
            // Equalize selected rows: same weight, preserving their combined total
            let selectedTotal = (minRow...maxRow).reduce(0.0) { $0 + layout.rowWeights![$1] }
            let uniform = selectedTotal / Double(selectedCount)
            for r in minRow...maxRow {
                layout.rowWeights![r] = uniform
            }
            // Shift+Up grows (more height), Shift+Down shrinks
            let delta = keyCode == Self.arrowUp ? step : -step
            for r in minRow...maxRow {
                layout.rowWeights![r] = max(0.1, layout.rowWeights![r] + delta)
            }
            if nonSelectedCount > 0 {
                let compensation = delta * Double(selectedCount) / Double(nonSelectedCount)
                for r in 0..<layout.rows where r < minRow || r > maxRow {
                    layout.rowWeights![r] = max(0.1, layout.rowWeights![r] - compensation)
                }
            }
        default:
            break
        }

        editedLayout = layout
        weightsDirty = true
        presenter.updateLayout(layout)
        presenter.showWeightStatus()
    }

    private func handleResetWeights() {
        guard selectionStage == .expanding, var layout = editedLayout else { return }
        layout.columnWeights = nil
        layout.rowWeights = nil
        editedLayout = layout
        weightsDirty = true
        presenter.updateLayout(layout)
        presenter.showWeightStatus()
    }

    private func commitWeightsIfNeeded() {
        guard weightsDirty, let layout = editedLayout else { return }
        onLayoutEdited?(layout)
    }

    private func handleReturn() {
        switch selectionStage {
        case .choosingAnchor:
            // Confirm anchor, move to expanding
            anchorCol = cursorCol
            anchorRow = cursorRow
            extentCol = cursorCol
            extentRow = cursorRow
            selectionStage = .expanding
            updateHighlight()

        case .expanding:
            confirmSelection()
        }
    }

    private func confirmSelection() {
        guard let layout = activeLayout else { return }

        let anchor = GridCell(col: anchorCol, row: anchorRow, colSpan: 1, rowSpan: 1)
        let extent = GridCell(col: extentCol, row: extentRow, colSpan: 1, rowSpan: 1)
        let target = WindowMover.boundingCell(from: anchor, to: extent)
        let resolvedLayout = editedLayout ?? layout
        commitWeightsIfNeeded()
        if let screen = activeScreen {
            let frame = WindowMover.frame(for: target, in: resolvedLayout, on: screen)
            displaySystem.moveFocusedWindow(to: frame)
        }
        dismissHUD()
    }

    private func updateHighlight() {
        switch selectionStage {
        case .choosingAnchor:
            presenter.updateHighlight(HighlightRegion(
                minCol: cursorCol, minRow: cursorRow,
                maxCol: cursorCol, maxRow: cursorRow
            ))
        case .expanding:
            presenter.updateHighlight(HighlightRegion(
                minCol: min(anchorCol, extentCol), minRow: min(anchorRow, extentRow),
                maxCol: max(anchorCol, extentCol), maxRow: max(anchorRow, extentRow)
            ))
        }
    }

    // MARK: - Prefix Mode

    private func enterPrefixMode(children: [KeyChild]) {
        var reachable: [Int: String] = [:]
        for child in children {
            reachable[child.cellIndex] = child.label
        }
        presenter.enterPrefixMode(reachableCells: reachable)
    }

    private func exitPrefixMode() {
        presenter.exitPrefixMode()
    }

    /// Shows the HUD directly in prefix mode (called from HotkeyManager when a prefix key fires on the fast path).
    public func showHUDInPrefixMode(children: [KeyChild]) {
        showHUD()
        guard isHUDVisible else { return }
        prefixState = PrefixState(prefixKeyCode: 0, children: children)
        enterPrefixMode(children: children)
    }

}
