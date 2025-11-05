import SwiftUI
import ApplicationServices

extension String {
    func appendToFile(at path: String) throws {
        let url = URL(fileURLWithPath: path)
        if let fileHandle = try? FileHandle(forWritingTo: url) {
            defer { fileHandle.closeFile() }
            fileHandle.seekToEndOfFile()
            if let data = self.data(using: .utf8) {
                fileHandle.write(data)
            }
        } else {
            try self.write(toFile: path, atomically: true, encoding: .utf8)
        }
    }
}

struct SettingsView: View {
    @ObservedObject private var settings = CrosshairsSettings.shared
    @ObservedObject private var localizationManager = LocalizationManager.shared
    @State private var selectedCategory: SettingsCategory = .appearance
    @State private var languageRefreshID = UUID()
    @State private var crosshairsVisible: Bool = false
    @State private var ignoreNextChange: Bool = false

    // Store reference to AppDelegate
    weak var appDelegate: AppDelegate?

    enum SettingsCategory: String, CaseIterable {
        case appearance
        case behavior
        case license
        case about

        var localizedName: String {
            switch self {
            case .appearance: return "settings.category.appearance".localized()
            case .behavior: return "settings.category.behavior".localized()
            case .license: return "settings.category.license".localized()
            case .about: return "settings.category.about".localized()
            }
        }

        var icon: String {
            switch self {
            case .appearance: return "paintbrush.fill"
            case .behavior: return "gearshape.fill"
            case .license: return "key.fill"
            case .about: return "info.circle"
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            // Sidebar
            List(SettingsCategory.allCases, id: \.self, selection: $selectedCategory) { category in
                Label(category.localizedName, systemImage: category.icon)
                    .tag(category)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 220)
            .listStyle(.sidebar)
        } detail: {
            // Detail view
            VStack(spacing: 0) {
                // Header
                HStack {
                    Image(systemName: selectedCategory.icon)
                        .font(.system(size: 32))
                        .foregroundColor(.accentColor)
                    Text(selectedCategory.localizedName)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Spacer()

                    // Toggle crosshair switch
                    HStack(spacing: 12) {
                        Text(LocalizedString.appName)
                            .font(.body)
                        Toggle("", isOn: $crosshairsVisible)
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .onChange(of: crosshairsVisible) { newValue in
                                NSLog("🔵 Toggle onChange: \(newValue), ignoreNextChange: \(ignoreNextChange)")
                                if ignoreNextChange {
                                    NSLog("🔵 Ignoring this change (from timer)")
                                    ignoreNextChange = false
                                    return
                                }
                                NSLog("🔵 User clicked toggle - calling toggleCrosshairs()")
                                toggleCrosshairs()
                            }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))

                Divider()

                // Content
                Group {
                    switch selectedCategory {
                    case .appearance:
                        AppearanceTab(settings: settings)
                    case .behavior:
                        BehaviorTab(settings: settings)
                    case .license:
                        LicenseTab(settings: settings)
                    case .about:
                        AboutTab(settings: settings)
                    }
                }
            }
            .frame(minWidth: 500, minHeight: 500)
        }
        .frame(minWidth: 600, idealWidth: 800, maxWidth: .infinity,
               minHeight: 600, idealHeight: 700, maxHeight: .infinity)
        .id(languageRefreshID)
        .onChange(of: localizationManager.currentLanguage) { _ in
            languageRefreshID = UUID()
        }
        .onAppear {
            checkCrosshairsVisibility()

            // Poll state every 0.1 seconds to keep in sync
            Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                checkCrosshairsVisibility()
            }

            // Listen for crosshairs state changes
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("CrosshairsVisibilityChanged"),
                object: nil,
                queue: .main
            ) { _ in
                checkCrosshairsVisibility()
            }
        }
    }

    private func toggleCrosshairs() {
        NSLog("🟡 toggleCrosshairs() called, appDelegate = \(String(describing: appDelegate))")
        if let appDelegate = appDelegate {
            NSLog("🟡 Calling appDelegate.toggleCrosshairs()")
            appDelegate.toggleCrosshairs()
            // Update state immediately
            checkCrosshairsVisibility()
        } else {
            NSLog("❌ toggleCrosshairs: appDelegate is nil!")
        }
    }

    private func checkCrosshairsVisibility() {
        if let appDelegate = appDelegate {
            let newState = appDelegate.crosshairsWindow != nil
            if crosshairsVisible != newState {
                NSLog("🟢 Timer updating state from \(crosshairsVisible) to \(newState)")
                ignoreNextChange = true
                crosshairsVisible = newState
            }
        }
    }
}

// MARK: - Appearance Tab

struct AppearanceTab: View {
    @ObservedObject var settings: CrosshairsSettings
    @ObservedObject var licenseManager = LicenseManager.shared

    private var hasFullAccess: Bool {
        settings.hasFullAccess
    }

