import SwiftUI
import AppKit

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
    var keyboardShortcutMonitor: KeyboardShortcutMonitor?
    var menuBarManager: MenuBarManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("🚀 App launching...")

        // Log build information
        BuildInfo.shared.logBuildInfo()

        // Hide dock icon and make it an accessory app
        NSApp.setActivationPolicy(.accessory)
        NSLog("✅ Set activation policy to accessory")

        // Initialize settings
        _ = CrosshairsSettings.shared
        NSLog("✅ Settings initialized")

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

        // A system hot key - needs no permission, so it works from first launch.
        setupKeyboardMonitor()

        // App Store screenshots need an empty screen and the crosshair already
        // drawn. The welcome dialog below would land on top of the shot, and the
        // crosshair is runtime-only state that no preference can preset.
        if Self.screenshotMode {
            NSLog("📸 Screenshot mode - skipping the welcome dialog")
            showCrosshairs()
            if ProcessInfo.processInfo.arguments.contains("-showSettingsForScreenshots") {
                NSApp.activate(ignoringOtherApps: true)
                showSettings()
            }
            return
        }

        // An app with no Dock icon and no window otherwise reads as a failed
        // install, so say where it lives.
        showFirstRunIntroductionIfNeeded()
        NSLog("✅ App initialized with keyboard shortcuts")
    }

    /// A DEBUG-only launch argument for the App Store screenshots. None of it
    /// can reach a Release build.
    private static var screenshotMode: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-screenshotMode")
        #else
        return false
        #endif
    }

    private static let firstRunKey = "hasCompletedFirstRun"

    private func showFirstRunIntroductionIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: Self.firstRunKey) else { return }
        UserDefaults.standard.set(true, forKey: Self.firstRunKey)

        let alert = NSAlert()
        alert.messageText = LocalizedString.welcomeTitle
        alert.informativeText = LocalizedString.welcomeMessage
        alert.alertStyle = .informational
        alert.addButton(withTitle: LocalizedString.welcomeContinue)
        alert.runModal()
    }

    func setupKeyboardMonitor() {
        // Release the old hot key before the new one is registered, so the two
        // never exist at once.
        if keyboardShortcutMonitor != nil {
            print("⌨️ Recreating keyboard monitor...")
            keyboardShortcutMonitor = nil
        }

        keyboardShortcutMonitor = KeyboardShortcutMonitor(appDelegate: self)
        print("✅ Keyboard shortcut monitor created/refreshed")

        // The menu shows the shortcut only if the system accepted it
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

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        hideCrosshairs()
        return .terminateNow
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Clean up notification observers
        NotificationCenter.default.removeObserver(self)
    }
}
