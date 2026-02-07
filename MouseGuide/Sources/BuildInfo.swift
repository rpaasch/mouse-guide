import Foundation
import AppKit

/// Provides information about the current build
class BuildInfo {
    static let shared = BuildInfo()

    private init() {}

    /// App version (e.g. "1.0")
    var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
    }

    /// Build number (e.g. "42")
    var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown"
    }

    /// Combined version and build (e.g. "1.0 (42)")
    var versionAndBuild: String {
        "\(version) (\(build))"
    }

    /// Full app path
    var appPath: String {
        Bundle.main.bundlePath
    }

    /// Bundle identifier
    var bundleID: String {
        Bundle.main.bundleIdentifier ?? "Unknown"
    }

    /// Is running from /Applications?
    var isRunningFromApplications: Bool {
        appPath.hasPrefix("/Applications/")
    }

    /// Is running from DerivedData (development build)?
    var isRunningFromDerivedData: Bool {
        appPath.contains("DerivedData")
    }

    /// Build location type
    enum BuildLocation {
        case applications
        case derivedData
        case other(String)

        var emoji: String {
            switch self {
            case .applications: return "✅"
            case .derivedData: return "⚠️"
            case .other: return "ℹ️"
            }
        }

        var description: String {
            switch self {
            case .applications: return "Applications"
            case .derivedData: return "DerivedData (Development)"
            case .other(let path): return path
            }
        }
    }

    var buildLocation: BuildLocation {
        if isRunningFromApplications {
            return .applications
        } else if isRunningFromDerivedData {
            return .derivedData
        } else {
            return .other(appPath)
        }
    }

    /// Log build info to console
    func logBuildInfo() {
        NSLog("╔═══════════════════════════════════════════════════════════════")
        NSLog("║ Mouse Guide - Build Information")
        NSLog("╠═══════════════════════════════════════════════════════════════")
        NSLog("║ Version:      \(version)")
        NSLog("║ Build:        \(build)")
        NSLog("║ Bundle ID:    \(bundleID)")
        NSLog("║ Location:     \(buildLocation.emoji) \(buildLocation.description)")
        NSLog("║ Full Path:    \(appPath)")
        NSLog("╚═══════════════════════════════════════════════════════════════")
    }

    /// Generate formatted build info string
    func generateBuildInfoString() -> String {
        """
        Mouse Guide
        Version \(versionAndBuild)

        Bundle ID: \(bundleID)
        Location: \(buildLocation.emoji) \(buildLocation.description)

        Path: \(appPath)
        """
    }
}
