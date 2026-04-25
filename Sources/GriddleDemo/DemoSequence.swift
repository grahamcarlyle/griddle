import Foundation
import GriddleLib

enum DemoAction {
    case showDesktop
    case showHUD(layout: String, theme: HUDTheme)
    case highlight(col: Int, row: Int)
    case highlightRegion(minCol: Int, minRow: Int, maxCol: Int, maxRow: Int)
    case tileWindow(windowIndex: Int, cellIndex: Int)
    case tileWindowToRegion(windowIndex: Int, minCol: Int, minRow: Int, maxCol: Int, maxRow: Int)
    case dismissHUD
    case resetWindows
    case setWeights(columnWeights: [Double]?, rowWeights: [Double]?)
    case showWeightStatus
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
                actions: [.resetWindows, .showDesktop]
            ),
            DemoStep(
                description: "HUD grid overlay appears",
                hold: 1.5,
                actions: [.showHUD(layout: "2x2", theme: .system)]
            ),
            DemoStep(
                description: "User presses Q — top-left cell highlights",
                hold: 1.0,
                actions: [.highlight(col: 0, row: 0)]
            ),
            DemoStep(
                description: "Window snaps to top-left cell",
                hold: 2.0,
                actions: [.dismissHUD, .tileWindow(windowIndex: 0, cellIndex: 0)]
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
                actions: [.resetWindows, .showDesktop]
            ),
            DemoStep(
                description: "HUD overlay appears (3x2 grid)",
                hold: 1.5,
                actions: [.showHUD(layout: "3x2", theme: .system)]
            ),
            DemoStep(
                description: "First key — top-left anchor selected",
                hold: 1.0,
                actions: [.highlight(col: 0, row: 0)]
            ),
            DemoStep(
                description: "Second key — span expands to top-right",
                hold: 1.5,
                actions: [.highlightRegion(minCol: 0, minRow: 0, maxCol: 2, maxRow: 0)]
            ),
            DemoStep(
                description: "Window spans the full top row",
                hold: 2.0,
                actions: [.dismissHUD, .tileWindowToRegion(windowIndex: 0, minCol: 0, minRow: 0, maxCol: 2, maxRow: 0)]
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
                actions: [.resetWindows, .showDesktop]
            ),
            DemoStep(
                description: "HUD overlay appears (3x2 grid)",
                hold: 1.0,
                actions: [.showHUD(layout: "3x2", theme: .system)]
            ),
            DemoStep(
                description: "Arrow key pressed — cursor appears at top-left",
                hold: 0.8,
                actions: [.highlight(col: 0, row: 0)]
            ),
            DemoStep(
                description: "Arrow right — cursor moves",
                hold: 0.8,
                actions: [.highlight(col: 1, row: 0)]
            ),
            DemoStep(
                description: "Arrow right again",
                hold: 0.8,
                actions: [.highlight(col: 2, row: 0)]
            ),
            DemoStep(
                description: "Arrow down",
                hold: 0.8,
                actions: [.highlight(col: 2, row: 1)]
            ),
            DemoStep(
                description: "Enter — anchor set, now expanding",
                hold: 1.0,
                actions: [.highlightRegion(minCol: 2, minRow: 1, maxCol: 2, maxRow: 1)]
            ),
            DemoStep(
                description: "Arrow left — selection expands",
                hold: 0.8,
                actions: [.highlightRegion(minCol: 1, minRow: 1, maxCol: 2, maxRow: 1)]
            ),
            DemoStep(
                description: "Enter — window tiles to selection",
                hold: 2.0,
                actions: [.dismissHUD, .tileWindowToRegion(windowIndex: 0, minCol: 1, minRow: 1, maxCol: 2, maxRow: 1)]
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
                actions: [.resetWindows, .showDesktop]
            ),
            DemoStep(
                description: "HUD overlay appears (2x2 grid)",
                hold: 1.0,
                actions: [.showHUD(layout: "2x2", theme: .system)]
            ),
            DemoStep(
                description: "Select top-left cell as anchor",
                hold: 0.8,
                actions: [.highlight(col: 0, row: 0)]
            ),
            DemoStep(
                description: "Enter — expanding mode, selection ready",
                hold: 0.8,
                actions: [.highlightRegion(minCol: 0, minRow: 0, maxCol: 0, maxRow: 0)]
            ),
            DemoStep(
                description: "Shift+Right — left column grows wider",
                hold: 1.0,
                actions: [
                    .setWeights(columnWeights: [1.3, 0.7], rowWeights: nil),
                    .showWeightStatus
                ]
            ),
            DemoStep(
                description: "Shift+Right again — left column even wider",
                hold: 1.0,
                actions: [
                    .setWeights(columnWeights: [1.6, 0.4], rowWeights: nil),
                    .showWeightStatus
                ]
            ),
            DemoStep(
                description: "Shift+Up — top row grows taller",
                hold: 1.0,
                actions: [
                    .setWeights(columnWeights: [1.6, 0.4], rowWeights: [1.4, 0.6]),
                    .showWeightStatus
                ]
            ),
            DemoStep(
                description: "Enter — window tiles with custom proportions",
                hold: 2.0,
                actions: [
                    .dismissHUD,
                    .tileWindow(windowIndex: 0, cellIndex: 0)
                ]
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