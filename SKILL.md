---
name: zen-timer
description: Manage the zen-timer macOS overlay app — start/stop sessions, tweak visuals (colors, size, opacity, waves), rebuild after changes, and run tests. Use when saying /zen-timer, "start a timer", "change the timer", "tweak zen-timer", "stop the timer", or working on zen-timer code.
model: haiku
---

# zen-timer

Manage the zen-timer visual session timer — a single-file Swift/AppKit overlay for macOS.

## Source

`~/Code/zen-timer/zen-timer.swift` — the entire app in one file.

## Quick Commands

```bash
# Start a session
~/Code/zen-timer/zen-timer 60

# Stop a running session
~/Code/zen-timer/zen-timer stop

# Rebuild after code changes
cd ~/Code/zen-timer && swiftc -O -framework AppKit -framework AVFoundation zen-timer.swift -o zen-timer
```

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
| `colorStart` | (0.50, 0.72, 0.92) | Water color at session start (light blue) |
| `colorEnd` | (0.42, 0.62, 0.85) | Water color at session end |
| `opacityStart` | 0.55 | Starting opacity |
| `opacityEnd` | 0.30 | Ending opacity (fades as you settle in) |
| `breathPeriod` | 7.0 | Glow breathing cycle in seconds |
| `surfaceCount` | 4 | Number of floating particles |

## Workflow

1. Read the current source before making changes
2. Edit the Swift file
3. Rebuild: `cd ~/Code/zen-timer && swiftc -O -framework AppKit -framework AVFoundation zen-timer.swift -o zen-timer`
4. Stop any running instance: `~/Code/zen-timer/zen-timer stop`
5. Test with a short session: `~/Code/zen-timer/zen-timer 1 &`

## Fullscreen Note

Requires `macos-non-native-fullscreen = true` in Ghostty config to overlay fullscreen apps.
