import Foundation
import AppKit
import SwiftUI
import ServiceManagement

class DiagnosticsManager {
    static let shared = DiagnosticsManager()

    private init() {}

    func generateDiagnostics() -> String {
        var diagnostics = """
        ═══════════════════════════════════════════════════
        Mouse Guide - Diagnostisk Rapport
        ═══════════════════════════════════════════════════
        Genereret: \(formattedDate())

        """

        diagnostics += systemInformation()
        diagnostics += "\n" + appInformation()
        diagnostics += "\n" + permissionsStatus()
        diagnostics += "\n" + userSettings()
        diagnostics += "\n" + screenConfiguration()
        diagnostics += "\n" + runtimeStatus()

        diagnostics += """

        ═══════════════════════════════════════════════════

        """

        return diagnostics
    }

    func saveDiagnosticsToFile() -> URL? {
        let diagnostics = generateDiagnostics()
        let fileName = "MouseGuide_Diagnostics_\(timestamp()).txt"

        // Gem på Skrivebordet
        let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
        guard let fileURL = desktopURL?.appendingPathComponent(fileName) else {
            return nil
        }

        do {
            try diagnostics.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            print("Failed to save diagnostics: \(error)")
            return nil
        }
    }

    // MARK: - Information Gathering

    private func systemInformation() -> String {
        let processInfo = ProcessInfo.processInfo
        let osVersion = processInfo.operatingSystemVersionString

        var cpuArchitecture = "Unknown"
        #if arch(arm64)
        cpuArchitecture = "Apple Silicon (ARM64)"
        #elseif arch(x86_64)
        cpuArchitecture = "Intel (x86_64)"
        #endif

        return """
        [SYSTEM INFORMATION]
        macOS Version: \(osVersion)
        CPU Architecture: \(cpuArchitecture)
        System Uptime: \(formatUptime(processInfo.systemUptime))
        Physical Memory: \(formatBytes(processInfo.physicalMemory))
        """
    }

    private func appInformation() -> String {
        let bundle = Bundle.main
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown"
        let bundleID = bundle.bundleIdentifier ?? "Unknown"
        let appPath = bundle.bundlePath

        return """
        [APP INFORMATION]
        Version: \(version)
        Build: \(build)
        Bundle ID: \(bundleID)
        App Path: \(appPath)
        """
    }

    private func permissionsStatus() -> String {
        let settings = CrosshairsSettings.shared
        let inputMonitoringGranted = settings.hasInputMonitoringPermission()
        let screenRecordingGranted = settings.hasScreenRecordingPermission()

        let status = """
        [PERMISSIONS STATUS]
        Input Monitoring: \(inputMonitoringGranted ? "✅ Granted" : "❌ Denied")
        Screen Recording: \(screenRecordingGranted ? "✅ Granted" : "❌ Denied")

        Build Location: \(BuildInfo.shared.buildLocation.description)
        """

        return status
    }

    private func userSettings() -> String {
        let settings = CrosshairsSettings.shared
        let defaults = UserDefaults.standard

        let shortcutModifiers = modifierFlagsToString(settings.activationModifiers)

        return """
        [USER SETTINGS]
        Crosshair Color: \(colorToHex(settings.crosshairColor))
        Border Color: \(colorToHex(settings.borderColor))
        Opacity: \(String(format: "%.0f%%", settings.opacity * 100))
        Center Radius: \(Int(settings.centerRadius))px
        Thickness: \(Int(settings.thickness))px
        Border Size: \(Int(settings.borderSize))px
        Orientation: \(settings.orientation.rawValue)
        Use Fixed Length: \(settings.useFixedLength)
        Fixed Length: \(Int(settings.fixedLength))px
        Auto Hide When Pointer Hidden: \(settings.autoHideWhenPointerHidden)
        Gliding Enabled: \(settings.glidingEnabled)
        Gliding Speed: \(String(format: "%.2f", settings.glidingSpeed))
        Gliding Delay: \(String(format: "%.2f", settings.glidingDelay))s
        Activation Shortcut: \(shortcutModifiers)\(settings.activationKey)
        Launch at Login: \(LaunchAtLogin.shared.isEnabled)
        """
    }

