# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

```bash
swift build -c release          # Release build → .build/release/Griddle
swift build                     # Debug build → .build/debug/Griddle
./build.sh                      # Wrapper: release build + prints install instructions
.build/release/Griddle          # Run the app (requires Accessibility permission)
```

There are no tests or linting configured in this project.

## Architecture

Griddle is a macOS menu-bar utility (Swift, SwiftUI, Swift Package Manager) that moves the focused window into grid cells via global hotkeys. It runs as an accessory app (no Dock icon).

**Key data flow:** `main.swift` boots the app, creates a `ConfigStore`, and wires it to `HotkeyManager` via a Combine `$config.sink`. When config changes (layout switch, modifier key toggle), hotkeys are automatically re-registered.

### Core components

- **GridLayout.swift** — Data models: `GridCell`, `GridLayout`, `GriddleConfig`, plus JSON persistence to `~/.config/griddle/config.json`. `GriddleConfig.default` provides built-in 2×2, 3×2, 3×3 layouts.
- **ConfigStore.swift** — `ObservableObject` wrapper that auto-saves on every `config` mutation via `didSet`.
- **HotkeyManager.swift** — Registers Carbon `EventHotKey` handlers mapping modifier+number-row keys (1–9) to grid cells. Uses `fourCharCode("GRDL")` signature. Supports up to 9 cells.
- **WindowMover.swift** — Uses Accessibility API (`AXUIElement`) to get the focused window, determines which screen it's on, converts between AppKit (bottom-left origin) and Quartz/AX (top-left origin) coordinate systems, then repositions/resizes the window.
- **StatusBarController.swift** — Creates the menu-bar icon and hosts a `NSPopover` containing the SwiftUI `SettingsView`.
- **SettingsView.swift** — SwiftUI popover UI: layout picker, grid preview, modifier key toggles, add/remove layout controls, quit button.
- **main.swift** — Entry point. Sets up the app as `.accessory`, checks Accessibility permission, and starts the run loop.

### Platform details

- Requires macOS 13+ (Ventura). Swift tools version 5.9.
- Uses Carbon Event API for global hotkeys (no modern replacement exists).
- Accessibility permission is mandatory — the app prompts on first launch and exits if not granted.