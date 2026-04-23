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

    @Test("uniform layout has nil weights")
    func uniformWeightsNil() {
        let layout = GridLayout.uniform(id: "3x3", name: "3×3", columns: 3, rows: 3)
        #expect(layout.columnWeights == nil)
        #expect(layout.rowWeights == nil)
    }
}

@Suite("GridLayout weights")
struct GridLayoutWeightTests {

    @Test("nil weights produce uniform offsets")
    func nilWeightsUniformOffsets() {
        let layout = GridLayout.uniform(id: "3x2", name: "3×2", columns: 3, rows: 2)
        let colOffsets = layout.columnOffsets()
        let rowOffsets = layout.rowOffsets()

        #expect(colOffsets.count == 4)
        #expect(rowOffsets.count == 3)

        #expect(abs(colOffsets[0] - 0.0) < 1e-10)
        #expect(abs(colOffsets[1] - 1.0/3.0) < 1e-10)
        #expect(abs(colOffsets[2] - 2.0/3.0) < 1e-10)
        #expect(abs(colOffsets[3] - 1.0) < 1e-10)

        #expect(abs(rowOffsets[0] - 0.0) < 1e-10)
        #expect(abs(rowOffsets[1] - 0.5) < 1e-10)
        #expect(abs(rowOffsets[2] - 1.0) < 1e-10)
    }

    @Test("custom column weights produce correct offsets")
    func customColumnWeights() {
        var layout = GridLayout.uniform(id: "3x1", name: "3×1", columns: 3, rows: 1)
        layout.columnWeights = [1.0, 2.0, 1.0]
        let offsets = layout.columnOffsets()

        #expect(offsets.count == 4)
        #expect(abs(offsets[0] - 0.0) < 1e-10)
        #expect(abs(offsets[1] - 0.25) < 1e-10)
        #expect(abs(offsets[2] - 0.75) < 1e-10)
        #expect(abs(offsets[3] - 1.0) < 1e-10)
    }

    @Test("custom row weights produce correct offsets")
    func customRowWeights() {
        var layout = GridLayout.uniform(id: "1x3", name: "1×3", columns: 1, rows: 3)
        layout.rowWeights = [1.0, 1.0, 2.0]
        let offsets = layout.rowOffsets()

        #expect(offsets.count == 4)
        #expect(abs(offsets[0] - 0.0) < 1e-10)
        #expect(abs(offsets[1] - 0.25) < 1e-10)
        #expect(abs(offsets[2] - 0.5) < 1e-10)
        #expect(abs(offsets[3] - 1.0) < 1e-10)
    }

    @Test("normalized weights sum to 1.0")
    func normalizedWeightsSum() {
        var layout = GridLayout.uniform(id: "4x1", name: "4×1", columns: 4, rows: 1)
        layout.columnWeights = [1.0, 3.0, 2.0, 4.0]
        let nw = layout.normalizedColumnWeights()
        let sum = nw.reduce(0, +)
        #expect(abs(sum - 1.0) < 1e-10)
        #expect(nw.count == 4)
    }

    @Test("offsets are monotonically increasing")
    func offsetsMonotonic() {
        var layout = GridLayout.uniform(id: "5x3", name: "5×3", columns: 5, rows: 3)
        layout.columnWeights = [0.5, 1.0, 2.0, 0.3, 1.5]
        layout.rowWeights = [1.0, 0.5, 3.0]

        let colOffsets = layout.columnOffsets()
        for i in 1..<colOffsets.count {
            #expect(colOffsets[i] > colOffsets[i-1])
        }

        let rowOffsets = layout.rowOffsets()
        for i in 1..<rowOffsets.count {
            #expect(rowOffsets[i] > rowOffsets[i-1])
        }
    }

    @Test("hasCustomWeights is false for nil weights")
    func hasCustomWeightsNil() {
        let layout = GridLayout.uniform(id: "2x2", name: "2×2", columns: 2, rows: 2)
        #expect(!layout.hasCustomWeights)
    }

    @Test("hasCustomWeights is false for equal weights")
    func hasCustomWeightsEqual() {
        var layout = GridLayout.uniform(id: "2x2", name: "2×2", columns: 2, rows: 2)
        layout.columnWeights = [1.0, 1.0]
        layout.rowWeights = [1.0, 1.0]
        #expect(!layout.hasCustomWeights)
    }

    @Test("hasCustomWeights is true for non-uniform column weights")
    func hasCustomWeightsNonUniformCols() {
        var layout = GridLayout.uniform(id: "2x2", name: "2×2", columns: 2, rows: 2)
        layout.columnWeights = [1.0, 2.0]
        #expect(layout.hasCustomWeights)
    }

    @Test("displayName appends * when weights are non-uniform")
    func displayNameStar() {
        var layout = GridLayout.uniform(id: "3x3", name: "3×3", columns: 3, rows: 3)
        #expect(layout.displayName == "3×3")
        layout.columnWeights = [1.0, 2.0, 1.0]
        #expect(layout.displayName == "3×3*")
    }
}
