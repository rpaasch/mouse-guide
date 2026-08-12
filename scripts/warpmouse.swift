// Places the mouse cursor at a point on the main display, which is what the
// crosshair overlay tracks. Screenshot framing needs the pointer at a known
// spot; synthesising a key event instead trips macOS's "receive keystrokes
// from another app" prompt, which then lands in the shot.
// A trailing "click" also presses the left button, which is needed to reach
// panes the app cannot be launched straight into. Mouse events are safe here;
// it is synthetic *key* events that trip the keystroke-receiving prompt.
// Usage: warpmouse <x> <y> [click]   (points, origin top-left)
import CoreGraphics
import Foundation

guard CommandLine.arguments.count >= 3,
      let x = Double(CommandLine.arguments[1]),
      let y = Double(CommandLine.arguments[2]) else {
    FileHandle.standardError.write("usage: warpmouse <x> <y> [click]\n".data(using: .utf8)!)
    exit(2)
}

let point = CGPoint(x: x, y: y)
CGWarpMouseCursorPosition(point)
CGAssociateMouseAndMouseCursorPosition(1)

if CommandLine.arguments.count > 3, CommandLine.arguments[3] == "click" {
    for type in [CGEventType.leftMouseDown, .leftMouseUp] {
        CGEvent(mouseEventSource: nil, mouseType: type,
                mouseCursorPosition: point, mouseButton: .left)?.post(tap: .cghidEventTap)
        usleep(60_000)
    }
    print("clicked \(Int(x)),\(Int(y))")
} else {
    print("moved to \(Int(x)),\(Int(y))")
}
