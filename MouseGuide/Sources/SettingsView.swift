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
                    .accessibilityLabel(String(format: "%@ %@", accessibilityLabelForCategory(category), LocalizedString.accessibilityNavigationSettingsSuffix))
                    .accessibilityHint(String(format: LocalizedString.accessibilityNavigationSettingsHint, accessibilityLabelForCategory(category)))
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
                        .accessibilityHidden(true)
                    Text(selectedCategory.localizedName)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Spacer()

                    // Toggle crosshair switch
                    HStack(spacing: 12) {
                        Text(LocalizedString.appName)
                            .font(.body)
                        Spacer()
                        Toggle("", isOn: $crosshairsVisible)
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .accessibilityLabel("\(LocalizedString.accessibilityToggleMainLabel), \(crosshairsVisible ? LocalizedString.accessibilityStateOn : LocalizedString.accessibilityStateOff)")
                            .accessibilityHint(LocalizedString.accessibilityToggleMainHint)
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
                        BehaviorTab(settings: settings, appDelegate: appDelegate)
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

    private func accessibilityLabelForCategory(_ category: SettingsCategory) -> String {
        return category.localizedName
    }
}

// MARK: - Appearance Tab

struct AppearanceTab: View {
    @ObservedObject var settings: CrosshairsSettings
    @ObservedObject var licenseManager = LicenseManager.shared

    private var hasFullAccess: Bool {
        settings.hasFullAccess
    }

    // Dynamic opacity description based on orientation
    private var opacityDescription: String {
        switch settings.orientation {
        case .circle:
            return LocalizedString.appearanceOpacityDescriptionCircle
        case .edgePointers:
            return LocalizedString.appearanceOpacityDescriptionEdgePointers
        default:
            return LocalizedString.appearanceOpacityDescriptionLines
        }
    }

