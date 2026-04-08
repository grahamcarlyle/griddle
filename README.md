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
- **Cycle layouts** — modifier + Space to show HUD and cycle through layouts (configurable key)
- **Configurable modifiers** — any combination of Ctrl, Option, Cmd, Shift
- **Runs in the menu bar** — no Dock icon, minimal footprint
- **Launch at login** — start tiling automatically

## How it works

With the default layout (2×2) and modifier keys (Ctrl+Alt):

**Quick move:** Press Ctrl+Alt+Q to instantly move the window to the top-left cell.

**Cycle layouts:** Press Ctrl+Alt+Space to show the HUD with the current layout. Press again to cycle to the next layout, then select a cell.

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

## Alternatives

macOS 15 Sequoia adds edge and corner snapping via Option-drag, which covers the basics for many users. If you need more, here is how the common options compare:

| Tool | Price | Interaction model | Visual HUD | Arbitrary grid | Multi-cell span |
|---|---|---|---|---|---|
| **Griddle** | Free | Hold modifier → press key(s) | Yes | Yes (custom layouts) | Yes |
| macOS 15 built-in | Free | Mouse drag to edge/corner | No | No (fixed zones only) | No |
| Rectangle | Free | Drag to edge or keyboard shortcut | No | No (fixed positions) | No |
| Magnet | $3 | Drag to edge or keyboard shortcut | No | No (fixed positions) | No |
| Moom | $15 | Hover green button or shortcuts | Partial (button pop-up) | Yes (saved layouts) | Yes |
| BetterSnapTool | $3 | Modifier + drag | No | Yes (custom snap areas) | No |
| Amethyst | Free | Automatic (xmonad-style tiling) | No | — | — |
| Yabai | Free | CLI / scripting | No | — | — |

**Prefer Griddle if** you want to place windows without touching the mouse, see exactly where a window will land before it snaps, and define your own grid rather than working from a fixed set of positions.

**Prefer Rectangle or Magnet if** drag-to-edge snapping or a handful of keyboard shortcuts covers your workflow and you don't need a visual overlay.

**Prefer Moom if** you need saved multi-app layouts, per-app rules, or pixel-level positioning.

**Prefer Amethyst or Yabai if** you want windows to tile themselves automatically rather than placing them manually.

## Requirements

- macOS 13 (Ventura) or later
- Swift toolchain (managed via [mise](https://mise.jdx.dev/))
- Accessibility permission (prompted on first launch)

## Build & Run

```bash
./build.sh                                       # Build + package as .app bundle (ad-hoc signed)
./install.sh                                     # Install to /Applications and remove quarantine
open /Applications/Griddle.app                   # Run
```

For downloaded releases, unzip and run `./install.sh` (or pass a custom path: `./install.sh path/to/Griddle.app`).

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
- Change the layout cycle key (Space, Tab, /, 0, −, =)
- Enable launch at login

The config file lives at `~/.config/griddle/config.json` and is automatically updated when you change settings. You can also define custom layouts with non-uniform cells (different `colSpan`/`rowSpan`) directly in the JSON.
