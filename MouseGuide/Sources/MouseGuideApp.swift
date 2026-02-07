import SwiftUI
import AppKit
import IOKit

@main
struct MouseGuideApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var crosshairsWindow: CrosshairsWindow?
    var settingsWindow: NSWindow?
    var sharewareWindow: NSWindow?
    var keyboardShortcutMonitor: KeyboardShortcutMonitor?
    var sessionExpiryWindow: NSWindow?
    var menuBarManager: MenuBarManager?

    // Check if global hotkeys work (only requires keyboard monitor to be active)
    var canShowShortcutInMenu: Bool {
        // NSEvent-based shortcuts only require Input Monitoring, not Accessibility
        // Just check if keyboard monitor is actively running
        return keyboardShortcutMonitor != nil
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("🚀 App launching...")

        // Log build information
        BuildInfo.shared.logBuildInfo()

        // Hide dock icon and make it an accessory app
        NSApp.setActivationPolicy(.accessory)
        NSLog("✅ Set activation policy to accessory")

        // Initialize settings
        let settings = CrosshairsSettings.shared
        NSLog("✅ Settings initialized")

        // Initialize license manager and check status
        let licenseManager = LicenseManager.shared
        licenseManager.checkLicenseStatus()
        NSLog("✅ License manager initialized")

        // Setup notification observer for free session expiry
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleFreeSessionExpiry),
            name: NSNotification.Name("FreeSessionExpired"),
            object: nil
        )
        NSLog("✅ Free session expiry observer registered")

        // Setup notification observer for crosshairs visibility changes (for MenuBarManager)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateMenuBarToggle),
            name: NSNotification.Name("CrosshairsVisibilityChanged"),
            object: nil
        )
        NSLog("✅ Crosshairs visibility observer registered")

        // Setup menu bar with MenuBarManager
        menuBarManager = MenuBarManager(appDelegate: self)
        NSLog("✅ MenuBarManager initialized")

        // Proactively request Input Monitoring permission at launch
        // This ensures keyboard shortcuts work globally from the start
        requestInputMonitoringPermission()

        // Setup keyboard monitor (will work after permission is granted)
        setupKeyboardMonitor()
        NSLog("✅ App initialized with keyboard shortcuts")
    }

    private func requestInputMonitoringPermission() {
        NSLog("🔐 Proactively requesting Input Monitoring permission...")

        // Use IOHIDRequestAccess - the proper API for triggering Input Monitoring dialog
        let granted = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)

        if granted {
            NSLog("✅ Input Monitoring permission is GRANTED")
        } else {
            NSLog("⚠️ Input Monitoring permission NOT granted yet")
            // Show dialog to guide user to System Settings
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.showInputMonitoringPermissionDialog()
            }
        }
    }

    private func showInputMonitoringPermissionDialog() {
        let alert = NSAlert()
        alert.messageText = LocalizedString.alertInputMonitoringTitle
        alert.informativeText = """
\(LocalizedString.alertInputMonitoringMessage)

\(LocalizedString.alertInputMonitoringExplanation)
\(LocalizedString.alertInputMonitoringFeature1)
\(LocalizedString.alertInputMonitoringFeature2)

\(LocalizedString.alertInputMonitoringInstruction)
"""
        alert.alertStyle = .informational
        alert.addButton(withTitle: LocalizedString.permissionButtonOpenSettings)
        alert.addButton(withTitle: LocalizedString.commonButtonLater)

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            // Open System Settings to Input Monitoring
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    func setupKeyboardMonitor() {
        // Always recreate monitor to ensure it's fresh
        // This is important after user grants Input Monitoring permission
        if keyboardShortcutMonitor != nil {
            print("⌨️ Recreating keyboard monitor...")
            keyboardShortcutMonitor = nil
        }

        keyboardShortcutMonitor = KeyboardShortcutMonitor(appDelegate: self)
        print("✅ Keyboard shortcut monitor created/refreshed")

        // Update menu bar to show shortcut now that monitor is active
        menuBarManager?.updateToggleState()
    }

    @objc func updateMenuBarToggle(_ notification: Notification) {
        menuBarManager?.updateToggleState()
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

        // Notify observers (AppState and settings window) to update toggle state
        NotificationCenter.default.post(name: NSNotification.Name("CrosshairsVisibilityChanged"), object: true)
    }

    func hideCrosshairs() {
        print("📍 hideCrosshairs() called")
        if let window = crosshairsWindow {
            window.orderOut(nil)  // Hide instead of close
            crosshairsWindow = nil
        }
        print("  ✅ Crosshairs hidden")

        // Notify observers (AppState and settings window) to update toggle state
        NotificationCenter.default.post(name: NSNotification.Name("CrosshairsVisibilityChanged"), object: false)
    }

    func showSettings() {
        print("📍 showSettings() called")

        if settingsWindow == nil {
            print("  → Creating settings window...")
            var contentView = SettingsView()
            contentView.appDelegate = self  // Pass AppDelegate reference
            settingsWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 850, height: 700),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            settingsWindow?.title = LocalizedString.windowSettingsTitle
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
            // Buy License - open Settings to License tab
            showSettings()
            // Don't terminate - let user purchase through StoreKit

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
