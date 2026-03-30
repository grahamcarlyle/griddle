# Griddle

A macOS window grid utility inspired by GNOME Tactile. Assign focused windows to grid positions using global keyboard shortcuts.

## Features

- Global hotkeys move the frontmost window into a grid cell
- Configurable grid layouts (2×2, 3×2, 3×3, or any custom grid)
- Menu-bar icon with settings popover
- Visual grid preview with cell numbers
- Configurable modifier keys (Ctrl, Alt/Option, Cmd, Shift)
- Config persisted to `~/.config/griddle/config.json`

## How it works

With the default layout (2×2) and modifier keys (Ctrl+Alt):

| Key | Position |
|-----|----------|
| Ctrl+Alt+1 | Top-left |
| Ctrl+Alt+2 | Top-right |
| Ctrl+Alt+3 | Bottom-left |
| Ctrl+Alt+4 | Bottom-right |

For a 3×2 layout:

| Key | Position |
|-----|----------|
| Ctrl+Alt+1 | Row 1, Col 1 |
| Ctrl+Alt+2 | Row 1, Col 2 |
| Ctrl+Alt+3 | Row 1, Col 3 |
| Ctrl+Alt+4 | Row 2, Col 1 |
| Ctrl+Alt+5 | Row 2, Col 2 |
| Ctrl+Alt+6 | Row 2, Col 3 |

Cells are numbered left-to-right, top-to-bottom.

## Requirements

- macOS 13 (Ventura) or later
- Xcode or Swift toolchain
- Accessibility permission (prompted on first launch)

## Build & Run

```bash
cd griddle
swift build -c release
.build/release/Griddle
```

Or open in Xcode:

```bash
swift package generate-xcodeproj
open Griddle.xcodeproj
```

## First launch

On first launch, macOS will ask for Accessibility permission. Grant it in:

**System Settings → Privacy & Security → Accessibility → Griddle**

Then relaunch the app.

## Configuration

The config file lives at `~/.config/griddle/config.json`. It is automatically created and updated when you change settings via the menu-bar popover.

Example config:

```json
{
  "activeLayoutID": "2x2",
  "layouts": [
    {
      "id": "2x2",
      "name": "2×2",
      "columns": 2,
      "rows": 2,
      "cells": [
        {"col": 0, "row": 0, "colSpan": 1, "rowSpan": 1},
        {"col": 1, "row": 0, "colSpan": 1, "rowSpan": 1},
        {"col": 0, "row": 1, "colSpan": 1, "rowSpan": 1},
        {"col": 1, "row": 1, "colSpan": 1, "rowSpan": 1}
      ]
    }
  ],
  "modifier": {
    "keys": ["ctrl", "alt"]
  }
}
```

You can define custom layouts with non-uniform cells (different `colSpan`/`rowSpan`) directly in the JSON.
