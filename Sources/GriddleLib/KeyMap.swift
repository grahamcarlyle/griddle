import Foundation
import Carbon

/// A child entry within a prefix key binding.
public struct KeyChild: Equatable, Sendable {
    public let keyCode: UInt16
    public let label: String
    public let cellIndex: Int

    public init(keyCode: UInt16, label: String, cellIndex: Int) {
        self.keyCode = keyCode
        self.label = label
        self.cellIndex = cellIndex
    }
}

/// Represents a key binding that is either a direct cell selection or a prefix requiring a follow-up key.
public enum KeyBinding: Equatable, Sendable {
    /// Single keypress directly selects a cell.
    case direct(cellIndex: Int)
    /// This key is a prefix; a follow-up keypress from the children list selects a cell.
    case prefix(children: [KeyChild])
}

/// Maps key codes to bindings for a given grid configuration.
/// Supports both direct (single-key) and prefix (two-key) cell selection.
public struct KeyMap: Equatable, Sendable {
    /// Top-level key code to binding mapping.
    public let bindings: [UInt16: KeyBinding]
    /// Display labels for each cell index in row-major order (e.g. "Q", "Z·Q").
    public let labels: [String]
    /// Total number of cells covered.
    public let cellCount: Int

    /// All top-level key codes, for hotkey registration.
    public var topLevelKeyCodes: [UInt16] {
        Array(bindings.keys).sorted()
    }

    public init(bindings: [UInt16: KeyBinding], labels: [String], cellCount: Int) {
        self.bindings = bindings
        self.labels = labels
        self.cellCount = cellCount
    }
}

// MARK: - Builder

extension KeyMap {

    // Spatial key codes by keyboard row
    static let spatialRows: [[UInt16]] = [
        [12, 13, 14, 15, 17, 16],  // Q W E R T Y
        [0,  1,  2,  3,  5,  4],   // A S D F G H
        [6,  7,  8,  9,  11, 45],  // Z X C V B N
    ]

    static let numberRowCodes: [UInt16] = [18, 19, 20, 21, 23, 22, 26, 28, 25]

    // QWERTY fallback labels keyed by key code
    static let qwertyLabels: [UInt16: String] = {
        var map: [UInt16: String] = [:]
        let spatialLabels = [
            ["Q", "W", "E", "R", "T", "Y"],
            ["A", "S", "D", "F", "G", "H"],
            ["Z", "X", "C", "V", "B", "N"],
        ]
        for (r, row) in spatialRows.enumerated() {
            for (c, code) in row.enumerated() {
                map[code] = spatialLabels[r][c]
            }
        }
        for (i, code) in numberRowCodes.enumerated() {
            map[code] = "\(i + 1)"
        }
        return map
    }()

    /// Builds a KeyMap for the given key style and grid dimensions.
    ///
    /// - Parameters:
    ///   - style: Whether to use spatial (QWERTY letter) or number-row keys.
    ///   - columns: Number of grid columns.
    ///   - rows: Number of grid rows.
    ///   - labelForKeyCode: Optional closure to convert key codes to display characters.
    ///     Defaults to system keyboard layout with QWERTY fallback.
    public static func build(
        for style: KeyStyle,
        columns: Int,
        rows: Int,
        labelForKeyCode: ((UInt16) -> String)? = nil
    ) -> KeyMap {
        let labelFn = labelForKeyCode ?? systemLabelForKeyCode
        switch style {
        case .spatial:
            return buildSpatial(columns: columns, rows: rows, labelFn: labelFn)
        case .numbers:
            return buildNumbers(columns: columns, rows: rows, labelFn: labelFn)
        }
    }

    // MARK: - Spatial

    private static func buildSpatial(columns: Int, rows: Int, labelFn: (UInt16) -> String) -> KeyMap {
        let cols = min(columns, spatialRows[0].count)
        var bindings: [UInt16: KeyBinding] = [:]
        var labels: [String] = []

        if rows <= spatialRows.count {
            // All direct — each keyboard row maps 1:1 to a grid row
            for r in 0..<rows {
                for c in 0..<cols {
                    let code = spatialRows[r][c]
                    let cellIndex = labels.count
                    bindings[code] = .direct(cellIndex: cellIndex)
                    labels.append(labelFn(code))
                }
            }
        } else {
            // Rows 0-1 are direct (Q-row, A-row), Z-row keys become prefixes
            let directKeyboardRows = 2
            for r in 0..<directKeyboardRows {
                for c in 0..<cols {
                    let code = spatialRows[r][c]
                    let cellIndex = labels.count
                    bindings[code] = .direct(cellIndex: cellIndex)
                    labels.append(labelFn(code))
                }
            }

            // Overflow grid rows need prefix keys from the Z-row
            let overflowRows = rows - directKeyboardRows
            let prefixesNeeded = (overflowRows + 1) / 2  // each prefix covers up to 2 grid rows

            for p in 0..<prefixesNeeded {
                let prefixCode = spatialRows[2][p]
                let prefixLabel = labelFn(prefixCode)
                var children: [KeyChild] = []

                // Each prefix covers 2 grid rows using Q-row (subRow 0) and A-row (subRow 1) as children
                for subRow in 0..<directKeyboardRows {
                    let gridRow = directKeyboardRows + p * directKeyboardRows + subRow
                    if gridRow >= rows { break }
                    for c in 0..<cols {
                        let childCode = spatialRows[subRow][c]
                        let childLabel = labelFn(childCode)
                        let cellIndex = labels.count
                        children.append(KeyChild(keyCode: childCode, label: childLabel, cellIndex: cellIndex))
                        labels.append("\(prefixLabel)·\(childLabel)")
                    }
                }

                bindings[prefixCode] = .prefix(children: children)
            }
        }

        return KeyMap(bindings: bindings, labels: labels, cellCount: labels.count)
    }

