# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

```bash
swift build -c release          # Release build
./build.sh                      # Release build + package as .app bundle
open .build/Griddle.app         # Run the app (requires Accessibility permission)
cp -r .build/Griddle.app /Applications/  # Install
```

No linting configured. Swift is managed via mise (experimental flag required: `mise settings experimental=true`).

```bash
swift test                      # Run all tests
```

## Gotchas

- CGEvent tap callbacks must be static/non-capturing C function pointers — access state via the `refcon` user data pointer only.
- macOS tracks Accessibility permission by app bundle path. Changing the binary path (e.g. moving from `.build/` to `/Applications/`) requires re-granting permission.
- The .app bundle needs `LSUIElement=true` in Info.plist to match the `.accessory` activation policy (no Dock icon).
- `swift build` fails in Claude Code's sandbox due to temp dir restrictions — must run with sandbox disabled.

## Architecture

Griddle is a macOS menu-bar utility (Swift, SwiftUI, Swift Package Manager) that moves the focused window into grid cells via global hotkeys. It runs as an accessory app (no Dock icon).

**Key data flow:** `main.swift` boots the app, creates `ConfigStore`, `HotkeyManager`, and `HUDController`, wiring them via a Combine `$config.sink`. When config changes, hotkeys and HUD are automatically re-registered. `HotkeyManager` cancels pending HUD shows on fast modifier+number combos.

### Core components

- **GridLayout.swift** — Data models: `GridCell`, `GridLayout`, `GriddleConfig`, plus JSON persistence to `~/.config/griddle/config.json`. `GriddleConfig.default` provides built-in 2×2, 3×2, 3×3 layouts.
- **ConfigStore.swift** — `ObservableObject` wrapper that auto-saves on every `config` mutation via `didSet`.
- **HotkeyManager.swift** — Registers Carbon `EventHotKey` handlers mapping modifier+number-row keys (1–9) to grid cells. Uses `fourCharCode("GRDL")` signature. Supports up to 9 cells.
- **HUDController.swift** — Shows a green grid overlay when modifier keys are held (~200ms delay). Supports two-step multi-cell selection (press two numbers to span a bounding box). Uses `NSEvent.addGlobalMonitorForEvents` for modifier detection and `CGEvent` tap for key suppression.
- **HUDOverlayView.swift** — `NSView` subclass that draws the fullscreen grid overlay with numbered cells and selection highlighting.
- **WindowMover.swift** — Uses Accessibility API (`AXUIElement`) to get the focused window, determines which screen it's on, converts between AppKit (bottom-left origin) and Quartz/AX (top-left origin) coordinate systems, then repositions/resizes the window.
- **StatusBarController.swift** — Creates the menu-bar icon and hosts a `NSPopover` containing the SwiftUI `SettingsView`.
- **SettingsView.swift** — SwiftUI popover UI: layout picker, grid preview, modifier key toggles, add/remove layout controls, quit button.
- **main.swift** — Entry point. Sets up the app as `.accessory`, checks Accessibility permission, and starts the run loop.

### Package structure

- **GriddleLib** — Library target containing all logic (testable). Sources in `Sources/GriddleLib/`.
- **Griddle** — Thin executable target (`Sources/Griddle/main.swift` only), imports `GriddleLib`.
- **GriddleTests** — Test target (`Tests/GriddleTests/`), imports `GriddleLib`. Uses Swift Testing framework (`import Testing`, `@Suite`, `@Test`, `#expect`).
- Types and methods used across modules need `public` access modifiers.

### Platform details

- Requires macOS 13+ (Ventura). Swift tools version 5.9.
- Uses Carbon Event API for global hotkeys (no modern replacement exists).
- Accessibility permission is mandatory — the app prompts on first launch and exits if not granted.