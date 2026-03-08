# zen-timer

A gentle visual timer overlay for macOS. A horizontal bar of water slowly drains over your session, then a synthesized singing bowl plays when time's up.

Transparent, click-through, always-on-top. Designed to sit in the corner of a fullscreen terminal without feeling like you're racing against a clock.

![macOS](https://img.shields.io/badge/macOS-only-blue)

## Build

Requires Xcode Command Line Tools (`xcode-select --install`). No other dependencies.

```bash
swiftc -O -framework AppKit -framework AVFoundation zen-timer.swift -o zen-timer
```

## Usage

```bash
./zen-timer 60        # 60 minute session
./zen-timer 30        # 30 minute session
./zen-timer           # default: 45 minutes
./zen-timer stop      # stop a running session
./zen-timer 25 sunset # 25 minutes, sunset theme
```

### Color themes

| Theme | Mood |
|-------|------|
| `blue` | Calm sky (default) |
| `green` / `slime` | Fresh and lively |
| `sunset` | Warm amber fading to rose |
| `lavender` | Soft violet twilight |
| `ocean` | Deep teal waters |
| `ember` | Glowing coals, gold to red |
| `rose` | Gentle pink warmth |

```bash
./zen-timer 45 lavender
./zen-timer ocean
```

**Option+drag** to reposition the overlay.

## Install globally

```bash
ln -s ~/Code/zen-timer/zen-timer /usr/local/bin/zen-timer
```

## Fullscreen

Native macOS fullscreen creates a separate Space that overlays can't penetrate. Add this to your Ghostty config for compatible fullscreen:

```
macos-non-native-fullscreen = true
```

## Customize

All visual parameters are constants at the top of `zen-timer.swift` — bar size, colors, opacity, corner radius, glow, breath speed. Edit and recompile.
