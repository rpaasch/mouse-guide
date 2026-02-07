import SwiftUI
import AppKit
import IOKit

class CrosshairsSettings: ObservableObject {
    static let shared = CrosshairsSettings()

    // Color settings
    @Published var crosshairColor: Color {
        didSet { saveSetting("crosshairColor", Self.colorToHex(crosshairColor)) }
    }

    @Published var borderColor: Color {
        didSet { saveSetting("borderColor", Self.colorToHex(borderColor)) }
    }

    @Published var circleFillColor: Color {
        didSet { saveSetting("circleFillColor", Self.colorToHex(circleFillColor)) }
    }

    // Numeric settings
    @Published var opacity: Double {
        didSet { saveSetting("opacity", opacity) }
    }

    @Published var centerRadius: Double {
        didSet { saveSetting("centerRadius", centerRadius) }
    }

    @Published var thickness: Double {
        didSet { saveSetting("thickness", thickness) }
    }

    @Published var edgePointerThickness: Double {
        didSet { saveSetting("edgePointerThickness", edgePointerThickness) }
    }

    @Published var borderSize: Double {
        didSet { saveSetting("borderSize", borderSize) }
    }

    @Published var fixedLength: Double {
        didSet { saveSetting("fixedLength", fixedLength) }
    }

    // Boolean settings
    @Published var useFixedLength: Bool {
        didSet { saveSetting("useFixedLength", useFixedLength) }
    }

    @Published var useReadingLine: Bool {
        didSet { saveSetting("useReadingLine", useReadingLine) }
    }

    @Published var autoHideWhenPointerHidden: Bool {
        didSet { saveSetting("autoHideWhenPointerHidden", autoHideWhenPointerHidden) }
    }

    @Published var autoHideWhileTyping: Bool {
        didSet { saveSetting("autoHideWhileTyping", autoHideWhileTyping) }
    }

    @Published var autoHideTypingDelay: Double {
        didSet { saveSetting("autoHideTypingDelay", autoHideTypingDelay) }
    }

    @Published var invertColors: Bool {
        didSet { saveSetting("invertColors", invertColors) }
    }

    // Orientation
    @Published var orientation: CrosshairOrientation {
        didSet { saveSetting("orientation", orientation.rawValue) }
    }

    // Keyboard shortcut
    @Published var activationKey: String {
        didSet { saveSetting("activationKey", activationKey) }
    }

    @Published var activationModifiers: NSEvent.ModifierFlags {
        didSet { saveSetting("activationModifiers", activationModifiers.rawValue) }
    }

    // Gliding cursor
    @Published var glidingEnabled: Bool {
        didSet { saveSetting("glidingEnabled", glidingEnabled) }
    }

    @Published var glidingSpeed: Double {
        didSet { saveSetting("glidingSpeed", glidingSpeed) }
    }

    @Published var glidingDelay: Double {
        didSet { saveSetting("glidingDelay", glidingDelay) }
    }

    // Circle radius (used when orientation is .circle)
    @Published var circleRadius: Double {
        didSet { saveSetting("circleRadius", circleRadius) }
    }

    // Circle fill opacity (0.0 = no fill, 1.0 = fully opaque fill)
    @Published var circleFillOpacity: Double {
        didSet { saveSetting("circleFillOpacity", circleFillOpacity) }
    }

    // Line style
    @Published var lineStyle: LineStyle {
        didSet { saveSetting("lineStyle", lineStyle.rawValue) }
    }

    // Language
    @Published var language: String {
        didSet {
            saveSetting("language", language)
            LocalizationManager.shared.setLanguage(language)
        }
    }

    // Shareware tracking
    var hasSeenSharewareReminder: Bool {
        get { UserDefaults.standard.bool(forKey: "hasSeenSharewareReminder") }
        set { UserDefaults.standard.set(newValue, forKey: "hasSeenSharewareReminder") }
    }

    var isPurchased: Bool {
        get { UserDefaults.standard.bool(forKey: "isPurchased") }
        set { UserDefaults.standard.set(newValue, forKey: "isPurchased") }
    }

