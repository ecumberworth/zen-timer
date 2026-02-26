---
name: zen-timer
description: Manage the zen-timer macOS overlay app — start/stop sessions, tweak visuals (colors, size, opacity, waves), rebuild after changes, and run tests. Use when saying /zen-timer, "start a timer", "change the timer", "tweak zen-timer", "stop the timer", or working on zen-timer code.
model: haiku
---

# zen-timer

Manage the zen-timer visual session timer — a single-file Swift/AppKit overlay for macOS.

## Source

`zen-timer.swift` — the entire app in one file.

## Quick Commands

```bash
# Build
swiftc -O -framework AppKit -framework AVFoundation zen-timer.swift -o zen-timer

# Start a 60-minute session (default blue variant)
./zen-timer 60

# Start with a color variant (minutes + variant, either order)
./zen-timer 60 green
./zen-timer green 60
./zen-timer 60 slime    # alias for green

# Stop a running session
./zen-timer stop
```

## Color Variants

- **blue** (default) — soft light blue water
- **green** / **slime** — bright slimy green for mood changes

## Architecture

- Single Swift file, no Xcode project, no dependencies beyond macOS dev tools
- `NSWindow` at screensaver level (1000), borderless, transparent, click-through
- `ignoresMouseEvents = true` by default; Option key toggles for drag-to-reposition
- PID file at `/tmp/zen-timer.pid` for stop command
- Singing bowl WAV synthesized at launch (harmonics + decay + vibrato)
- 30fps animation timer drives the water drain visual
- Handles SIGINT (ctrl+c) and SIGTERM (from stop command) gracefully

## Tweakable Constants

All at the top of the file — edit and recompile:

| Constant | Current | What it does |
|----------|---------|-------------|
| `barWidth` | 140 | Water bar width in px |
| `barHeight` | 20 | Water bar height in px |
| `cornerRadius` | 8 | Rounded ends |
| `edgeMargin` | 12 | Distance from screen corner |
| `colorSchemes` | (dict) | Color palettes for variants |
| `opacityStart` | varies | Starting opacity (scheme-dependent) |
| `opacityEnd` | varies | Ending opacity (scheme-dependent) |
| `breathPeriod` | 7.0 | Glow breathing cycle in seconds |
| `surfaceCount` | 4 | Number of floating particles |

## Workflow

1. Read the current source before making changes
2. Edit the Swift file (add new schemes to `colorSchemes` dict)
3. Rebuild: `swiftc -O -framework AppKit -framework AVFoundation zen-timer.swift -o zen-timer`
4. Stop any running instance: `./zen-timer stop`
5. Test with a short session: `./zen-timer 1 variantname &`

## Adding New Variants

Edit the `colorSchemes` dictionary at the top:

```swift
"mycolor": (
    start: (r: CGFloat(0.xx), g: CGFloat(0.xx), b: CGFloat(0.xx)),
    end:   (r: CGFloat(0.xx), g: CGFloat(0.xx), b: CGFloat(0.xx)),
    opacityStart: 0.xx,
    opacityEnd: 0.xx
),
```

Then rebuild and test: `./zen-timer 1 mycolor`

## Fullscreen Note

Requires `macos-non-native-fullscreen = true` in Ghostty config to overlay fullscreen apps.
