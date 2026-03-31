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

    public init(id: String, name: String, columns: Int, rows: Int, cells: [GridCell]) {
        self.id = id
        self.name = name
        self.columns = columns
        self.rows = rows
        self.cells = cells
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
}

/// Top-level configuration stored in ~/.config/griddle/config.json
public struct GriddleConfig: Codable {
    public var activeLayoutID: String
    public var layouts: [GridLayout]
    public var modifier: ModifierConfig

    public struct ModifierConfig: Codable {
        /// Key modifiers used for grid bindings: "ctrl", "alt", "cmd", "shift"
        public var keys: [String]

        public init(keys: [String]) {
            self.keys = keys
        }
    }

    public init(activeLayoutID: String, layouts: [GridLayout], modifier: ModifierConfig) {
        self.activeLayoutID = activeLayoutID
        self.layouts = layouts
        self.modifier = modifier
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
