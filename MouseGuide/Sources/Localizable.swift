import Foundation
import SwiftUI

class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()

    @Published var currentLanguage: String = "en"
    private var bundle: Bundle?

    private init() {
        // Will be set by CrosshairsSettings
    }

    func setLanguage(_ language: String) {
        currentLanguage = language

        // Get the path to the language bundle
        if let path = Bundle.main.path(forResource: language, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            self.bundle = bundle
        } else {
            self.bundle = Bundle.main
        }

        // Notify all views to update
        objectWillChange.send()
        NotificationCenter.default.post(name: .init("LanguageChanged"), object: nil)
    }

    func localizedString(_ key: String, comment: String = "") -> String {
        if let bundle = bundle {
            return bundle.localizedString(forKey: key, value: nil, table: nil)
        }
        return NSLocalizedString(key, comment: comment)
    }
}

// Helper extension to make it easier to get localized strings
extension String {
    func localized(_ comment: String = "") -> String {
        return LocalizationManager.shared.localizedString(self, comment: comment)
    }
}

// Localization helper
enum LocalizedString {
    // App name
    static var appName: String { "app.name".localized() }

    // Menu Bar
    static var menuToggle: String { "menu.toggle".localized() }
    static var menuToggleLabel: String { "menu.toggleLabel".localized() }
    static var menuToggleOn: String { "menu.toggleOn".localized() }
    static var menuToggleOff: String { "menu.toggleOff".localized() }
    static var menuGettingStarted: String { "menu.gettingStarted".localized() }
    static var menuSettings: String { "menu.settings".localized() }
    static var menuAbout: String { "menu.about".localized() }
    static var menuSupport: String { "menu.support".localized() }
    static var menuThankyou: String { "menu.thankyou".localized() }
    static var menuQuit: String { "menu.quit".localized() }
    static var menuToggleShow: String { "menu.toggle.show".localized() }
    static var menuToggleHide: String { "menu.toggle.hide".localized() }

    // Onboarding
    static var onboardingTitle: String { "onboarding.title".localized() }
    static var onboardingWelcome: String { "onboarding.welcome".localized() }
    static var onboardingStep1Title: String { "onboarding.step1.title".localized() }
    static var onboardingStep1Description: String { "onboarding.step1.description".localized() }
    static var onboardingStep2Title: String { "onboarding.step2.title".localized() }
    static var onboardingStep2Description: String { "onboarding.step2.description".localized() }
    static var onboardingStep3Title: String { "onboarding.step3.title".localized() }
    static var onboardingStep3Description: String { "onboarding.step3.description".localized() }
    static var onboardingStep4Title: String { "onboarding.step4.title".localized() }
    static var onboardingStep4Description: String { "onboarding.step4.description".localized() }
    static var onboardingPermissionTitle: String { "onboarding.permission.title".localized() }
    static var onboardingPermissionDescription: String { "onboarding.permission.description".localized() }
    static var onboardingButtonOpenSettings: String { "onboarding.button.openSettings".localized() }
    static var onboardingButtonGetStarted: String { "onboarding.button.getStarted".localized() }
    static var onboardingButtonContinue: String { "onboarding.button.continue".localized() }

    // Settings
    static var settingsTitle: String { "settings.title".localized() }
    static var settingsActivation: String { "settings.activation".localized() }
    static var settingsKeyboardShortcut: String { "settings.keyboardShortcut".localized() }
    static var settingsCurrent: String { "settings.current".localized() }
    static var settingsChange: String { "settings.change".localized() }
    static var settingsShortcutHelp: String { "settings.shortcutHelp".localized() }

    static var settingsAppearance: String { "settings.appearance".localized() }
    static var settingsCrosshairColor: String { "settings.crosshairColor".localized() }
    static var settingsBorderColor: String { "settings.borderColor".localized() }
    static var settingsOpacity: String { "settings.opacity".localized() }
    static var settingsCenterRadius: String { "settings.centerRadius".localized() }
    static var settingsThickness: String { "settings.thickness".localized() }
    static var settingsEdgePointerThickness: String { "settings.edgePointerThickness".localized() }
    static var settingsBorderSize: String { "settings.borderSize".localized() }
    static var settingsInvertColors: String { "settings.invertColors".localized() }

