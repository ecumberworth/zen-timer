// zen-timer — a gentle visual timer for macOS
// Build:  swiftc -O -framework AppKit -framework AVFoundation zen-timer.swift -o zen-timer
// Usage:  ./zen-timer [minutes]   (default: 45)
//         ./zen-timer stop
//         Option+drag to reposition

import AppKit
import AVFoundation

let pidPath = "/tmp/zen-timer.pid"

// ─── Stop Command ──────────────────────────────────────────────

if CommandLine.arguments.count > 1 && CommandLine.arguments[1] == "stop" {
    if let pidStr = try? String(contentsOfFile: pidPath, encoding: .utf8),
       let pid = Int32(pidStr.trimmingCharacters(in: .whitespacesAndNewlines)) {
        kill(pid, SIGTERM)
        try? FileManager.default.removeItem(atPath: pidPath)
        print("zen-timer: stopped")
    } else {
        print("zen-timer: not running")
    }
    exit(0)
}

// ─── Tweak These ───────────────────────────────────────────────

let sessionMinutes: Double = {
    if CommandLine.arguments.count > 1, let m = Double(CommandLine.arguments[1]) { return m }
    return 45
}()

let barWidth:     CGFloat = 140     // the water bar width
let barHeight:    CGFloat = 20      // the water bar height
let cornerRadius: CGFloat = 8       // rounded ends
let glowPad:      CGFloat = 12      // padding around bar for glow
let edgeMargin:   CGFloat = 12      // from screen corner
let breathPeriod          = 7.0
let surfaceCount          = 4       // particles near the water edge

// Soft light blue water
let colorStart = (r: CGFloat(0.50), g: CGFloat(0.72), b: CGFloat(0.92))
let colorEnd   = (r: CGFloat(0.42), g: CGFloat(0.62), b: CGFloat(0.85))
let opacityStart: CGFloat = 0.55
let opacityEnd:   CGFloat = 0.30

// Derived window size (bar + glow padding)
let windowWidth  = barWidth + glowPad * 2
let windowHeight = barHeight + glowPad * 2

// ─── Singing Bowl Sound ────────────────────────────────────────

func generateBowlSound() -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("zen-bowl.wav")
    let sr = 44100
    let duration = 12.0
    let n = Int(Double(sr) * duration)

    let harmonics: [(Double, Double, Double)] = [
        (262.0,  0.35, 0.22),
        (393.0,  0.12, 0.32),
        (786.0,  0.22, 0.38),
        (1310.0, 0.08, 0.55),
        (1834.0, 0.04, 0.75),
        (264.5,  0.09, 0.25),
    ]

    var pcm = Data(capacity: n * 2)
    for i in 0..<n {
        let t = Double(i) / Double(sr)
        var sample = 0.0
        for (freq, amp, decay) in harmonics {
            sample += amp * sin(2 * .pi * freq * t) * exp(-decay * t)
        }
        sample *= min(1.0, t / 0.008) * (1.0 + 0.015 * sin(2 * .pi * 5.2 * t))
        let clamped = Int16(clamping: Int(sample * 32000))
        withUnsafeBytes(of: clamped.littleEndian) { pcm.append(contentsOf: $0) }
    }

    var wav = Data()
    func w32(_ v: UInt32) { withUnsafeBytes(of: v.littleEndian) { wav.append(contentsOf: $0) } }
    func w16(_ v: UInt16) { withUnsafeBytes(of: v.littleEndian) { wav.append(contentsOf: $0) } }

    wav.append(contentsOf: "RIFF".utf8); w32(UInt32(36 + pcm.count))
    wav.append(contentsOf: "WAVE".utf8)
    wav.append(contentsOf: "fmt ".utf8); w32(16); w16(1); w16(1)
    w32(UInt32(sr)); w32(UInt32(sr * 2)); w16(2); w16(16)
    wav.append(contentsOf: "data".utf8); w32(UInt32(pcm.count))
    wav.append(pcm)
    try! wav.write(to: url)
    return url
}

// ─── Organic Drift ─────────────────────────────────────────────

func drift(_ t: Double, _ seed: Double) -> Double {
    sin(t * 0.7 + seed) * 0.5 +
    sin(t * 1.3 + seed * 2.1) * 0.3 +
    sin(t * 2.9 + seed * 0.7) * 0.2
}

// ─── Surface Particle ──────────────────────────────────────────

struct Floater {
    var seedX: Double
    var seedBob: Double
}

// ─── Overlay View ──────────────────────────────────────────────

class ZenView: NSView {
    var floaters: [Floater] = []
    let startTime = Date()
    let duration: TimeInterval
    let bowlURL: URL
    var player: AVAudioPlayer?
    var bowlPlayed = false
    var sessionDone: Date?
    var fading = false
    var animTimer: Timer?