    private var isLicensed: Bool {
        if case .licensed = licenseManager.licenseState {
            return true
        }
        return false
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Orientation Section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(LocalizedString.settingsOrientation)
                            .font(.headline)
                        if !isLicensed {
                            Text("Pro")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.purple)
                                .cornerRadius(4)
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 8) {
                            // Horizontal
                            Button(action: {
                                settings.orientation = .horizontal
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: settings.orientation == .horizontal ? "circle.inset.filled" : "circle")
                                        .foregroundColor(settings.orientation == .horizontal ? .accentColor : .secondary)
                                    Image(systemName: "arrow.left.and.right")
                                        .foregroundColor(.primary)
                                    Text(LocalizedString.settingsOrientationHorizontal)
                                        .foregroundColor(.primary)
                                }
                            }
                            .buttonStyle(.plain)

                            // Vertical
                            Button(action: {
                                settings.orientation = .vertical
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: settings.orientation == .vertical ? "circle.inset.filled" : "circle")
                                        .foregroundColor(settings.orientation == .vertical ? .accentColor : .secondary)
                                    Image(systemName: "arrow.up.and.down")
                                        .foregroundColor(.primary)
                                    Text(LocalizedString.settingsOrientationVertical)
                                        .foregroundColor(.primary)
                                }
                            }
                            .buttonStyle(.plain)

                            // Both
                            Button(action: {
                                settings.orientation = .both
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: settings.orientation == .both ? "circle.inset.filled" : "circle")
                                        .foregroundColor(settings.orientation == .both ? .accentColor : .secondary)
                                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                                        .foregroundColor(.primary)
                                    Text(LocalizedString.settingsOrientationBoth)
                                        .foregroundColor(.primary)
                                }
                            }
                            .buttonStyle(.plain)

                            // Reading Line
                            Button(action: {
                                settings.orientation = .readingLine
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: settings.orientation == .readingLine ? "circle.inset.filled" : "circle")
                                        .foregroundColor(settings.orientation == .readingLine ? .accentColor : .secondary)
                                    Image(systemName: "text.alignleft")
                                        .foregroundColor(.primary)
                                    Text(LocalizedString.settingsOrientationReadingLine)
                                        .foregroundColor(.primary)
                                }
                            }
                            .buttonStyle(.plain)

                            // Edge Pointers
                            Button(action: {
                                settings.orientation = .edgePointers
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: settings.orientation == .edgePointers ? "circle.inset.filled" : "circle")
                                        .foregroundColor(settings.orientation == .edgePointers ? .accentColor : .secondary)
                                    Image(systemName: "arrowtriangle.right.fill")
                                        .foregroundColor(.primary)
                                    Text(LocalizedString.settingsOrientationEdgePointers)
                                        .foregroundColor(.primary)
                                }
                            }
                            .buttonStyle(.plain)

                            // Circle
                            Button(action: {
                                settings.orientation = .circle
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: settings.orientation == .circle ? "circle.inset.filled" : "circle")
                                        .foregroundColor(settings.orientation == .circle ? .accentColor : .secondary)
                                    Image(systemName: "circle")
                                        .foregroundColor(.primary)
                                    Text(LocalizedString.settingsOrientationCircle)
                                        .foregroundColor(.primary)
                                }
                            }
                            .buttonStyle(.plain)
                        }

                        Divider()

                        Text(LocalizedString.appearanceOrientationDescription)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 16)
                    .padding(.horizontal, 24)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                }
                .padding(.horizontal, 24)
                .disabled(!hasFullAccess)
                .opacity(hasFullAccess ? 1.0 : 0.6)

                // Dimensions Section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(LocalizedString.appearanceDimensions)
                            .font(.headline)
                        if !isLicensed {
                            Text("Pro")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.purple)
                                .cornerRadius(4)
                        }
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        SettingSlider(
                            label: LocalizedString.settingsOpacity,
                            description: LocalizedString.appearanceOpacityDescription,
                            value: $settings.opacity,
                            range: 0.1...1.0,
                            format: { LocalizedString.formatPercentVisible($0) }
                        )

                        // Center radius only relevant for crosshair orientations, not circle or edge pointers
                        if settings.orientation != .circle && settings.orientation != .edgePointers {
                            SettingSlider(
                                label: LocalizedString.settingsCenterRadius,
                                description: LocalizedString.appearanceCenterRadiusDescription,
                                value: $settings.centerRadius,
                                range: 0...100,
                                format: { LocalizedString.formatPixels($0) }
                            )
                        }

                        // Thickness slider - hide for edge pointers since they use their own thickness setting
                        if settings.orientation != .edgePointers {
                            SettingSlider(
                                label: LocalizedString.settingsThickness,
                                description: LocalizedString.appearanceThicknessDescription,
                                value: $settings.thickness,
                                range: 1...50,
                                format: { LocalizedString.formatPixels($0) }
                            )
                        }

                        SettingSlider(
                            label: LocalizedString.settingsBorderSize,
                            description: LocalizedString.appearanceBorderSizeDescription,
                            value: $settings.borderSize,
                            range: 0...10,
                            format: { LocalizedString.formatPixels($0) }
                        )

                        // Circle-specific settings - only show when Circle orientation is selected
                        if settings.orientation == .circle {
                            SettingSlider(
                                label: LocalizedString.settingsCircleRadius,
                                description: LocalizedString.appearanceCircleRadiusDescription,
                                value: $settings.circleRadius,
                                range: 20...200,
                                format: { LocalizedString.formatPixels($0) }
                            )

                            SettingSlider(
                                label: LocalizedString.settingsCircleFillOpacity,
                                description: LocalizedString.settingsCircleFillOpacityDescription,
                                value: $settings.circleFillOpacity,
                                range: 0...1,
                                format: { LocalizedString.formatPercentVisible($0) }
                            )
                        }

                        // Edge pointer-specific settings - only show when Edge Pointers orientation is selected
                        if settings.orientation == .edgePointers {
                            SettingSlider(
                                label: LocalizedString.settingsEdgePointerThickness,
                                description: LocalizedString.appearanceEdgePointerThicknessDescription,
                                value: $settings.edgePointerThickness,
                                range: 0.5...20,
                                format: { LocalizedString.formatPixels($0) }
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 16)
                    .padding(.horizontal, 24)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                }
                .padding(.horizontal, 24)
                .disabled(!hasFullAccess)
                .opacity(hasFullAccess ? 1.0 : 0.6)

                // Colors Section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(LocalizedString.appearanceColors)
                            .font(.headline)
                        if !isLicensed {
                            Text("Pro")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.purple)
                                .cornerRadius(4)
                        }
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        if settings.invertColors {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text(LocalizedString.appearanceColorsWarning)
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                            .padding(.bottom, 4)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(LocalizedString.settingsCrosshairColor)
                                Spacer()
                                ColorPicker("", selection: $settings.crosshairColor)
                                    .labelsHidden()
                                    .frame(width: 60)
                                    .disabled(settings.invertColors || !hasFullAccess)
                            }

                            // Quick color presets
                            if !settings.invertColors {
                                HStack(spacing: 6) {
                                    Text(LocalizedString.appearanceColorsQuickSelect)
                                        .font(.caption)
                                        .foregroundColor(.secondary)

                                    ColorPresetButton(color: .red, currentColor: $settings.crosshairColor)
                                    ColorPresetButton(color: .green, currentColor: $settings.crosshairColor)
                                    ColorPresetButton(color: .blue, currentColor: $settings.crosshairColor)
                                    ColorPresetButton(color: .yellow, currentColor: $settings.crosshairColor)
                                    ColorPresetButton(color: .orange, currentColor: $settings.crosshairColor)
                                    ColorPresetButton(color: .purple, currentColor: $settings.crosshairColor)
                                    ColorPresetButton(color: .white, currentColor: $settings.crosshairColor)
                                    ColorPresetButton(color: .black, currentColor: $settings.crosshairColor)
                                }
                                .padding(.top, 4)
                            }

                            Text(LocalizedString.appearanceColorsCrosshairDescription)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .opacity(settings.invertColors ? 0.5 : 1.0)

                        Divider()

                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(LocalizedString.settingsBorderColor)
                                Spacer()
                                ColorPicker("", selection: $settings.borderColor)
                                    .labelsHidden()
                                    .frame(width: 60)
                                    .disabled(settings.invertColors || !hasFullAccess)
                            }

                            // Quick color presets
                            if !settings.invertColors {
                                HStack(spacing: 6) {
                                    Text(LocalizedString.appearanceColorsQuickSelect)
                                        .font(.caption)
                                        .foregroundColor(.secondary)

                                    ColorPresetButton(color: .black, currentColor: $settings.borderColor)
                                    ColorPresetButton(color: .white, currentColor: $settings.borderColor)
                                    ColorPresetButton(color: .gray, currentColor: $settings.borderColor)
                                    ColorPresetButton(color: .red, currentColor: $settings.borderColor)
                                    ColorPresetButton(color: .blue, currentColor: $settings.borderColor)
                                    ColorPresetButton(color: .green, currentColor: $settings.borderColor)
                                    ColorPresetButton(color: .yellow, currentColor: $settings.borderColor)
                                    ColorPresetButton(color: .orange, currentColor: $settings.borderColor)
                                }
                                .padding(.top, 4)
                            }

                            Text(LocalizedString.appearanceColorsBorderDescription)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .opacity(settings.invertColors ? 0.5 : 1.0)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 16)
                    .padding(.horizontal, 24)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                }
                .padding(.horizontal, 24)
                .disabled(!hasFullAccess)
                .opacity(hasFullAccess ? 1.0 : 0.6)

                // Length Section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(LocalizedString.settingsLength)
                            .font(.headline)
                        if !isLicensed {
                            Text("Pro")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.purple)
                                .cornerRadius(4)
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(LocalizedString.settingsFixLength)
                            Spacer()
                            Toggle("", isOn: $settings.useFixedLength)
                                .labelsHidden()
                                .toggleStyle(.switch)
                        }
                        Text(LocalizedString.appearanceLengthDescription)
                            .font(.caption)
                            .foregroundColor(.secondary)

                        if settings.useFixedLength {
                            Divider().padding(.vertical, 4)
                            SettingSlider(
                                label: LocalizedString.settingsFixedLength,
                                description: LocalizedString.appearanceFixedLengthDescription,
                                value: $settings.fixedLength,
                                range: 50...2000,
                                format: { LocalizedString.formatPixels($0) }
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 16)
                    .padding(.horizontal, 24)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                }
                .padding(.horizontal, 24)
                .disabled(!hasFullAccess)
                .opacity(hasFullAccess ? 1.0 : 0.6)

                // Line Style Section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(LocalizedString.settingsLineStyle)
                            .font(.headline)
                        if !isLicensed {
                            Text("Pro")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.purple)
                                .cornerRadius(4)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        // Solid
                        Button(action: {
                            settings.lineStyle = .solid
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: settings.lineStyle == .solid ? "circle.inset.filled" : "circle")
                                    .foregroundColor(settings.lineStyle == .solid ? .accentColor : .secondary)
                                Image(systemName: "line.horizontal.3")
                                    .foregroundColor(.primary)
                                Text(LocalizedString.settingsLineStyleSolid)
                                    .foregroundColor(.primary)
                            }
                        }
                        .buttonStyle(.plain)

                        // Dashed
                        Button(action: {
                            settings.lineStyle = .dashed
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: settings.lineStyle == .dashed ? "circle.inset.filled" : "circle")
                                    .foregroundColor(settings.lineStyle == .dashed ? .accentColor : .secondary)
                                Image(systemName: "line.horizontal.3.decrease")
                                    .foregroundColor(.primary)
                                Text(LocalizedString.settingsLineStyleDashed)
                                    .foregroundColor(.primary)
                            }
                        }
                        .buttonStyle(.plain)

                        // Dotted
                        Button(action: {
                            settings.lineStyle = .dotted
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: settings.lineStyle == .dotted ? "circle.inset.filled" : "circle")
                                    .foregroundColor(settings.lineStyle == .dotted ? .accentColor : .secondary)
                                Image(systemName: "circle.grid.3x3")
                                    .foregroundColor(.primary)
                                Text(LocalizedString.settingsLineStyleDotted)
                                    .foregroundColor(.primary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 16)
                    .padding(.horizontal, 24)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                }
                .padding(.horizontal, 24)
                .disabled(!hasFullAccess)
                .opacity(hasFullAccess ? 1.0 : 0.6)
            }
            .padding(.vertical, 24)
        }
    }
}

