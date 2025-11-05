import AppKit
import Foundation

print("=== Screen Configuration Debug ===\n")

let screens = NSScreen.screens
print("Number of screens: \(screens.count)\n")

for (index, screen) in screens.enumerated() {
    print("Screen \(index):")
    print("  Frame: \(screen.frame)")
    print("  Visible Frame: \(screen.visibleFrame)")
    print("  Device Description: \(screen.deviceDescription)")
    if let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber {
        print("  Screen Number: \(screenNumber)")
    }
    print()
}

// Calculate union of all screens
var unionFrame = NSRect.zero
if let firstScreen = screens.first {
    unionFrame = firstScreen.frame
    for screen in screens.dropFirst() {
        unionFrame = unionFrame.union(screen.frame)
    }
}

print("Union of all screens:")
print("  Frame: \(unionFrame)")
print("  Origin: (\(unionFrame.origin.x), \(unionFrame.origin.y))")
print("  Size: \(unionFrame.width) x \(unionFrame.height)")
print()

// Test mouse position
print("Current mouse position: \(NSEvent.mouseLocation)")
print()

// Calculate what the window coordinates would be
let mouseLocation = NSEvent.mouseLocation
let windowX = mouseLocation.x - unionFrame.minX
let windowY = unionFrame.maxY - mouseLocation.y

print("Calculated window coordinates:")
print("  X: \(windowX)")
print("  Y: \(windowY)")
print()

print("Is mouse within union frame?")
print("  X in range: \(unionFrame.minX) <= \(mouseLocation.x) <= \(unionFrame.maxX)")
print("  Y in range: \(unionFrame.minY) <= \(mouseLocation.y) <= \(unionFrame.maxY)")
print("  Result: \(unionFrame.contains(mouseLocation))")