    init(frame: NSRect, duration: TimeInterval, bowlURL: URL) {
        self.duration = duration
        self.bowlURL = bowlURL
        super.init(frame: frame)
        wantsLayer = true

        for _ in 0..<surfaceCount {
            floaters.append(Floater(
                seedX: .random(in: 0..<100),
                seedBob: .random(in: 0..<100)
            ))
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    func start() {
        animTimer = Timer.scheduledTimer(withTimeInterval: 1.0/30, repeats: true) {
            [weak self] _ in self?.tick()
        }
    }

    func tick() {
        let elapsed = Date().timeIntervalSince(startTime)
        let progress = min(1.0, elapsed / duration)

        if progress >= 1.0 && !bowlPlayed {
            bowlPlayed = true
            player = try? AVAudioPlayer(contentsOf: bowlURL)
            player?.play()
            sessionDone = Date()
        }

        if let doneTime = sessionDone,
           Date().timeIntervalSince(doneTime) > 14,
           !fading {
            fading = true
            animTimer?.invalidate()
            NSAnimationContext.beginGrouping()
            NSAnimationContext.current.duration = 3.0
            window?.animator().alphaValue = 0
            NSAnimationContext.endGrouping()
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                NSApplication.shared.terminate(nil)
            }
        }

        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.clear(bounds)

        let elapsed = Date().timeIntervalSince(startTime)
        let progress = CGFloat(min(1.0, elapsed / duration))
        let t = elapsed

        // Color
        let cr = colorStart.r + (colorEnd.r - colorStart.r) * progress
        let cg = colorStart.g + (colorEnd.g - colorStart.g) * progress
        let cb = colorStart.b + (colorEnd.b - colorStart.b) * progress
        let breath = 1.0 + 0.03 * CGFloat(sin(t * 2 * .pi / breathPeriod))
        let alpha = (opacityStart + (opacityEnd - opacityStart) * progress) * breath

        let space = CGColorSpaceCreateDeviceRGB()

        let barRect = CGRect(
            x: glowPad, y: glowPad,
            width: barWidth, height: barHeight
        )
        let barPath = CGPath(
            roundedRect: barRect,
            cornerWidth: cornerRadius, cornerHeight: cornerRadius,
            transform: nil
        )

        // Soft glow
        ctx.saveGState()
        ctx.setShadow(
            offset: .zero, blur: 10,
            color: CGColor(colorSpace: space, components: [cr, cg, cb, alpha * 0.15])!
        )
        ctx.setFillColor(CGColor(colorSpace: space, components: [cr, cg, cb, alpha * 0.04])!)
        ctx.addPath(barPath)
        ctx.fillPath()
        ctx.restoreGState()

        // Vessel outline — visible enough to gauge remaining time
        ctx.setStrokeColor(CGColor(
            colorSpace: space, components: [cr, cg, cb, alpha * 0.22]
        )!)
        ctx.setLineWidth(0.75)
        ctx.addPath(barPath)
        ctx.strokePath()

        // ─── Water fill ────────────────────────────────────────
        let level = 1.0 - progress
        if level > 0.005 {
            let fillWidth = level * barRect.width
            let surfaceX = barRect.minX + fillWidth

            // Clip to bar shape
            ctx.saveGState()
            ctx.addPath(barPath)
            ctx.clip()

            // Build water shape with wavy top and wavy right edge
            let waterPath = CGMutablePath()

            // Bottom edge: left to right
            waterPath.move(to: CGPoint(x: barRect.minX - 1, y: barRect.minY - 1))
            waterPath.addLine(to: CGPoint(x: surfaceX + 3, y: barRect.minY - 1))

            // Right edge: meniscus going up (layered waves)
            var y = barRect.minY
            while y <= barRect.maxY {
                let wx = surfaceX
                    + 1.2 * CGFloat(sin(Double(y - barRect.minY) / 4.0 + t * 1.1))
                    + 0.6 * CGFloat(sin(Double(y - barRect.minY) / 2.5 + t * 0.7 + 1.3))
                waterPath.addLine(to: CGPoint(x: wx, y: y))
                y += 0.5
            }

            // Top edge: ocean surface waves going right to left
            var x = surfaceX
            while x >= barRect.minX - 1 {
                let wy = barRect.maxY
                    + 1.2 * CGFloat(sin(Double(x) / 14.0 + t * 0.6))
                    + 0.5 * CGFloat(sin(Double(x) / 7.0 + t * 1.3 + 2.0))
                    + 0.3 * CGFloat(sin(Double(x) / 4.0 + t * 0.4 + 4.5))
                waterPath.addLine(to: CGPoint(x: x, y: wy))
                x -= 1
            }

            waterPath.closeSubpath()

            // Clip to water shape, draw gradient + ripples
            ctx.saveGState()
            ctx.addPath(waterPath)
            ctx.clip()

            // Vertical gradient: dark depths → bright middle → surface sheen
            let deepColor = CGColor(
                colorSpace: space, components: [cr * 0.7, cg * 0.7, cb * 0.8, alpha * 0.30]
            )!
            let midColor = CGColor(
                colorSpace: space, components: [cr, cg, cb, alpha * 0.42]
            )!
            let surfColor = CGColor(
                colorSpace: space, components: [
                    min(1, cr * 1.15), min(1, cg * 1.1), min(1, cb * 1.05),
                    alpha * 0.35
                ]
            )!
            if let fillGrad = CGGradient(
                colorsSpace: space,
                colors: [deepColor, midColor, surfColor] as CFArray,
                locations: [0, 0.55, 1]
            ) {
                ctx.drawLinearGradient(
                    fillGrad,
                    start: CGPoint(x: barRect.midX, y: barRect.minY),
                    end: CGPoint(x: barRect.midX, y: barRect.maxY + 2),
                    options: []
                )
            }

            // Internal ripple lines — light refracting through water
            ctx.setLineWidth(0.5)
            for ry in stride(from: barRect.minY + 4, to: barRect.maxY - 2, by: 4.5) {
                let rippleAlpha = alpha * 0.07 * (1.0 - (ry - barRect.minY) / barRect.height * 0.5)
                ctx.setStrokeColor(CGColor(
                    colorSpace: space, components: [1, 1, 1, rippleAlpha]
                )!)
                let ripple = CGMutablePath()
                var first = true
                var rx = barRect.minX
                while rx <= surfaceX {
                    let rwy = ry
                        + 0.7 * CGFloat(sin(Double(rx) / 11.0 + t * 0.4 + Double(ry) * 0.3))
                        + 0.3 * CGFloat(sin(Double(rx) / 5.0 + t * 0.7 + Double(ry) * 0.5))
                    if first { ripple.move(to: CGPoint(x: rx, y: rwy)); first = false }
                    else { ripple.addLine(to: CGPoint(x: rx, y: rwy)) }
                    rx += 1
                }
                ctx.addPath(ripple)
                ctx.strokePath()
            }

            ctx.restoreGState()  // water clip
            ctx.restoreGState()  // bar clip

            // ─── Floaters near the water's edge ────────────────
            for fl in floaters {
                let bob = CGFloat(drift(t * 0.5, fl.seedBob))
                let py = barRect.midY + bob * (barRect.height * 0.3)
                let nx = CGFloat(drift(t * 0.12, fl.seedX))
                let px = surfaceX - 8 + nx * 5

                if px > barRect.minX + 2 && px < surfaceX + 1 {
                    let dotColor = CGColor(
                        colorSpace: space, components: [
                            min(1, cr * 1.2), min(1, cg * 1.15), min(1, cb * 1.1),
                            alpha * 0.5
                        ]
                    )!
                    ctx.setShadow(offset: .zero, blur: 2.5, color: dotColor)
                    ctx.setFillColor(dotColor)
                    ctx.fillEllipse(in: CGRect(
                        x: px - 1, y: py - 1, width: 2, height: 2
                    ))
                }
            }
        }
    }
}

// ─── Draggable Window ──────────────────────────────────────────

class ZenWindow: NSWindow {
    var isDragging = false
    var dragOffset = NSPoint.zero