// MARK: - Behavior Tab

struct BehaviorTab: View {
    @ObservedObject var settings: CrosshairsSettings
    @ObservedObject var licenseManager = LicenseManager.shared

    private var hasFullAccess: Bool {
        settings.hasFullAccess
    }

    private var isLicensed: Bool {
        if case .licensed = licenseManager.licenseState {
            return true
        }
        return false
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Color Adaptation
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(LocalizedString.behaviorColorAdaptation)
                            .font(.headline)
                        if !isLicensed {
                            Text("Pro")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.purple)
                                .cornerRadius(4)
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(LocalizedString.settingsInvertColors)
                            Spacer()
                            Toggle("", isOn: $settings.invertColors)
                                .labelsHidden()
                                .toggleStyle(.switch)
                        }
                        Text(LocalizedString.behaviorColorAdaptationDescription)
                            .font(.caption)
                            .foregroundColor(.secondary)

                        if settings.invertColors {
                            HStack(spacing: 8) {
                                Image(systemName: "info.circle")
                                    .foregroundColor(.blue)
                                Text(LocalizedString.behaviorColorAdaptationInfo)
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                            .padding(.top, 4)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 16)
                    .padding(.horizontal, 24)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                }
                .padding(.horizontal, 24)
                .disabled(!hasFullAccess)
                .opacity(hasFullAccess ? 1.0 : 0.6)

