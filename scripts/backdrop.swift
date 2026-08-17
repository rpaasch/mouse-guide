// A plain full-screen backdrop, so a screen recording cannot pick up whatever
// else is open. Hiding the other apps was tried first and is not reliable --
// Electron apps ignore "set visible to false", and the terminal running the
// script activates itself again. A window that physically covers the screen
// cannot fail in that way.
//
// Sits at normal window level and is ordered to the front, so other apps stay
// behind it while Cursor Sightline's own windows can still be raised above.
// The crosshair overlay is unaffected: it lives just below .cursorWindow, far
// above this.
//
// Runs until killed. Usage: backdrop [hex]   e.g. backdrop 1d2433
import Cocoa

let hex = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "1d2433"

func colour(_ hex: String) -> NSColor {
    var v: UInt64 = 0
    Scanner(string: hex).scanHexInt64(&v)
    return NSColor(
        red: CGFloat((v >> 16) & 0xff) / 255,
        green: CGFloat((v >> 8) & 0xff) / 255,
        blue: CGFloat(v & 0xff) / 255,
        alpha: 1)
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)   // no Dock icon of our own in the frame

var windows: [NSWindow] = []
for screen in NSScreen.screens {
    let w = NSWindow(
        contentRect: screen.frame,
        styleMask: .borderless,
        backing: .buffered,
        defer: false,
        screen: screen)
    w.backgroundColor = colour(hex)
    w.isOpaque = true
    w.hasShadow = false
    w.level = .normal
    // Stray clicks must not reach the apps underneath and pull them forward.
    w.ignoresMouseEvents = false
    w.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
    w.setFrame(screen.frame, display: true)
    w.orderFrontRegardless()
    windows.append(w)
}

app.run()
