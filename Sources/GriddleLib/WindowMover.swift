import Foundation

/// Pure geometry functions for grid-based window tiling.
public struct WindowMover {

    /// Computes the target frame for a cell within a layout on the given screen.
    public static func frame(for cell: GridCell, in layout: GridLayout, on screen: ScreenInfo) -> CGRect {
        let colOffsets = layout.columnOffsets()
        let rowOffsets = layout.rowOffsets()

        return CGRect(
            x: screen.visibleFrame.origin.x + colOffsets[cell.col] * screen.visibleFrame.width,
            y: screen.visibleFrame.origin.y + rowOffsets[cell.row] * screen.visibleFrame.height,
            width: (colOffsets[cell.col + cell.colSpan] - colOffsets[cell.col]) * screen.visibleFrame.width,
            height: (rowOffsets[cell.row + cell.rowSpan] - rowOffsets[cell.row]) * screen.visibleFrame.height
        )
    }

    /// Computes the bounding GridCell that spans from cell1 to cell2.
    public static func boundingCell(from cell1: GridCell, to cell2: GridCell) -> GridCell {
        let minCol = min(cell1.col, cell2.col)
        let minRow = min(cell1.row, cell2.row)
        let maxCol = max(cell1.col + cell1.colSpan, cell2.col + cell2.colSpan)
        let maxRow = max(cell1.row + cell1.rowSpan, cell2.row + cell2.rowSpan)
        return GridCell(col: minCol, row: minRow, colSpan: maxCol - minCol, rowSpan: maxRow - minRow)
    }
}
