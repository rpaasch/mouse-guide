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
        guard let appDelegate = appDelegate else { return }
        let isVisible = appDelegate.crosshairsWindow != nil

        // The checkmark carries the state, so the title stays a stable noun
        // phrase. Doing both - a checkmark AND a "turn off" verb - reads as
        // "the turn-off action is checked", which is nonsense.
        toggleMenuItem?.state = isVisible ? .on : .off
        toggleMenuItem?.title = LocalizedString.menuToggleLabel

        // The icon has to show the state too: it is the only part of this app
        // visible without opening the menu, and the app is essentially one switch.
        statusItem?.button?.appearsDisabled = !isVisible

        let statusText = isVisible ? LocalizedString.accessibilityStateOn : LocalizedString.accessibilityStateOff
        toggleMenuItem?.setAccessibilityLabel("\(LocalizedString.menuToggleLabel), \(statusText)")

        updateShortcutDisplay()
    }

    /// Shows the shortcut the user has actually configured, and only when Input
    /// Monitoring is granted - the global monitor is created regardless of
    /// permission, so anything based on its existence would advertise a
    /// shortcut that silently does nothing.
    private func updateShortcutDisplay() {
        let settings = CrosshairsSettings.shared

        if settings.hasInputMonitoringPermission() {
            toggleMenuItem?.keyEquivalent = settings.activationKey.lowercased()
            toggleMenuItem?.keyEquivalentModifierMask = settings.activationModifiers
        } else {
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
