import Foundation
import ServiceManagement

class LaunchAtLogin {
    static let shared = LaunchAtLogin()

    private init() {}

    var isEnabled: Bool {
        get {
            // Check if app is in login items
            return UserDefaults.standard.bool(forKey: "launchAtLogin")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "launchAtLogin")

            if newValue {
                addToLoginItems()
            } else {
                removeFromLoginItems()
            }
        }
    }

    private func addToLoginItems() {
        guard let bundleID = Bundle.main.bundleIdentifier else { return }

        if #available(macOS 13.0, *) {
            // Modern API for macOS 13+
            do {
                try SMAppService.mainApp.register()
                print("✅ Added to login items (macOS 13+)")
            } catch {
                print("❌ Failed to add to login items: \(error)")
            }
        } else {
            // Fallback for older macOS
            let script = """
            tell application "System Events"
                make new login item at end with properties {path:"\(Bundle.main.bundlePath)", hidden:false}
            end tell
            """

            if let appleScript = NSAppleScript(source: script) {
                var error: NSDictionary?
                appleScript.executeAndReturnError(&error)
                if let error = error {
                    print("❌ Failed to add to login items: \(error)")
                } else {
                    print("✅ Added to login items (AppleScript)")
                }
            }
        }
    }

    private func removeFromLoginItems() {
        if #available(macOS 13.0, *) {
            // Modern API for macOS 13+
            do {
                try SMAppService.mainApp.unregister()
                print("✅ Removed from login items (macOS 13+)")
            } catch {
                print("❌ Failed to remove from login items: \(error)")
            }
        } else {
            // Fallback for older macOS
            let script = """
            tell application "System Events"
                delete (every login item whose name is "MouseCrosshairs")
            end tell
            """

            if let appleScript = NSAppleScript(source: script) {
                var error: NSDictionary?
                appleScript.executeAndReturnError(&error)
                if let error = error {
                    print("❌ Failed to remove from login items: \(error)")
                } else {
                    print("✅ Removed from login items (AppleScript)")
                }
            }
        }
    }
}
