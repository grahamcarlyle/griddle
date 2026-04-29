import Cocoa
import ApplicationServices
import GriddleLib

// MARK: - Accessibility permission check

func checkAccessibilityPermission() -> Bool {
    let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as NSString: false]
    return AXIsProcessTrustedWithOptions(options)
}

// MARK: - App entry point

let app = NSApplication.shared
app.setActivationPolicy(.accessory)  // Run as background app (no Dock icon)

let displaySystem = RealDisplaySystem()
let configStore = ConfigStore()
let inputSource = RealInputSource(modifierKeys: configStore.config.modifier.keys)
let hotkeyManager = HotkeyManager(config: configStore.config, displaySystem: displaySystem, inputSource: inputSource)
let hudController = HUDController(config: configStore.config, displaySystem: displaySystem, inputSource: inputSource, presenter: PanelHUDPresenter())
hotkeyManager.hudController = hudController
hudController.onLayoutEdited = { layout in
    configStore.updateLayout(layout)
    hotkeyManager.update(config: configStore.config)
}
hotkeyManager.onLayoutCycle = {
    let screen = displaySystem.screenForFocusedWindow()
    if hudController.isHUDVisible {
        configStore.cycleLayout(on: screen)
    }
    hudController.showHUD()
    inputSource.cancelModifierTap()  // Prevent modifier release from dismissing the HUD
}

// Register hotkeys and update HUD on config changes (including initial setup)
var cancellable = configStore.$config.sink { newConfig in
    hotkeyManager.update(config: newConfig)
    hudController.update(config: newConfig)
    inputSource.update(modifierKeys: newConfig.modifier.keys)
}

// Check accessibility permission, polling until granted or user quits
while !checkAccessibilityPermission() {
    NSLog("Griddle: Accessibility permission not granted")
    let alert = NSAlert()
    alert.messageText = "Accessibility Permission Required"
    alert.informativeText = "Griddle needs Accessibility access to move windows.\n\nPlease grant access in System Settings → Privacy & Security → Accessibility, then click \"Check Again\"."
    alert.alertStyle = .warning
    alert.addButton(withTitle: "Check Again")
    alert.addButton(withTitle: "Open System Settings")
    alert.addButton(withTitle: "Quit")
    let response = alert.runModal()
    if response == .alertSecondButtonReturn {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    } else if response == .alertThirdButtonReturn {
        exit(0)
    }
}

inputSource.startModifierWatch(handler: hudController)

// Set up status bar
let statusBarController = StatusBarController(configStore: configStore, hotkeyManager: hotkeyManager, displaySystem: displaySystem)

app.run()
