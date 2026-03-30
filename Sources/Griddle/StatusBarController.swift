import Cocoa
import SwiftUI

/// Manages the menu-bar status item and the popover/settings UI.
class StatusBarController: NSObject {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var configStore: ConfigStore
    private var hotkeyManager: HotkeyManager

    init(configStore: ConfigStore, hotkeyManager: HotkeyManager) {
        self.configStore = configStore
        self.hotkeyManager = hotkeyManager
        super.init()
        setupStatusItem()
        setupPopover()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "grid", accessibilityDescription: "Griddle")
            button.action = #selector(togglePopover)
            button.target = self
        }
    }

    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 340, height: 400)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: SettingsView(configStore: configStore, hotkeyManager: hotkeyManager)
        )
    }

    @objc private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else if let button = statusItem.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
}
