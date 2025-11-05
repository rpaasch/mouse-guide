import AppKit
import SwiftUI

class TestWindow: NSWindow {
    init(for screen: NSScreen) {
        super.init(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false,
            screen: screen
        )

        self.isOpaque = false
        self.backgroundColor = NSColor.red.withAlphaComponent(0.3)
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .stationary]
        self.ignoresMouseEvents = true

        print("Created window for screen: \(screen.frame)")
        print("  Window frame: \(self.frame)")
        print("  Window content view frame: \(self.contentView?.frame ?? .zero)")
        print("  Backing scale factor: \(self.backingScaleFactor)")
    }
}

print("=== Testing Window Sizes ===\n")

let app = NSApplication.shared
app.setActivationPolicy(.regular)

var windows: [NSWindow] = []

for (index, screen) in NSScreen.screens.enumerated() {
    print("Screen \(index): \(screen.frame)")
    let window = TestWindow(for: screen)
    windows.append(window)
    window.orderFrontRegardless()
}

print("\nWindows created. They should appear as red overlays on each screen.")
print("Press Ctrl+C to quit")

app.run()
