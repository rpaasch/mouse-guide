#!/usr/bin/env swift

import AppKit
import SwiftUI

@main
struct TestApp: App {
    @NSApplicationDelegateAdaptor(TestAppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class TestAppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var testWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // Setup menu bar
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.title = "✚"
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Test Crosshairs", action: #selector(testCrosshairs), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Show Window", action: #selector(showWindow), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))

        menu.items.forEach { $0.target = self }
        statusItem?.menu = menu

        // Show test window immediately
        showWindow()

        print("✅ Test app started successfully!")
    }

    @objc func testCrosshairs() {
        print("Test crosshairs clicked!")
        let alert = NSAlert()
        alert.messageText = "Test"
        alert.informativeText = "Crosshairs test - dette virker!"
        alert.runModal()
    }

    @objc func showWindow() {
        print("Showing window...")
        if testWindow == nil {
            let contentView = VStack {
                Text("Test Vindue")
                    .font(.largeTitle)
                    .padding()
                Text("Hvis du kan se dette, virker appen!")
                    .padding()
                Button("Luk") {
                    self.testWindow?.close()
                }
                .padding()
            }
            .frame(width: 400, height: 300)

            testWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            testWindow?.title = "Test"
            testWindow?.contentView = NSHostingView(rootView: contentView)
            testWindow?.center()
        }

        testWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func quit() {
        NSApp.terminate(nil)
    }
}
