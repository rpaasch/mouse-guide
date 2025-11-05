import Cocoa
import CoreGraphics

// Test if we can sample screen colors
func testScreenSampling() {
    let mouseLocation = NSEvent.mouseLocation
    print("Mouse location: \(mouseLocation)")

    // Try to capture a 3x3 pixel area at mouse location
    guard let screenImage = CGWindowListCreateImage(
        CGRect(x: mouseLocation.x - 1, y: mouseLocation.y - 1, width: 3, height: 3),
        .optionOnScreenOnly,
        kCGNullWindowID,
        [.bestResolution, .nominalResolution]
    ) else {
        print("❌ FAILED: Could not create screen image")
        print("This means Screen Recording permission is NOT granted")
        exit(1)
    }

    print("✅ Screen image created successfully")
    print("Image size: \(screenImage.width) x \(screenImage.height)")

    guard let dataProvider = screenImage.dataProvider,
          let data = dataProvider.data,
          let bytes = CFDataGetBytePtr(data) else {
        print("❌ FAILED: Could not get pixel data")
        exit(1)
    }

    print("✅ Got pixel data")

    let bytesPerPixel = 4
    let centerPixelOffset = (1 * screenImage.width + 1) * bytesPerPixel

    let r = CGFloat(bytes[centerPixelOffset]) / 255.0
    let g = CGFloat(bytes[centerPixelOffset + 1]) / 255.0
    let b = CGFloat(bytes[centerPixelOffset + 2]) / 255.0

    print("✅ Sampled color: R=\(r), G=\(g), B=\(b)")

    // Calculate luminance
    let luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b
    print("Luminance: \(luminance)")

    if luminance < 0.5 {
        print("→ Dark background detected - would use WHITE crosshairs")
    } else {
        print("→ Light background detected - would use BLACK crosshairs")
    }

    print("")
    print("🎉 SUCCESS! Screen sampling is working correctly!")
}

testScreenSampling()
