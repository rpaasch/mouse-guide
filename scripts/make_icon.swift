import Foundation
import AppKit

// Cursor Sightline icon — the sight rendered as a physical instrument:
// a machined ring holding glass, with the reticle inside, resting on a
// saturated ground and casting its own shadow.
//
// Detail is spent where it can be seen. Below 64pt the glass gradients and
// the specular arc are dropped and the geometry coarsens, because at those
// sizes they turn to mud and only the silhouette survives.

let tileFraction: CGFloat = 824.0 / 1024.0
let cornerFraction: CGFloat = 185.4 / 824.0

func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat { a + (b - a) * t }

func drawIcon(size: CGFloat) -> NSBitmapImageRep {
    let px = Int(size)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                               isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext
    ctx.setAllowsAntialiasing(true)

    let tile = (size * tileFraction).rounded()
    let o = ((size - tile) / 2).rounded()
    let rect = CGRect(x: o, y: o, width: tile, height: tile)
    let radius = tile * cornerFraction
    let tilePath = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
    let space = CGColorSpaceCreateDeviceRGB()
    let detailed = tile >= 64

    // ---- ground -------------------------------------------------------
    ctx.saveGState()
    ctx.addPath(tilePath); ctx.clip()
    let g = CGGradient(colorsSpace: space, colors: [
        CGColor(red: 0.278, green: 0.549, blue: 0.980, alpha: 1),   // bright blue, top
        CGColor(red: 0.086, green: 0.235, blue: 0.780, alpha: 1),   // deep indigo, bottom
    ] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(g, start: CGPoint(x: rect.minX, y: rect.maxY),
                           end: CGPoint(x: rect.maxX, y: rect.minY), options: [])

    if detailed {
        // faint light pooling at the top edge, the way a curved surface catches sky
        let sheen = CGGradient(colorsSpace: space, colors: [
            CGColor(red: 1, green: 1, blue: 1, alpha: 0.22),
            CGColor(red: 1, green: 1, blue: 1, alpha: 0.0),
        ] as CFArray, locations: [0, 1])!
        ctx.drawRadialGradient(sheen,
            startCenter: CGPoint(x: rect.midX, y: rect.maxY), startRadius: 0,
            endCenter: CGPoint(x: rect.midX, y: rect.maxY), endRadius: tile * 0.85, options: [])
    }
    ctx.restoreGState()

    // ---- the instrument ----------------------------------------------
    let cx = rect.midX, cy = rect.midY
    let outerR   = tile * (detailed ? 0.315 : 0.345)
    let ringW    = tile * (detailed ? 0.058 : 0.085)
    let innerR   = outerR - ringW

    // shadow cast onto the ground
    ctx.saveGState()
    ctx.addPath(tilePath); ctx.clip()
    if detailed {
        ctx.setShadow(offset: CGSize(width: 0, height: -tile * 0.022),
                      blur: tile * 0.055,
                      color: CGColor(red: 0, green: 0.05, blue: 0.25, alpha: 0.55))
    }
    ctx.setFillColor(CGColor(red: 0.05, green: 0.09, blue: 0.22, alpha: 1))
    ctx.fillEllipse(in: CGRect(x: cx - outerR, y: cy - outerR, width: outerR * 2, height: outerR * 2))
    ctx.restoreGState()

    // glass interior
    ctx.saveGState()
    ctx.addEllipse(in: CGRect(x: cx - innerR, y: cy - innerR, width: innerR * 2, height: innerR * 2))
    ctx.clip()
    if detailed {
        let glass = CGGradient(colorsSpace: space, colors: [
            CGColor(red: 0.102, green: 0.157, blue: 0.310, alpha: 1),
            CGColor(red: 0.027, green: 0.051, blue: 0.145, alpha: 1),
        ] as CFArray, locations: [0, 1])!
        ctx.drawRadialGradient(glass,
            startCenter: CGPoint(x: cx - innerR * 0.35, y: cy + innerR * 0.45), startRadius: 0,
            endCenter: CGPoint(x: cx, y: cy), endRadius: innerR * 1.55, options: [])
    } else {
        ctx.setFillColor(CGColor(red: 0.043, green: 0.075, blue: 0.180, alpha: 1))
        ctx.fill(CGRect(x: cx - innerR, y: cy - innerR, width: innerR * 2, height: innerR * 2))
    }
    ctx.restoreGState()

    // inner edge: a hairline of shadow so the glass sits inside the rim
    // rather than looking painted onto it
    ctx.saveGState()
    ctx.addEllipse(in: CGRect(x: cx - innerR, y: cy - innerR, width: innerR * 2, height: innerR * 2))
    ctx.clip()
    if detailed {
        ctx.setLineWidth(tile * 0.016)
        ctx.setStrokeColor(CGColor(red: 0, green: 0.02, blue: 0.08, alpha: 0.55))
        ctx.addArc(center: CGPoint(x: cx, y: cy), radius: innerR,
                   startAngle: 0, endAngle: .pi * 2, clockwise: false)
        ctx.strokePath()
    }
    ctx.restoreGState()

    // machined rim: an annulus filled with a directional metal gradient
    ctx.saveGState()
    let ring = CGMutablePath()
    ring.addEllipse(in: CGRect(x: cx - outerR, y: cy - outerR, width: outerR * 2, height: outerR * 2))
    ring.addEllipse(in: CGRect(x: cx - innerR, y: cy - innerR, width: innerR * 2, height: innerR * 2))
    ctx.addPath(ring); ctx.clip(using: .evenOdd)
    let metal = CGGradient(colorsSpace: space, colors: [
        CGColor(red: 0.988, green: 0.992, blue: 1.000, alpha: 1),
        CGColor(red: 0.792, green: 0.827, blue: 0.882, alpha: 1),
        CGColor(red: 0.545, green: 0.596, blue: 0.686, alpha: 1),
    ] as CFArray, locations: [0, 0.55, 1])!
    ctx.drawLinearGradient(metal,
        start: CGPoint(x: cx - outerR, y: cy + outerR),
        end:   CGPoint(x: cx + outerR, y: cy - outerR), options: [])
    ctx.restoreGState()

    // reticle: four bars from the glass edge toward a precise void
    let barW = tile * (detailed ? 0.040 : 0.075)
    let gap  = tile * (detailed ? 0.058 : 0.045)
    let reach = innerR * 0.98
    ctx.saveGState()
    ctx.addEllipse(in: CGRect(x: cx - innerR, y: cy - innerR, width: innerR * 2, height: innerR * 2))
    ctx.clip()
    if detailed {
        ctx.setShadow(offset: .zero, blur: tile * 0.011,
                      color: CGColor(red: 1, green: 0.15, blue: 0.10, alpha: 0.55))
    }
    ctx.setFillColor(CGColor(red: 1.0, green: 0.231, blue: 0.188, alpha: 1))
    for r in [
        CGRect(x: cx - reach, y: cy - barW/2, width: reach - gap, height: barW),
        CGRect(x: cx + gap,   y: cy - barW/2, width: reach - gap, height: barW),
        CGRect(x: cx - barW/2, y: cy - reach, width: barW, height: reach - gap),
        CGRect(x: cx - barW/2, y: cy + gap,   width: barW, height: reach - gap),
    ] { ctx.fill(r) }
    ctx.restoreGState()

    // specular arc along the upper-left of the rim
    if detailed {
        ctx.saveGState()
        ctx.addPath(ring); ctx.clip(using: .evenOdd)
        ctx.setLineWidth(ringW * 0.34)
        ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.62))
        ctx.setLineCap(.round)
        let hr = outerR - ringW * 0.30
        ctx.addArc(center: CGPoint(x: cx, y: cy), radius: hr,
                   startAngle: .pi * 0.60, endAngle: .pi * 1.02, clockwise: false)
        ctx.strokePath()
        ctx.restoreGState()
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let sizes: [(Int, String)] = [
    (16,"icon_16x16_1x_16.png"), (32,"icon_16x16_2x_32.png"),
    (32,"icon_32x32_1x_32.png"), (64,"icon_32x32_2x_64.png"),
    (128,"icon_128x128_1x_128.png"), (256,"icon_128x128_2x_256.png"),
    (256,"icon_256x256_1x_256.png"), (512,"icon_256x256_2x_512.png"),
    (512,"icon_512x512_1x_512.png"), (1024,"icon_512x512_2x_1024.png"),
]
let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/tmp/icons3"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
for (s, n) in sizes {
    let rep = drawIcon(size: CGFloat(s))
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(outDir)/\(n)"))
}
print("gengivet i \(outDir)")