    static var settingsOrientation: String { "settings.orientation".localized() }
    static var settingsOrientationLabel: String { "settings.orientationLabel".localized() }
    static var settingsOrientationHorizontal: String { "settings.orientation.horizontal".localized() }
    static var settingsOrientationVertical: String { "settings.orientation.vertical".localized() }
    static var settingsOrientationBoth: String { "settings.orientation.both".localized() }
    static var settingsOrientationEdgePointers: String { "settings.orientation.edgePointers".localized() }
    static var settingsOrientationCircle: String { "settings.orientation.circle".localized() }
    static var settingsOrientationReadingLine: String { "settings.orientation.readingLine".localized() }

    static var settingsLength: String { "settings.length".localized() }
    static var settingsFixLength: String { "settings.fixLength".localized() }
    static var settingsFixedLength: String { "settings.fixedLength".localized() }

    static var settingsCircle: String { "settings.circle".localized() }
    static var settingsShowCircle: String { "settings.showCircle".localized() }
    static var settingsCircleRadius: String { "settings.circleRadius".localized() }
    static var settingsCircleFillOpacity: String { "settings.circleFillOpacity".localized() }
    static var settingsCircleFillOpacityDescription: String { "settings.circleFillOpacity.description".localized() }
    static var settingsCircleFillColor: String { "settings.circleFillColor".localized() }

    static var settingsLineStyle: String { "settings.lineStyle".localized() }
    static var settingsLineStyleSolid: String { "settings.lineStyle.solid".localized() }
    static var settingsLineStyleDashed: String { "settings.lineStyle.dashed".localized() }
    static var settingsLineStyleDotted: String { "settings.lineStyle.dotted".localized() }

    static var settingsBehavior: String { "settings.behavior".localized() }
    static var settingsAutoHide: String { "settings.autoHide".localized() }
    static var settingsLaunchAtLogin: String { "settings.launchAtLogin".localized() }

    static var settingsGliding: String { "settings.gliding".localized() }
    static var settingsGlidingEnable: String { "settings.glidingEnable".localized() }
    static var settingsGlidingSpeed: String { "settings.glidingSpeed".localized() }
    static var settingsGlidingSpeedHelp: String { "settings.glidingSpeedHelp".localized() }
    static var settingsGlidingDelay: String { "settings.glidingDelay".localized() }
    static var settingsGlidingDelayHelp: String { "settings.glidingDelayHelp".localized() }
    static var settingsGlidingNote: String { "settings.glidingNote".localized() }

    // Alerts
    static var alertShortcutTitle: String { "alert.shortcut.title".localized() }
    static var alertShortcutMessage: String { "alert.shortcut.message".localized() }
    static var alertOK: String { "alert.ok".localized() }

    // Permissions
    static var permissionAccessibilityRequired: String { "permission.accessibility.required".localized() }
    static var permissionAccessibilityTitle: String { "permission.accessibility.title".localized() }
    static var permissionAccessibilityDescription: String { "permission.accessibility.description".localized() }
    static var permissionButtonOpenSettings: String { "permission.button.openSettings".localized() }

    // Alerts - Accessibility
    static var alertAccessibilityMessage: String { "alert.accessibility.message".localized() }
    static var alertAccessibilityFeature1: String { "alert.accessibility.feature1".localized() }
    static var alertAccessibilityFeature2: String { "alert.accessibility.feature2".localized() }
    static var alertAccessibilityInstruction: String { "alert.accessibility.instruction".localized() }

    // Alerts - Input Monitoring
    static var alertInputMonitoringTitle: String { "alert.inputMonitoring.title".localized() }
    static var alertInputMonitoringMessage: String { "alert.inputMonitoring.message".localized() }
    static var alertInputMonitoringExplanation: String { "alert.inputMonitoring.explanation".localized() }
    static var alertInputMonitoringFeature1: String { "alert.inputMonitoring.feature1".localized() }
    static var alertInputMonitoringFeature2: String { "alert.inputMonitoring.feature2".localized() }
    static var alertInputMonitoringInstruction: String { "alert.inputMonitoring.instruction".localized() }