                // General Behavior
                VStack(alignment: .leading, spacing: 12) {
                    Text(LocalizedString.behaviorGeneral)
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(LocalizedString.settingsAutoHide)
                                Spacer()
                                Toggle("", isOn: $settings.autoHideWhenPointerHidden)
                                    .labelsHidden()
                                    .toggleStyle(.switch)
                            }
                            Text(LocalizedString.behaviorAutoHideDescription)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Divider()

                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(LocalizedString.behaviorAutoHideTyping)
                                Spacer()
                                Toggle("", isOn: $settings.autoHideWhileTyping)
                                    .labelsHidden()
                                    .toggleStyle(.switch)
                            }
                            Text(LocalizedString.behaviorAutoHideTypingDescription)
                                .font(.caption)
                                .foregroundColor(.secondary)

                            if settings.autoHideWhileTyping {
                                SettingSlider(
                                    label: LocalizedString.behaviorAutoHideTypingDelay,
                                    description: LocalizedString.behaviorAutoHideTypingDelayDescription,
                                    value: $settings.autoHideTypingDelay,
                                    range: 0.5...5.0,
                                    format: { LocalizedString.formatSeconds($0) }
                                )
                                .padding(.top, 8)
                            }

                            if settings.autoHideWhileTyping && !AXIsProcessTrusted() {
                                HStack(spacing: 8) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                    Text(LocalizedString.behaviorAutoHideTypingPermissions)
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                                .padding(.top, 4)
                            }
                        }

                        Divider()

                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(LocalizedString.settingsLaunchAtLogin)
                                Spacer()
                                Toggle("", isOn: Binding(
                                    get: { LaunchAtLogin.shared.isEnabled },
                                    set: { LaunchAtLogin.shared.isEnabled = $0 }
                                ))
                                .labelsHidden()
                                .toggleStyle(.switch)
                            }
                            Text(LocalizedString.behaviorLaunchAtLoginDescription)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 16)
                    .padding(.horizontal, 24)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                }
                .padding(.horizontal, 24)

                // Gliding Cursor
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(LocalizedString.settingsGliding)
                            .font(.headline)
                        if !isLicensed {
                            Text("Pro")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.purple)
                                .cornerRadius(4)
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(LocalizedString.settingsGlidingEnable)
                            Spacer()
                            Toggle("", isOn: $settings.glidingEnabled)
                                .labelsHidden()
                                .toggleStyle(.switch)
                        }
                        Text(LocalizedString.behaviorGlidingDescription)
                            .font(.caption)
                            .foregroundColor(.secondary)

                        if settings.glidingEnabled {
                            Divider().padding(.vertical, 4)

                            SettingSlider(
                                label: LocalizedString.settingsGlidingSpeed,
                                description: LocalizedString.behaviorGlidingSpeedDescription,
                                value: $settings.glidingSpeed,
                                range: 0.1...2.0,
                                format: { LocalizedString.formatSpeed($0) }
                            )

                            SettingSlider(
                                label: LocalizedString.settingsGlidingDelay,
                                description: LocalizedString.behaviorGlidingDelayDescription,
                                value: $settings.glidingDelay,
                                range: 0...1.0,
                                format: { LocalizedString.formatDelay($0) }
                            )

                            Divider().padding(.vertical, 4)

                            HStack(spacing: 8) {
                                Image(systemName: "info.circle")
                                    .foregroundColor(.orange)
                                Text(LocalizedString.settingsGlidingNote)
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 16)
                    .padding(.horizontal, 24)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                }
                .padding(.horizontal, 24)
                .disabled(!hasFullAccess)
                .opacity(hasFullAccess ? 1.0 : 0.6)

                // Keyboard Shortcut
                VStack(alignment: .leading, spacing: 12) {
                    Text(LocalizedString.settingsActivation)
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 16) {
                        Text(LocalizedString.settingsKeyboardShortcut)
                            .font(.subheadline)
                            .fontWeight(.medium)

                        KeyboardShortcutRecorder(
                            key: $settings.activationKey,
                            modifiers: $settings.activationModifiers
                        )
                        .frame(height: 36)

                        Divider()

                        HStack(spacing: 8) {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                            Text(LocalizedString.settingsShortcutHelp)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 16)
                    .padding(.horizontal, 24)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                }
                .padding(.horizontal, 24)
            }
            .padding(.vertical, 24)
        }
    }
}

