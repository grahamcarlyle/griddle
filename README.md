<p align="center">
  <img src="griddle.png" width="128" alt="Griddle app icon">
</p>

<h1 align="center">Griddle</h1>

<p align="center">
  Tile your macOS windows with just the keyboard.<br>
  Tap a hotkey, see a grid, press a letter — done.
</p>

<p align="center">
  <img src="screenshot.png" width="720" alt="Griddle HUD overlay showing a 2×2 grid on the desktop">
</p>

Griddle is a lightweight menu-bar utility inspired by [GNOME Tactile](https://extensions.gnome.org/extension/4548/tactile/). It lets you snap the focused window into grid positions using global keyboard shortcuts — no mouse required. A translucent HUD overlay shows the grid so you always know where your windows will land.

## Highlights

- **Instant tiling** — modifier + letter key moves the focused window to a grid cell
- **Visual HUD** — tap modifier keys to toggle a grid overlay on screen
- **Spatial key mapping** — keys match grid positions (Q/W top row, A/S bottom row), or switch to number keys (1–9)
- **Multi-cell spanning** — press two keys to stretch a window across cells
- **Arrow key navigation** — use arrow keys and Enter to select cells without memorising key bindings
- **Customisable grids** — built-in 2×2, 3×2, 3×3 layouts, or create your own (up to 6×4)
- **Per-screen layouts** — assign different grids to different monitors
- **HUD themes** — System, Green, High Contrast, Purple, or Orange
- **Configurable modifiers** — any combination of Ctrl, Option, Cmd, Shift
- **Runs in the menu bar** — no Dock icon, minimal footprint
- **Launch at login** — start tiling automatically

## How it works

With the default layout (2×2) and modifier keys (Ctrl+Alt):

**Quick move:** Press Ctrl+Alt+Q to instantly move the window to the top-left cell.

**HUD overlay:** Tap and release Ctrl+Alt to toggle a grid overlay on screen. Then:
- Press a letter key to move the window to that cell
- Press two letter keys to span the window across those cells (e.g. Q then S = full screen)
- Use arrow keys to navigate the grid, then Enter to confirm
- Press two arrows to span across multiple cells (Enter after the first to set the anchor)
- Press Escape or tap the modifier keys again to dismiss

By default, keys are mapped spatially to match the grid layout:

| Key | Position (2×2) |
|-----|----------------|
| Q   | Top-left       |
| W   | Top-right      |
| A   | Bottom-left    |
| S   | Bottom-right   |

For larger grids the mapping extends across the keyboard rows (Q/W/E/R/T/Y, A/S/D/F/G/H, Z/X/C/V/B/N). You can switch to number keys (1–9) in the settings.

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
- Switch between grid layouts or add custom ones (up to 6 columns × 4 rows)
- Assign different layouts to different screens
- Choose between spatial letter keys (Q/W/A/S) or number keys (1–9)
- Pick a HUD colour theme
- Choose modifier keys
- Enable launch at login

The config file lives at `~/.config/griddle/config.json` and is automatically updated when you change settings. You can also define custom layouts with non-uniform cells (different `colSpan`/`rowSpan`) directly in the JSON.
