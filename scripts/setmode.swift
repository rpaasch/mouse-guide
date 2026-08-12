// Switches the main display to a mode whose backing store is exactly WxH
// pixels, so screencapture lands on an App Store accepted size with no
// rescaling. Usage: setmode <pixelWidth> <pixelHeight>
import CoreGraphics
import Foundation

guard CommandLine.arguments.count == 3,
      let wantW = Int(CommandLine.arguments[1]),
      let wantH = Int(CommandLine.arguments[2]) else {
    FileHandle.standardError.write("usage: setmode <pixelWidth> <pixelHeight>\n".data(using: .utf8)!)
    exit(2)
}

let display = CGMainDisplayID()
let opts = [kCGDisplayShowDuplicateLowResolutionModes as String: true] as CFDictionary
guard let modes = CGDisplayCopyAllDisplayModes(display, opts) as? [CGDisplayMode] else {
    FileHandle.standardError.write("could not enumerate modes\n".data(using: .utf8)!)
    exit(1)
}

// Prefer the HiDPI variant: same pixel size, half the point size, so text and
// UI stay at Retina density instead of being drawn at 1x and looking coarse.
let candidates = modes.filter {
    $0.pixelWidth == wantW && $0.pixelHeight == wantH && $0.isUsableForDesktopGUI()
}
guard let mode = candidates.min(by: { $0.width < $1.width }) else {
    FileHandle.standardError.write("no usable mode with backing store \(wantW)x\(wantH)\n".data(using: .utf8)!)
    exit(1)
}

var config: CGDisplayConfigRef?
guard CGBeginDisplayConfiguration(&config) == .success else { exit(1) }
CGConfigureDisplayWithDisplayMode(config, display, mode, nil)
guard CGCompleteDisplayConfiguration(config, .permanently) == .success else {
    FileHandle.standardError.write("configuration failed\n".data(using: .utf8)!)
    exit(1)
}

print("set \(mode.width)x\(mode.height) points, \(mode.pixelWidth)x\(mode.pixelHeight) pixels")
