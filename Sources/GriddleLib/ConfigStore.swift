import Foundation
import Combine

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
    }
}
