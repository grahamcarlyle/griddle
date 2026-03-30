import Cocoa
import Carbon

/// Maps keyboard shortcuts to grid cells and registers global hotkeys.
class HotkeyManager {
    private var config: GriddleConfig
    private var eventHandlerRef: EventHandlerRef?
    private var hotKeyRefs: [EventHotKeyRef?] = []
    private var hotKeyMap: [UInt32: GridCell] = [:]  // hotKeyID -> GridCell
    private var nextID: UInt32 = 1

    init(config: GriddleConfig) {
        self.config = config
    }

    func update(config: GriddleConfig) {
        self.config = config
        unregisterAll()
        register()
    }

    func register() {
        guard let layout = config.layouts.first(where: { $0.id == config.activeLayoutID }) else { return }

        // Install event handler once
        if eventHandlerRef == nil {
            var eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                         eventKind: OSType(kEventHotKeyPressed))
            InstallEventHandler(GetApplicationEventTarget(),
                                { (_, event, userData) -> OSStatus in
                                    guard let ud = userData else { return noErr }
                                    let mgr = Unmanaged<HotkeyManager>.fromOpaque(ud).takeUnretainedValue()
                                    return mgr.handleHotKey(event: event)
                                },
                                1, &eventSpec,
                                Unmanaged.passUnretained(self).toOpaque(),
                                &eventHandlerRef)
        }

        let modifiers = carbonModifiers(from: config.modifier.keys)

        // We use numpad/number keys to correspond to grid cells.
        // Layout assigns keys in row-major order from numpad 1 (bottom-left on numpad)
        // but we map left-to-right, top-to-bottom with keys 1..9 on the number row.
        // Key assignment: top-left = key 1, going right then down.
        let keyCodes = gridKeyCodes(for: layout)

        for (index, cell) in layout.cells.prefix(keyCodes.count).enumerated() {
            let keyCode = keyCodes[index]
            let id = nextID
            nextID += 1
            hotKeyMap[id] = cell
            var hotKeyID = EventHotKeyID(signature: fourCharCode("GRDL"), id: id)
            var hotKeyRef: EventHotKeyRef?
            RegisterEventHotKey(UInt32(keyCode), modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
            hotKeyRefs.append(hotKeyRef)
        }
    }

    func unregisterAll() {
        for ref in hotKeyRefs {
            if let ref = ref { UnregisterEventHotKey(ref) }
        }
        hotKeyRefs.removeAll()
        hotKeyMap.removeAll()
        nextID = 1
    }

    private func handleHotKey(event: EventRef?) -> OSStatus {
        guard let event = event else { return noErr }
        var hotKeyID = EventHotKeyID()
        GetEventParameter(event,
                          EventParamName(kEventParamDirectObject),
                          EventParamType(typeEventHotKeyID),
                          nil,
                          MemoryLayout<EventHotKeyID>.size,
                          nil,
                          &hotKeyID)
        guard let cell = hotKeyMap[hotKeyID.id] else { return noErr }
        guard let layout = config.layouts.first(where: { $0.id == config.activeLayoutID }) else { return noErr }
        WindowMover.moveFocusedWindow(to: cell, in: layout)
        return noErr
    }

    // MARK: - Helpers

    /// Returns key codes in row-major order (top-left to bottom-right) for the grid.
    /// Uses number row keys 1-9 (up to 9 cells).
    private func gridKeyCodes(for layout: GridLayout) -> [Int] {
        // macOS virtual key codes for keys 1-9 on number row
        let numberRowCodes = [18, 19, 20, 21, 23, 22, 26, 28, 25] // 1-9
        return Array(numberRowCodes.prefix(layout.cells.count))
    }

    private func carbonModifiers(from keys: [String]) -> UInt32 {
        var mods: UInt32 = 0
        for key in keys {
            switch key.lowercased() {
            case "ctrl":  mods |= UInt32(controlKey)
            case "alt":   mods |= UInt32(optionKey)
            case "cmd":   mods |= UInt32(cmdKey)
            case "shift": mods |= UInt32(shiftKey)
            default: break
            }
        }
        return mods
    }
}

private func fourCharCode(_ string: String) -> OSType {
    assert(string.count == 4)
    var result: OSType = 0
    for char in string.unicodeScalars {
        result = (result << 8) + OSType(char.value)
    }
    return result
}
