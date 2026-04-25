import Testing
import CoreGraphics
@testable import GriddleLib

@Suite("WindowMover.frame geometry")
struct WindowMoverFrameTests {
    let screen = ScreenInfo(
        id: "Test @ 0,0",
        localizedName: "Test",
        frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
        visibleFrame: CGRect(x: 0, y: 25, width: 1920, height: 1055)
    )

    @Test("single cell in uniform 2x2 grid fills a quarter of visible frame")
    func singleCell2x2() {
        let layout = GridLayout.uniform(id: "2x2", name: "2x2", columns: 2, rows: 2)
        let cell = layout.cells[0] // top-left
        let frame = WindowMover.frame(for: cell, in: layout, on: screen)

        #expect(frame.origin.x == 0)
        #expect(frame.origin.y == 25)
        #expect(frame.width == 960)
        #expect(frame.height == 527.5)
    }

    @Test("bottom-right cell in 2x2 grid")
    func bottomRightCell2x2() {
        let layout = GridLayout.uniform(id: "2x2", name: "2x2", columns: 2, rows: 2)
        let cell = layout.cells[3] // bottom-right (row 1, col 1)
        let frame = WindowMover.frame(for: cell, in: layout, on: screen)

        #expect(frame.origin.x == 960)
        #expect(frame.origin.y == 552.5)
        #expect(frame.width == 960)
        #expect(frame.height == 527.5)
    }

    @Test("3x2 grid cells cover entire visible frame without gaps")
    func fullCoverage3x2() {
        let layout = GridLayout.uniform(id: "3x2", name: "3x2", columns: 3, rows: 2)
        var coveredArea: CGFloat = 0
        for cell in layout.cells {
            let frame = WindowMover.frame(for: cell, in: layout, on: screen)
            coveredArea += frame.width * frame.height
        }
        let visibleArea = screen.visibleFrame.width * screen.visibleFrame.height
        #expect(abs(coveredArea - visibleArea) < 1.0)
    }

    @Test("bounding cell spanning two cells produces correct frame")
    func boundingCellFrame() {
        let layout = GridLayout.uniform(id: "3x2", name: "3x2", columns: 3, rows: 2)
        let topLeft = layout.cells[0]
        let topMiddle = layout.cells[1]
        let bounding = WindowMover.boundingCell(from: topLeft, to: topMiddle)
        let frame = WindowMover.frame(for: bounding, in: layout, on: screen)

        #expect(frame.origin.x == 0)
        #expect(frame.origin.y == 25)
        #expect(abs(frame.width - 1280) < 1.0) // 2/3 of 1920
        #expect(abs(frame.height - 527.5) < 1.0) // half of 1055
    }

    @Test("custom column weights produce non-uniform widths")
    func customColumnWeights() {
        var layout = GridLayout.uniform(id: "2x1", name: "2x1", columns: 2, rows: 1)
        layout.columnWeights = [2.0, 1.0]

        let leftFrame = WindowMover.frame(for: layout.cells[0], in: layout, on: screen)
        let rightFrame = WindowMover.frame(for: layout.cells[1], in: layout, on: screen)

        // Left column should be 2/3 of width, right 1/3
        #expect(abs(leftFrame.width - 1280) < 1.0)
        #expect(abs(rightFrame.width - 640) < 1.0)
        // Together they cover the full width
        #expect(abs(leftFrame.width + rightFrame.width - 1920) < 1.0)
    }
}