// MARK: - Shortcuts Tab

struct ShortcutsTab: View {
    @ObservedObject var settings: CrosshairsSettings

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(LocalizedString.settingsActivation)
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 16) {
                        Text(LocalizedString.settingsKeyboardShortcut)
                            .font(.subheadline)
                            .fontWeight(.medium)

                        KeyboardShortcutRecorder(
                            key: $settings.activationKey,
                            modifiers: $settings.activationModifiers
                        )
                        .frame(height: 36)

                        Divider()

                        HStack(spacing: 8) {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                            Text(LocalizedString.settingsShortcutHelp)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 16)
                    .padding(.horizontal, 24)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                }
                .padding(.horizontal, 24)
            }
            .padding(.vertical, 24)
        }
    }
}

// MARK: - License Tab

struct LicenseTab: View {
    @ObservedObject var settings: CrosshairsSettings
    @ObservedObject var licenseManager = LicenseManager.shared
    @State private var licenseKey: String = ""
    @State private var showActivationSuccess: Bool = false
    @State private var activationError: String?
    @State private var isActivating: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Trial Status / License Status
                VStack(alignment: .leading, spacing: 12) {
                    Text(LocalizedString.licenseStatus)
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 16) {
                        switch licenseManager.licenseState {
                        case .licensed:
                            // Licensed
                            HStack(spacing: 12) {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.green)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(LocalizedString.licenseActivated)
                                        .font(.headline)
                                        .foregroundColor(.green)

                                    Text(LocalizedString.licenseThankyou)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }

                        case .fullTrial(let daysRemaining):
                            // Full trial
                            HStack(spacing: 12) {
                                Image(systemName: "clock.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.blue)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(LocalizedString.licenseTrial)
                                        .font(.headline)
                                        .foregroundColor(.blue)

                                    Text("\(daysRemaining) \(LocalizedString.licenseTrialDays)")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }

                        case .free(let minutesRemaining):
                            // Free version - 10 minute restart cycles
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(spacing: 12) {
                                    Image(systemName: "gift.fill")
                                        .font(.system(size: 40))
                                        .foregroundColor(.purple)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(LocalizedString.licenseFree)
                                            .font(.headline)
                                            .foregroundColor(.purple)

                                        Text(String(format: "%02d:%02d \(LocalizedString.licenseFreeMinutes)", licenseManager.freeMinutesRemaining, licenseManager.freeSecondsRemaining))
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                }

                                Text(LocalizedString.licenseFreeRestrictions)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.top, 4)
                            }

                        case .freeExpired:
                            // Free version after timer expired
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(spacing: 12) {
                                    Image(systemName: "gift.fill")
                                        .font(.system(size: 40))
                                        .foregroundColor(.orange)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(LocalizedString.licenseFree)
                                            .font(.headline)
                                            .foregroundColor(.orange)

                                        Text(LocalizedString.licenseFreeRestart)
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                }

