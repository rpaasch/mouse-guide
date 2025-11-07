import SwiftUI
import Combine

/// Observable state object that bridges between SwiftUI MenuBarExtra and AppDelegate
class AppState: ObservableObject {
    @Published var isCrosshairsVisible: Bool = false

    init() {
        // Listen for crosshairs visibility changes from AppDelegate
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(crosshairsVisibilityChanged),
            name: NSNotification.Name("CrosshairsVisibilityChanged"),
            object: nil
        )
    }

    @objc private func crosshairsVisibilityChanged(_ notification: Notification) {
        DispatchQueue.main.async {
            // Get visibility state from notification
            if let isVisible = notification.object as? Bool {
                self.isCrosshairsVisible = isVisible
            }
        }
    }

    func toggleCrosshairs() {
        // Post notification for AppDelegate to handle
        NotificationCenter.default.post(
            name: NSNotification.Name("ToggleCrosshairsRequested"),
            object: nil
        )
    }

    func showSettings() {
        // Post notification for AppDelegate to handle
        NotificationCenter.default.post(
            name: NSNotification.Name("ShowSettingsRequested"),
            object: nil
        )
    }

    func quit() {
        NSApp.terminate(nil)
    }
}
