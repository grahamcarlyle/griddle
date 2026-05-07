import Foundation
import Combine

/// Observable wrapper around GriddleConfig that persists changes automatically.
public class ConfigStore: ObservableObject {
    @Published public var config: GriddleConfig {
        didSet { config.save() }
    }

    public init() {
        config = GriddleConfig.load()
        sortLayouts()
    }

    /// Creates a ConfigStore with a specific config (no file I/O).
    public init(config: GriddleConfig) {
        self.config = config
    }

    public var activeLayout: GridLayout? {
        config.layouts.first(where: { $0.id == config.activeLayoutID })
    }

    public func setActiveLayout(id: String) {
        config.activeLayoutID = id
    }

    public func addLayout(_ layout: GridLayout) {
        config.layouts.append(layout)
        sortLayouts()
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
    public func layout(for screen: ScreenInfo) -> GridLayout? {
        config.layoutForScreen(key: screen.id)
    }

    public func setScreenLayout(screen: ScreenInfo, layoutID: String) {
        config.screenLayouts[screen.id] = layoutID
    }

    public func removeScreenLayout(screen: ScreenInfo) {
        config.screenLayouts.removeValue(forKey: screen.id)
    }

    /// Returns the layouts available for a specific screen (pool-filtered or all).
    public func layoutsForScreen(_ screen: ScreenInfo) -> [GridLayout] {
        config.layoutsForScreen(key: screen.id)
    }

    public func setScreenLayoutPool(screen: ScreenInfo, layoutIDs: [String]) {
        config.screenLayoutPools[screen.id] = layoutIDs
    }

    public func clearScreenLayoutPool(screen: ScreenInfo) {
        config.screenLayoutPools.removeValue(forKey: screen.id)
    }

    public func updateLayout(_ layout: GridLayout) {
        guard let index = config.layouts.firstIndex(where: { $0.id == layout.id }) else { return }
        config.layouts[index] = layout
    }

    public func renameLayout(id: String, name: String) {
        guard let index = config.layouts.firstIndex(where: { $0.id == id }) else { return }
        config.layouts[index].name = name
        sortLayouts()
    }

    private func sortLayouts() {
        config.layouts.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    public func setColumnWeight(layoutID: String, index: Int, value: Double) {
        guard let li = config.layouts.firstIndex(where: { $0.id == layoutID }) else { return }
        if config.layouts[li].columnWeights == nil {
            config.layouts[li].columnWeights = Array(repeating: 1.0, count: config.layouts[li].columns)
        }
        config.layouts[li].columnWeights![index] = max(0.1, value)
    }

    public func setRowWeight(layoutID: String, index: Int, value: Double) {
        guard let li = config.layouts.firstIndex(where: { $0.id == layoutID }) else { return }
        if config.layouts[li].rowWeights == nil {
            config.layouts[li].rowWeights = Array(repeating: 1.0, count: config.layouts[li].rows)
        }
        config.layouts[li].rowWeights![index] = max(0.1, value)
    }

    public func resetWeights(layoutID: String) {
        guard let li = config.layouts.firstIndex(where: { $0.id == layoutID }) else { return }
        config.layouts[li].columnWeights = nil
        config.layouts[li].rowWeights = nil
    }

    public func cycleLayout(on screen: ScreenInfo? = nil, reverse: Bool = false) {
        let pool: [GridLayout]
        let currentID: String

        if let screen = screen {
            pool = config.layoutsForScreen(key: screen.id)
            currentID = config.screenLayouts[screen.id] ?? config.activeLayoutID
        } else {
            pool = config.layouts
            currentID = config.activeLayoutID
        }

        guard pool.count > 1 else { return }
        let currentIndex = pool.firstIndex(where: { $0.id == currentID }) ?? 0
        let delta = reverse ? -1 : 1
        let nextID = pool[(currentIndex + delta + pool.count) % pool.count].id

        if let screen = screen {
            config.screenLayouts[screen.id] = nextID
        } else {
            config.activeLayoutID = nextID
        }
    }
}