                                Text(LocalizedString.licenseFreeRestrictions)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.top, 4)
                            }

                        case .checking:
                            HStack(spacing: 12) {
                                ProgressView()
                                    .controlSize(.large)
                                Text(LocalizedString.licenseChecking)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 16)
                    .padding(.horizontal, 24)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                }
                .padding(.horizontal, 24)

                // Purchase
                if case .licensed = licenseManager.licenseState {
                    // Don't show purchase section if licensed
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(LocalizedString.licenseBuyTitle)
                            .font(.headline)

                        VStack(alignment: .leading, spacing: 16) {
                            Text(LocalizedString.licenseBuyDescription)
                                .font(.body)

                            Button(action: {
                                if let url = URL(string: "https://gumroad.com/l/mouseguide") {
                                    NSWorkspace.shared.open(url)
                                }
                            }) {
                                HStack {
                                    Image(systemName: "cart.fill")
                                    Text(LocalizedString.licenseBuyNow)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 16)
                        .padding(.horizontal, 24)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                    }
                    .padding(.horizontal, 24)
                }

                // Activate License
                VStack(alignment: .leading, spacing: 12) {
                    Text(settings.isPurchased ? LocalizedString.licenseManageTitle : LocalizedString.licenseAlreadyBought)
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 16) {
                        if case .licensed = licenseManager.licenseState {
                            Text(LocalizedString.licenseActive)
                                .font(.body)
                                .foregroundColor(.secondary)
                        } else {
                            Text(LocalizedString.licenseEnterKey)
                                .font(.body)
                                .foregroundColor(.secondary)

                            TextField(LocalizedString.licensePlaceholder, text: $licenseKey)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(.body, design: .monospaced))
                                .textCase(.uppercase)
                                .disabled(isActivating)
                                .onChange(of: licenseKey) { newValue in
                                    NSLog("📝 TextField changed: '\(newValue)' (isEmpty: \(newValue.isEmpty))")
                                }

                            if let error = activationError {
                                HStack(spacing: 8) {
                                    Image(systemName: "exclamationmark.circle.fill")
                                        .foregroundColor(.red)
                                    Text(error)
                                        .font(.callout)
                                        .foregroundColor(.red)
                                }
                            }

                            Button(action: {
                                let btnMsg = "🔴 BUTTON CLICKED! licenseKey = '\(licenseKey)'\n"
                                try? btnMsg.appendToFile(at: "/tmp/mouse_debug.log")
                                NSLog("🔴 BUTTON CLICKED! licenseKey = '\(licenseKey)'")
                                activateLicense()
                            }) {
                                HStack {
                                    if isActivating {
                                        ProgressView()
                                            .controlSize(.small)
                                    }
                                    Image(systemName: "key.fill")
                                    Text(isActivating ? LocalizedString.licenseActivating : LocalizedString.licenseActivate)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(licenseKey.isEmpty || isActivating)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 16)
                    .padding(.horizontal, 24)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                }
                .padding(.horizontal, 24)

                // Developer Testing
                #if DEBUG
                VStack(alignment: .leading, spacing: 12) {
                    Text("🧪 Developer Testing")
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 12) {
                        Button(action: {
                            NSLog("🧪 Simulating expired trial...")

                            // Get or create trial data
                            var trial = licenseManager.loadTrialData() ?? LicenseManager.TrialData(firstLaunchDate: Date(), sessionStartDate: Date())

                            // Set first launch date to 8 days ago (trial is 7 days)
                            trial.firstLaunchDate = Calendar.current.date(byAdding: .day, value: -8, to: Date())!
                            trial.sessionStartDate = Date()

                            // Save and update
                            licenseManager.saveTrialData(trial)
                            NSLog("  ✅ Trial data set to 8 days ago")

                            // Clear isPurchased flag
                            CrosshairsSettings.shared.isPurchased = false
                            NSLog("  ✅ isPurchased cleared")

                            // Check status (will trigger free mode)
                            licenseManager.checkLicenseStatus()
                            NSLog("  ✅ License status checked")

                            // Force UI update
                            NotificationCenter.default.post(name: .init("CrosshairsSettingsChanged"), object: nil)
                            NSLog("✅ Simulation complete - should be in free mode now")
                        }) {
                            HStack {
                                Image(systemName: "clock.badge.xmark")
                                Text("Simuler udløbet trial (gratis mode)")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.bordered)

                        Button(action: {
                            licenseManager.resetTrial()
                        }) {
                            HStack {
                                Image(systemName: "arrow.counterclockwise")
                                Text("Reset trial (7 dages fuld trial)")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.bordered)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 16)
                    .padding(.horizontal, 24)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                }
                .padding(.horizontal, 24)
                #endif
            }
            .padding(.vertical, 24)
        }
        .alert(LocalizedString.licenseActivatedTitle, isPresented: $showActivationSuccess) {
            Button("OK") {}
        } message: {
            Text(LocalizedString.licenseActivatedMessage)
        }
        .onAppear {
            let appearMsg = "🟢 LicenseTab appeared - NEW VERSION WITH LOGGING IS RUNNING\n"
            try? appearMsg.appendToFile(at: "/tmp/mouse_debug.log")
            NSLog("🟢 LicenseTab appeared - NEW VERSION WITH LOGGING IS RUNNING")
        }
    }

    private func activateLicense() {
        let logMsg = "🎯 SettingsView.activateLicense() CALLED - licenseKey: \(licenseKey)\n"
        try? logMsg.appendToFile(at: "/tmp/mouse_debug.log")
        NSLog("🎯 SettingsView.activateLicense() CALLED - licenseKey: \(licenseKey)")
        isActivating = true
        activationError = nil

        Task {
            let taskMsg = "🎯 Task started, about to call licenseManager.activateLicense()\n"
            try? taskMsg.appendToFile(at: "/tmp/mouse_debug.log")
            NSLog("🎯 Task started, about to call licenseManager.activateLicense()")
            let result = await licenseManager.activateLicense(licenseKey)
            let returnMsg = "🎯 licenseManager.activateLicense() returned\n"
            try? returnMsg.appendToFile(at: "/tmp/mouse_debug.log")
            NSLog("🎯 licenseManager.activateLicense() returned")

            await MainActor.run {
                NSLog("🎯 MainActor.run - processing result")
                isActivating = false

                switch result {
                case .success:
                    NSLog("✅ License activation SUCCESS")
                    showActivationSuccess = true
                    licenseKey = ""
                    activationError = nil

                case .failure(let error):
                    NSLog("❌ License activation FAILED: \(error.localizedDescription)")
                    activationError = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Helper Views

struct SettingRow<Content: View>: View {
    let label: String
    let content: Content

    init(label: String, @ViewBuilder content: () -> Content) {
        self.label = label
        self.content = content()
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .frame(alignment: .leading)
            Spacer()
            content
        }
    }
}

struct SliderRow: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let format: (Double) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                Spacer()
                Text(format(value))
                    .foregroundColor(.secondary)
                    .font(.system(.body, design: .monospaced))
                    .frame(minWidth: 60, alignment: .trailing)
            }
            Slider(value: $value, in: range)
        }
    }
}