    // Alerts - Development
    static var alertDevelopmentWarning: String { "alert.development.warning".localized() }
    static var alertDevelopmentInstruction: String { "alert.development.instruction".localized() }
    static var alertDevelopmentPermissionNote: String { "alert.development.permissionNote".localized() }

    // Alerts - About
    static var alertAboutTitle: String { "alert.about.title".localized() }
    static var alertCopiedTitle: String { "alert.copied.title".localized() }

    // Common Buttons
    static var commonButtonLater: String { "common.button.later".localized() }
    static var commonButtonDisable: String { "common.button.disable".localized() }
    static var commonButtonCopyInfo: String { "common.button.copyInfo".localized() }

    // Language
    static var settingsLanguage: String { "settings.language".localized() }
    static var settingsLanguageDescription: String { "settings.language.description".localized() }
    static var languageDanish: String { "language.danish".localized() }
    static var languageEnglish: String { "language.english".localized() }

    // Appearance Tab
    static var appearanceColors: String { "appearance.colors".localized() }
    static var appearanceColorsWarning: String { "appearance.colors.warning".localized() }
    static var appearanceColorsQuickSelect: String { "appearance.colors.quickSelect".localized() }
    static var appearanceColorsCrosshairDescription: String { "appearance.colors.crosshair.description".localized() }
    static var appearanceColorsBorderDescription: String { "appearance.colors.border.description".localized() }
    static var appearanceColorsCircleFill: String { "appearance.colors.circleFill".localized() }
    static var appearanceColorsCircleFillDescription: String { "appearance.colors.circleFill.description".localized() }
    static var appearanceDimensions: String { "appearance.dimensions".localized() }
    static var appearanceOpacityDescription: String { "appearance.opacity.description".localized() }
    static var appearanceOpacityDescriptionLines: String { "appearance.opacity.description.lines".localized() }
    static var appearanceOpacityDescriptionCircle: String { "appearance.opacity.description.circle".localized() }
    static var appearanceOpacityDescriptionEdgePointers: String { "appearance.opacity.description.edgePointers".localized() }
    static var appearanceCenterRadiusDescription: String { "appearance.centerRadius.description".localized() }
    static var appearanceCircleRadiusDescription: String { "appearance.circleRadius.description".localized() }
    static var appearanceThicknessDescription: String { "appearance.thickness.description".localized() }
    static var appearanceEdgePointerThicknessDescription: String { "appearance.edgePointerThickness.description".localized() }
    static var appearanceBorderSizeDescription: String { "appearance.borderSize.description".localized() }
    static var appearanceOrientationDescription: String { "appearance.orientation.description".localized() }
    static var appearanceReadingLine: String { "appearance.readingLine".localized() }
    static var appearanceLengthDescription: String { "appearance.length.description".localized() }
    static var appearanceFixedLengthDescription: String { "appearance.fixedLength.description".localized() }

    // Behavior Tab
    static var behaviorColorAdaptation: String { "behavior.colorAdaptation".localized() }
    static var behaviorColorAdaptationDescription: String { "behavior.colorAdaptation.description".localized() }
    static var behaviorColorAdaptationInfo: String { "behavior.colorAdaptation.info".localized() }
    static var behaviorGeneral: String { "behavior.general".localized() }
    static var behaviorAutoHideDescription: String { "behavior.autoHide.description".localized() }
    static var behaviorAutoHideTyping: String { "behavior.autoHideTyping".localized() }
    static var behaviorAutoHideTypingDescription: String { "behavior.autoHideTyping.description".localized() }
    static var behaviorAutoHideTypingDelay: String { "behavior.autoHideTyping.delay".localized() }
    static var behaviorAutoHideTypingDelayDescription: String { "behavior.autoHideTyping.delay.description".localized() }
    static var behaviorAutoHideTypingPermissions: String { "behavior.autoHideTyping.permissions".localized() }
    static var behaviorLaunchAtLoginDescription: String { "behavior.launchAtLogin.description".localized() }
    static var behaviorGlidingDescription: String { "behavior.gliding.description".localized() }
    static var behaviorGlidingSpeedDescription: String { "behavior.gliding.speed.description".localized() }
    static var behaviorGlidingDelayDescription: String { "behavior.gliding.delay.description".localized() }
    static var behaviorGlidingNote: String { "behavior.gliding.note".localized() }
    static var behaviorShortcutDescription: String { "behavior.shortcut.description".localized() }

