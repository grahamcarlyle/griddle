import Testing
import Foundation
@testable import GriddleLib

@Suite("GriddleConfig Codable")
struct ConfigCodableTests {

    @Test("default config roundtrips through JSON")
    func defaultRoundtrip() throws {
        let original = GriddleConfig.default
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(GriddleConfig.self, from: data)

        #expect(decoded.activeLayoutID == original.activeLayoutID)
        #expect(decoded.layouts.count == original.layouts.count)
        #expect(decoded.modifier.keys == original.modifier.keys)
    }

    @Test("layout cell data preserved through encode/decode")
    func cellDataPreserved() throws {
        let layout = GridLayout.uniform(id: "2x2", name: "2×2", columns: 2, rows: 2)
        let config = GriddleConfig(
            activeLayoutID: "2x2",
            layouts: [layout],
            modifier: .init(keys: ["ctrl"])
        )
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(GriddleConfig.self, from: data)

        #expect(decoded.layouts[0].cells == layout.cells)
        #expect(decoded.layouts[0].columns == 2)
        #expect(decoded.layouts[0].rows == 2)
    }

    @Test("custom layout with non-uniform cells roundtrips")
    func customCellsRoundtrip() throws {
        let cells = [
            GridCell(col: 0, row: 0, colSpan: 2, rowSpan: 1),
            GridCell(col: 2, row: 0, colSpan: 1, rowSpan: 2),
            GridCell(col: 0, row: 1, colSpan: 2, rowSpan: 1),
        ]
        let layout = GridLayout(id: "custom", name: "Custom", columns: 3, rows: 2, cells: cells)
        let config = GriddleConfig(
            activeLayoutID: "custom",
            layouts: [layout],
            modifier: .init(keys: ["cmd", "shift"])
        )
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(GriddleConfig.self, from: data)

        #expect(decoded.layouts[0].cells == cells)
        #expect(decoded.modifier.keys == ["cmd", "shift"])
    }

    @Test("default config has expected built-in layouts")
    func defaultLayouts() {
        let config = GriddleConfig.default
        #expect(config.layouts.count == 3)

        let ids = config.layouts.map(\.id)
        #expect(ids.contains("2x2"))
        #expect(ids.contains("3x2"))
        #expect(ids.contains("3x3"))

        let layout2x2 = config.layouts.first(where: { $0.id == "2x2" })!
        #expect(layout2x2.cells.count == 4)
        #expect(layout2x2.columns == 2)
        #expect(layout2x2.rows == 2)

        let layout3x2 = config.layouts.first(where: { $0.id == "3x2" })!
        #expect(layout3x2.cells.count == 6)

        let layout3x3 = config.layouts.first(where: { $0.id == "3x3" })!
        #expect(layout3x3.cells.count == 9)
    }

    @Test("default active layout is 2x2")
    func defaultActiveLayout() {
        #expect(GriddleConfig.default.activeLayoutID == "2x2")
    }

    @Test("default modifiers are ctrl+alt")
    func defaultModifiers() {
        #expect(GriddleConfig.default.modifier.keys == ["ctrl", "alt"])
    }

    @Test("default screenLayouts is empty")
    func defaultScreenLayouts() {
        #expect(GriddleConfig.default.screenLayouts.isEmpty)
    }

    @Test("screenLayouts roundtrips through JSON")
    func screenLayoutsRoundtrip() throws {
        var config = GriddleConfig.default
        config.screenLayouts = ["Monitor A @ 0,0": "3x2", "Monitor B @ -1920,0": "2x2"]
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(GriddleConfig.self, from: data)
        #expect(decoded.screenLayouts == config.screenLayouts)
    }

    @Test("missing screenLayouts in JSON defaults to empty")
    func missingScreenLayoutsDefaultsToEmpty() throws {
        let json = """
        {
            "activeLayoutID": "2x2",
            "layouts": [],
            "modifier": {"keys": ["ctrl"]}
        }
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(GriddleConfig.self, from: json)
        #expect(decoded.screenLayouts.isEmpty)
    }

    @Test("layoutForScreen resolves screen-specific layout")
    func layoutForScreenSpecific() {
        var config = GriddleConfig.default
        config.screenLayouts = ["External @ 0,0": "3x2"]
        let layout = config.layoutForScreen(key: "External @ 0,0")
        #expect(layout?.id == "3x2")
    }

    @Test("layoutForScreen falls back to activeLayoutID")
    func layoutForScreenFallback() {
        let config = GriddleConfig.default
        let layout = config.layoutForScreen(key: "Unknown @ 999,999")
        #expect(layout?.id == config.activeLayoutID)
    }

    @Test("maxGridDimensions returns largest across all screen layouts")
    func maxGridDimensions() {
        var config = GriddleConfig.default  // has 2x2, 3x2, 3x3
        config.activeLayoutID = "2x2"
        config.screenLayouts = ["External @ 0,0": "3x3"]
        let dims = config.maxGridDimensions()
        #expect(dims.columns == 3)
        #expect(dims.rows == 3)
    }

    @Test("maxGridDimensions with only default layout")
    func maxGridDimensionsDefault() {
        var config = GriddleConfig.default
        config.activeLayoutID = "2x2"
        let dims = config.maxGridDimensions()
        #expect(dims.columns == 2)
        #expect(dims.rows == 2)
    }

    @Test("default hudTheme is system")
    func defaultHudTheme() {
        #expect(GriddleConfig.default.hudTheme == .system)
    }

    @Test("hudTheme roundtrips through JSON")
    func hudThemeRoundtrip() throws {
        var config = GriddleConfig.default
        config.hudTheme = .purple
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(GriddleConfig.self, from: data)
        #expect(decoded.hudTheme == .purple)
    }

    @Test("missing hudTheme in JSON defaults to system")
    func missingHudThemeDefaultsToSystem() throws {
        let json = """
        {
            "activeLayoutID": "2x2",
            "layouts": [],
            "modifier": {"keys": ["ctrl"]}
        }
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(GriddleConfig.self, from: json)
        #expect(decoded.hudTheme == .system)
    }
}