struct SettingSlider: View {
    let label: String
    let description: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let format: (Double) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                Spacer()
                Text(format(value))
                    .foregroundColor(.secondary)
                    .font(.system(.body, design: .monospaced))
                    .frame(minWidth: 60, alignment: .trailing)
            }
            Slider(value: $value, in: range)
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - About Tab

struct AboutTab: View {
    @ObservedObject var settings: CrosshairsSettings
    @ObservedObject var localizationManager = LocalizationManager.shared
    @State private var showResetConfirmation = false
    @State private var hasAccessibilityPermission = false
    @State private var hasScreenRecordingPermission = false
    @State private var hasInputMonitoringPermission = false

    let timer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(spacing: 12) {
                    Image(systemName: "crosshair.circle.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.accentColor)

                    Text(LocalizedString.appName)
                        .font(.title)
                        .fontWeight(.bold)

                    Text("Version 1.0")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 40)

                Divider()
                    .padding(.horizontal, 24)

                VStack(alignment: .leading, spacing: 16) {
                    Text(LocalizedString.aboutApp)
                        .font(.title3)
                        .fontWeight(.semibold)

                    Text(LocalizedString.aboutDescription)
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(LocalizedString.aboutFeatures)
                        .font(.headline)
                        .padding(.top, 8)

                    VStack(alignment: .leading, spacing: 10) {
                        FeatureRow(icon: "display.2", text: LocalizedString.aboutFeatureMultimonitor)
                        FeatureRow(icon: "paintbrush.fill", text: LocalizedString.aboutFeatureColorAdaptation)
                        FeatureRow(icon: "slider.horizontal.3", text: LocalizedString.aboutFeatureCustomizable)
                        FeatureRow(icon: "cursorarrow.motionlines", text: LocalizedString.aboutFeatureGliding)
                        FeatureRow(icon: "keyboard", text: LocalizedString.aboutFeatureShortcut)
                    }
                }
                .padding(.horizontal, 24)

                Divider()
                    .padding(.horizontal, 24)

                VStack(alignment: .leading, spacing: 8) {
                    Text(LocalizedString.aboutMadeBy)
                        .font(.body)
                        .foregroundColor(.secondary)

                    Text(LocalizedString.aboutCopyright)
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
                .padding(.horizontal, 24)

                Divider()

                VStack(alignment: .leading, spacing: 12) {
                    Text(LocalizedString.aboutPermissions)
                        .font(.title3)
                        .fontWeight(.semibold)

                    Text(LocalizedString.aboutPermissionsDescription)
                        .font(.body)
                        .foregroundColor(.secondary)

                    VStack(alignment: .leading, spacing: 12) {
                        PermissionRow(
                            icon: "hand.raised.fill",
                            title: LocalizedString.aboutPermissionAccessibility,
                            description: LocalizedString.aboutPermissionAccessibilityDescription,
                            isGranted: hasAccessibilityPermission,
                            action: {
                                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                            }
                        )

                        PermissionRow(
                            icon: "keyboard",
                            title: LocalizedString.aboutPermissionInputMonitoring,
                            description: LocalizedString.aboutPermissionInputMonitoringDescription,
                            isGranted: hasInputMonitoringPermission,
                            action: {
                                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!)
                            }
                        )

                        PermissionRow(
                            icon: "record.circle.fill",
                            title: LocalizedString.aboutPermissionScreenRecording,
                            description: LocalizedString.aboutPermissionScreenRecordingDescription,
                            isGranted: hasScreenRecordingPermission,
                            action: {
                                // Request screen recording permission
                                CGRequestScreenCaptureAccess()
                            }
                        )
                    }
                    .padding(.vertical, 16)
                    .padding(.horizontal, 24)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                }
                .padding(.horizontal, 24)

                Divider()
                    .padding(.horizontal, 24)

                VStack(alignment: .leading, spacing: 12) {
                    Text(LocalizedString.settingsLanguage)
                        .font(.title3)
                        .fontWeight(.semibold)

                    Text(LocalizedString.settingsLanguageDescription)
                        .font(.body)
                        .foregroundColor(.secondary)

                    HStack {
                        Text(LocalizedString.settingsLanguage + ":")
                            .frame(width: 100, alignment: .leading)

                        Picker("", selection: $settings.language) {
                            Text(LocalizedString.languageDanish).tag("da")
                            Text(LocalizedString.languageEnglish).tag("en")
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(width: 200)

                        Spacer()
                    }
                    .padding(.vertical, 16)
                    .padding(.horizontal, 24)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                }
                .padding(.horizontal, 24)

                Divider()
                    .padding(.horizontal, 24)

                VStack(alignment: .leading, spacing: 12) {
                    Text(LocalizedString.aboutReset)
                        .font(.title3)
                        .fontWeight(.semibold)

                    Text(LocalizedString.aboutResetDescription)
                        .font(.body)
                        .foregroundColor(.secondary)

                    Button(action: {
                        showResetConfirmation = true
                    }) {
                        HStack {
                            Image(systemName: "arrow.counterclockwise.circle.fill")
                            Text(LocalizedString.aboutResetButton)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .alert(LocalizedString.aboutResetConfirmTitle, isPresented: $showResetConfirmation) {
                        Button(LocalizedString.aboutResetConfirmCancel, role: .cancel) {}
                        Button(LocalizedString.aboutResetConfirmReset, role: .destructive) {
                            settings.resetToDefaults()
                        }
                    } message: {
                        Text(LocalizedString.aboutResetConfirmMessage)
                    }
                }
                .padding(.horizontal, 24)

                Spacer()
            }
            .padding(.vertical, 24)
        }
        .onAppear {
            checkPermissions()
        }
        .onReceive(timer) { _ in
            checkPermissions()
        }
    }

    private func checkPermissions() {
        // Check Accessibility permission
        hasAccessibilityPermission = AXIsProcessTrusted()

        // Check Screen Recording permission
        hasScreenRecordingPermission = CGPreflightScreenCaptureAccess()

        // Check Input Monitoring permission
        // There's no direct API, so we try to create a test monitor
        // If it succeeds, we have permission
        let testMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { _ in }
        hasInputMonitoringPermission = (testMonitor != nil)
        if let monitor = testMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .frame(width: 20)
            Text(text)
                .font(.body)
        }
    }
}

