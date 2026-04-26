import Cocoa

/// Real HUD presenter that creates NSPanel and HUDOverlayView for the grid overlay.
public class PanelHUDPresenter: HUDPresenter {
    private var panel: NSPanel?
    private var overlayView: HUDOverlayView?

    public init() {}

    public func showOverlay(on screen: ScreenInfo, layout: GridLayout, keyLabels: [String], theme: HUDTheme) {
        let screenFrame = screen.visibleFrame
        let panel = makePanel(frame: screenFrame)

        let overlayView = HUDOverlayView(frame: NSRect(origin: .zero, size: screenFrame.size))
        overlayView.layout = layout
        overlayView.keyLabels = keyLabels
        overlayView.theme = theme
        panel.contentView = overlayView

        panel.orderFrontRegardless()

        self.panel = panel
        self.overlayView = overlayView
    }

    public func showDisabledOverlay(on screen: ScreenInfo, message: String, theme: HUDTheme) {
        let screenFrame = screen.frame
        let panel = makePanel(frame: screenFrame)

        let overlayView = HUDOverlayView(frame: NSRect(origin: .zero, size: screenFrame.size))
        overlayView.theme = theme
        overlayView.disabledMessage = message
        panel.contentView = overlayView

        panel.orderFrontRegardless()

        self.panel = panel
        self.overlayView = overlayView
    }

    public func dismiss() {
        panel?.orderOut(nil)
        panel = nil
        overlayView = nil
    }

    public func updateHighlight(_ region: HighlightRegion?) {
        overlayView?.highlightedRegion = region
    }

    public func updateLayout(_ layout: GridLayout) {
        overlayView?.layout = layout
        overlayView?.needsDisplay = true
    }

    public func showWeightStatus() {
        overlayView?.showWeightStatus = true
        overlayView?.needsDisplay = true
    }

    public func enterPrefixMode(reachableCells: [Int: String]) {
        overlayView?.prefixReachableCells = reachableCells
    }

    public func exitPrefixMode() {
        overlayView?.prefixReachableCells = nil
    }

    public func showLayoutNameBanner(_ name: String) {
        overlayView?.showLayoutNameBanner(name)
    }

    private func makePanel(frame: CGRect) -> NSPanel {
        let panel = NSPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        return panel
    }
}
