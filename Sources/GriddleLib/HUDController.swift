import Cocoa

/// Manages the HUD grid overlay: tap-toggle activation, two-stage cell selection.
public class HUDController {
    private var config: GriddleConfig
    private var panel: NSPanel?
    private var overlayView: HUDOverlayView?
    private var isVisible = false
    private var modifiersTapped = false
    private var inactivityTimer: DispatchWorkItem?
    private var flagsMonitor: Any?
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var activeLayout: GridLayout?
    private var activeKeyCodes: [UInt16] = []

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

    private static let inactivityTimeout: TimeInterval = 1.0
    private static let escapeKeyCode: UInt16 = 53
    private static let returnKeyCode: UInt16 = 36
    private static let arrowUp: UInt16 = 126
    private static let arrowDown: UInt16 = 125
    private static let arrowLeft: UInt16 = 123
    private static let arrowRight: UInt16 = 124

    public init(config: GriddleConfig) {
        self.config = config
    }

    public func update(config: GriddleConfig) {
        self.config = config
        if isVisible {
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
            if isVisible {
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
        guard !isVisible else { return }
        guard let screen = WindowMover.screenForFocusedWindow() ?? NSScreen.main else { return }
        let screenKey = GriddleConfig.screenKey(for: screen)
        guard let layout = config.layoutForScreen(key: screenKey) else { return }

        let screenFrame = screen.visibleFrame
        let keyCodes = HotkeyManager.keyCodes(for: config.keyStyle, columns: layout.columns, rows: layout.rows)
        let keyLabels = HotkeyManager.keyLabels(for: config.keyStyle, columns: layout.columns, rows: layout.rows)

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
        self.isVisible = true
        self.activeKeyCodes = keyCodes
        self.selectionStage = .choosingAnchor
        self.cursorRevealed = false
        self.cursorCol = 0
        self.cursorRow = 0

        installEventTap(layout: layout)
    }

    private func dismissHUD() {
        inactivityTimer?.cancel()
        inactivityTimer = nil
        selectionStage = .choosingAnchor
        removeEventTap()
        panel?.orderOut(nil)
        panel = nil
        overlayView = nil
        activeKeyCodes = []
        isVisible = false
    }

    // MARK: - Inactivity Timer

    private func resetInactivityTimer() {
        inactivityTimer?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.confirmSelection()
        }
        inactivityTimer = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.inactivityTimeout, execute: work)
    }

    // MARK: - Selection Logic

    private func handleCellSelected(index: Int) {
        guard let layout = activeLayout, index < layout.cells.count else { return }
        let cell = layout.cells[index]

        switch selectionStage {
        case .choosingAnchor:
            // Letter/number key selects anchor and moves to expanding stage
            anchorCol = cell.col
            anchorRow = cell.row
            extentCol = cell.col
            extentRow = cell.row
            selectionStage = .expanding
            updateHighlight()
            resetInactivityTimer()

        case .expanding:
            // Second letter/number key — compute bounding box and move immediately
            inactivityTimer?.cancel()
            inactivityTimer = nil
            let anchor = GridCell(col: anchorCol, row: anchorRow, colSpan: 1, rowSpan: 1)
            let target = WindowMover.boundingCell(from: anchor, to: cell)
            WindowMover.moveFocusedWindow(to: target, in: layout)
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
            resetInactivityTimer()

        case .expanding:
            switch keyCode {
            case Self.arrowUp:    extentRow = max(0, extentRow - 1)
            case Self.arrowDown:  extentRow = min(maxRow, extentRow + 1)
            case Self.arrowLeft:  extentCol = max(0, extentCol - 1)
            case Self.arrowRight: extentCol = min(maxCol, extentCol + 1)
            default: break
            }
            updateHighlight()
            resetInactivityTimer()
        }
    }

    private func handleReturn() {
        switch selectionStage {
        case .choosingAnchor:
            // Confirm anchor, move to expanding
            inactivityTimer?.cancel()
            inactivityTimer = nil
            anchorCol = cursorCol
            anchorRow = cursorRow
            extentCol = cursorCol
            extentRow = cursorRow
            selectionStage = .expanding
            updateHighlight()
            resetInactivityTimer()

        case .expanding:
            inactivityTimer?.cancel()
            inactivityTimer = nil
            confirmSelection()
        }
    }

    private func confirmSelection() {
        guard let layout = activeLayout else { return }

        switch selectionStage {
        case .choosingAnchor:
            // Timeout during anchor selection — move to cursor cell
            let cell = GridCell(col: cursorCol, row: cursorRow, colSpan: 1, rowSpan: 1)
            WindowMover.moveFocusedWindow(to: cell, in: layout)

        case .expanding:
            // Confirm the current bounding box
            let anchor = GridCell(col: anchorCol, row: anchorRow, colSpan: 1, rowSpan: 1)
            let extent = GridCell(col: extentCol, row: extentRow, colSpan: 1, rowSpan: 1)
            let target = WindowMover.boundingCell(from: anchor, to: extent)
            WindowMover.moveFocusedWindow(to: target, in: layout)
        }
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
            DispatchQueue.main.async { controller.handleArrowKey(keyCode: keyCode) }
            return nil
        }

        let keyCodes = controller.activeKeyCodes
        if let cellIndex = keyCodes.firstIndex(of: keyCode) {
            let index = keyCodes.distance(from: keyCodes.startIndex, to: cellIndex)
            DispatchQueue.main.async {
                controller.handleCellSelected(index: index)
            }
            return nil
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
