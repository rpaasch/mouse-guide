// Places the mouse cursor at a point on the main display, which is what the
// crosshair overlay tracks. Screenshot framing needs the pointer at a known
// spot; synthesising a key event instead trips macOS's "receive keystrokes
// from another app" prompt, which then lands in the shot.
// Usage: warpmouse <x> <y>   (points, origin top-left)
import CoreGraphics
import Foundation

guard CommandLine.arguments.count == 3,
      let x = Double(CommandLine.arguments[1]),
      let y = Double(CommandLine.arguments[2]) else {
    FileHandle.standardError.write("usage: warpmouse <x> <y>\n".data(using: .utf8)!)
    exit(2)
}

CGWarpMouseCursorPosition(CGPoint(x: x, y: y))
CGAssociateMouseAndMouseCursorPosition(1)
print("moved to \(Int(x)),\(Int(y))")