    // Color Names
    static var colorRed: String { "color.red".localized() }
    static var colorGreen: String { "color.green".localized() }
    static var colorBlue: String { "color.blue".localized() }
    static var colorYellow: String { "color.yellow".localized() }
    static var colorOrange: String { "color.orange".localized() }
    static var colorPurple: String { "color.purple".localized() }
    static var colorWhite: String { "color.white".localized() }
    static var colorBlack: String { "color.black".localized() }
    static var colorGray: String { "color.gray".localized() }

    // About Tab
    static var aboutApp: String { "about.app".localized() }
    static var aboutDescription: String { "about.description".localized() }
    static var aboutFeatures: String { "about.features".localized() }
    static var aboutFeatureMultimonitor: String { "about.feature.multimonitor".localized() }
    static var aboutFeatureColorAdaptation: String { "about.feature.colorAdaptation".localized() }
    static var aboutFeatureCustomizable: String { "about.feature.customizable".localized() }
    static var aboutFeatureGliding: String { "about.feature.gliding".localized() }
    static var aboutFeatureShortcut: String { "about.feature.shortcut".localized() }
    static var aboutMadeBy: String { "about.madeBy".localized() }
    static var aboutCopyright: String { "about.copyright".localized() }
    static var aboutPermissions: String { "about.permissions".localized() }
    static var aboutPermissionsDescription: String { "about.permissions.description".localized() }
    static var aboutPermissionAccessibility: String { "about.permission.accessibility".localized() }
    static var aboutPermissionAccessibilityDescription: String { "about.permission.accessibility.description".localized() }
    static var aboutPermissionInputMonitoring: String { "about.permission.inputMonitoring".localized() }
    static var aboutPermissionInputMonitoringDescription: String { "about.permission.inputMonitoring.description".localized() }
    static var aboutPermissionScreenRecording: String { "about.permission.screenRecording".localized() }
    static var aboutPermissionScreenRecordingDescription: String { "about.permission.screenRecording.description".localized() }
    static var aboutPermissionGranted: String { "about.permission.granted".localized() }
    static var aboutPermissionMissing: String { "about.permission.missing".localized() }
    static var aboutPermissionOpenSettings: String { "about.permission.openSettings".localized() }
    static var aboutReset: String { "about.reset".localized() }
    static var aboutResetDescription: String { "about.reset.description".localized() }
    static var aboutResetButton: String { "about.reset.button".localized() }
    static var aboutResetConfirmTitle: String { "about.reset.confirm.title".localized() }
    static var aboutResetConfirmMessage: String { "about.reset.confirm.message".localized() }
    static var aboutResetConfirmCancel: String { "about.reset.confirm.cancel".localized() }
    static var aboutResetConfirmReset: String { "about.reset.confirm.reset".localized() }

    // Common
    static var commonOK: String { "common.ok".localized() }
    static var commonOk: String { "common.ok".localized() }
    static var commonCancel: String { "common.cancel".localized() }
    static var commonClose: String { "common.close".localized() }

    // Formatted Values
    static func formatPercentVisible(_ value: Double) -> String {
        String(format: "format.percent.visible".localized(), Int(value * 100))
    }
    static func formatPixels(_ value: Double) -> String {
        String(format: "format.pixels".localized(), Int(value))
    }
    static func formatSeconds(_ value: Double) -> String {
        String(format: "format.seconds".localized(), value)
    }
    static func formatSpeed(_ value: Double) -> String {
        String(format: "format.speed".localized(), value)
    }
    static func formatDelay(_ value: Double) -> String {
        String(format: "format.delay".localized(), value)
    }
    static func formatMinutes(_ value: Int) -> String {
        if value == 1 {
            return "1 \("format.minute.singular".localized())"
        } else {
            return "\(value) \("format.minute.plural".localized())"
        }
    }

