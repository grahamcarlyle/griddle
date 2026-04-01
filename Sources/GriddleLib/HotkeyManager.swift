import Cocoa
import Carbon

/// Maps keyboard shortcuts to grid cells and registers global hotkeys.
public class HotkeyManager {
    private var config: GriddleConfig
    private var eventHandlerRef: EventHandlerRef?
    private var hotKeyRefs: [EventHotKeyRef?] = []
    private var hotKeyMap: [UInt32: GridCell] = [:]  // hotKeyID -> GridCell
    private var nextID: UInt32 = 1
    public weak var hudController: HUDController?

    public init(config: GriddleConfig) {
        self.config = config
    }

    public func update(config: GriddleConfig) {
        self.config = config
        unregisterAll()
        register()
    }

    public func register() {
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
            let hotKeyID = EventHotKeyID(signature: fourCharCode("GRDL"), id: id)
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