    // MARK: - Numbers

    private static func buildNumbers(columns: Int, rows: Int, labelFn: (UInt16) -> String) -> KeyMap {
        let totalCells = columns * rows
        var bindings: [UInt16: KeyBinding] = [:]
        var labels: [String] = []

        if totalCells <= numberRowCodes.count {
            // All direct
            for i in 0..<totalCells {
                let code = numberRowCodes[i]
                bindings[code] = .direct(cellIndex: i)
                labels.append(labelFn(code))
            }
        } else {
            // Find minimum number of prefix keys needed
            var numPrefixes = 1
            while numPrefixes < numberRowCodes.count {
                let directCount = numberRowCodes.count - numPrefixes
                if directCount * (1 + numPrefixes) >= totalCells { break }
                numPrefixes += 1
            }

            let directCount = numberRowCodes.count - numPrefixes

            // Direct keys
            for i in 0..<directCount {
                let code = numberRowCodes[i]
                bindings[code] = .direct(cellIndex: i)
                labels.append(labelFn(code))
            }

            // Prefix keys
            var cellIndex = directCount
            for p in 0..<numPrefixes {
                let prefixCode = numberRowCodes[directCount + p]
                let prefixLabel = labelFn(prefixCode)
                var children: [KeyChild] = []

                for c in 0..<directCount {
                    if cellIndex >= totalCells { break }
                    let childCode = numberRowCodes[c]
                    let childLabel = labelFn(childCode)
                    children.append(KeyChild(keyCode: childCode, label: childLabel, cellIndex: cellIndex))
                    labels.append("\(prefixLabel)·\(childLabel)")
                    cellIndex += 1
                }

                bindings[prefixCode] = .prefix(children: children)
            }
        }

        return KeyMap(bindings: bindings, labels: labels, cellCount: labels.count)
    }
}

// MARK: - System Keyboard Layout Labels

extension KeyMap {

    /// Returns the display character for a key code based on the active keyboard input source.
    /// Falls back to QWERTY labels if the system API fails.
    public static func systemLabelForKeyCode(_ keyCode: UInt16) -> String {
        if let label = keyLabelFromInputSource(keyCode) {
            return label
        }
        return qwertyLabels[keyCode] ?? "?"
    }

    /// Carbon's TIS / UCKeyTranslate / LMGetKbdType APIs aren't safe to call from multiple
    /// threads simultaneously — concurrent callers can SIGABRT inside HIToolbox. In production
    /// these are invoked from the main thread, but parallel test suites can race them.
    private static let inputSourceLock = NSLock()

    private static func keyLabelFromInputSource(_ keyCode: UInt16) -> String? {
        inputSourceLock.lock()
        defer { inputSourceLock.unlock() }
        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
              let rawPtr = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else {
            return nil
        }
        let layoutData = unsafeBitCast(rawPtr, to: CFData.self)
        guard let dataPtr = CFDataGetBytePtr(layoutData) else { return nil }

        let layoutPtr = UnsafeRawPointer(dataPtr).assumingMemoryBound(to: UCKeyboardLayout.self)
        var deadKeyState: UInt32 = 0
        var chars = [UniChar](repeating: 0, count: 4)
        var actualLength: Int = 0

        let status = UCKeyTranslate(
            layoutPtr,
            keyCode,
            UInt16(kUCKeyActionDisplay),
            0,  // no modifiers
            UInt32(LMGetKbdType()),
            UInt32(kUCKeyTranslateNoDeadKeysBit),
            &deadKeyState,
            chars.count,
            &actualLength,
            &chars
        )

        guard status == noErr, actualLength > 0 else { return nil }
        return String(utf16CodeUnits: chars, count: actualLength).uppercased()
    }
}