    private func colorNameForAccessibility(_ color: Color) -> String {
        let nsColor = NSColor(color)
        guard let rgb = nsColor.usingColorSpace(.deviceRGB) else {
            return LocalizedString.colorRed
        }

        // Find closest color name
        if rgb.redComponent > 0.8 && rgb.greenComponent < 0.3 && rgb.blueComponent < 0.3 {
            return LocalizedString.colorRed
        } else if rgb.redComponent < 0.3 && rgb.greenComponent > 0.8 && rgb.blueComponent < 0.3 {
            return LocalizedString.colorGreen
        } else if rgb.redComponent < 0.3 && rgb.greenComponent < 0.3 && rgb.blueComponent > 0.8 {
            return LocalizedString.colorBlue
        } else if rgb.redComponent > 0.8 && rgb.greenComponent > 0.8 && rgb.blueComponent < 0.3 {
            return LocalizedString.colorYellow
        } else if rgb.redComponent > 0.8 && rgb.greenComponent > 0.4 && rgb.greenComponent < 0.7 && rgb.blueComponent < 0.3 {
            return LocalizedString.colorOrange
        } else if rgb.redComponent > 0.6 && rgb.greenComponent < 0.5 && rgb.blueComponent > 0.6 {
            return LocalizedString.colorPurple
        } else if rgb.redComponent > 0.9 && rgb.greenComponent > 0.9 && rgb.blueComponent > 0.9 {
            return LocalizedString.colorWhite
        } else if rgb.redComponent < 0.2 && rgb.greenComponent < 0.2 && rgb.blueComponent < 0.2 {
            return LocalizedString.colorBlack
        } else if rgb.redComponent > 0.4 && rgb.redComponent < 0.6 && rgb.greenComponent > 0.4 && rgb.greenComponent < 0.6 && rgb.blueComponent > 0.4 && rgb.blueComponent < 0.6 {
            return LocalizedString.colorGray
        }
        return LocalizedString.colorRed
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Orientation Section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(LocalizedString.settingsOrientation)
                            .font(.headline)
                        if !hasFullAccess {
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
                            // Horizontal with Reading Line option
                            VStack(alignment: .leading, spacing: 4) {
                                Button(action: {
                                    settings.orientation = .horizontal
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: settings.orientation == .horizontal ? "circle.inset.filled" : "circle")
                                            .foregroundColor(settings.orientation == .horizontal ? .accentColor : .secondary)
                                            .accessibilityHidden(true)
                                        Image(systemName: "arrow.left.and.right")
                                            .foregroundColor(.primary)
                                            .accessibilityHidden(true)
                                        Text(LocalizedString.settingsOrientationHorizontal)
                                            .foregroundColor(.primary)
                                        Spacer()
                                    }
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("\(LocalizedString.accessibilityOrientationHorizontalLabel), \(settings.orientation == .horizontal ? LocalizedString.accessibilityStateSelected : LocalizedString.accessibilityStateNotSelected)")
                                .accessibilityHint(LocalizedString.accessibilityOrientationHorizontalHint)

                                // Reading Line checkbox - always visible, indented
                                HStack(spacing: 8) {
                                    Spacer().frame(width: 36) // Indent to align with text
                                    Toggle("", isOn: $settings.useReadingLine)
                                        .labelsHidden()
                                        .toggleStyle(.checkbox)
                                        .accessibilityLabel(LocalizedString.settingsOrientationReadingLine)
                                        .disabled(settings.orientation != .horizontal)
                                    Text(LocalizedString.settingsOrientationReadingLine)
                                        .font(.caption)
                                        .foregroundColor(settings.orientation == .horizontal ? .secondary : Color.secondary.opacity(0.5))
                                    Spacer()
                                }
                            }

                            // Vertical
                            Button(action: {
                                settings.orientation = .vertical
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: settings.orientation == .vertical ? "circle.inset.filled" : "circle")
                                        .foregroundColor(settings.orientation == .vertical ? .accentColor : .secondary)
                                        .accessibilityHidden(true)
                                    Image(systemName: "arrow.up.and.down")
                                        .foregroundColor(.primary)
                                        .accessibilityHidden(true)
                                    Text(LocalizedString.settingsOrientationVertical)
                                        .foregroundColor(.primary)
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(LocalizedString.accessibilityOrientationVerticalLabel), \(settings.orientation == .vertical ? LocalizedString.accessibilityStateSelected : LocalizedString.accessibilityStateNotSelected)")
                            .accessibilityHint(LocalizedString.accessibilityOrientationVerticalHint)

                            // Both
                            Button(action: {
                                settings.orientation = .both
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: settings.orientation == .both ? "circle.inset.filled" : "circle")
                                        .foregroundColor(settings.orientation == .both ? .accentColor : .secondary)
                                        .accessibilityHidden(true)
                                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                                        .foregroundColor(.primary)
                                        .accessibilityHidden(true)
                                    Text(LocalizedString.settingsOrientationBoth)
                                        .foregroundColor(.primary)
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(LocalizedString.accessibilityOrientationBothLabel), \(settings.orientation == .both ? LocalizedString.accessibilityStateSelected : LocalizedString.accessibilityStateNotSelected)")
                            .accessibilityHint(LocalizedString.accessibilityOrientationBothHint)

                            // Edge Pointers
                            Button(action: {
                                settings.orientation = .edgePointers
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: settings.orientation == .edgePointers ? "circle.inset.filled" : "circle")
                                        .foregroundColor(settings.orientation == .edgePointers ? .accentColor : .secondary)
                                        .accessibilityHidden(true)
                                    Image(systemName: "arrowtriangle.right.fill")
                                        .foregroundColor(.primary)
                                        .accessibilityHidden(true)
                                    Text(LocalizedString.settingsOrientationEdgePointers)
                                        .foregroundColor(.primary)
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(LocalizedString.accessibilityOrientationEdgePointersLabel), \(settings.orientation == .edgePointers ? LocalizedString.accessibilityStateSelected : LocalizedString.accessibilityStateNotSelected)")
                            .accessibilityHint(LocalizedString.accessibilityOrientationEdgePointersHint)

                            // Circle
                            Button(action: {
                                settings.orientation = .circle
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: settings.orientation == .circle ? "circle.inset.filled" : "circle")
                                        .foregroundColor(settings.orientation == .circle ? .accentColor : .secondary)
                                        .accessibilityHidden(true)
                                    Image(systemName: "circle")
                                        .foregroundColor(.primary)
                                        .accessibilityHidden(true)
                                    Text(LocalizedString.settingsOrientationCircle)
                                        .foregroundColor(.primary)
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(LocalizedString.accessibilityOrientationCircleLabel), \(settings.orientation == .circle ? LocalizedString.accessibilityStateSelected : LocalizedString.accessibilityStateNotSelected)")
                            .accessibilityHint(LocalizedString.accessibilityOrientationCircleHint)
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
                        if !hasFullAccess {
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
                            description: opacityDescription,
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
                        if !hasFullAccess {
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
                                    .accessibilityHidden(true)
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
                                    .accessibilityLabel(LocalizedString.accessibilityColorCrosshairLabel)
                                    .accessibilityValue(colorNameForAccessibility(settings.crosshairColor))
                                    .accessibilityHint(LocalizedString.accessibilityColorCrosshairHint)
                            }

                            // Quick color presets
                            if !settings.invertColors {
                                HStack(spacing: 6) {
                                    Text(LocalizedString.appearanceColorsQuickSelect)
                                        .font(.caption)
                                        .foregroundColor(.secondary)

                                    ColorPresetButton(color: .black, currentColor: $settings.crosshairColor, colorType: "crosshair")
                                    ColorPresetButton(color: .white, currentColor: $settings.crosshairColor, colorType: "crosshair")
                                    ColorPresetButton(color: .gray, currentColor: $settings.crosshairColor, colorType: "crosshair")
                                    ColorPresetButton(color: .red, currentColor: $settings.crosshairColor, colorType: "crosshair")
                                    ColorPresetButton(color: .green, currentColor: $settings.crosshairColor, colorType: "crosshair")
                                    ColorPresetButton(color: .blue, currentColor: $settings.crosshairColor, colorType: "crosshair")
                                    ColorPresetButton(color: .yellow, currentColor: $settings.crosshairColor, colorType: "crosshair")
                                    ColorPresetButton(color: .orange, currentColor: $settings.crosshairColor, colorType: "crosshair")
                                    ColorPresetButton(color: .purple, currentColor: $settings.crosshairColor, colorType: "crosshair")
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
                                    .accessibilityLabel(LocalizedString.accessibilityColorBorderLabel)
                                    .accessibilityValue(colorNameForAccessibility(settings.borderColor))
                                    .accessibilityHint(LocalizedString.accessibilityColorBorderHint)
                            }

                            // Quick color presets
                            if !settings.invertColors {
                                HStack(spacing: 6) {
                                    Text(LocalizedString.appearanceColorsQuickSelect)
                                        .font(.caption)
                                        .foregroundColor(.secondary)

                                    ColorPresetButton(color: .black, currentColor: $settings.borderColor, colorType: "border")
                                    ColorPresetButton(color: .white, currentColor: $settings.borderColor, colorType: "border")
                                    ColorPresetButton(color: .gray, currentColor: $settings.borderColor, colorType: "border")
                                    ColorPresetButton(color: .red, currentColor: $settings.borderColor, colorType: "border")
                                    ColorPresetButton(color: .green, currentColor: $settings.borderColor, colorType: "border")
                                    ColorPresetButton(color: .blue, currentColor: $settings.borderColor, colorType: "border")
                                    ColorPresetButton(color: .yellow, currentColor: $settings.borderColor, colorType: "border")
                                    ColorPresetButton(color: .orange, currentColor: $settings.borderColor, colorType: "border")
                                    ColorPresetButton(color: .purple, currentColor: $settings.borderColor, colorType: "border")
                                }
                                .padding(.top, 4)
                            }

                            Text(LocalizedString.appearanceColorsBorderDescription)
                                .font(.caption)
                                .foregroundColor(.secondary)

                            // Circle Fill Color - only show in circle mode
                            if settings.orientation == .circle {
                                Divider()
                                    .padding(.vertical, 12)

                                Text(LocalizedString.appearanceColorsCircleFill)
                                    .font(.headline)

                                HStack {
                                    Text(LocalizedString.settingsCircleFillColor)
                                    Spacer()
                                    ColorPicker("", selection: $settings.circleFillColor)
                                        .labelsHidden()
                                        .frame(width: 60)
                                        .disabled(settings.invertColors || !hasFullAccess)
                                        .accessibilityLabel(LocalizedString.accessibilityColorCircleFillLabel)
                                        .accessibilityValue(colorNameForAccessibility(settings.circleFillColor))
                                        .accessibilityHint(LocalizedString.accessibilityColorCircleFillHint)
                                }

                                // Quick select buttons
                                if !settings.invertColors {
                                    HStack(spacing: 8) {
                                        Text(LocalizedString.appearanceColorsQuickSelect)
                                            .font(.caption)
                                            .foregroundColor(.secondary)

                                        ColorPresetButton(color: .black, currentColor: $settings.circleFillColor, colorType: "circleFill")
                                        ColorPresetButton(color: .white, currentColor: $settings.circleFillColor, colorType: "circleFill")
                                        ColorPresetButton(color: .gray, currentColor: $settings.circleFillColor, colorType: "circleFill")
                                        ColorPresetButton(color: .red, currentColor: $settings.circleFillColor, colorType: "circleFill")
                                        ColorPresetButton(color: .green, currentColor: $settings.circleFillColor, colorType: "circleFill")
                                        ColorPresetButton(color: .blue, currentColor: $settings.circleFillColor, colorType: "circleFill")
                                        ColorPresetButton(color: .yellow, currentColor: $settings.circleFillColor, colorType: "circleFill")
                                        ColorPresetButton(color: .orange, currentColor: $settings.circleFillColor, colorType: "circleFill")
                                        ColorPresetButton(color: .purple, currentColor: $settings.circleFillColor, colorType: "circleFill")
                                    }
                                    .padding(.top, 4)
                                }

                                Text(LocalizedString.appearanceColorsCircleFillDescription)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
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

                // Length Section - only show for line-based orientations, not for circle or edge pointers
                if settings.orientation != .circle && settings.orientation != .edgePointers {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(LocalizedString.settingsLength)
                                .font(.headline)
                            if !hasFullAccess {
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
                                    .accessibilityLabel("\(LocalizedString.accessibilityFixedLengthToggleLabel), \(settings.useFixedLength ? LocalizedString.accessibilityStateOn : LocalizedString.accessibilityStateOff)")
                                    .accessibilityHint(LocalizedString.accessibilityFixedLengthToggleHint)
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
                }

                // Line Style Section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(LocalizedString.settingsLineStyle)
                            .font(.headline)
                        if !hasFullAccess {
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
                                    .accessibilityHidden(true)
                                Image(systemName: "line.horizontal.3")
                                    .foregroundColor(.primary)
                                    .accessibilityHidden(true)
                                Text(LocalizedString.settingsLineStyleSolid)
                                    .foregroundColor(.primary)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(LocalizedString.accessibilityLineStyleSolidLabel), \(settings.lineStyle == .solid ? LocalizedString.accessibilityStateSelected : LocalizedString.accessibilityStateNotSelected)")
                        .accessibilityHint(LocalizedString.accessibilityLineStyleSolidHint)

                        // Dashed
                        Button(action: {
                            settings.lineStyle = .dashed
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: settings.lineStyle == .dashed ? "circle.inset.filled" : "circle")
                                    .foregroundColor(settings.lineStyle == .dashed ? .accentColor : .secondary)
                                    .accessibilityHidden(true)
                                Image(systemName: "line.horizontal.3.decrease")
                                    .foregroundColor(.primary)
                                    .accessibilityHidden(true)
                                Text(LocalizedString.settingsLineStyleDashed)
                                    .foregroundColor(.primary)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(LocalizedString.accessibilityLineStyleDashedLabel), \(settings.lineStyle == .dashed ? LocalizedString.accessibilityStateSelected : LocalizedString.accessibilityStateNotSelected)")
                        .accessibilityHint(LocalizedString.accessibilityLineStyleDashedHint)

                        // Dotted
                        Button(action: {
                            settings.lineStyle = .dotted
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: settings.lineStyle == .dotted ? "circle.inset.filled" : "circle")
                                    .foregroundColor(settings.lineStyle == .dotted ? .accentColor : .secondary)
                                    .accessibilityHidden(true)
                                Image(systemName: "circle.grid.3x3")
                                    .foregroundColor(.primary)
                                    .accessibilityHidden(true)
                                Text(LocalizedString.settingsLineStyleDotted)
                                    .foregroundColor(.primary)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(LocalizedString.accessibilityLineStyleDottedLabel), \(settings.lineStyle == .dotted ? LocalizedString.accessibilityStateSelected : LocalizedString.accessibilityStateNotSelected)")
                        .accessibilityHint(LocalizedString.accessibilityLineStyleDottedHint)
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
    @State private var showResetConfirmation = false
    weak var appDelegate: AppDelegate?

    private var hasFullAccess: Bool {
        settings.hasFullAccess
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Color Adaptation
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(LocalizedString.behaviorColorAdaptation)
                            .font(.headline)
                        if !hasFullAccess {
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
                            Toggle("", isOn: Binding(
                                get: { settings.invertColors },
                                set: { newValue in
                                    settings.invertColors = newValue
                                    if newValue {
                                        // Request Screen Recording - macOS will show system dialog automatically
                                        settings.requestScreenRecordingPermission()
                                        NSLog("✅ Screen Recording permission requested for color adaptation")
                                    }
                                }
                            ))
                                .labelsHidden()
                                .toggleStyle(.switch)
                                .accessibilityLabel("\(LocalizedString.accessibilityBehaviorColorAdaptationLabel), \(settings.invertColors ? LocalizedString.accessibilityStateOn : LocalizedString.accessibilityStateOff)")
                                .accessibilityHint(LocalizedString.accessibilityBehaviorColorAdaptationHint)
                        }
                        Text(LocalizedString.behaviorColorAdaptationDescription)
                            .font(.caption)
                            .foregroundColor(.secondary)

                        if settings.invertColors {
                            HStack(spacing: 8) {
                                Image(systemName: "info.circle")
                                    .foregroundColor(.blue)
                                    .accessibilityHidden(true)
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
                                    .accessibilityLabel("\(LocalizedString.accessibilityBehaviorAutoHidePointerLabel), \(settings.autoHideWhenPointerHidden ? LocalizedString.accessibilityStateOn : LocalizedString.accessibilityStateOff)")
                                    .accessibilityHint(LocalizedString.accessibilityBehaviorAutoHidePointerHint)
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
                                Toggle("", isOn: Binding(
                                    get: { settings.autoHideWhileTyping },
                                    set: { newValue in
                                        if newValue {
                                            // Check permission before enabling
                                            handleAutoHideWhileTypingToggle(enable: true)
                                        } else {
                                            // Disable without permission check
                                            settings.autoHideWhileTyping = false
                                        }
                                    }
                                ))
                                    .labelsHidden()
                                    .toggleStyle(.switch)
                                    .accessibilityLabel("\(LocalizedString.accessibilityBehaviorAutoHideTypingLabel), \(settings.autoHideWhileTyping ? LocalizedString.accessibilityStateOn : LocalizedString.accessibilityStateOff)")
                                    .accessibilityHint(LocalizedString.accessibilityBehaviorAutoHideTypingHint)
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
                                .accessibilityLabel("\(LocalizedString.accessibilityBehaviorLaunchAtLoginLabel), \(LaunchAtLogin.shared.isEnabled ? LocalizedString.accessibilityStateOn : LocalizedString.accessibilityStateOff)")
                                .accessibilityHint(LocalizedString.accessibilityBehaviorLaunchAtLoginHint)
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
                        if !hasFullAccess {
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
                                .accessibilityLabel("\(LocalizedString.accessibilityBehaviorGlidingLabel), \(settings.glidingEnabled ? LocalizedString.accessibilityStateOn : LocalizedString.accessibilityStateOff)")
                                .accessibilityHint(LocalizedString.accessibilityBehaviorGlidingHint)
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
                                    .accessibilityHidden(true)
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
                        .onChange(of: settings.activationKey) { _ in
                            handleKeyboardShortcutChange()
                        }
                        .onChange(of: settings.activationModifiers) { _ in
                            handleKeyboardShortcutChange()
                        }

                        Divider()

                        HStack(spacing: 8) {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                                .accessibilityHidden(true)
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

                // Language
                VStack(alignment: .leading, spacing: 12) {
                    Text(LocalizedString.settingsLanguage)
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(LocalizedString.settingsLanguageDescription)
                            .font(.caption)
                            .foregroundColor(.secondary)

                        HStack {
                            Text(LocalizedString.settingsLanguage + ":")
                                .frame(width: 80, alignment: .leading)

                            Picker("", selection: $settings.language) {
                                Text(LocalizedString.languageDanish).tag("da")
                                Text(LocalizedString.languageEnglish).tag("en")
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                            .frame(width: 150)
                            .accessibilityLabel(LocalizedString.accessibilityLanguagePickerLabel)
                            .accessibilityHint(LocalizedString.accessibilityLanguagePickerHint)

                            Spacer()
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 16)
                    .padding(.horizontal, 24)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                }
                .padding(.horizontal, 24)

                // Reset Settings (nederst)
                VStack(alignment: .leading, spacing: 12) {
                    Text(LocalizedString.aboutReset)
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(LocalizedString.aboutResetDescription)
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Button(action: {
                            showResetConfirmation = true
                        }) {
                            HStack {
                                Image(systemName: "arrow.counterclockwise.circle.fill")
                                    .accessibilityHidden(true)
                                Text(LocalizedString.aboutResetButton)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        .accessibilityLabel(LocalizedString.accessibilityResetButtonLabel)
                        .accessibilityHint(LocalizedString.accessibilityResetButtonHint)
                        .alert(LocalizedString.aboutResetConfirmTitle, isPresented: $showResetConfirmation) {
                            Button(LocalizedString.aboutResetConfirmCancel, role: .cancel) {}
                            Button(LocalizedString.aboutResetConfirmReset, role: .destructive) {
                                settings.resetToDefaults()
                            }
                        } message: {
                            Text(LocalizedString.aboutResetConfirmMessage)
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

    // MARK: - Permission Handlers

    private func handleKeyboardShortcutChange() {
        // Recreate keyboard monitor with new shortcut settings
        // Input Monitoring permission is requested at app launch, so this should just work
        appDelegate?.setupKeyboardMonitor()
        NSLog("✅ Keyboard shortcut updated")
    }

    private func handleAutoHideWhileTypingToggle(enable: Bool) {
        // Just toggle the setting - Input Monitoring permission is requested at app launch
        settings.autoHideWhileTyping = enable
        NSLog("✅ Auto-hide while typing: \(enable)")
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
                                .accessibilityHidden(true)
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
    @ObservedObject var storeKitManager = StoreKitManager.shared
    @State private var showPurchaseSuccess: Bool = false
    @State private var isPurchasing: Bool = false

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
                            // Licensed via StoreKit
                            HStack(spacing: 12) {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.green)
                                    .accessibilityHidden(true)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(LocalizedString.licenseActivated)
                                        .font(.headline)
                                        .foregroundColor(.green)

                                    Text(LocalizedString.licenseThankyou)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel(LocalizedString.accessibilityLicenseActive)

                        case .fullTrial(let daysRemaining):
                            // Full trial
                            HStack(spacing: 12) {
                                Image(systemName: "clock.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.blue)
                                    .accessibilityHidden(true)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(LocalizedString.licenseTrial)
                                        .font(.headline)
                                        .foregroundColor(.blue)

                                    Text("\(daysRemaining) \(LocalizedString.licenseTrialDays)")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel(String(format: LocalizedString.accessibilityLicenseTrial, daysRemaining))

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

                // Purchase via StoreKit
                if case .licensed = licenseManager.licenseState {
                    // Show restore purchases button if licensed
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 16) {
                            Button(action: {
                                Task {
                                    await licenseManager.restorePurchases()
                                }
                            }) {
                                HStack {
                                    Image(systemName: "arrow.clockwise.circle.fill")
                                    Text(LocalizedString.licenseRestorePurchases)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                            }
                            .buttonStyle(.bordered)
                            .accessibilityLabel(LocalizedString.accessibilityLicenseRestoreLabel)
                            .accessibilityHint(LocalizedString.accessibilityLicenseRestoreHint)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 16)
                        .padding(.horizontal, 24)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                    }
                    .padding(.horizontal, 24)
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(LocalizedString.licenseBuyTitle)
                            .font(.headline)

                        VStack(alignment: .leading, spacing: 16) {
                            Text(LocalizedString.licenseBuyDescription)
                                .font(.body)

                            // Buy button
                            Button(action: {
                                purchaseNow()
                            }) {
                                HStack {
                                    if isPurchasing {
                                        ProgressView()
                                            .controlSize(.small)
                                    }
                                    Image(systemName: "cart.fill")
                                    Text(LocalizedString.licenseBuyNow)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .disabled(isPurchasing || storeKitManager.product == nil)
                            .accessibilityLabel(LocalizedString.accessibilityLicenseBuyLabel)
                            .accessibilityHint(LocalizedString.accessibilityLicenseBuyHint)

                            Divider()

                            // Restore purchases
                            Button(action: {
                                Task {
                                    await licenseManager.restorePurchases()
                                }
                            }) {
                                HStack {
                                    Image(systemName: "arrow.clockwise.circle.fill")
                                    Text(LocalizedString.licenseRestorePurchases)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                            }
                            .buttonStyle(.bordered)
                            .accessibilityLabel(LocalizedString.accessibilityLicenseRestorePreviousLabel)
                            .accessibilityHint(LocalizedString.accessibilityLicenseRestorePreviousHint)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 16)
                        .padding(.horizontal, 24)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                    }
                    .padding(.horizontal, 24)
                }


                // Developer Testing
                #if DEBUG
                VStack(alignment: .leading, spacing: 12) {
                    Text(LocalizedString.licenseDeveloperTesting)
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
                                Text(LocalizedString.licenseSimulateExpiredTrial)
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
                                Text(LocalizedString.licenseResetTrial)
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
        .alert(LocalizedString.licenseActivatedTitle, isPresented: $showPurchaseSuccess) {
            Button(LocalizedString.commonOK) {}
        } message: {
            Text(LocalizedString.licenseActivatedMessage)
        }
    }

    private func purchaseNow() {
        isPurchasing = true

        Task {
            NSLog("🛒 Starting StoreKit purchase...")
            let success = await licenseManager.purchase()

            await MainActor.run {
                isPurchasing = false

                if success {
                    NSLog("✅ Purchase successful!")
                    showPurchaseSuccess = true
                } else {
                    NSLog("❌ Purchase failed or cancelled")
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
                .accessibilityLabel(label)
                .accessibilityValue(format(value))
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
                .accessibilityLabel(label)
                .accessibilityValue(format(value))
                .accessibilityHint(description)
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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(spacing: 12) {
                    Image(systemName: "crosshair.circle.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.accentColor)
                        .accessibilityHidden(true)

                    Text(LocalizedString.appName)
                        .font(.title)
                        .fontWeight(.bold)

                    Text("Version \(BuildInfo.shared.version) (Build \(BuildInfo.shared.build))")
                        .foregroundColor(.secondary)

                    // Show app location
                    HStack(spacing: 4) {
                        Text(BuildInfo.shared.buildLocation.emoji)
                        Text(BuildInfo.shared.buildLocation.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 4)
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

                // Permissions Section
                PermissionsSection(settings: settings)

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

                Spacer()
            }
            .padding(.vertical, 24)
        }
    }
}

// MARK: - Permissions Section

struct PermissionsSection: View {
    @ObservedObject var settings: CrosshairsSettings
    @State private var inputMonitoringGranted: Bool = false
    @State private var screenRecordingGranted: Bool = false

    // Timer to refresh permission status (user may grant in System Settings and return)
    let refreshTimer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(LocalizedString.aboutPermissions)
                .font(.title3)
                .fontWeight(.semibold)

            Text(LocalizedString.aboutPermissionsDescription)
                .font(.body)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 12) {
                // Input Monitoring Permission
                PermissionRow(
                    title: LocalizedString.aboutPermissionInputMonitoring,
                    description: LocalizedString.aboutPermissionInputMonitoringDescription,
                    isGranted: inputMonitoringGranted,
                    onOpenSettings: {
                        openInputMonitoringSettings()
                    }
                )

                Divider()

                // Screen Recording Permission
                PermissionRow(
                    title: LocalizedString.aboutPermissionScreenRecording,
                    description: LocalizedString.aboutPermissionScreenRecordingDescription,
                    isGranted: screenRecordingGranted,
                    onOpenSettings: {
                        openScreenRecordingSettings()
                    }
                )
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 20)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
        }
        .padding(.horizontal, 24)
        .onAppear {
            refreshPermissionStatus()
        }
        .onReceive(refreshTimer) { _ in
            refreshPermissionStatus()
        }
    }

    private func refreshPermissionStatus() {
        inputMonitoringGranted = settings.hasInputMonitoringPermission()
        screenRecordingGranted = settings.hasScreenRecordingPermission()
    }

    private func openInputMonitoringSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
    }

    private func openScreenRecordingSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }
}

struct PermissionRow: View {
    let title: String
    let description: String
    let isGranted: Bool
    let onOpenSettings: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Status icon
            Image(systemName: isGranted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 20))
                .foregroundColor(isGranted ? .green : .orange)
                .frame(width: 24)
                .accessibilityHidden(true)

            // Title and description
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(.headline)

                    Text(isGranted ? LocalizedString.aboutPermissionGranted : LocalizedString.aboutPermissionMissing)
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(isGranted ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
                        .foregroundColor(isGranted ? .green : .orange)
                        .cornerRadius(4)
                }

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            // Open Settings button (only show if not granted)
            if !isGranted {
                Button(action: onOpenSettings) {
                    Text(LocalizedString.aboutPermissionOpenSettings)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(isGranted ? LocalizedString.accessibilityStateGranted : LocalizedString.accessibilityStateMissing)")
        .accessibilityHint(isGranted ? "" : String(format: LocalizedString.accessibilityPermissionOpenSettingsHint, title))
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
                .accessibilityHidden(true)
            Text(text)
                .font(.body)
        }
    }
}

// MARK: - Color Preset Button

struct ColorPresetButton: View {
    let color: Color
    @Binding var currentColor: Color
    var colorType: String? = nil  // "crosshair" or "border"

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
                                .accessibilityHidden(true)
                        }
                    }
                )
        }
        .buttonStyle(.plain)
        .help(colorName(color))
        .accessibilityLabel(buildAccessibilityLabel())
        .accessibilityHint(String(format: LocalizedString.accessibilityColorPresetHint, colorNameEnglish(color)))
    }

    private func buildAccessibilityLabel() -> String {
        var label = String(format: LocalizedString.accessibilityColorPresetLabel, colorNameEnglish(color))

        // Add color type if specified
        if let type = colorType {
            let typeString = type == "crosshair" ? LocalizedString.accessibilityColorTypeCrosshair : LocalizedString.accessibilityColorTypeBorder
            label += ", \(typeString)"
        }

        // Add selection state
        let stateString = colorMatches(color, currentColor) ? LocalizedString.accessibilityStateSelected : LocalizedString.accessibilityStateNotSelected
        label += ", \(stateString)"

        return label
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
        case .red: return LocalizedString.colorRed
        case .green: return LocalizedString.colorGreen
        case .blue: return LocalizedString.colorBlue
        case .yellow: return LocalizedString.colorYellow
        case .orange: return LocalizedString.colorOrange
        case .purple: return LocalizedString.colorPurple
        case .white: return LocalizedString.colorWhite
        case .black: return LocalizedString.colorBlack
        case .gray: return LocalizedString.colorGray
        default: return LocalizedString.colorRed
        }
    }

    private func colorNameEnglish(_ color: Color) -> String {
        // Use the same localized color names for accessibility
        // This ensures consistency across the app
        return colorName(color)
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
