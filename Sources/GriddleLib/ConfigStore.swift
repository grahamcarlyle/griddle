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
        // Remove from per-screen layout pools
        for (key, pool) in config.screenLayoutPools {
            let filtered = pool.filter { $0 != id }
            if filtered.isEmpty {
                config.screenLayoutPools.removeValue(forKey: key)
            } else {
                config.screenLayoutPools[key] = filtered
            }
        }
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

    /// Returns the layouts available for a specific screen (pool-filtered or all).
    public func layoutsForScreen(_ screen: NSScreen) -> [GridLayout] {
        let key = GriddleConfig.screenKey(for: screen)
        return config.layoutsForScreen(key: key)
    }

    public func setScreenLayoutPool(screen: NSScreen, layoutIDs: [String]) {
        let key = GriddleConfig.screenKey(for: screen)
        config.screenLayoutPools[key] = layoutIDs
    }

    public func clearScreenLayoutPool(screen: NSScreen) {
        let key = GriddleConfig.screenKey(for: screen)
        config.screenLayoutPools.removeValue(forKey: key)
    }

    public func cycleLayout(on screen: NSScreen? = nil) {
        let pool: [GridLayout]
        let currentID: String

        if let screen = screen {
            let key = GriddleConfig.screenKey(for: screen)
            pool = config.layoutsForScreen(key: key)
            currentID = config.screenLayouts[key] ?? config.activeLayoutID
        } else {
            pool = config.layouts
            currentID = config.activeLayoutID
        }

        guard pool.count > 1 else { return }
        let currentIndex = pool.firstIndex(where: { $0.id == currentID }) ?? 0
        let nextID = pool[(currentIndex + 1) % pool.count].id

        if let screen = screen {
            let key = GriddleConfig.screenKey(for: screen)
            config.screenLayouts[key] = nextID
        } else {
            config.activeLayoutID = nextID
        }
    }
}
