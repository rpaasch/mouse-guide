import Foundation
import ServiceManagement

/// Wraps the login-item registration.
///
/// The deployment target is macOS 13, so `SMAppService` is always available and
/// the old AppleScript fallback was unreachable - it would also have been
/// blocked by the App Sandbox, which forbids sending Apple events to System
/// Events without an entitlement.
class LaunchAtLogin {
    static let shared = LaunchAtLogin()

    private init() {}

    /// Reads the real registration state rather than a cached flag, so the
    /// toggle cannot drift out of step with what the system actually does
    /// (the user can disable login items in System Settings behind our back).
    var isEnabled: Bool {
        get {
            SMAppService.mainApp.status == .enabled
        }
        set {
            do {
                if newValue {
                    try SMAppService.mainApp.register()
                    print("✅ Added to login items")
                } else {
                    try SMAppService.mainApp.unregister()
                    print("✅ Removed from login items")
                }
            } catch {
                print("❌ Failed to update login item: \(error)")
            }
        }
    }
}
