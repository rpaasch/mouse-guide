import Foundation
import AppKit

// Light reticle: a thin ring and four ticks with a centre void.
// One accent, one ground, no material simulation at all.

struct P { let name: String
           let g1:(CGFloat,CGFloat,CGFloat); let g2:(CGFloat,CGFloat,CGFloat)
           let mark:(CGFloat,CGFloat,CGFloat) }
func C(_ t:(CGFloat,CGFloat,CGFloat), _ a: CGFloat = 1) -> CGColor { CGColor(red:t.0,green:t.1,blue:t.2,alpha:a) }

let tileF: CGFloat = 824.0/1024.0, cornerF: CGFloat = 185.4/824.0

func draw(_ p: P, size: CGFloat) -> NSBitmapImageRep {
    let px = Int(size)
    let rep = NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:px,pixelsHigh:px,bitsPerSample:8,
        samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
    NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext
    ctx.setAllowsAntialiasing(true)

    let tile = (size*tileF).rounded(), o = ((size-tile)/2).rounded()
    let rect = CGRect(x:o,y:o,width:tile,height:tile)
    let path = CGPath(roundedRect: rect, cornerWidth: tile*cornerF, cornerHeight: tile*cornerF, transform: nil)
    let sp = CGColorSpaceCreateDeviceRGB()
    let small = tile < 64

    ctx.saveGState(); ctx.addPath(path); ctx.clip()
    let grad = CGGradient(colorsSpace: sp, colors: [C(p.g1), C(p.g2)] as CFArray, locations: [0,1])!
    ctx.drawLinearGradient(grad, start: CGPoint(x:rect.minX,y:rect.maxY),
                           end: CGPoint(x:rect.maxX,y:rect.minY), options: [])
    ctx.restoreGState()

    // The mark. Weight grows as the canvas shrinks so it never disappears.
    let cx = rect.midX, cy = rect.midY
    let R  = tile * 0.300
    let w  = tile * (small ? 0.075 : 0.042)      // stroke
    let gap = tile * (small ? 0.075 : 0.095)     // half the centre void
    let over = tile * (small ? 0.0 : 0.055)      // how far ticks pass the ring

    ctx.setStrokeColor(C(p.mark))
    ctx.setFillColor(C(p.mark))
    ctx.setLineWidth(w)
    ctx.setLineCap(.butt)

    // ring
    ctx.addArc(center: CGPoint(x:cx,y:cy), radius: R, startAngle: 0, endAngle: .pi*2, clockwise: false)
    ctx.strokePath()

    // four ticks, crossing the ring, stopping short of the centre
    let reach = R + over
    for (dx, dy) in [(-1.0,0.0),(1.0,0.0),(0.0,-1.0),(0.0,1.0)] {
        let x0 = cx + CGFloat(dx)*gap, y0 = cy + CGFloat(dy)*gap
        let x1 = cx + CGFloat(dx)*reach, y1 = cy + CGFloat(dy)*reach
        ctx.move(to: CGPoint(x:x0,y:y0)); ctx.addLine(to: CGPoint(x:x1,y:y1))
    }
    ctx.strokePath()

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let chosen = P(name:"sightline", g1:(0.361,0.180,0.694), g2:(0.145,0.055,0.310), mark:(1,1,1))

let sizes: [(Int,String)] = [
    (16,"icon_16x16_1x_16.png"), (32,"icon_16x16_2x_32.png"),
    (32,"icon_32x32_1x_32.png"), (64,"icon_32x32_2x_64.png"),
    (128,"icon_128x128_1x_128.png"), (256,"icon_128x128_2x_256.png"),
    (256,"icon_256x256_1x_256.png"), (512,"icon_256x256_2x_512.png"),
    (512,"icon_512x512_1x_512.png"), (1024,"icon_512x512_2x_1024.png"),
]

let dir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/tmp/final"
try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
for (s,n) in sizes {
    let rep = draw(chosen, size: CGFloat(s))
    try! rep.representation(using:.png,properties:[:])!.write(to: URL(fileURLWithPath:"\(dir)/\(n)"))
}
print("gengivet i \(dir)")

// kontaktark ved sm\u{00e5} st\u{00f8}rrelser, forst\u{00f8}rret uden udj\u{00e6}vning
let shown = [16,32,64,128], pad = 8
let SW = shown.reduce(0){$0+$1+pad}+pad, SH = 128+pad*2
let sh = NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:SW,pixelsHigh:SH,bitsPerSample:8,
    samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: sh)
let g2c = NSGraphicsContext.current!.cgContext
g2c.setFillColor(CGColor(gray:0.60,alpha:1)); g2c.fill(CGRect(x:0,y:0,width:SW,height:SH))
var xx = pad
for s in shown {
    let rep = draw(chosen, size: CGFloat(s))
    g2c.draw(rep.cgImage!, in: CGRect(x:xx, y:SH-pad-s, width:s, height:s)); xx += s+pad
}
NSGraphicsContext.restoreGraphicsState()
let bw = SW*6, bh = SH*6
let big = NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:bw,pixelsHigh:bh,bitsPerSample:8,
    samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: big)
let bc = NSGraphicsContext.current!.cgContext
bc.interpolationQuality = .none
bc.draw(sh.cgImage!, in: CGRect(x:0,y:0,width:bw,height:bh))
NSGraphicsContext.restoreGraphicsState()
try! big.representation(using:.png,properties:[:])!.write(to: URL(fileURLWithPath:"/tmp/finalsheet.png"))
print("ark: /tmp/finalsheet.png")
