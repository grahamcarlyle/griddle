import Foundation
import GriddleLib

enum ArrowDirection {
    case up, down, left, right
}

enum DemoAction {
    /// Reset windows to their initial scattered positions; dismisses HUD if visible.
    case resetWindows
    /// Show the HUD with the given layout and theme (drives controller via modifier tap).
    case showHUD(layout: String, theme: HUDTheme)
    /// Press the cell key for (col, row) — anchors at choosingAnchor, confirms+tiles at expanding.
    case cellKey(col: Int, row: Int)
    /// Arrow key — reveals/moves cursor at choosingAnchor, moves extent at expanding.
    case arrowKey(ArrowDirection)
    /// Return — anchors at choosingAnchor, confirms+tiles at expanding.
    case pressEnter
    /// Shift-flags-changed event (true paints resize borders, false clears them).
    case shiftHold(Bool)
    /// Shift+arrow — drives HUDController's resize logic.
    case shiftArrow(ArrowDirection)
}

struct DemoStep {
    let description: String
    let hold: TimeInterval
    let actions: [DemoAction]
}

struct DemoSequence {
    let name: String        // output filename stem
    let steps: [DemoStep]

    static let all: [DemoSequence] = [
        windowTiling,
        multiCellSpan,
        arrowNavigation,
        weightEditing,
        themes,
    ]

    // MARK: - Basic window tiling

    static let windowTiling = DemoSequence(
        name: "window-tiling",
        steps: [
            DemoStep(
                description: "Desktop with scattered windows",
                hold: 1.5,
                actions: [.resetWindows]
            ),
            DemoStep(
                description: "HUD grid overlay appears",
                hold: 1.5,
                actions: [.showHUD(layout: "2x2", theme: .system)]
            ),
            DemoStep(
                description: "User presses Q — top-left cell highlights",
                hold: 1.0,
                actions: [.cellKey(col: 0, row: 0)]
            ),
            DemoStep(
                description: "Press Q again — window snaps to top-left cell",
                hold: 2.0,
                actions: [.cellKey(col: 0, row: 0)]
            ),
        ]
    )

    // MARK: - Multi-cell spanning

    static let multiCellSpan = DemoSequence(
        name: "multi-cell-span",
        steps: [
            DemoStep(
                description: "Desktop with scattered windows",
                hold: 1.0,
                actions: [.resetWindows]
            ),
            DemoStep(
                description: "HUD overlay appears (3x2 grid)",
                hold: 1.5,
                actions: [.showHUD(layout: "3x2", theme: .system)]
            ),
            DemoStep(
                description: "First key — top-left anchor selected",
                hold: 1.0,
                actions: [.cellKey(col: 0, row: 0)]
            ),
            DemoStep(
                description: "Arrow right — span extends",
                hold: 0.8,
                actions: [.arrowKey(.right)]
            ),
            DemoStep(
                description: "Arrow right — span reaches top-right",
                hold: 1.0,
                actions: [.arrowKey(.right)]
            ),
            DemoStep(
                description: "Enter — window spans the full top row",
                hold: 2.0,
                actions: [.pressEnter]
            ),
        ]
    )

    // MARK: - Arrow key navigation

    static let arrowNavigation = DemoSequence(
        name: "arrow-navigation",
        steps: [
            DemoStep(
                description: "Desktop with scattered windows",
                hold: 1.0,
                actions: [.resetWindows]
            ),
            DemoStep(
                description: "HUD overlay appears (3x2 grid)",
                hold: 1.0,
                actions: [.showHUD(layout: "3x2", theme: .system)]
            ),
            DemoStep(
                description: "Arrow key pressed — cursor appears at top-left",
                hold: 0.8,
                actions: [.arrowKey(.right)]
            ),
            DemoStep(
                description: "Arrow right — cursor moves",
                hold: 0.8,
                actions: [.arrowKey(.right)]
            ),
            DemoStep(
                description: "Arrow right again",
                hold: 0.8,
                actions: [.arrowKey(.right)]
            ),
            DemoStep(
                description: "Arrow down",
                hold: 0.8,
                actions: [.arrowKey(.down)]
            ),
            DemoStep(
                description: "Enter — anchor set, now expanding",
                hold: 1.0,
                actions: [.pressEnter]
            ),
            DemoStep(
                description: "Arrow left — selection expands",
                hold: 0.8,
                actions: [.arrowKey(.left)]
            ),
            DemoStep(
                description: "Enter — window tiles to selection",
                hold: 2.0,
                actions: [.pressEnter]
            ),
        ]
    )

    // MARK: - Weight editing

    static let weightEditing = DemoSequence(
        name: "weight-editing",
        steps: [
            DemoStep(
                description: "Desktop with scattered windows",
                hold: 1.0,
                actions: [.resetWindows]
            ),
            DemoStep(
                description: "HUD overlay appears (2x2 grid)",
                hold: 1.0,
                actions: [.showHUD(layout: "2x2", theme: .system)]
            ),
            DemoStep(
                description: "Arrow reveals cursor at top-left",
                hold: 0.8,
                actions: [.arrowKey(.right)]
            ),
            DemoStep(
                description: "Enter — anchor set, expanding mode",
                hold: 0.8,
                actions: [.pressEnter]
            ),
            DemoStep(
                description: "Hold Shift — resize borders highlight",
                hold: 1.0,
                actions: [.shiftHold(true)]
            ),
            DemoStep(
                description: "Shift+Right — left column grows wider",
                hold: 1.0,
                actions: [.shiftArrow(.right)]
            ),
            DemoStep(
                description: "Shift+Right again — left column even wider",
                hold: 1.0,
                actions: [.shiftArrow(.right)]
            ),
            DemoStep(
                description: "Shift+Up — top row grows taller",
                hold: 1.0,
                actions: [.shiftArrow(.up)]
            ),
            DemoStep(
                description: "Enter — window tiles with custom proportions",
                hold: 2.0,
                actions: [.shiftHold(false), .pressEnter]
            ),
        ]
    )

    // MARK: - Themes

    static let themes = DemoSequence(
        name: "themes",
        steps: [
            DemoStep(
                description: "System theme (default)",
                hold: 1.5,
                actions: [.resetWindows, .showHUD(layout: "2x2", theme: .system)]
            ),
            DemoStep(
                description: "Green theme",
                hold: 1.5,
                actions: [.showHUD(layout: "2x2", theme: .green)]
            ),
            DemoStep(
                description: "Purple theme",
                hold: 1.5,
                actions: [.showHUD(layout: "2x2", theme: .purple)]
            ),
            DemoStep(
                description: "Orange theme",
                hold: 1.5,
                actions: [.showHUD(layout: "2x2", theme: .orange)]
            ),
            DemoStep(
                description: "High contrast theme",
                hold: 1.5,
                actions: [.showHUD(layout: "2x2", theme: .highContrast)]
            ),
        ]
    )
}
