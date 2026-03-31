import Testing
@testable import GriddleLib

@Suite("GridLayout.uniform")
struct GridLayoutUniformTests {

    @Test("generates correct number of cells")
    func cellCount() {
        let layout = GridLayout.uniform(id: "3x2", name: "3×2", columns: 3, rows: 2)
        #expect(layout.cells.count == 6)
    }

    @Test("cells are in row-major order (left-to-right, top-to-bottom)")
    func rowMajorOrder() {
        let layout = GridLayout.uniform(id: "2x2", name: "2×2", columns: 2, rows: 2)
        #expect(layout.cells[0] == GridCell(col: 0, row: 0, colSpan: 1, rowSpan: 1))
        #expect(layout.cells[1] == GridCell(col: 1, row: 0, colSpan: 1, rowSpan: 1))
        #expect(layout.cells[2] == GridCell(col: 0, row: 1, colSpan: 1, rowSpan: 1))
        #expect(layout.cells[3] == GridCell(col: 1, row: 1, colSpan: 1, rowSpan: 1))
    }

    @Test("all cells have span of 1x1")
    func uniformSpans() {
        let layout = GridLayout.uniform(id: "3x3", name: "3×3", columns: 3, rows: 3)
        for cell in layout.cells {
            #expect(cell.colSpan == 1)
            #expect(cell.rowSpan == 1)
        }
    }

    @Test("cells cover the full grid without gaps or overlap")
    func fullCoverage() {
        let layout = GridLayout.uniform(id: "3x2", name: "3×2", columns: 3, rows: 2)
        var covered = Set<String>()
        for cell in layout.cells {
            for r in cell.row..<(cell.row + cell.rowSpan) {
                for c in cell.col..<(cell.col + cell.colSpan) {
                    let key = "\(c),\(r)"
                    #expect(!covered.contains(key), "Cell at \(key) covered twice")
                    covered.insert(key)
                }
            }
        }
        #expect(covered.count == layout.columns * layout.rows)
    }

    @Test("1x1 grid produces a single cell")
    func singleCell() {
        let layout = GridLayout.uniform(id: "1x1", name: "1×1", columns: 1, rows: 1)
        #expect(layout.cells.count == 1)
        #expect(layout.cells[0] == GridCell(col: 0, row: 0, colSpan: 1, rowSpan: 1))
    }
}