    override func mouseDown(with event: NSEvent) {
        dragOffset = event.locationInWindow
        isDragging = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard isDragging else { return }
        let screen = NSEvent.mouseLocation
        setFrameOrigin(NSPoint(
            x: screen.x - dragOffset.x,
            y: screen.y - dragOffset.y
        ))
    }

    override func mouseUp(with event: NSEvent) {
        isDragging = false
        ignoresMouseEvents = true
    }
}

// ─── App Delegate ──────────────────────────────────────────────

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: ZenWindow!
    var flagsMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let screen = NSScreen.main!.visibleFrame

        window = ZenWindow(
            contentRect: NSRect(
                x: screen.maxX - windowWidth - edgeMargin,
                y: screen.minY + edgeMargin,
                width: windowWidth, height: windowHeight
            ),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.level = NSWindow.Level(rawValue: 1000)
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        window.isOpaque = false
        window.backgroundColor = .clear
        window.ignoresMouseEvents = true
        window.hasShadow = false

        flagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) {
            [weak self] event in
            guard let w = self?.window else { return }
            if event.modifierFlags.contains(.option) {
                w.ignoresMouseEvents = false
            } else if !w.isDragging {
                w.ignoresMouseEvents = true
            }
        }

        let bowlURL = generateBowlSound()
        let view = ZenView(
            frame: NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight),
            duration: sessionMinutes * 60,
            bowlURL: bowlURL
        )
        window.contentView = view
        window.orderFrontRegardless()
        view.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        try? FileManager.default.removeItem(atPath: pidPath)
    }
}

// ─── Main ──────────────────────────────────────────────────────

try? "\(ProcessInfo.processInfo.processIdentifier)"
    .write(toFile: pidPath, atomically: true, encoding: .utf8)

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let delegate = AppDelegate()
app.delegate = delegate

signal(SIGINT, SIG_IGN)
let sigSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
sigSource.setEventHandler { NSApplication.shared.terminate(nil) }
sigSource.resume()

signal(SIGTERM, SIG_IGN)
let termSource = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
termSource.setEventHandler { NSApplication.shared.terminate(nil) }
termSource.resume()

print("zen-timer: \(Int(sessionMinutes))m \u{2014} `zen-timer stop` to end \u{2014} option+drag to move")
app.run()
