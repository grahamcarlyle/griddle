import Foundation
import Combine
import Cocoa

/// Observable wrapper around GriddleConfig that persists changes automatically.
public class ConfigStore: ObservableObject {
    @Published public var config: GriddleConfig {
        didSet { config.save() }
    }

    public init() {
        config = GriddleConfig.load()
    }

    public var activeLayout: GridLayout? {
        config.layouts.first(where: { $0.id == config.activeLayoutID })
    }

    public func setActiveLayout(id: String) {
        config.activeLayoutID = id
    }

    public func addLayout(_ layout: GridLayout) {
        config.layouts.append(layout)
    }

    public func removeLayout(id: String) {
        config.layouts.removeAll(where: { $0.id == id })
        if config.activeLayoutID == id {
            config.activeLayoutID = config.layouts.first?.id ?? ""
        }
        // Remove any screen mappings that reference this layout
        config.screenLayouts = config.screenLayouts.filter { $0.value != id }
    }

    /// Resolves the layout for a specific screen, falling back to the global default.
    public func layout(for screen: NSScreen) -> GridLayout? {
        let key = GriddleConfig.screenKey(for: screen)
        return config.layoutForScreen(key: key)
    }

    public func setScreenLayout(screen: NSScreen, layoutID: String) {
        let key = GriddleConfig.screenKey(for: screen)
        config.screenLayouts[key] = layoutID
    }

    public func removeScreenLayout(screen: NSScreen) {
        let key = GriddleConfig.screenKey(for: screen)
        config.screenLayouts.removeValue(forKey: key)
    }
}