    private init() {
        // Load or set defaults
        self.crosshairColor = Self.colorFromHex(UserDefaults.standard.string(forKey: "crosshairColor") ?? "#FF0000") ?? .red
        self.borderColor = Self.colorFromHex(UserDefaults.standard.string(forKey: "borderColor") ?? "#000000") ?? .black
        self.circleFillColor = Self.colorFromHex(UserDefaults.standard.string(forKey: "circleFillColor") ?? "#FF0000") ?? .red

        let opacity = UserDefaults.standard.double(forKey: "opacity")
        self.opacity = opacity == 0 ? 0.75 : opacity

        let centerRadius = UserDefaults.standard.double(forKey: "centerRadius")
        self.centerRadius = centerRadius == 0 ? 20 : centerRadius

        let thickness = UserDefaults.standard.double(forKey: "thickness")
        self.thickness = thickness == 0 ? 5 : thickness

        let edgePointerThickness = UserDefaults.standard.double(forKey: "edgePointerThickness")
        self.edgePointerThickness = edgePointerThickness == 0 ? 1 : edgePointerThickness

        let borderSize = UserDefaults.standard.double(forKey: "borderSize")
        self.borderSize = borderSize == 0 ? 1 : borderSize

        let fixedLength = UserDefaults.standard.double(forKey: "fixedLength")
        self.fixedLength = fixedLength == 0 ? 200 : fixedLength

        self.useFixedLength = UserDefaults.standard.bool(forKey: "useFixedLength")
        self.useReadingLine = UserDefaults.standard.bool(forKey: "useReadingLine")
        self.autoHideWhenPointerHidden = UserDefaults.standard.bool(forKey: "autoHideWhenPointerHidden")
        self.autoHideWhileTyping = UserDefaults.standard.bool(forKey: "autoHideWhileTyping")

        let autoHideTypingDelay = UserDefaults.standard.double(forKey: "autoHideTypingDelay")
        self.autoHideTypingDelay = autoHideTypingDelay == 0 ? 1.5 : autoHideTypingDelay

        self.invertColors = UserDefaults.standard.bool(forKey: "invertColors")
        self.glidingEnabled = UserDefaults.standard.bool(forKey: "glidingEnabled")

        let orientationRaw = UserDefaults.standard.string(forKey: "orientation") ?? CrosshairOrientation.both.rawValue
        self.orientation = CrosshairOrientation(rawValue: orientationRaw) ?? .both

        self.activationKey = UserDefaults.standard.string(forKey: "activationKey") ?? "L"
        let modifiersRaw = UserDefaults.standard.integer(forKey: "activationModifiers")
        self.activationModifiers = modifiersRaw == 0 ? [.shift, .control] : NSEvent.ModifierFlags(rawValue: UInt(modifiersRaw))

        let glidingSpeed = UserDefaults.standard.double(forKey: "glidingSpeed")
        self.glidingSpeed = glidingSpeed == 0 ? 0.5 : glidingSpeed

        let glidingDelay = UserDefaults.standard.double(forKey: "glidingDelay")
        self.glidingDelay = glidingDelay == 0 ? 0.2 : glidingDelay

        // Circle radius
        let circleRadius = UserDefaults.standard.double(forKey: "circleRadius")
        self.circleRadius = circleRadius == 0 ? 50 : circleRadius

        // Circle fill opacity
        self.circleFillOpacity = UserDefaults.standard.double(forKey: "circleFillOpacity")

        // Line style
        let lineStyleRaw = UserDefaults.standard.string(forKey: "lineStyle") ?? LineStyle.solid.rawValue
        self.lineStyle = LineStyle(rawValue: lineStyleRaw) ?? .solid

        // Language - default to system language if available, otherwise English
        let savedLanguage = UserDefaults.standard.string(forKey: "language")
        if let savedLanguage = savedLanguage {
            self.language = savedLanguage
        } else {
            // Detect system language
            let systemLanguage = Locale.preferredLanguages.first ?? "en"
            self.language = systemLanguage.hasPrefix("da") ? "da" : "en"
        }

        // Set initial language
        LocalizationManager.shared.setLanguage(self.language)
    }

    private func saveSetting<T>(_ key: String, _ value: T) {
        UserDefaults.standard.set(value, forKey: key)
        // Notify views to update
        NotificationCenter.default.post(name: .init("CrosshairsSettingsChanged"), object: nil)
    }

