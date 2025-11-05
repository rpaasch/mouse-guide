import AppKit
import SwiftUI

class MenuBarManager {
    var statusItem: NSStatusItem?  // Changed to var so AppDelegate can access it
    weak var appDelegate: AppDelegate?
    private var toggleSwitch: NSSwitch?
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

        // Toggle switch with label
        let toggleItem = NSMenuItem()

        // Create a container view with label and switch
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 200, height: 25))

        let label = NSTextField(labelWithString: LocalizedString.appName)
        label.frame = NSRect(x: 14, y: 4, width: 120, height: 17)  // 14px for better alignment
        label.font = NSFont.menuFont(ofSize: 0)  // Use system menu font size
        container.addSubview(label)

        let switchControl = NSSwitch()
        switchControl.frame = NSRect(x: 148, y: 2, width: 40, height: 20)
        switchControl.target = self
        switchControl.action = #selector(toggleSwitchChanged(_:))
        toggleSwitch = switchControl
        container.addSubview(switchControl)

        toggleItem.view = container
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

    @objc private func toggleSwitchChanged(_ sender: NSSwitch) {
        appDelegate?.toggleCrosshairs()
    }

    func updateToggleState() {
        if let appDelegate = appDelegate {
            let isVisible = appDelegate.crosshairsWindow != nil
            toggleSwitch?.state = isVisible ? .on : .off
        }
    }

    @objc private func showSettings() {
        appDelegate?.showSettings()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    @objc private func languageChanged() {
        // Update all menu item titles
        appNameMenuItem?.title = LocalizedString.appName
        settingsMenuItem?.title = LocalizedString.menuSettings
        quitMenuItem?.title = LocalizedString.menuQuit
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
