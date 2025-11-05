import SwiftUI
import AppKit

@main
struct MouseCrosshairsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var menuBarManager: MenuBarManager?
    var crosshairsWindow: CrosshairsWindow?
    var settingsWindow: NSWindow?
    var onboardingWindow: NSWindow?
    var sharewareWindow: NSWindow?
    var keyboardShortcutMonitor: KeyboardShortcutMonitor?
    var sessionExpiryWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("🚀 App launching...")

        // Hide dock icon and make it an accessory app
        NSApp.setActivationPolicy(.accessory)
        print("✅ Set activation policy to accessory")

        // Initialize settings
        let settings = CrosshairsSettings.shared
        print("✅ Settings initialized")

        // Initialize license manager and check status
        let licenseManager = LicenseManager.shared
        licenseManager.checkLicenseStatus()
        print("✅ License manager initialized")

        // Setup notification observer for free session expiry
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleFreeSessionExpiry),
            name: NSNotification.Name("FreeSessionExpired"),
            object: nil
        )
        print("✅ Free session expiry observer registered")

        // Setup menu bar
        menuBarManager = MenuBarManager(appDelegate: self)
        print("✅ Menu bar manager created")

        // Setup keyboard shortcut monitor
        keyboardShortcutMonitor = KeyboardShortcutMonitor(appDelegate: self)
        print("✅ Keyboard shortcut monitor created")

        // Show onboarding on first launch
        let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "com.mousecrosshairs.hasCompletedOnboarding")
        print("📝 Has completed onboarding: \(hasCompletedOnboarding)")

        if !hasCompletedOnboarding {
            print("🎯 First launch - showing onboarding")
            showOnboarding()
        } else {
            print("⚠️ Onboarding already completed - skipping")
        }
    }

    func showOnboarding() {
        let onboardingView = SmartOnboardingView {
            // Mark onboarding as completed
            UserDefaults.standard.set(true, forKey: "com.mousecrosshairs.hasCompletedOnboarding")
            UserDefaults.standard.synchronize()
            print("✅ Onboarding completed and saved")

            self.onboardingWindow?.close()
            self.onboardingWindow = nil
        }

        onboardingWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 700),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        onboardingWindow?.title = "Mouse Guide"
        onboardingWindow?.contentView = NSHostingView(rootView: onboardingView)
        onboardingWindow?.center()
        onboardingWindow?.makeKeyAndOrderFront(nil)

        NSApp.activate(ignoringOtherApps: true)
    }

    func toggleCrosshairs() {
        print("🔄 Toggle crosshairs called")
        if crosshairsWindow == nil {
            print("  → Showing crosshairs")
            showCrosshairs()
        } else {
            print("  → Hiding crosshairs")
            hideCrosshairs()
        }
    }

    func showCrosshairs() {
        print("📍 showCrosshairs() called")
        guard crosshairsWindow == nil else {
            print("  ⚠️ Crosshairs already showing")
            return
        }
        print("  → Creating CrosshairsWindow...")
        crosshairsWindow = CrosshairsWindow()
        crosshairsWindow?.orderFrontRegardless()

        // Make absolutely sure it stays on top
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.crosshairsWindow?.orderFrontRegardless()
        }

        print("  ✅ Crosshairs window created and shown")

        // Update menu bar toggle
        menuBarManager?.updateToggleState()

        // Notify settings window to update toggle button
        NotificationCenter.default.post(name: NSNotification.Name("CrosshairsVisibilityChanged"), object: nil)
    }

    func hideCrosshairs() {
        print("📍 hideCrosshairs() called")
        if let window = crosshairsWindow {
            window.orderOut(nil)  // Hide instead of close
            crosshairsWindow = nil
        }
        print("  ✅ Crosshairs hidden")

        // Update menu bar toggle
        menuBarManager?.updateToggleState()

        // Notify settings window to update toggle button
        NotificationCenter.default.post(name: NSNotification.Name("CrosshairsVisibilityChanged"), object: nil)

        // Force menubar to redraw
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let statusItem = self.menuBarManager?.statusItem {
                statusItem.isVisible = true
            }
        }
    }

    func showSettings() {
        print("📍 showSettings() called")
        if settingsWindow == nil {
            print("  → Creating settings window...")
            var contentView = SettingsView()
            contentView.appDelegate = self  // Pass AppDelegate reference
            settingsWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 600, height: 700),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            settingsWindow?.title = "Mouse Guide - Indstillinger"
            settingsWindow?.contentView = NSHostingView(rootView: contentView)
            settingsWindow?.center()
            settingsWindow?.minSize = NSSize(width: 500, height: 600)
            settingsWindow?.maxSize = NSSize(width: 1200, height: 1400)
            settingsWindow?.isReleasedWhenClosed = false
            settingsWindow?.hidesOnDeactivate = false
            print("  ✅ Settings window created")
        }

        print("  → Making settings window visible...")
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        print("  ✅ Settings window shown")
    }

    @objc func handleFreeSessionExpiry() {
        print("⏰ Free session expired - 10 minutes up")

        // DON'T hide crosshairs - user can continue working
        // hideCrosshairs()

        // Show restart recommendation dialog
        showFreeSessionExpiryDialog()
    }

    func showFreeSessionExpiryDialog() {
        let alert = NSAlert()
        alert.messageText = LocalizedString.freeSessionExpiredTitle
        alert.informativeText = LocalizedString.freeSessionExpiredMessage
        alert.alertStyle = .informational
        alert.addButton(withTitle: LocalizedString.freeSessionBuyLicense)
        alert.addButton(withTitle: LocalizedString.freeSessionRestart)
        alert.addButton(withTitle: LocalizedString.commonClose)

        let response = alert.runModal()

        switch response {
        case .alertFirstButtonReturn:
            // Buy License - open Gumroad
            if let url = URL(string: "https://gumroad.com/l/mouseguide") {
                NSWorkspace.shared.open(url)
            }
            NSApp.terminate(nil)

        case .alertSecondButtonReturn:
            // Restart - use a helper script to restart the app
            restartApp()

        case .alertThirdButtonReturn:
            // Close - do nothing, user can continue with 1px crosshair
            print("✅ User chose to continue with free version")

        default:
            // Close button or ESC
            print("✅ User closed dialog")
        }
    }

    private func restartApp() {
        // Get the app path
        guard let appPath = Bundle.main.bundlePath as String? else {
            print("❌ Could not get app path")
            NSApp.terminate(nil)
            return
        }

        // Use a simple shell script to wait and reopen the app
        let script = """
        sleep 0.5
        open "\(appPath)"
        """

        let task = Process()
        task.launchPath = "/bin/sh"
        task.arguments = ["-c", script]
        task.launch()

        // Terminate this instance
        NSApp.terminate(nil)
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        hideCrosshairs()
        return .terminateNow
    }
}