    func resetToDefaults() {
        // Reset all settings to their default values
        self.crosshairColor = .red
        self.borderColor = .black
        self.circleFillColor = .red
        self.opacity = 0.75
        self.centerRadius = 20
        self.thickness = 5
        self.edgePointerThickness = 1
        self.borderSize = 1
        self.fixedLength = 200
        self.useFixedLength = false
        self.useReadingLine = false
        self.autoHideWhenPointerHidden = false
        self.autoHideWhileTyping = false
        self.autoHideTypingDelay = 1.5
        self.invertColors = false
        self.glidingEnabled = false
        self.orientation = .both
        self.activationKey = "L"
        self.activationModifiers = [.shift, .control]
        self.glidingSpeed = 0.5
        self.glidingDelay = 0.2

        // Save to UserDefaults
        saveSetting("crosshairColor", Self.colorToHex(.red))
        saveSetting("borderColor", Self.colorToHex(.black))
        saveSetting("opacity", 0.75)
        saveSetting("centerRadius", 20.0)
        saveSetting("thickness", 5.0)
        saveSetting("borderSize", 1.0)
        saveSetting("fixedLength", 200.0)
        saveSetting("useFixedLength", false)
        saveSetting("autoHideWhenPointerHidden", false)
        saveSetting("autoHideWhileTyping", false)
        saveSetting("autoHideTypingDelay", 1.5)
        saveSetting("invertColors", false)
        saveSetting("glidingEnabled", false)
        saveSetting("orientation", CrosshairOrientation.both.rawValue)
        saveSetting("activationKey", "L")
        saveSetting("activationModifiers", NSEvent.ModifierFlags([.shift, .control]).rawValue)
        saveSetting("glidingSpeed", 0.5)
        saveSetting("glidingDelay", 0.2)

        // Notify that settings have been reset
        NotificationCenter.default.post(name: .init("CrosshairsSettingsChanged"), object: nil)
    }

    // Helper functions for color conversion
    private static func colorToHex(_ color: Color) -> String {
        let nsColor = NSColor(color)
        guard let rgbColor = nsColor.usingColorSpace(.deviceRGB) else { return "#000000" }

        let r = Int(rgbColor.redComponent * 255)
        let g = Int(rgbColor.greenComponent * 255)
        let b = Int(rgbColor.blueComponent * 255)

        return String(format: "#%02X%02X%02X", r, g, b)
    }

    private static func colorFromHex(_ hex: String) -> Color? {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0

        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0

        return Color(red: r, green: g, blue: b)
    }

    // MARK: - License-based Feature Availability

    var hasFullAccess: Bool {
        // Full access during trial or with license
        if isPurchased {
            NSLog("🔓 hasFullAccess = true (isPurchased)")
            return true
        }

        let licenseState = LicenseManager.shared.licenseState
        NSLog("🔐 Checking hasFullAccess, licenseState = \(licenseState)")
        switch licenseState {
        case .fullTrial, .licensed:
            NSLog("🔓 hasFullAccess = true (trial/licensed)")
            return true
        case .free, .freeExpired, .checking:
            NSLog("🔒 hasFullAccess = false (free/freeExpired/checking)")
            return false
        }
    }

    var effectiveCrosshairColor: Color {
        hasFullAccess ? crosshairColor : .red
    }

    var effectiveBorderColor: Color {
        hasFullAccess ? borderColor : .black
    }

    var effectiveCircleFillColor: Color {
        hasFullAccess ? circleFillColor : .red
    }

    var effectiveThickness: Double {
        hasFullAccess ? thickness : 1.0
    }

    var effectiveOpacity: Double {
        hasFullAccess ? opacity : 1.0
    }

    var effectiveCenterRadius: Double {
        hasFullAccess ? centerRadius : 5.0
    }

    var effectiveBorderSize: Double {
        hasFullAccess ? borderSize : 0.0
    }

    var effectiveInvertColors: Bool {
        hasFullAccess ? invertColors : false
    }

    // MARK: - Permission Helpers

    /// Check if Input Monitoring permission is granted
    func hasInputMonitoringPermission() -> Bool {
        let status = IOHIDCheckAccess(kIOHIDRequestTypeListenEvent)
        return status == kIOHIDAccessTypeGranted
    }

    /// Check if Screen Recording permission is granted
    func hasScreenRecordingPermission() -> Bool {
        return CGPreflightScreenCaptureAccess()
    }

    /// Request Input Monitoring permission - triggers macOS permission dialog
    func requestInputMonitoringPermission() -> Bool {
        return IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
    }

    /// Request Screen Recording permission
    func requestScreenRecordingPermission() {
        // This automatically shows macOS system dialog
        CGRequestScreenCaptureAccess()
    }
}

enum CrosshairOrientation: String, CaseIterable {
    case horizontal = "Horizontal"
    case vertical = "Vertical"
    case both = "Both"
    case edgePointers = "EdgePointers"
    case circle = "Circle"
}

enum LineStyle: String, CaseIterable {
    case solid = "Solid"
    case dashed = "Dashed"
    case dotted = "Dotted"
}
