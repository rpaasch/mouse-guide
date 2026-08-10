import SwiftUI
import AppKit
import IOKit

class CrosshairsSettings: ObservableObject {
    static let shared = CrosshairsSettings()

    /// Key for the cached purchase flag in UserDefaults. StoreKitManager writes
    /// it; everything else reads it. Declared here rather than on
    /// StoreKitManager so non-main-actor code can reach it.
    static let purchaseCacheKey = "isPurchased"

    /// Single source of truth for default values. Both `init` and
    /// `resetToDefaults()` read from here, so the two cannot drift apart -
    /// which is how reset previously ended up missing seven settings.
    enum Defaults {
        static let crosshairColor = Color.red
        static let borderColor = Color.black
        static let circleFillColor = Color.red
        static let opacity = 0.75
        static let centerRadius = 20.0
        static let thickness = 5.0
        static let edgePointerThickness = 1.0
        static let borderSize = 1.0
        static let fixedLength = 200.0
        static let useFixedLength = false
        static let useReadingLine = false
        static let autoHideInFullscreen = false
        static let autoHideWhileTyping = false
        static let autoHideTypingDelay = 1.5
        static let invertColors = false
        static let orientation = CrosshairOrientation.both
        static let activationKey = "L"
        static let activationModifiers: NSEvent.ModifierFlags = [.shift, .control]
        static let glidingEnabled = false
        static let glidingSpeed = 0.5
        static let glidingDelay = 0.2
        static let circleRadius = 50.0
        static let circleFillOpacity = 0.0
        static let lineStyle = LineStyle.solid
    }

    /// Appearance used when the full version has not been purchased.
    /// Deliberately sparse - one fixed look, no customisation - but legible.
    /// The 1px border is not a feature; it is what keeps a red line visible
    /// against a red or dark background, and the whole point of the app is
    /// being seen.
    enum FreeTier {
        static let crosshairColor = Color.red
        static let borderColor = Color.black
        static let thickness = 2.0
        static let borderSize = 1.0
        static let centerRadius = 10.0
        static let opacity = 1.0
        static let orientation = CrosshairOrientation.both
        static let lineStyle = LineStyle.solid
    }

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

