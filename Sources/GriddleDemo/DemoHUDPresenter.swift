import Cocoa
import GriddleLib

/// HUDPresenter for headless demos: writes the overlay into a parent NSView
/// instead of an NSPanel, so it composes with the SimulatedDesktopView.
class DemoHUDPresenter: HUDPresenter {
    weak var parentView: NSView?
    var overlayView: HUDOverlayView?

    init(parentView: NSView) {
        self.parentView = parentView
    }

    func showOverlay(on screen: ScreenInfo, layout: GridLayout, keyLabels: [String], theme: HUDTheme) {
        dismiss()
        guard let parent = parentView else { return }
        let view = HUDOverlayView(frame: NSRect(origin: .zero, size: screen.frame.size))
        view.layout = layout
        view.keyLabels = keyLabels
        view.theme = theme
        parent.addSubview(view)
        self.overlayView = view
    }

    func showDisabledOverlay(on screen: ScreenInfo, message: String, theme: HUDTheme) {
        // Not exercised by demos.
    }

    func dismiss() {
        overlayView?.removeFromSuperview()
        overlayView = nil
    }

    func updateHighlight(_ region: HighlightRegion?) {
        overlayView?.highlightedRegion = region
    }

    func updateResizePreview(_ preview: ResizePreview?) {
        overlayView?.resizePreview = preview
    }

    func updateLayout(_ layout: GridLayout) {
        overlayView?.layout = layout
        overlayView?.needsDisplay = true
    }

    func showWeightStatus() {
        overlayView?.showWeightStatus = true
        overlayView?.needsDisplay = true
    }

    func enterPrefixMode(reachableCells: [Int: String]) {
        overlayView?.prefixReachableCells = reachableCells
    }

    func exitPrefixMode() {
        overlayView?.prefixReachableCells = nil
    }

    func showLayoutNameBanner(_ name: String) {
        overlayView?.showLayoutNameBanner(name)
    }
}
