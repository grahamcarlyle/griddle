import Cocoa
import ApplicationServices

// MARK: - Accessibility permission check

func checkAccessibilityPermission() -> Bool {
    let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as NSString: true]
    return AXIsProcessTrustedWithOptions(options)
}

// MARK: - App entry point

let app = NSApplication.shared
app.setActivationPolicy(.accessory)  // Run as background app (no Dock icon)

let configStore = ConfigStore()
let hotkeyManager = HotkeyManager(config: configStore.config)

// Re-register hotkeys whenever config changes
var cancellable = configStore.$config.sink { newConfig in
    hotkeyManager.update(config: newConfig)
}

// Check accessibility permission
if !checkAccessibilityPermission() {
    let alert = NSAlert()
    alert.messageText = "Accessibility Permission Required"
    alert.informativeText = "Griddle needs Accessibility access to move windows.\n\nPlease grant access in System Settings → Privacy & Security → Accessibility, then relaunch Griddle."
    alert.alertStyle = .warning
    alert.addButton(withTitle: "Open System Settings")
    alert.addButton(withTitle: "Quit")
    let response = alert.runModal()
    if response == .alertFirstButtonReturn {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }
    exit(0)
}

// Register initial hotkeys
hotkeyManager.register()

// Set up status bar
let statusBarController = StatusBarController(configStore: configStore, hotkeyManager: hotkeyManager)

app.run()
