import Testing
@testable import GriddleLib

@Suite("WindowMover.boundingCell")
struct BoundingCellTests {

    @Test("same cell returns that cell unchanged")
    func sameCell() {
        let cell = GridCell(col: 1, row: 0, colSpan: 1, rowSpan: 1)
        let result = WindowMover.boundingCell(from: cell, to: cell)
        #expect(result == cell)
    }

    @Test("adjacent cells in same row")
    func adjacentHorizontal() {
        let cell1 = GridCell(col: 0, row: 0, colSpan: 1, rowSpan: 1)
        let cell2 = GridCell(col: 1, row: 0, colSpan: 1, rowSpan: 1)
        let result = WindowMover.boundingCell(from: cell1, to: cell2)
        #expect(result == GridCell(col: 0, row: 0, colSpan: 2, rowSpan: 1))
    }

    @Test("adjacent cells in same column")
    func adjacentVertical() {
        let cell1 = GridCell(col: 0, row: 0, colSpan: 1, rowSpan: 1)
        let cell2 = GridCell(col: 0, row: 1, colSpan: 1, rowSpan: 1)
        let result = WindowMover.boundingCell(from: cell1, to: cell2)
        #expect(result == GridCell(col: 0, row: 0, colSpan: 1, rowSpan: 2))
    }

    @Test("diagonal corners span the full grid (2x2)")
    func diagonalCorners2x2() {
        let topLeft = GridCell(col: 0, row: 0, colSpan: 1, rowSpan: 1)
        let bottomRight = GridCell(col: 1, row: 1, colSpan: 1, rowSpan: 1)
        let result = WindowMover.boundingCell(from: topLeft, to: bottomRight)
        #expect(result == GridCell(col: 0, row: 0, colSpan: 2, rowSpan: 2))
    }

    @Test("order doesn't matter (commutative)")
    func commutative() {
        let cell1 = GridCell(col: 0, row: 0, colSpan: 1, rowSpan: 1)
        let cell2 = GridCell(col: 2, row: 1, colSpan: 1, rowSpan: 1)
        let forward = WindowMover.boundingCell(from: cell1, to: cell2)
        let reverse = WindowMover.boundingCell(from: cell2, to: cell1)
        #expect(forward == reverse)
    }

    @Test("diagonal corners on 3x2 grid span full grid")
    func diagonalCorners3x2() {
        let topLeft = GridCell(col: 0, row: 0, colSpan: 1, rowSpan: 1)
        let bottomRight = GridCell(col: 2, row: 1, colSpan: 1, rowSpan: 1)
        let result = WindowMover.boundingCell(from: topLeft, to: bottomRight)
        #expect(result == GridCell(col: 0, row: 0, colSpan: 3, rowSpan: 2))
    }

    @Test("cells with non-uniform spans")
    func nonUniformSpans() {
        let cell1 = GridCell(col: 0, row: 0, colSpan: 2, rowSpan: 1)
        let cell2 = GridCell(col: 1, row: 1, colSpan: 1, rowSpan: 2)
        let result = WindowMover.boundingCell(from: cell1, to: cell2)
        #expect(result == GridCell(col: 0, row: 0, colSpan: 2, rowSpan: 3))
    }

    @Test("non-adjacent cells include gap in bounding box")
    func nonAdjacentWithGap() {
        let cell1 = GridCell(col: 0, row: 0, colSpan: 1, rowSpan: 1)
        let cell2 = GridCell(col: 2, row: 0, colSpan: 1, rowSpan: 1)
        let result = WindowMover.boundingCell(from: cell1, to: cell2)
        #expect(result == GridCell(col: 0, row: 0, colSpan: 3, rowSpan: 1))
    }
}
