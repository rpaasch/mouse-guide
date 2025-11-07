#!/usr/bin/env swift

import Foundation
import ApplicationServices

let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: false]
let accessibilityEnabled = AXIsProcessTrustedWithOptions(options)

if accessibilityEnabled {
    print("✅ Accessibility permissions are GRANTED")
} else {
    print("❌ Accessibility permissions are DENIED")
    print("\nTo fix this:")
    print("1. Open System Settings")
    print("2. Go to Privacy & Security → Accessibility")
    print("3. Add and enable Mouse Guide")
}

exit(accessibilityEnabled ? 0 : 1)
