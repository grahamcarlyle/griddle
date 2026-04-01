# Griddle

A macOS window grid utility inspired by GNOME Tactile. Assign focused windows to grid positions using global keyboard shortcuts.

## Features

- Global hotkeys move the frontmost window into a grid cell
- **HUD grid overlay** — hold modifier keys to see a visual grid with numbered cells
- **Multi-cell selection** — press two numbers to span a window across multiple cells (bounding box)
- Configurable grid layouts (2×2, 3×2, 3×3, or any custom grid)
- Menu-bar icon with settings popover
- Configurable modifier keys (Ctrl, Alt/Option, Cmd, Shift)
- Launch at login option
- Config persisted to `~/.config/griddle/config.json`

## How it works

With the default layout (2×2) and modifier keys (Ctrl+Alt):

**Quick move:** Press Ctrl+Alt+1 to instantly move the window to the top-left cell.

**HUD overlay:** Hold Ctrl+Alt for ~200ms to show a green grid overlay on screen. Then:
- Press a number key (1–4) to move the window to that cell
- Press two number keys to span the window across those cells (e.g. 1 then 4 = full screen)
- Press Escape or release the modifier keys to dismiss

Cells are numbered left-to-right, top-to-bottom:

| Key | Position (2×2) |
|-----|----------------|
| 1   | Top-left       |
| 2   | Top-right      |
| 3   | Bottom-left    |
| 4   | Bottom-right   |

## Requirements

- macOS 13 (Ventura) or later
- Swift toolchain (managed via [mise](https://mise.jdx.dev/))
- Accessibility permission (prompted on first launch)

## Build & Run

```bash
./build.sh                                       # Build + package as .app bundle (ad-hoc signed)
open .build/Griddle.app                          # Run
cp -r .build/Griddle.app /Applications/          # Install
```

## First launch

On first launch, Griddle will prompt for Accessibility permission. Grant it in:

**System Settings → Privacy & Security → Accessibility → Griddle**

Then relaunch the app.

## Configuration

Settings are available via the menu-bar icon (grid icon). You can:
- Switch between grid layouts
- Add custom layouts (up to 6 columns × 4 rows)
- Choose modifier keys
- Enable launch at login

The config file lives at `~/.config/griddle/config.json` and is automatically updated when you change settings. You can also define custom layouts with non-uniform cells (different `colSpan`/`rowSpan`) directly in the JSON.
