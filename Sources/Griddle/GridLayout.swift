import Foundation

/// Represents a single cell in the grid, defined by its column and row span.
struct GridCell: Codable, Equatable {
    var col: Int
    var row: Int
    var colSpan: Int
    var rowSpan: Int
}

/// A grid layout with a fixed number of columns and rows.
struct GridLayout: Codable, Identifiable {
    var id: String
    var name: String
    var columns: Int
    var rows: Int
    var cells: [GridCell]

    /// Generate default cells for a uniform grid.
    static func uniform(id: String, name: String, columns: Int, rows: Int) -> GridLayout {
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
struct GriddleConfig: Codable {
    var activeLayoutID: String
    var layouts: [GridLayout]
    var modifier: ModifierConfig

    struct ModifierConfig: Codable {
        /// Key modifiers used for grid bindings: "ctrl", "alt", "cmd", "shift"
        var keys: [String]
    }

    static var `default`: GriddleConfig {
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
    static var configURL: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home
            .appendingPathComponent(".config")
            .appendingPathComponent("griddle")
            .appendingPathComponent("config.json")
    }

    static func load() -> GriddleConfig {
        let url = configURL
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let config = try? JSONDecoder().decode(GriddleConfig.self, from: data) else {
            return .default
        }
        return config
    }

    func save() {
        let url = GriddleConfig.configURL
        let dir = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(self) {
            try? data.write(to: url)
        }
    }
}
