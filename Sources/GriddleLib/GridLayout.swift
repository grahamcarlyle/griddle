import Foundation

/// Represents a single cell in the grid, defined by its column and row span.
public struct GridCell: Codable, Equatable {
    public var col: Int
    public var row: Int
    public var colSpan: Int
    public var rowSpan: Int

    public init(col: Int, row: Int, colSpan: Int, rowSpan: Int) {
        self.col = col
        self.row = row
        self.colSpan = colSpan
        self.rowSpan = rowSpan
    }
}

/// A grid layout with a fixed number of columns and rows.
public struct GridLayout: Codable, Identifiable {
    public var id: String
    public var name: String
    public var columns: Int
    public var rows: Int
    public var cells: [GridCell]
    public var columnWeights: [Double]?
    public var rowWeights: [Double]?

    public init(id: String, name: String, columns: Int, rows: Int, cells: [GridCell],
                columnWeights: [Double]? = nil, rowWeights: [Double]? = nil) {
        self.id = id
        self.name = name
        self.columns = columns
        self.rows = rows
        self.cells = cells
        self.columnWeights = columnWeights
        self.rowWeights = rowWeights
    }

    /// Generate default cells for a uniform grid.
    public static func uniform(id: String, name: String, columns: Int, rows: Int) -> GridLayout {
        var cells: [GridCell] = []
        for row in 0..<rows {
            for col in 0..<columns {
                cells.append(GridCell(col: col, row: row, colSpan: 1, rowSpan: 1))
            }
        }
        return GridLayout(id: id, name: name, columns: columns, rows: rows, cells: cells)
    }

    /// Whether this layout has non-uniform weights.
    public var hasCustomWeights: Bool {
        if let cw = columnWeights, !cw.allSatisfy({ $0 == cw[0] }) { return true }
        if let rw = rowWeights, !rw.allSatisfy({ $0 == rw[0] }) { return true }
        return false
    }

    /// Name with a `*` suffix when weights are non-uniform.
    public var displayName: String {
        hasCustomWeights ? "\(name)*" : name
    }

    /// Returns column weights normalized to sum to 1.0. Falls back to uniform if nil.
    public func normalizedColumnWeights() -> [Double] {
        let raw = columnWeights ?? Array(repeating: 1.0, count: columns)
        let total = raw.reduce(0, +)
        guard total > 0 else { return Array(repeating: 1.0 / Double(columns), count: columns) }
        return raw.map { $0 / total }
    }

    /// Returns row weights normalized to sum to 1.0. Falls back to uniform if nil.
    public func normalizedRowWeights() -> [Double] {
        let raw = rowWeights ?? Array(repeating: 1.0, count: rows)
        let total = raw.reduce(0, +)
        guard total > 0 else { return Array(repeating: 1.0 / Double(rows), count: rows) }
        return raw.map { $0 / total }
    }

    /// Cumulative column offsets as fractions of the total width: [0, w0, w0+w1, …, 1.0].
    /// Length is `columns + 1`.
    public func columnOffsets() -> [Double] {
        let nw = normalizedColumnWeights()
        var offsets = [0.0]
        for w in nw { offsets.append(offsets.last! + w) }
        offsets[offsets.count - 1] = 1.0
        return offsets
    }

    /// Cumulative row offsets as fractions of the total height: [0, h0, h0+h1, …, 1.0].
    /// Length is `rows + 1`.
    public func rowOffsets() -> [Double] {
        let nw = normalizedRowWeights()
        var offsets = [0.0]
        for w in nw { offsets.append(offsets.last! + w) }
        offsets[offsets.count - 1] = 1.0
        return offsets
    }
}

/// HUD overlay colour theme.
public enum HUDTheme: String, Codable, CaseIterable {
    case system
    case green
    case highContrast
    case purple
    case orange
}

/// Key used with modifier to cycle through layouts.
public enum CycleKey: String, Codable, CaseIterable {
    case space
    case tab
    case slash
    case zero
    case minus
    case equals

    public var keyCode: UInt32 {
        switch self {
        case .space:  return 49
        case .tab:    return 48
        case .slash:  return 44
        case .zero:   return 29
        case .minus:  return 27
        case .equals: return 24
        }
    }

    public var displayName: String {
        switch self {
        case .space:  return "Space"
        case .tab:    return "Tab"
        case .slash:  return "/"
        case .zero:   return "0"
        case .minus:  return "−"
        case .equals: return "="
        }
    }
}

/// Whether grid cells are mapped to spatial letter keys or number keys.
public enum KeyStyle: String, Codable, CaseIterable {
    case spatial
    case numbers
}