struct PermissionRow: View {
    let icon: String
    let title: String
    let description: String
    let isGranted: Bool
    let action: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(isGranted ? .green : .orange)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.body)
                        .fontWeight(.medium)
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                HStack(spacing: 6) {
                    Image(systemName: isGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(isGranted ? .green : .orange)
                    Text(isGranted ? LocalizedString.aboutPermissionGranted : LocalizedString.aboutPermissionMissing)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(isGranted ? .green : .orange)
                }
            }

            if !isGranted {
                Button(action: action) {
                    HStack {
                        Image(systemName: "gearshape.fill")
                        Text(LocalizedString.aboutPermissionOpenSettings)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Color Preset Button

struct ColorPresetButton: View {
    let color: Color
    @Binding var currentColor: Color

    var body: some View {
        Button(action: {
            currentColor = color
        }) {
            RoundedRectangle(cornerRadius: 4)
                .fill(color)
                .frame(width: 24, height: 24)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                )
                .overlay(
                    // Show checkmark if this is the current color
                    Group {
                        if colorMatches(color, currentColor) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(color == .white || color == .yellow ? .black : .white)
                        }
                    }
                )
        }
        .buttonStyle(.plain)
        .help(colorName(color))
    }

    private func colorMatches(_ c1: Color, _ c2: Color) -> Bool {
        let ns1 = NSColor(c1)
        let ns2 = NSColor(c2)
        guard let rgb1 = ns1.usingColorSpace(.deviceRGB),
              let rgb2 = ns2.usingColorSpace(.deviceRGB) else { return false }
        return abs(rgb1.redComponent - rgb2.redComponent) < 0.01 &&
               abs(rgb1.greenComponent - rgb2.greenComponent) < 0.01 &&
               abs(rgb1.blueComponent - rgb2.blueComponent) < 0.01
    }

    private func colorName(_ color: Color) -> String {
        switch color {
        case .red: return "Rød"
        case .green: return "Grøn"
        case .blue: return "Blå"
        case .yellow: return "Gul"
        case .orange: return "Orange"
        case .purple: return "Lilla"
        case .white: return "Hvid"
        case .black: return "Sort"
        case .gray: return "Grå"
        default: return "Farve"
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
