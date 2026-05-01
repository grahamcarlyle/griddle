/// No-op HUD presenter for tests and demos.
public class NullHUDPresenter: HUDPresenter {
    public init() {}

    public func showOverlay(on screen: ScreenInfo, layout: GridLayout, keyLabels: [String], theme: HUDTheme) {}
    public func showDisabledOverlay(on screen: ScreenInfo, message: String, theme: HUDTheme) {}
    public func dismiss() {}
    public func updateHighlight(_ region: HighlightRegion?) {}
    public func updateResizePreview(_ preview: ResizePreview?) {}
    public func updateLayout(_ layout: GridLayout) {}
    public func showWeightStatus() {}
    public func enterPrefixMode(reachableCells: [Int: String]) {}
    public func exitPrefixMode() {}
    public func showLayoutNameBanner(_ name: String) {}
}
