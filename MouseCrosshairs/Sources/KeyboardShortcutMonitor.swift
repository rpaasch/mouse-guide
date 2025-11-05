import AppKit
import Carbon

class KeyboardShortcutMonitor {
    private var eventTap: CFMachPort?
    private var settings = CrosshairsSettings.shared
    weak var appDelegate: AppDelegate?

    init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
        checkAccessibility()
        setupGlobalShortcut()
    }

    deinit {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
    }

    private func checkAccessibility() {
        // Check permission WITHOUT showing prompt on startup
        // Let the setup function handle showing alerts if needed
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: false]
        let hasAccess = AXIsProcessTrustedWithOptions(options)
        print("🔐 Accessibility permission: \(hasAccess ? "✅ GRANTED" : "❌ DENIED")")
    }

    private func setupGlobalShortcut() {
        print("⌨️ Setting up keyboard shortcut monitoring...")
        print("   Expected: ⌘⇧\(settings.activationKey)")

        // Create event tap for global monitoring
        let eventMask = (1 << CGEventType.keyDown.rawValue)

        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
                let monitor = Unmanaged<KeyboardShortcutMonitor>.fromOpaque(refcon).takeUnretainedValue()
                return monitor.handleCGEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            print("❌ Failed to create event tap - Accessibility permission required!")
            print("   Please grant permission in: System Settings → Privacy & Security → Accessibility")
            print("   You can grant permission through the onboarding or by opening Settings from menu bar")
            // Don't show alert on startup - let user discover through onboarding or menu
            return
        }

        self.eventTap = eventTap

        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)

        print("✅ Keyboard monitoring setup complete with Event Tap")
    }

    private func handleCGEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        guard type == .keyDown else { return Unmanaged.passUnretained(event) }

        let nsEvent = NSEvent(cgEvent: event)
        guard let nsEvent = nsEvent else { return Unmanaged.passUnretained(event) }

        let modifiers = nsEvent.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let key = nsEvent.charactersIgnoringModifiers?.uppercased() ?? ""

        // Check if this matches the activation shortcut
        if key == settings.activationKey && modifiers == settings.activationModifiers {
            print("🎯 SHORTCUT MATCHED! Toggling crosshairs...")

            DispatchQueue.main.async {
                NSSound.beep()  // Safe on main thread
                self.appDelegate?.toggleCrosshairs()
            }

            // Consume the event so other apps don't see it
            return nil
        }

        // Pass through the event
        return Unmanaged.passUnretained(event)
    }

    private func modifierString(_ flags: NSEvent.ModifierFlags) -> String {
        var parts: [String] = []
        if flags.contains(.command) { parts.append("⌘") }
        if flags.contains(.shift) { parts.append("⇧") }
        if flags.contains(.option) { parts.append("⌥") }
        if flags.contains(.control) { parts.append("⌃") }
        return parts.joined()
    }

    func requestAccessibilityPermissions() -> Bool {
        // Request permission WITH prompt dialog
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true]
        let accessibilityEnabled = AXIsProcessTrustedWithOptions(options)
        return accessibilityEnabled
    }
}
