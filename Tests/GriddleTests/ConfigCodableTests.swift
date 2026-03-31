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
}