    @Published var autoHideInFullscreen: Bool {
        didSet { saveSetting("autoHideInFullscreen", autoHideInFullscreen) }
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

    private init() {
        let defaults = UserDefaults.standard

        self.crosshairColor = Self.colorFromHex(defaults.string(forKey: "crosshairColor") ?? "") ?? Defaults.crosshairColor
        self.borderColor = Self.colorFromHex(defaults.string(forKey: "borderColor") ?? "") ?? Defaults.borderColor
        self.circleFillColor = Self.colorFromHex(defaults.string(forKey: "circleFillColor") ?? "") ?? Defaults.circleFillColor

        // Read through `object(forKey:)` rather than `double(forKey:)`: the
        // latter returns 0 for a missing key, which made a genuine stored 0
        // (border size, center radius) indistinguishable from "unset" and
        // silently reverted it to the default on next launch.
        self.opacity = Self.storedDouble("opacity", default: Defaults.opacity)
        self.centerRadius = Self.storedDouble("centerRadius", default: Defaults.centerRadius)
        self.thickness = Self.storedDouble("thickness", default: Defaults.thickness)
        self.edgePointerThickness = Self.storedDouble("edgePointerThickness", default: Defaults.edgePointerThickness)
        self.borderSize = Self.storedDouble("borderSize", default: Defaults.borderSize)
        self.fixedLength = Self.storedDouble("fixedLength", default: Defaults.fixedLength)
        self.autoHideTypingDelay = Self.storedDouble("autoHideTypingDelay", default: Defaults.autoHideTypingDelay)
        self.glidingSpeed = Self.storedDouble("glidingSpeed", default: Defaults.glidingSpeed)
        self.glidingDelay = Self.storedDouble("glidingDelay", default: Defaults.glidingDelay)
        self.circleRadius = Self.storedDouble("circleRadius", default: Defaults.circleRadius)
        self.circleFillOpacity = Self.storedDouble("circleFillOpacity", default: Defaults.circleFillOpacity)

        self.useFixedLength = Self.storedBool("useFixedLength", default: Defaults.useFixedLength)
        self.useReadingLine = Self.storedBool("useReadingLine", default: Defaults.useReadingLine)
        self.autoHideInFullscreen = Self.storedBool("autoHideInFullscreen", default: Defaults.autoHideInFullscreen)
        self.autoHideWhileTyping = Self.storedBool("autoHideWhileTyping", default: Defaults.autoHideWhileTyping)
        self.invertColors = Self.storedBool("invertColors", default: Defaults.invertColors)
        self.glidingEnabled = Self.storedBool("glidingEnabled", default: Defaults.glidingEnabled)

        let orientationRaw = defaults.string(forKey: "orientation") ?? Defaults.orientation.rawValue
        self.orientation = CrosshairOrientation(rawValue: orientationRaw) ?? Defaults.orientation

        let lineStyleRaw = defaults.string(forKey: "lineStyle") ?? Defaults.lineStyle.rawValue
        self.lineStyle = LineStyle(rawValue: lineStyleRaw) ?? Defaults.lineStyle

        self.activationKey = defaults.string(forKey: "activationKey") ?? Defaults.activationKey
        let modifiersRaw = defaults.integer(forKey: "activationModifiers")
        self.activationModifiers = modifiersRaw == 0 ? Defaults.activationModifiers : NSEvent.ModifierFlags(rawValue: UInt(modifiersRaw))

        // Language - default to system language if available, otherwise English
        if let savedLanguage = defaults.string(forKey: "language") {
            self.language = savedLanguage
        } else {
            let systemLanguage = Locale.preferredLanguages.first ?? "en"
            self.language = systemLanguage.hasPrefix("da") ? "da" : "en"
        }

        LocalizationManager.shared.setLanguage(self.language)

        self.hasFullAccess = defaults.bool(forKey: Self.purchaseCacheKey)
        NotificationCenter.default.addObserver(
            forName: .init("PurchaseStateChanged"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshPurchaseState()
        }
    }

    private static func storedDouble(_ key: String, default fallback: Double) -> Double {
        (UserDefaults.standard.object(forKey: key) as? Double) ?? fallback
    }

    private static func storedBool(_ key: String, default fallback: Bool) -> Bool {
        (UserDefaults.standard.object(forKey: key) as? Bool) ?? fallback
    }

    private func saveSetting<T>(_ key: String, _ value: T) {
        UserDefaults.standard.set(value, forKey: key)
        // Notify views to update
        NotificationCenter.default.post(name: .init("CrosshairsSettingsChanged"), object: nil)
    }

    /// Restores every crosshair setting to its default. Each assignment persists
    /// itself through the property's `didSet`, so there is no separate save
    /// list to keep in sync. `language` is deliberately excluded - it is a user
    /// preference, not a crosshair setting.
    func resetToDefaults() {
        crosshairColor = Defaults.crosshairColor
        borderColor = Defaults.borderColor
        circleFillColor = Defaults.circleFillColor
        opacity = Defaults.opacity
        centerRadius = Defaults.centerRadius
        thickness = Defaults.thickness
        edgePointerThickness = Defaults.edgePointerThickness
        borderSize = Defaults.borderSize
        fixedLength = Defaults.fixedLength
        useFixedLength = Defaults.useFixedLength
        useReadingLine = Defaults.useReadingLine
        autoHideInFullscreen = Defaults.autoHideInFullscreen
        autoHideWhileTyping = Defaults.autoHideWhileTyping
        autoHideTypingDelay = Defaults.autoHideTypingDelay
        invertColors = Defaults.invertColors
        orientation = Defaults.orientation
        activationKey = Defaults.activationKey
        activationModifiers = Defaults.activationModifiers
        glidingEnabled = Defaults.glidingEnabled
        glidingSpeed = Defaults.glidingSpeed
        glidingDelay = Defaults.glidingDelay
        circleRadius = Defaults.circleRadius
        circleFillOpacity = Defaults.circleFillOpacity
        lineStyle = Defaults.lineStyle
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

    // MARK: - Purchase-based Feature Availability

    /// True when the full version has been purchased.
    ///
    /// Held in memory rather than read on demand: every `effective*` property
    /// consults it, and the draw path touches roughly ten of them per frame per
    /// screen. It is refreshed from the cache StoreKitManager writes, whenever
    /// `PurchaseStateChanged` fires.
    ///
    /// Known trade-off: the underlying flag can be forged with `defaults write`,
    /// so gating is not tamper-proof. Accepted deliberately for a low-priced
    /// utility - the alternative costs a visible flash at launch.
    @Published private(set) var hasFullAccess: Bool = false

    private func refreshPurchaseState() {
        let latest = UserDefaults.standard.bool(forKey: Self.purchaseCacheKey)
        guard latest != hasFullAccess else { return }
        hasFullAccess = latest
        NotificationCenter.default.post(name: .init("CrosshairsSettingsChanged"), object: nil)
    }

    var effectiveCrosshairColor: Color {
        hasFullAccess ? crosshairColor : FreeTier.crosshairColor
    }

    var effectiveBorderColor: Color {
        hasFullAccess ? borderColor : FreeTier.borderColor
    }

    var effectiveCircleFillColor: Color {
        hasFullAccess ? circleFillColor : FreeTier.crosshairColor
    }

    var effectiveThickness: Double {
        hasFullAccess ? thickness : FreeTier.thickness
    }

    var effectiveOpacity: Double {
        hasFullAccess ? opacity : FreeTier.opacity
    }

    var effectiveCenterRadius: Double {
        hasFullAccess ? centerRadius : FreeTier.centerRadius
    }

    var effectiveBorderSize: Double {
        hasFullAccess ? borderSize : FreeTier.borderSize
    }

    var effectiveInvertColors: Bool {
        hasFullAccess ? invertColors : false
    }

    /// Locked to a fixed value for free users rather than "whatever was last
    /// selected", so nobody is stranded in e.g. circle mode after buying and
    /// refunding, or after upgrading from an older build.
    var effectiveOrientation: CrosshairOrientation {
        hasFullAccess ? orientation : FreeTier.orientation
    }

    var effectiveLineStyle: LineStyle {
        hasFullAccess ? lineStyle : FreeTier.lineStyle
    }

    var effectiveUseFixedLength: Bool {
        hasFullAccess ? useFixedLength : false
    }

    var effectiveUseReadingLine: Bool {
        hasFullAccess ? useReadingLine : false
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
