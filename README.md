# zen-bell

A gentle visual timer overlay for macOS. A horizontal bar of water slowly drains over your session, then a synthesized singing bowl plays when time's up.

Transparent, click-through, always-on-top. Designed to sit in the corner of a fullscreen terminal without feeling like you're racing against a clock.

![macOS](https://img.shields.io/badge/macOS-only-blue)

## Build

Requires Xcode Command Line Tools (`xcode-select --install`). No other dependencies.

```bash
swiftc -O -framework AppKit -framework AVFoundation zen-bell.swift -o zen-bell
```

## Usage

```bash
./zen-bell 60        # 60 minute session
./zen-bell 30        # 30 minute session
./zen-bell           # default: 45 minutes
./zen-bell stop      # stop a running session
```

**Option+drag** to reposition the overlay.

## Install globally

```bash
ln -s ~/Code/zen-bell/zen-bell /usr/local/bin/zen-bell
```

## Fullscreen

Native macOS fullscreen creates a separate Space that overlays can't penetrate. Add this to your Ghostty config for compatible fullscreen:

```
macos-non-native-fullscreen = true
```

## Customize

All visual parameters are constants at the top of `zen-bell.swift` — bar size, colors, opacity, corner radius, glow, breath speed. Edit and recompile.
