import Cocoa

/// Manages the HUD grid overlay: tap-toggle activation, two-step cell selection.
public class HUDController {
    private var config: GriddleConfig
    private var panel: NSPanel?
    private var overlayView: HUDOverlayView?
    private var isVisible = false
    private var modifiersTapped = false
    private var singleCellTimerWork: DispatchWorkItem?
    private var flagsMonitor: Any?
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var activeLayout: GridLayout?
    private var activeKeyCodes: [UInt16] = []
    private var firstSelectedIndex: Int?

    private static let singleCellTimeout: TimeInterval = 1.0
    private static let escapeKeyCode: UInt16 = 53

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
            // Modifiers just pressed — mark as tapped (may be cancelled by fast hotkey)
            modifiersTapped = true
        } else if modifiersTapped {
            // Modifiers released and tap wasn't cancelled — toggle HUD
            modifiersTapped = false
            if isVisible {
                dismissHUD()
            } else {
                showHUD()
            }
        }
    }

    /// Called by HotkeyManager when a fast modifier+key combo fires.
    /// Cancels the pending tap so the HUD doesn't toggle on modifier release.
    public func cancelShowHUD() {
        modifiersTapped = false
    }

    // MARK: - Show/Dismiss HUD

    private func showHUD() {
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
        panel.contentView = overlayView

        panel.orderFrontRegardless()

        self.panel = panel
        self.overlayView = overlayView
        self.isVisible = true
        self.firstSelectedIndex = nil
        self.activeKeyCodes = keyCodes

        installEventTap(layout: layout)
    }

    private func dismissHUD() {
        singleCellTimerWork?.cancel()
        singleCellTimerWork = nil
        firstSelectedIndex = nil
        removeEventTap()
        panel?.orderOut(nil)
        panel = nil
        overlayView = nil
        activeKeyCodes = []
        isVisible = false
    }

    // MARK: - Cell Selection

    private func handleCellSelected(index: Int) {
        guard let layout = activeLayout, index < layout.cells.count else { return }

        if let firstIndex = firstSelectedIndex {
            // Second key press — compute bounding box and move
            singleCellTimerWork?.cancel()
            singleCellTimerWork = nil
            let cell1 = layout.cells[firstIndex]
            let cell2 = layout.cells[index]
            let targetCell = WindowMover.boundingCell(from: cell1, to: cell2)
            WindowMover.moveFocusedWindow(to: targetCell, in: layout)
            dismissHUD()
        } else {
            // First key press — highlight and wait for second
            firstSelectedIndex = index
            overlayView?.highlightedIndex = index

            // Start single-cell timer — if no second key within timeout, move to just this cell
            let work = DispatchWorkItem { [weak self] in
                guard let self = self, let layout = self.activeLayout, index < layout.cells.count else { return }
                let cell = layout.cells[index]
                WindowMover.moveFocusedWindow(to: cell, in: layout)
                self.dismissHUD()
            }
            singleCellTimerWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.singleCellTimeout, execute: work)
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
