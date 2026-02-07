import AppKit

class KeyboardShortcutMonitor {
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var settings = CrosshairsSettings.shared
    private var hasShownPermissionNotification = false
    weak var appDelegate: AppDelegate?

    init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
        setupGlobalShortcut()
        setupLocalShortcut()
    }

    deinit {
        cleanup()
    }

    private func setupGlobalShortcut() {
        print("⌨️ Setting up GLOBAL keyboard shortcut monitoring...")
        print("   Expected: ⌃⇧\(settings.activationKey)")
        print("   ℹ️  Requires Input Monitoring permission")

        // Global monitor - works when app is NOT frontmost
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            _ = self?.handleKeyEvent(event) // Discard return value for global monitor
        }

        if globalMonitor != nil {
            print("✅ Global keyboard shortcut monitor initialized")
        } else {
            print("⚠️ Failed to create global monitor - Input Monitoring permission may be missing")
        }
    }

    private func setupLocalShortcut() {
        print("⌨️ Setting up LOCAL keyboard shortcut monitoring...")

        // Local monitor - works when app IS frontmost
        // Returns event to allow normal processing, or nil to consume
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.handleKeyEvent(event) == true {
                // Event was handled - consume it
                return nil
            }
            // Event not handled - pass it through
            return event
        }

        if localMonitor != nil {
            print("✅ Local keyboard shortcut monitor initialized")
        } else {
            print("❌ Failed to create local monitor")
        }
    }

    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        // Filter to only relevant modifiers (ignore caps lock, function key, etc.)
        let relevantModifiers: NSEvent.ModifierFlags = [.command, .shift, .control, .option]
        let modifiers = event.modifierFlags.intersection(relevantModifiers)
        let expectedModifiers = settings.activationModifiers.intersection(relevantModifiers)
        let key = event.charactersIgnoringModifiers?.uppercased() ?? ""

        // Check if this matches the activation shortcut
        if key == settings.activationKey && modifiers == expectedModifiers {
            print("🎯 SHORTCUT MATCHED! Toggling crosshairs...")
            print("   Key: \(key), Modifiers: \(modifiers)")

            DispatchQueue.main.async {
                NSSound.beep()
                self.appDelegate?.toggleCrosshairs()
            }

            return true // Event handled
        }

        return false // Event not handled
    }

    func cleanup() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
        print("✅ Keyboard shortcut monitors cleaned up")
    }

    private func showPermissionNotification() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = LocalizedString.shortcutPermissionTitle
            alert.informativeText = LocalizedString.shortcutPermissionMessage
            alert.alertStyle = .informational
            alert.addButton(withTitle: LocalizedString.shortcutPermissionOpenSettings)
            alert.addButton(withTitle: LocalizedString.shortcutPermissionLater)

            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                // Open System Settings to Input Monitoring
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }
}