    // License Tab
    static var licenseStatus: String { "license.status".localized() }
    static var licenseActivated: String { "license.activated".localized() }
    static var licenseThankyou: String { "license.thankyou".localized() }
    static var licenseEmail: String { "license.email".localized() }
    static var licenseProduct: String { "license.product".localized() }
    static var licenseActivatedDate: String { "license.activatedDate".localized() }
    static var licenseKey: String { "license.key".localized() }
    static var licenseTrial: String { "license.trial".localized() }
    static var licenseTrialDays: String { "license.trialDays".localized() }
    static var licenseFree: String { "license.free".localized() }
    static var licenseFreeMinutes: String { "license.freeMinutes".localized() }
    static var licenseFreeRestrictions: String { "license.freeRestrictions".localized() }
    static var licenseFreeRestart: String { "license.freeRestart".localized() }
    static var licenseChecking: String { "license.checking".localized() }
    static var licenseBuyTitle: String { "license.buyTitle".localized() }
    static var licenseBuyDescription: String { "license.buyDescription".localized() }
    static var licenseBuyNow: String { "license.buyNow".localized() }
    static var licenseAlreadyBought: String { "license.alreadyBought".localized() }
    static var licenseEnterKey: String { "license.enterKey".localized() }
    static var licensePlaceholder: String { "license.placeholder".localized() }
    static var licenseActivate: String { "license.activate".localized() }
    static var licenseActivating: String { "license.activating".localized() }
    static var licenseActivatedTitle: String { "license.activated.title".localized() }
    static var licenseActivatedMessage: String { "license.activated.message".localized() }
    static var licenseRestorePurchases: String { "license.restorePurchases".localized() }
    static var licenseDeveloperTesting: String { "license.developerTesting".localized() }
    static var licenseSimulateExpiredTrial: String { "license.simulateExpiredTrial".localized() }
    static var licenseResetTrial: String { "license.resetTrial".localized() }

    // Free Session Expiry
    static var freeSessionExpiredTitle: String { "freeSession.expired.title".localized() }
    static var freeSessionExpiredMessage: String { "freeSession.expired.message".localized() }
    static var freeSessionBuyLicense: String { "freeSession.buyLicense".localized() }
    static var freeSessionRestart: String { "freeSession.restart".localized() }

    // Updates
    static var updateCheck: String { "update.check".localized() }
    static var updateChecking: String { "update.checking".localized() }
    static var updateUpToDate: String { "update.upToDate".localized() }
    static var updateUpToDateMessage: String { "update.upToDateMessage".localized() }
    static var updateAvailable: String { "update.available".localized() }
    static var updateAvailableMessage: String { "update.availableMessage".localized() }
    static var updateDownload: String { "update.download".localized() }
    static var updateError: String { "update.error".localized() }
    static var updateErrorMessage: String { "update.errorMessage".localized() }
    static var updateCurrentVersion: String { "update.currentVersion".localized() }

    // Accessibility
    static var accessibilityMenubarToggleLabel: String { "accessibility.menubar.toggle.label".localized() }
    static var accessibilityMenubarToggleHelp: String { "accessibility.menubar.toggle.help".localized() }
    static var accessibilityStateOn: String { "accessibility.state.on".localized() }
    static var accessibilityStateOff: String { "accessibility.state.off".localized() }
    static var accessibilityStateSelected: String { "accessibility.state.selected".localized() }
    static var accessibilityStateNotSelected: String { "accessibility.state.notSelected".localized() }
    static var accessibilityStateGranted: String { "accessibility.state.granted".localized() }
    static var accessibilityStateMissing: String { "accessibility.state.missing".localized() }

