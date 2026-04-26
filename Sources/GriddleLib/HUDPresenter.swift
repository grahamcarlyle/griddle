import CoreGraphics

/// Abstracts the HUD overlay presentation so HUDController can be tested without AppKit UI.
public protocol HUDPresenter {
    func showOverlay(on screen: ScreenInfo, layout: GridLayout, keyLabels: [String], theme: HUDTheme)
    func showDisabledOverlay(on screen: ScreenInfo, message: String, theme: HUDTheme)
    func dismiss()
    func updateHighlight(_ region: HighlightRegion?)
    func updateLayout(_ layout: GridLayout)
    func showWeightStatus()
    func enterPrefixMode(reachableCells: [Int: String])
    func exitPrefixMode()
    func showLayoutNameBanner(_ name: String)
}
