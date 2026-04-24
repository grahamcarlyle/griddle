import Cocoa

/// Manages the HUD grid overlay: tap-toggle activation, two-stage cell selection.
public class HUDController {
    private var config: GriddleConfig
    private var panel: NSPanel?
    private var overlayView: HUDOverlayView?
    public private(set) var isHUDVisible = false
    private var modifiersTapped = false
    private var flagsMonitor: Any?
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var activeLayout: GridLayout?
    private var activeKeyMap: KeyMap?

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

    public init(config: GriddleConfig) {
        self.config = config
    }

    public func update(config: GriddleConfig) {
        self.config = config
        if isHUDVisible {
            dismissHUD()
        }
    }

    // MARK: - Modifier Watch (tap-toggle)

    public func startModifierWatch() {
        flagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
        }
    }

    private func handleFlagsChanged(_ event: NSEvent) {
        let requiredFlags = HotkeyManager.nsModifierFlags(from: config.modifier.keys)
        let currentFlags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let modifiersHeld = currentFlags.contains(requiredFlags)

        if modifiersHeld {
            modifiersTapped = true
        } else if modifiersTapped {
            modifiersTapped = false
            if isHUDVisible {
                dismissHUD()
            } else {
                showHUD()
            }
        }
    }

    public func cancelShowHUD() {
        modifiersTapped = false
    }

    // MARK: - Show/Dismiss HUD

    public func showHUD() {
        guard !isHUDVisible else { return }

        // In native full-screen, tiling can't work — show a brief message instead
        if WindowMover.isFocusedWindowFullScreen() {
            showDisabledHUD(message: "Exit full screen to tile")
            return
        }

        guard let screen = WindowMover.screenForFocusedWindow() ?? NSScreen.main else { return }
        let screenKey = GriddleConfig.screenKey(for: screen)
        guard let layout = config.layoutForScreen(key: screenKey) else { return }

        let screenFrame = screen.visibleFrame
        let keyMap = KeyMap.build(for: config.keyStyle, columns: layout.columns, rows: layout.rows)
        let keyLabels = keyMap.labels

        let panel = NSPanel(
            contentRect: screenFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let overlayView = HUDOverlayView(frame: NSRect(origin: .zero, size: screenFrame.size))
        overlayView.layout = layout
        overlayView.keyLabels = keyLabels
        overlayView.theme = config.hudTheme
        panel.contentView = overlayView

        panel.orderFrontRegardless()

        self.panel = panel
        self.overlayView = overlayView
        self.isHUDVisible = true
        self.activeKeyMap = keyMap
        self.selectionStage = .choosingAnchor
        self.cursorRevealed = false
        self.cursorCol = 0
        self.cursorRow = 0
        self.editedLayout = layout
        self.weightsDirty = false

        installEventTap(layout: layout)
    }

    private func showDisabledHUD(message: String) {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.frame

        let panel = NSPanel(
            contentRect: screenFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let overlayView = HUDOverlayView(frame: NSRect(origin: .zero, size: screenFrame.size))
        overlayView.theme = config.hudTheme
        overlayView.disabledMessage = message
        panel.contentView = overlayView

        panel.orderFrontRegardless()

        self.panel = panel
        self.overlayView = overlayView
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
        removeEventTap()
        panel?.orderOut(nil)
        panel = nil
        overlayView = nil
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
            WindowMover.moveFocusedWindow(to: target, in: resolvedLayout)
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
        overlayView?.layout = layout
        overlayView?.showWeightStatus = true
        overlayView?.needsDisplay = true
    }

    private func handleResetWeights() {
        guard selectionStage == .expanding, var layout = editedLayout else { return }
        layout.columnWeights = nil
        layout.rowWeights = nil
        editedLayout = layout
        weightsDirty = true
        overlayView?.layout = layout
        overlayView?.showWeightStatus = true
        overlayView?.needsDisplay = true
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
        WindowMover.moveFocusedWindow(to: target, in: resolvedLayout)
        dismissHUD()
    }

    private func updateHighlight() {
        switch selectionStage {
        case .choosingAnchor:
            overlayView?.highlightedRegion = HighlightRegion(
                minCol: cursorCol, minRow: cursorRow,
                maxCol: cursorCol, maxRow: cursorRow
            )
        case .expanding:
            overlayView?.highlightedRegion = HighlightRegion(
                minCol: min(anchorCol, extentCol), minRow: min(anchorRow, extentRow),
                maxCol: max(anchorCol, extentCol), maxRow: max(anchorRow, extentRow)
            )
        }
    }

    // MARK: - Prefix Mode

    private func enterPrefixMode(children: [KeyChild]) {
        var reachable: [Int: String] = [:]
        for child in children {
            reachable[child.cellIndex] = child.label
        }
        overlayView?.prefixReachableCells = reachable
    }

    private func exitPrefixMode() {
        overlayView?.prefixReachableCells = nil
    }

    /// Shows the HUD directly in prefix mode (called from HotkeyManager when a prefix key fires on the fast path).
    public func showHUDInPrefixMode(children: [KeyChild]) {
        showHUD()
        guard isHUDVisible else { return }
        prefixState = PrefixState(prefixKeyCode: 0, children: children)
        enterPrefixMode(children: children)
    }

    // MARK: - CGEvent Tap (key suppression)

    private func installEventTap(layout: GridLayout) {
        self.activeLayout = layout

        let eventMask = (1 << CGEventType.keyDown.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: HUDController.eventTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return }

        self.eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private static let eventTapCallback: CGEventTapCallBack = { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
        guard let refcon = refcon else { return Unmanaged.passRetained(event) }
        let controller = Unmanaged<HUDController>.fromOpaque(refcon).takeUnretainedValue()

        guard type == .keyDown else {
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let tap = controller.eventTap {
                    CGEvent.tapEnable(tap: tap, enable: true)
                }
            }
            return Unmanaged.passRetained(event)
        }

        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))

        if keyCode == escapeKeyCode {
            DispatchQueue.main.async { controller.dismissHUD() }
            return nil
        }

        if keyCode == returnKeyCode {
            DispatchQueue.main.async { controller.handleReturn() }
            return nil
        }

        if keyCode == arrowUp || keyCode == arrowDown || keyCode == arrowLeft || keyCode == arrowRight {
            let flags = CGEventFlags(rawValue: event.flags.rawValue & CGEventFlags.maskShift.rawValue)
            if flags.contains(.maskShift) {
                DispatchQueue.main.async { controller.handleShiftArrowKey(keyCode: keyCode) }
            } else {
                DispatchQueue.main.async { controller.handleArrowKey(keyCode: keyCode) }
            }
            return nil
        }

        // Shift+0 resets weights
        if keyCode == zeroKeyCode {
            let flags = CGEventFlags(rawValue: event.flags.rawValue & CGEventFlags.maskShift.rawValue)
            if flags.contains(.maskShift) {
                DispatchQueue.main.async { controller.handleResetWeights() }
                return nil
            }
        }

        // Prefix state: check if this key resolves a pending prefix
        if let prefix = controller.prefixState {
            controller.prefixState = nil
            if let child = prefix.children.first(where: { $0.keyCode == keyCode }) {
                DispatchQueue.main.async {
                    controller.exitPrefixMode()
                    controller.handleCellSelected(index: child.cellIndex)
                }
                return nil
            }
            // Not a valid child — clear prefix mode and fall through to handle as new top-level key
            DispatchQueue.main.async { controller.exitPrefixMode() }
        }

        // Top-level key lookup via KeyMap
        if let keyMap = controller.activeKeyMap, let binding = keyMap.bindings[keyCode] {
            switch binding {
            case .direct(let cellIndex):
                DispatchQueue.main.async {
                    controller.handleCellSelected(index: cellIndex)
                }
                return nil
            case .prefix(let children):
                controller.prefixState = PrefixState(prefixKeyCode: keyCode, children: children)
                DispatchQueue.main.async { controller.enterPrefixMode(children: children) }
                return nil
            }
        }

        return Unmanaged.passRetained(event)
    }

    private func removeEventTap() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        eventTap = nil
        runLoopSource = nil
    }
}