    // Accessibility - Navigation
    static var accessibilityNavigationSettingsSuffix: String { "accessibility.navigation.settings.suffix".localized() }
    static var accessibilityNavigationSettingsHint: String { "accessibility.navigation.settings.hint".localized() }

    // Accessibility - Main Toggle
    static var accessibilityToggleMainLabel: String { "accessibility.toggle.main.label".localized() }
    static var accessibilityToggleMainHint: String { "accessibility.toggle.main.hint".localized() }

    // Accessibility - Orientations
    static var accessibilityOrientationHorizontalLabel: String { "accessibility.orientation.horizontal.label".localized() }
    static var accessibilityOrientationHorizontalHint: String { "accessibility.orientation.horizontal.hint".localized() }
    static var accessibilityOrientationVerticalLabel: String { "accessibility.orientation.vertical.label".localized() }
    static var accessibilityOrientationVerticalHint: String { "accessibility.orientation.vertical.hint".localized() }
    static var accessibilityOrientationBothLabel: String { "accessibility.orientation.both.label".localized() }
    static var accessibilityOrientationBothHint: String { "accessibility.orientation.both.hint".localized() }
    static var accessibilityOrientationReadingLineLabel: String { "accessibility.orientation.readingLine.label".localized() }
    static var accessibilityOrientationReadingLineHint: String { "accessibility.orientation.readingLine.hint".localized() }
    static var accessibilityOrientationEdgePointersLabel: String { "accessibility.orientation.edgePointers.label".localized() }
    static var accessibilityOrientationEdgePointersHint: String { "accessibility.orientation.edgePointers.hint".localized() }
    static var accessibilityOrientationCircleLabel: String { "accessibility.orientation.circle.label".localized() }
    static var accessibilityOrientationCircleHint: String { "accessibility.orientation.circle.hint".localized() }

    // Accessibility - Colors
    static var accessibilityColorCrosshairLabel: String { "accessibility.color.crosshair.label".localized() }
    static var accessibilityColorCrosshairHint: String { "accessibility.color.crosshair.hint".localized() }
    static var accessibilityColorBorderLabel: String { "accessibility.color.border.label".localized() }
    static var accessibilityColorBorderHint: String { "accessibility.color.border.hint".localized() }
    static var accessibilityColorCircleFillLabel: String { "accessibility.color.circleFill.label".localized() }
    static var accessibilityColorCircleFillHint: String { "accessibility.color.circleFill.hint".localized() }

    // Accessibility - Fixed Length
    static var accessibilityFixedLengthToggleLabel: String { "accessibility.fixedLength.toggle.label".localized() }
    static var accessibilityFixedLengthToggleHint: String { "accessibility.fixedLength.toggle.hint".localized() }

    // Accessibility - Line Styles
    static var accessibilityLineStyleSolidLabel: String { "accessibility.lineStyle.solid.label".localized() }
    static var accessibilityLineStyleSolidHint: String { "accessibility.lineStyle.solid.hint".localized() }
    static var accessibilityLineStyleDashedLabel: String { "accessibility.lineStyle.dashed.label".localized() }
    static var accessibilityLineStyleDashedHint: String { "accessibility.lineStyle.dashed.hint".localized() }
    static var accessibilityLineStyleDottedLabel: String { "accessibility.lineStyle.dotted.label".localized() }
    static var accessibilityLineStyleDottedHint: String { "accessibility.lineStyle.dotted.hint".localized() }

    // Accessibility - Behaviors
    static var accessibilityBehaviorColorAdaptationLabel: String { "accessibility.behavior.colorAdaptation.label".localized() }
    static var accessibilityBehaviorColorAdaptationHint: String { "accessibility.behavior.colorAdaptation.hint".localized() }
    static var accessibilityBehaviorAutoHidePointerLabel: String { "accessibility.behavior.autoHidePointer.label".localized() }
    static var accessibilityBehaviorAutoHidePointerHint: String { "accessibility.behavior.autoHidePointer.hint".localized() }
    static var accessibilityBehaviorAutoHideTypingLabel: String { "accessibility.behavior.autoHideTyping.label".localized() }
    static var accessibilityBehaviorAutoHideTypingHint: String { "accessibility.behavior.autoHideTyping.hint".localized() }
    static var accessibilityBehaviorLaunchAtLoginLabel: String { "accessibility.behavior.launchAtLogin.label".localized() }
    static var accessibilityBehaviorLaunchAtLoginHint: String { "accessibility.behavior.launchAtLogin.hint".localized() }
    static var accessibilityBehaviorGlidingLabel: String { "accessibility.behavior.gliding.label".localized() }
    static var accessibilityBehaviorGlidingHint: String { "accessibility.behavior.gliding.hint".localized() }

