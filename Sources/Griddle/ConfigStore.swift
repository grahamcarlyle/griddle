import Foundation
import Combine

/// Observable wrapper around GriddleConfig that persists changes automatically.
class ConfigStore: ObservableObject {
    @Published var config: GriddleConfig {
        didSet { config.save() }
    }

    init() {
        config = GriddleConfig.load()
    }

    var activeLayout: GridLayout? {
        config.layouts.first(where: { $0.id == config.activeLayoutID })
    }

    func setActiveLayout(id: String) {
        config.activeLayoutID = id
    }

    func addLayout(_ layout: GridLayout) {
        config.layouts.append(layout)
    }

    func removeLayout(id: String) {
        config.layouts.removeAll(where: { $0.id == id })
        if config.activeLayoutID == id {
            config.activeLayoutID = config.layouts.first?.id ?? ""
        }
    }
}