    private func screenConfiguration() -> String {
        let screens = NSScreen.screens
        var config = """
        [SCREEN CONFIGURATION]
        Number of Screens: \(screens.count)
        """

        for (index, screen) in screens.enumerated() {
            let frame = screen.frame
            let visibleFrame = screen.visibleFrame
            let backingScaleFactor = screen.backingScaleFactor

            config += """

            Screen \(index + 1):
              Frame: \(Int(frame.width))x\(Int(frame.height)) at (\(Int(frame.origin.x)), \(Int(frame.origin.y)))
              Visible Frame: \(Int(visibleFrame.width))x\(Int(visibleFrame.height))
              Backing Scale Factor: \(backingScaleFactor)x
              Main Screen: \(screen == NSScreen.main ? "Yes" : "No")
            """
        }

        return config
    }

    private func runtimeStatus() -> String {
        var status = """
        [RUNTIME STATUS]
        """

        // Check if app is in login items (macOS 13+)
        if #available(macOS 13.0, *) {
            let loginItemStatus = SMAppService.mainApp.status
            let statusString: String
            switch loginItemStatus {
            case .enabled:
                statusString = "✅ Enabled"
            case .notRegistered:
                statusString = "⚠️ Not Registered"
            case .notFound:
                statusString = "❌ Not Found"
            case .requiresApproval:
                statusString = "⚠️ Requires Approval"
            @unknown default:
                statusString = "❓ Unknown"
            }
            status += "\nLogin Item Status (SMAppService): \(statusString)"
        } else {
            status += "\nLogin Item Status: Using legacy AppleScript method"
        }

        // Event tap info
        let accessibilityEnabled = AXIsProcessTrusted()
        status += "\nEvent Tap Available: \(accessibilityEnabled ? "✅ Yes" : "❌ No (requires Accessibility)")"

        // UserDefaults keys
        let userDefaultsKeys = UserDefaults.standard.dictionaryRepresentation().keys
            .filter { $0.contains("crosshair") || $0.contains("gliding") || $0.contains("activation") || $0.contains("launch") }
            .sorted()

        if !userDefaultsKeys.isEmpty {
            status += "\n\nUserDefaults Keys Present:"
            for key in userDefaultsKeys {
                status += "\n  • \(key)"
            }
        }

        return status
    }

    // MARK: - Helper Functions

    private func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        formatter.locale = Locale(identifier: "da_DK")
        return formatter.string(from: Date())
    }

    private func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return formatter.string(from: Date())
    }

    private func formatUptime(_ uptime: TimeInterval) -> String {
        let days = Int(uptime) / 86400
        let hours = (Int(uptime) % 86400) / 3600
        let minutes = (Int(uptime) % 3600) / 60
        return "\(days)d \(hours)h \(minutes)m"
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        let gb = Double(bytes) / 1_073_741_824
        return String(format: "%.2f GB", gb)
    }

    private func colorToHex(_ color: Color) -> String {
        let nsColor = NSColor(color)
        guard let rgbColor = nsColor.usingColorSpace(.deviceRGB) else { return "#000000" }

        let r = Int(rgbColor.redComponent * 255)
        let g = Int(rgbColor.greenComponent * 255)
        let b = Int(rgbColor.blueComponent * 255)

        return String(format: "#%02X%02X%02X", r, g, b)
    }

    private func modifierFlagsToString(_ flags: NSEvent.ModifierFlags) -> String {
        var parts: [String] = []
        if flags.contains(.command) { parts.append("⌘") }
        if flags.contains(.shift) { parts.append("⇧") }
        if flags.contains(.option) { parts.append("⌥") }
        if flags.contains(.control) { parts.append("⌃") }
        return parts.joined()
    }
}
