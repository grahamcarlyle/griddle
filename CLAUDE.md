# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

```bash
swift build -c release          # Release build
./build.sh                      # Release build + package as .app bundle
./install.sh                    # Stop running Griddle, install to /Applications
open /Applications/Griddle.app  # Launch (requires Accessibility permission)
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
- Both `HotkeyManager` and `HUDController` maintain independent prefix key state machines. A prefix key in one path (e.g. Carbon hotkey) can trigger the HUD via `showHUDInPrefixMode()`, handing off to the HUD's event tap for the child key. The Huffman property (no key code is both a direct binding and a prefix key) prevents ambiguity.
- Carbon hotkeys and the HUD's CGEvent tap can both fire for the same keypress. `HotkeyManager` skips cell handling when `hudController.isHUDVisible` to avoid double-moves.
- JetBrains IDEs enable `AXEnhancedUserInterface` which causes AX position/size sets to revert. `RealDisplaySystem.setFrame` temporarily disables it (matching Rectangle, Loop, and Yabai).
- `HUDController.commitWeightsIfNeeded()` fires `onLayoutEdited` → `configStore.updateLayout` → Combine `$config.sink` → `hudController.update()` → `dismissHUD()`, which nils `editedLayout`. Any code that reads `editedLayout` after committing weights must capture it into a local variable first.

## Architecture

Griddle is a macOS menu-bar utility (Swift, SwiftUI, Swift Package Manager) that moves the focused window into grid cells via global hotkeys. It runs as an accessory app (no Dock icon).

**Key data flow:** `main.swift` boots the app, creates `ConfigStore`, `HotkeyManager`, and `HUDController`, injecting production implementations (`RealDisplaySystem`, `PanelHUDPresenter`, `RealInputSource`) and wiring them via a Combine `$config.sink`. When config changes, hotkeys and HUD are automatically re-registered. `HotkeyManager` cancels pending HUD shows on fast modifier+key combos. `KeyMap.build()` is called at registration time (HotkeyManager) and HUD show time (HUDController) to compute key-to-cell bindings, including prefix keys for large grids.

### Core components

- **GridLayout.swift** — Data models: `GridCell`, `GridLayout`, `GriddleConfig`, plus JSON persistence to `~/.config/griddle/config.json`. `GriddleConfig.default` provides built-in 2×2, 3×2, 3×3 layouts. `GridLayout` supports optional `columnWeights`/`rowWeights` for non-uniform proportions, with `columnOffsets()`/`rowOffsets()` computing normalised cumulative fractions.
- **ConfigStore.swift** — `ObservableObject` wrapper that auto-saves on every `config` mutation via `didSet`.
- **KeyMap.swift** — Trie-based key-to-cell mapping. `KeyBinding` is either `.direct(cellIndex)` or `.prefix(children)`. `KeyMap.build(for:columns:rows:)` allocates single-key bindings for cells that fit, and two-key prefix sequences for overflow (e.g. spatial grids with >3 rows use Z-row keys as prefixes, number grids with >9 cells use key 9+ as prefixes). Includes `UCKeyTranslate`-based label generation for keyboard-layout-aware display (Dvorak, Colemak, etc.) with QWERTY fallback.
- **DisplaySystem.swift** — `DisplaySystem` protocol abstracting screen enumeration and window movement, plus `InputSource`/`InputHandler` protocols for input event delivery. `RealDisplaySystem.swift` wraps NSScreen + AX APIs; `SimulatedDisplaySystem.swift` provides an in-memory model for headless testing.
- **HotkeyManager.swift** — Registers Carbon `EventHotKey` handlers mapping modifier+key combos to grid cells via `KeyMap`. Takes `DisplaySystem` and `InputSource` via DI. Uses `fourCharCode("GRDL")` signature. Manages prefix key state: when a prefix key fires, auto-shows HUD in prefix mode for the follow-up child key. Skips cell handling when the HUD is visible (the HUD's CGEvent tap handles input in that case).
- **HUDController.swift** — Shows a grid overlay on modifier tap-toggle. Takes `DisplaySystem`, `InputSource`, and `HUDPresenter` via DI. Supports two-step multi-cell selection (press two cell keys to span a bounding box) and prefix key state (press prefix key, then child key). `showHUDInPrefixMode()` is called by HotkeyManager when a prefix fires on the fast path. Shift+arrow edits column/row weights in the HUD: selected cells are equalised to uniform weight first, then scaled together, with non-selected cells compensating.
- **HUDPresenter.swift** — Protocol for HUD overlay presentation. `PanelHUDPresenter.swift` is the production implementation using NSPanel + `HUDOverlayView`; `NullHUDPresenter.swift` is a no-op for tests.
- **RealInputSource.swift** / **ScriptedInputSource.swift** — `InputSource` implementations. `RealInputSource` uses `NSEvent.addGlobalMonitorForEvents` for modifier detection and `CGEvent` tap for key suppression. `ScriptedInputSource` allows programmatic input injection for tests and demos.
- **HUDOverlayView.swift** — `NSView` subclass that draws the fullscreen grid overlay with labelled cells, selection highlighting, and prefix mode (dims unreachable cells, shows child key labels only). Font auto-scales for multi-character labels.
- **WindowMover.swift** — Pure geometry: computes target frames for grid cells on a screen and bounding cells for multi-cell spans. AX-based window movement and coordinate conversion now live in `RealDisplaySystem`.
- **StatusBarController.swift** — Creates the menu-bar icon and hosts a `NSPopover` containing the SwiftUI `SettingsView`.
- **SettingsView.swift** — SwiftUI popover UI: layout picker, grid preview, modifier key toggles, launch at login toggle (via `SMAppService`), add/remove layout controls, proportions sliders for column/row weights, quit button.
- **main.swift** — Entry point. Sets up the app as `.accessory`, wires production implementations, checks Accessibility permission, and starts the run loop.

### Package structure

- **GriddleLib** — Library target containing all logic (testable). Sources in `Sources/GriddleLib/`.
- **Griddle** — Thin executable target (`Sources/Griddle/main.swift` only), imports `GriddleLib`.
- **GriddleDemo** — Demo/snapshot executable target (`Sources/GriddleDemo/`). Uses `SimulatedDisplaySystem`, `ScriptedInputSource`, and `NullHUDPresenter` to run HUD scenarios headlessly for visual regression snapshots.
- **GriddleTests** — Test target (`Tests/GriddleTests/`), imports `GriddleLib`. Uses Swift Testing framework (`import Testing`, `@Suite`, `@Test`, `#expect`). Tests exercise `HUDController` via `SimulatedDisplaySystem`/`ScriptedInputSource`/`NullHUDPresenter`.
- Types and methods used across modules need `public` access modifiers.

