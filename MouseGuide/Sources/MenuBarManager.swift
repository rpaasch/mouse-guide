import AppKit
import SwiftUI

class MenuBarManager {
    var statusItem: NSStatusItem?  // Changed to var so AppDelegate can access it
    weak var appDelegate: AppDelegate?
    private var toggleMenuItem: NSMenuItem?
    private var appNameMenuItem: NSMenuItem?
    private var settingsMenuItem: NSMenuItem?
    private var quitMenuItem: NSMenuItem?

    init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
        setupMenuBar()

        // Listen for language changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(languageChanged),
            name: NSNotification.Name("LanguageChanged"),
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = createCrosshairIcon()
            button.image?.isTemplate = true
        }

        setupMenu()
    }

    private func setupMenu() {
        let menu = NSMenu()

        // Toggle menu item with checkmark (keyboard accessible)
        let toggleItem = NSMenuItem(
            title: LocalizedString.menuToggleLabel,
            action: #selector(toggleMenuItemClicked),
            keyEquivalent: ""
        )
        toggleItem.target = self
        toggleMenuItem = toggleItem
        menu.addItem(toggleItem)

        menu.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(
            title: LocalizedString.menuSettings,
            action: #selector(showSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        settingsMenuItem = settingsItem
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(
            title: LocalizedString.menuQuit,
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        quitMenuItem = quitItem
        menu.addItem(quitItem)

        statusItem?.menu = menu

        // Update toggle state based on crosshairs visibility
        updateToggleState()
    }

    @objc private func toggleMenuItemClicked() {
        appDelegate?.toggleCrosshairs()
    }

    func updateToggleState() {
        if let appDelegate = appDelegate {
            let isVisible = appDelegate.crosshairsWindow != nil
            toggleMenuItem?.state = isVisible ? .on : .off

            // Update title based on state: "Slå Mouse Guide til" / "Slå Mouse Guide fra"
            toggleMenuItem?.title = isVisible ? LocalizedString.menuToggleHide : LocalizedString.menuToggleShow

            // Update accessibility label to include state
            let statusText = isVisible ? LocalizedString.accessibilityStateOn : LocalizedString.accessibilityStateOff
            toggleMenuItem?.setAccessibilityLabel("\(toggleMenuItem?.title ?? ""), \(statusText)")

            // Update keyboard shortcut display if hotkeys work
            updateShortcutDisplay()
        }
    }

    private func updateShortcutDisplay() {
        guard let appDelegate = appDelegate else { return }

        if appDelegate.canShowShortcutInMenu {
            // Show the actual shortcut: Shift+Ctrl+L
            toggleMenuItem?.keyEquivalent = "l"
            toggleMenuItem?.keyEquivalentModifierMask = [.shift, .control]
        } else {
            // Hide shortcut when it doesn't work
            toggleMenuItem?.keyEquivalent = ""
            toggleMenuItem?.keyEquivalentModifierMask = []
        }
    }

    @objc private func showSettings() {
        appDelegate?.showSettings()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    @objc private func languageChanged() {
        // Rebuild the entire menu to update the toggle label
        setupMenu()
    }

    private func modifierFlagsToString(_ flags: NSEvent.ModifierFlags) -> String {
        var parts: [String] = []
        if flags.contains(.command) { parts.append("⌘") }
        if flags.contains(.shift) { parts.append("⇧") }
        if flags.contains(.option) { parts.append("⌥") }
        if flags.contains(.control) { parts.append("⌃") }
        return parts.joined()
    }

    private func createCrosshairIcon() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)

        image.lockFocus()

        let path = NSBezierPath()

        // Horizontal line
        path.move(to: NSPoint(x: 2, y: 9))
        path.line(to: NSPoint(x: 7, y: 9))
        path.move(to: NSPoint(x: 11, y: 9))
        path.line(to: NSPoint(x: 16, y: 9))

        // Vertical line
        path.move(to: NSPoint(x: 9, y: 2))
        path.line(to: NSPoint(x: 9, y: 7))
        path.move(to: NSPoint(x: 9, y: 11))
        path.line(to: NSPoint(x: 9, y: 16))

        path.lineWidth = 2
        NSColor.black.setStroke()
        path.stroke()

        image.unlockFocus()

        return image
    }
}