/// Top-level configuration stored in ~/.config/griddle/config.json
public struct GriddleConfig: Codable {
    public var activeLayoutID: String
    public var layouts: [GridLayout]
    public var modifier: ModifierConfig
    public var keyStyle: KeyStyle
    public var hudTheme: HUDTheme
    public var cycleKey: CycleKey
    /// Per-screen layout overrides. Key is screen identifier (name + position), value is layout ID.
    public var screenLayouts: [String: String]
    /// Per-screen layout pool overrides. Key is screen identifier, value is array of layout IDs.
    /// When set for a screen, only these layouts are available for it. When absent, all layouts are available.
    public var screenLayoutPools: [String: [String]]

    public struct ModifierConfig: Codable {
        /// Key modifiers used for grid bindings: "ctrl", "alt", "cmd", "shift"
        public var keys: [String]

        public init(keys: [String]) {
            self.keys = keys
        }
    }

    public init(activeLayoutID: String, layouts: [GridLayout], modifier: ModifierConfig, keyStyle: KeyStyle = .spatial, hudTheme: HUDTheme = .system, cycleKey: CycleKey = .space, screenLayouts: [String: String] = [:], screenLayoutPools: [String: [String]] = [:]) {
        self.activeLayoutID = activeLayoutID
        self.layouts = layouts
        self.modifier = modifier
        self.keyStyle = keyStyle
        self.hudTheme = hudTheme
        self.cycleKey = cycleKey
        self.screenLayouts = screenLayouts
        self.screenLayoutPools = screenLayoutPools
    }

    // Custom decoding for backward compatibility
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        activeLayoutID = try container.decode(String.self, forKey: .activeLayoutID)
        layouts = try container.decode([GridLayout].self, forKey: .layouts)
        modifier = try container.decode(ModifierConfig.self, forKey: .modifier)
        keyStyle = try container.decodeIfPresent(KeyStyle.self, forKey: .keyStyle) ?? .spatial
        hudTheme = try container.decodeIfPresent(HUDTheme.self, forKey: .hudTheme) ?? .system
        cycleKey = try container.decodeIfPresent(CycleKey.self, forKey: .cycleKey) ?? .space
        screenLayouts = try container.decodeIfPresent([String: String].self, forKey: .screenLayouts) ?? [:]
        screenLayoutPools = try container.decodeIfPresent([String: [String]].self, forKey: .screenLayoutPools) ?? [:]
    }

    /// Returns the layouts available for a given screen.
    /// If a custom pool is set for the screen, only those layouts are returned; otherwise all layouts.
    public func layoutsForScreen(key: String) -> [GridLayout] {
        guard let poolIDs = screenLayoutPools[key], !poolIDs.isEmpty else {
            return layouts
        }
        return layouts.filter { poolIDs.contains($0.id) }
    }

    /// Resolves the layout for a given screen, falling back to activeLayoutID.
    public func layoutForScreen(key: String) -> GridLayout? {
        if let layoutID = screenLayouts[key],
           let layout = layouts.first(where: { $0.id == layoutID }) {
            return layout
        }
        return layouts.first(where: { $0.id == activeLayoutID })
    }

    /// Returns the maximum grid dimensions across all layouts that could be active on any screen.
    public func maxGridDimensions() -> (columns: Int, rows: Int) {
        var maxCols = 0
        var maxRows = 0
        // Check all layouts referenced by screen mappings + the default
        let relevantIDs = Set(screenLayouts.values + [activeLayoutID])
        for layout in layouts where relevantIDs.contains(layout.id) {
            maxCols = max(maxCols, layout.columns)
            maxRows = max(maxRows, layout.rows)
        }
        return (maxCols, maxRows)
    }

    public static var `default`: GriddleConfig {
        GriddleConfig(
            activeLayoutID: "2x2",
            layouts: [
                .uniform(id: "2x2", name: "2×2", columns: 2, rows: 2),
                .uniform(id: "3x2", name: "3×2", columns: 3, rows: 2),
                .uniform(id: "3x3", name: "3×3", columns: 3, rows: 3),
            ],
            modifier: ModifierConfig(keys: ["ctrl", "alt"])
        )
    }
}

// MARK: - Config persistence

extension GriddleConfig {
    public static var configURL: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home
            .appendingPathComponent(".config")
            .appendingPathComponent("griddle")
            .appendingPathComponent("config.json")
    }

    public static func load() -> GriddleConfig {
        let url = configURL
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let config = try? JSONDecoder().decode(GriddleConfig.self, from: data) else {
            return .default
        }
        return config
    }

    public func save() {
        let url = GriddleConfig.configURL
        let dir = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(self) {
            try? data.write(to: url)
        }
    }
}