    // Accessibility - License
    static var accessibilityLicenseActive: String { "accessibility.license.active".localized() }
    static var accessibilityLicenseTrial: String { "accessibility.license.trial".localized() }
    static var accessibilityLicenseRestoreLabel: String { "accessibility.license.restore.label".localized() }
    static var accessibilityLicenseRestoreHint: String { "accessibility.license.restore.hint".localized() }
    static var accessibilityLicenseBuyLabel: String { "accessibility.license.buy.label".localized() }
    static var accessibilityLicenseBuyHint: String { "accessibility.license.buy.hint".localized() }
    static var accessibilityLicenseRestorePreviousLabel: String { "accessibility.license.restorePrevious.label".localized() }
    static var accessibilityLicenseRestorePreviousHint: String { "accessibility.license.restorePrevious.hint".localized() }

    // Accessibility - Updates
    static var accessibilityUpdateCheckLabel: String { "accessibility.update.check.label".localized() }
    static var accessibilityUpdateCheckHint: String { "accessibility.update.check.hint".localized() }

    // Accessibility - Language
    static var accessibilityLanguagePickerLabel: String { "accessibility.language.picker.label".localized() }
    static var accessibilityLanguagePickerHint: String { "accessibility.language.picker.hint".localized() }

    // Accessibility - Reset
    static var accessibilityResetButtonLabel: String { "accessibility.reset.button.label".localized() }
    static var accessibilityResetButtonHint: String { "accessibility.reset.button.hint".localized() }

    // Accessibility - Permissions
    static var accessibilityPermissionStatusFormat: String { "accessibility.permission.status.format".localized() }
    static var accessibilityPermissionOpenSettingsLabel: String { "accessibility.permission.openSettings.label".localized() }
    static var accessibilityPermissionOpenSettingsHint: String { "accessibility.permission.openSettings.hint".localized() }

    // Accessibility - Color Presets
    static var accessibilityColorPresetLabel: String { "accessibility.colorPreset.label".localized() }
    static var accessibilityColorPresetHint: String { "accessibility.colorPreset.hint".localized() }
    static var accessibilityColorTypeCrosshair: String { "accessibility.colorType.crosshair".localized() }
    static var accessibilityColorTypeBorder: String { "accessibility.colorType.border".localized() }

    // Accessibility - Keyboard Shortcut
    static var accessibilityShortcutRecorderLabel: String { "accessibility.shortcutRecorder.label".localized() }
    static var accessibilityShortcutRecorderHint: String { "accessibility.shortcutRecorder.hint".localized() }
    static var accessibilityShortcutRecorderRecording: String { "accessibility.shortcutRecorder.recording".localized() }

    // Keyboard Shortcut Recorder
    static var shortcutRecorderPlaceholder: String { "shortcut.recorder.placeholder".localized() }
    static var shortcutRecorderRecording: String { "shortcut.recorder.recording".localized() }

    // Keyboard Shortcut Permission Alert
    static var shortcutPermissionTitle: String { "shortcut.permission.title".localized() }
    static var shortcutPermissionMessage: String { "shortcut.permission.message".localized() }
    static var shortcutPermissionOpenSettings: String { "shortcut.permission.openSettings".localized() }
    static var shortcutPermissionLater: String { "shortcut.permission.later".localized() }

    // Window Titles
    static var windowSettingsTitle: String { "window.settings.title".localized() }
    static var gettingStartedTitle: String { "window.gettingStarted.title".localized() }
}
