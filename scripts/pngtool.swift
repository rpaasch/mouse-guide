// Two jobs for the screenshot pipeline:
//   solid   <w> <h> <rrggbb> <out>  - a flat desktop picture, so the translucent
//                                     menu bar has nothing interesting to blend
//   flatten <in> <out>              - drop the alpha channel; App Store Connect
//                                     rejects screenshots that carry one
import AppKit
import Foundation

func write(_ image: CGImage, to path: String) -> Bool {
    let rep = NSBitmapImageRep(cgImage: image)
    guard let data = rep.representation(using: .png, properties: [:]) else { return false }
    return (try? data.write(to: URL(fileURLWithPath: path))) != nil
}

func opaqueContext(width: Int, height: Int) -> CGContext? {
    CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
              space: CGColorSpaceCreateDeviceRGB(),
              bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
}

let args = CommandLine.arguments
switch args.count >= 2 ? args[1] : "" {
case "solid":
    guard args.count == 6, let w = Int(args[2]), let h = Int(args[3]),
          let rgb = Int(args[4], radix: 16), let ctx = opaqueContext(width: w, height: h) else { exit(2) }
    ctx.setFillColor(red: CGFloat((rgb >> 16) & 0xFF) / 255,
                     green: CGFloat((rgb >> 8) & 0xFF) / 255,
                     blue: CGFloat(rgb & 0xFF) / 255, alpha: 1)
    ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
    guard let img = ctx.makeImage(), write(img, to: args[5]) else { exit(1) }

case "flatten":
    guard args.count == 4,
          let src = NSImage(contentsOfFile: args[2])?.cgImage(forProposedRect: nil, context: nil, hints: nil),
          let ctx = opaqueContext(width: src.width, height: src.height) else { exit(2) }
    ctx.draw(src, in: CGRect(x: 0, y: 0, width: src.width, height: src.height))
    guard let img = ctx.makeImage(), write(img, to: args[3]) else { exit(1) }

default:
    FileHandle.standardError.write("usage: pngtool solid <w> <h> <rrggbb> <out> | flatten <in> <out>\n".data(using: .utf8)!)
    exit(2)
}
