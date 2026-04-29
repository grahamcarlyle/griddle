import Cocoa

/// Real input source that uses NSEvent modifier monitoring and CGEvent tap.
public class RealInputSource: InputSource {
    private var modifierKeys: [String]
    private var modifiersTapped = false
    private var flagsMonitor: Any?
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private weak var handler: InputHandler?

    public init(modifierKeys: [String]) {
        self.modifierKeys = modifierKeys
    }

    public func update(modifierKeys: [String]) {
        self.modifierKeys = modifierKeys
    }

    // MARK: - Modifier Watch

    public func startModifierWatch(handler: InputHandler) {
        self.handler = handler
        flagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
        }
    }

    private func handleFlagsChanged(_ event: NSEvent) {
        let requiredFlags = HotkeyManager.nsModifierFlags(from: modifierKeys)
        let currentFlags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let modifiersHeld = currentFlags.contains(requiredFlags)

        if modifiersHeld {
            modifiersTapped = true
        } else if modifiersTapped {
            modifiersTapped = false
            handler?.handleModifierTap()
        }
    }

    public func cancelModifierTap() {
        modifiersTapped = false
    }

    // MARK: - InputSource Protocol

    public func start(handler: InputHandler) {
        self.handler = handler
        installEventTap()
    }

    public func stop() {
        removeEventTap()
    }

    // MARK: - CGEvent Tap

    private func installEventTap() {
        let eventMask = (1 << CGEventType.keyDown.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: RealInputSource.eventTapCallback,
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
        let source = Unmanaged<RealInputSource>.fromOpaque(refcon).takeUnretainedValue()

        guard type == .keyDown else {
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let tap = source.eventTap {
                    CGEvent.tapEnable(tap: tap, enable: true)
                }
            }
            return Unmanaged.passRetained(event)
        }

        guard let handler = source.handler else { return Unmanaged.passRetained(event) }

        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let shiftHeld = CGEventFlags(rawValue: event.flags.rawValue & CGEventFlags.maskShift.rawValue).contains(.maskShift)

        let consumed = handler.handleKeyDown(keyCode: keyCode, shiftHeld: shiftHeld)
        return consumed ? nil : Unmanaged.passRetained(event)
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