### Platform details

- Requires macOS 13+ (Ventura). Swift tools version 5.9.
- Uses Carbon Event API for global hotkeys (no modern replacement exists).
- Accessibility permission is mandatory — the app prompts on first launch and exits if not granted.

## Release & distribution

CI (`.github/workflows/build.yml`) publishes a release on every push to `main`, tagged `v${{ github.run_number }}`. After publishing the versioned release, the **Bump cask in homebrew-tap** step clones `grahamcarlyle/homebrew-tap`, rewrites `version` and `sha256` in `Casks/g/griddle.rb`, and pushes — so anyone who installed via `brew install --cask grahamcarlyle/tap/griddle` gets the new build on `brew upgrade`.

- The bump step uses a fine-scoped PAT stored as the `TAP_REPO_PAT` secret on this repo (write access scoped to `homebrew-tap` only). The default `GITHUB_TOKEN` can't push to other repos.
- The cask's `livecheck` block uses a custom regex `/^v?(\d+)$/i` because build numbers are bare integers, not semver — the default `:github_latest` regex requires a dot.
- The cask has a `postflight` block that strips the `com.apple.quarantine` xattr after install. Without it, Gatekeeper blocks first launch because `build.sh` ad-hoc-signs the bundle (no Developer ID, no notarization). This mirrors what the bundled `install.sh` does.
- Versioned releases must NOT be marked `prerelease: true`; livecheck's `:github_latest` strategy hits `/releases/latest` which excludes prereleases. The rolling `latest` tag stays as a prerelease, which is fine — livecheck doesn't watch it.