import Cocoa
import Carbon


/// Maps keyboard shortcuts to grid cells and registers global hotkeys.
public class HotkeyManager {
    private var config: GriddleConfig
    private var eventHandlerRef: EventHandlerRef?
    private var hotKeyRefs: [EventHotKeyRef?] = []
    private var hotKeyIDToKeyCode: [UInt32: UInt16] = [:]  // hotKeyID -> keyCode
    private var keyMap: KeyMap?
    private var nextID: UInt32 = 1
    private var cycleHotKeyRef: EventHotKeyRef?
    private var cycleHotKeyID: UInt32 = 0
    public weak var hudController: HUDController?
    public var onLayoutCycle: (() -> Void)?

    // Prefix key state
    private struct PrefixState {
        let children: [KeyChild]
    }
    private var prefixState: PrefixState?


    public init(config: GriddleConfig) {
        self.config = config
    }

    public func update(config: GriddleConfig) {
        self.config = config
        unregisterAll()
        register()
    }

    public func register() {
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

        // Build KeyMap for the max grid size across all screen layouts.
        let maxDims = config.maxGridDimensions()
        let map = KeyMap.build(for: config.keyStyle, columns: maxDims.columns, rows: maxDims.rows)
        self.keyMap = map

        // Register hotkeys for all top-level key codes (both direct and prefix keys).
        for keyCode in map.topLevelKeyCodes {
            let id = nextID
            nextID += 1
            hotKeyIDToKeyCode[id] = keyCode
            let hotKeyID = EventHotKeyID(signature: fourCharCode("GRDL"), id: id)
            var hotKeyRef: EventHotKeyRef?
            RegisterEventHotKey(UInt32(keyCode), modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
            hotKeyRefs.append(hotKeyRef)
        }

        // Register modifier+cycleKey to cycle through layouts
        let cycleID = nextID
        nextID += 1
        cycleHotKeyID = cycleID
        let cycleHKID = EventHotKeyID(signature: fourCharCode("GRDL"), id: cycleID)
        RegisterEventHotKey(config.cycleKey.keyCode, modifiers, cycleHKID, GetApplicationEventTarget(), 0, &cycleHotKeyRef)
    }

    func unregisterAll() {
        for ref in hotKeyRefs {
            if let ref = ref { UnregisterEventHotKey(ref) }
        }
        hotKeyRefs.removeAll()
        hotKeyIDToKeyCode.removeAll()
        keyMap = nil
        prefixState = nil
        if let ref = cycleHotKeyRef { UnregisterEventHotKey(ref) }
        cycleHotKeyRef = nil
        cycleHotKeyID = 0
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
        if hotKeyID.id == cycleHotKeyID {
            onLayoutCycle?()
            return noErr
        }

        guard let keyCode = hotKeyIDToKeyCode[hotKeyID.id],
              let map = keyMap else { return noErr }

        // Check if we're resolving a pending prefix
        if let prefix = prefixState {
            prefixState = nil

            if let child = prefix.children.first(where: { $0.keyCode == keyCode }) {
                return moveWindowToCell(index: child.cellIndex)
            }
            // Not a valid child — fall through to handle as new top-level key
        }

        // Top-level key lookup
        guard let binding = map.bindings[keyCode] else { return noErr }

        switch binding {
        case .direct(let cellIndex):
            return moveWindowToCell(index: cellIndex)

        case .prefix(let children):
            // Enter prefix state and auto-show HUD for visual feedback
            prefixState = PrefixState(children: children)
            hudController?.cancelShowHUD()
            hudController?.showHUDInPrefixMode(children: children)
            return noErr
        }
    }

    private func moveWindowToCell(index cellIndex: Int) -> OSStatus {
        // Resolve layout for the focused window's screen
        let screenKey = WindowMover.screenForFocusedWindow().map { GriddleConfig.screenKey(for: $0) }
        guard let layout = config.layoutForScreen(key: screenKey ?? "") else { return noErr }

        // Ignore if this cell index doesn't exist in the screen's layout
        guard cellIndex < layout.cells.count else { return noErr }
        let cell = layout.cells[cellIndex]

        hudController?.cancelShowHUD()
        WindowMover.moveFocusedWindow(to: cell, in: layout)
        return noErr
    }

    // MARK: - Key Code Mapping

    // Spatial key codes: rows of letter keys matching screen grid position
    // Q=12  W=13  E=14  R=15  T=17  Y=16
    // A=0   S=1   D=2   F=3   G=5   H=4
    // Z=6   X=7   C=8   V=9   B=11  N=45
    private static let spatialRows: [[UInt16]] = [
        [12, 13, 14, 15, 17, 16],  // Q W E R T Y
        [0,  1,  2,  3,  5,  4],   // A S D F G H
        [6,  7,  8,  9,  11, 45],  // Z X C V B N
    ]

    private static let spatialLabelsRows: [[String]] = [
        ["Q", "W", "E", "R", "T", "Y"],
        ["A", "S", "D", "F", "G", "H"],
        ["Z", "X", "C", "V", "B", "N"],
    ]

    private static let numberRowCodes: [UInt16] = [18, 19, 20, 21, 23, 22, 26, 28, 25]

    /// Returns key codes for the given style and grid dimensions, in row-major order.
    public static func keyCodes(for style: KeyStyle, columns: Int, rows: Int) -> [UInt16] {
        switch style {
        case .spatial:
            var codes: [UInt16] = []
            for row in 0..<min(rows, spatialRows.count) {
                for col in 0..<min(columns, spatialRows[row].count) {
                    codes.append(spatialRows[row][col])
                }
            }
            return codes
        case .numbers:
            let count = min(columns * rows, numberRowCodes.count)
            return Array(numberRowCodes.prefix(count))
        }
    }

    /// Returns display labels for the given style and grid dimensions, in row-major order.
    public static func keyLabels(for style: KeyStyle, columns: Int, rows: Int) -> [String] {
        switch style {
        case .spatial:
            var labels: [String] = []
            for row in 0..<min(rows, spatialLabelsRows.count) {
                for col in 0..<min(columns, spatialLabelsRows[row].count) {
                    labels.append(spatialLabelsRows[row][col])
                }
            }
            return labels
        case .numbers:
            let count = min(columns * rows, numberRowCodes.count)
            return (1...count).map { "\($0)" }
        }
    }

    private func gridKeyCodes(for layout: GridLayout) -> [Int] {
        return Self.keyCodes(for: config.keyStyle, columns: layout.columns, rows: layout.rows).map { Int($0) }
    }

    /// Returns NSEvent modifier flags matching the configured modifier keys.
    public static func nsModifierFlags(from keys: [String]) -> NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        for key in keys {
            switch key.lowercased() {
            case "ctrl":  flags.insert(.control)
            case "alt":   flags.insert(.option)
            case "cmd":   flags.insert(.command)
            case "shift": flags.insert(.shift)
            default: break
            }
        }
        return flags
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
