import Foundation
import Combine

class LicenseManager: ObservableObject {
    static let shared = LicenseManager()

    @Published var licenseState: LicenseState = .checking {
        didSet {
            NSLog("📢 LicenseState changed to \(licenseState)")
            NotificationCenter.default.post(name: .init("LicenseStateChanged"), object: nil)
        }
    }
    @Published var trialDaysRemaining: Int = 7
    @Published var freeMinutesRemaining: Int = 10
    @Published var freeSecondsRemaining: Int = 0

    private var freeTimer: Timer?
    private let appSupportURL: URL
    private let trialDataURL: URL

    enum LicenseState {
        case checking
        case fullTrial(daysRemaining: Int)
        case free(minutesRemaining: Int)  // After trial - red cross 1px, one screen, restart every 10 min
        case freeExpired  // After free session expires - continue with basic features
        case licensed
    }

    struct TrialData: Codable {
        var firstLaunchDate: Date
        var sessionStartDate: Date?
    }


    private init() {
        // Set up AppSupport directory
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        appSupportURL = appSupport.appendingPathComponent("com.mouseguide", isDirectory: true)
        trialDataURL = appSupportURL.appendingPathComponent("trial.json")

        // Create directory if needed
        try? fileManager.createDirectory(at: appSupportURL, withIntermediateDirectories: true)

        // Check license status
        checkLicenseStatus()
    }

    func checkLicenseStatus() {
        // First check StoreKit purchase status
        Task { @MainActor in
            await StoreKitManager.shared.checkPurchaseStatus()

            if StoreKitManager.shared.isPurchased {
                self.licenseState = .licensed
                CrosshairsSettings.shared.isPurchased = true
                NSLog("✅ User has valid StoreKit purchase")
                return
            }

            // No purchase, check trial status
            await self.checkTrialStatus()
        }
    }

    private func checkTrialStatus() async {
        // No purchase, check trial status
        var trialData = loadTrialData()

        if trialData == nil {
            // First launch - create trial data
            trialData = TrialData(firstLaunchDate: Date(), sessionStartDate: Date())
            saveTrialData(trialData!)
        }

        guard let trial = trialData else { return }

        let calendar = Calendar.current
        let daysSinceFirstLaunch = calendar.dateComponents([.day], from: trial.firstLaunchDate, to: Date()).day ?? 0

        NSLog("📅 Days since first launch: \(daysSinceFirstLaunch)")

        if daysSinceFirstLaunch < 7 {
            // Still in full trial period
            let daysRemaining = 7 - daysSinceFirstLaunch
            trialDaysRemaining = daysRemaining
            licenseState = .fullTrial(daysRemaining: daysRemaining)

            // Update session start
            var updatedTrial = trial
            updatedTrial.sessionStartDate = Date()
            saveTrialData(updatedTrial)
        } else {
            // Trial expired - free version with 10 minute restart requirement
            startFreeSession()
        }
    }

    private func startFreeSession() {
        // Safely load trial data, or create new if missing
        var trial: TrialData
        if let existingTrial = loadTrialData() {
            trial = existingTrial
        } else {
            // Create new trial data if somehow missing
            trial = TrialData(firstLaunchDate: Date(), sessionStartDate: Date())
            NSLog("⚠️ Trial data was missing, created new")
        }
        trial.sessionStartDate = Date()
        saveTrialData(trial)

        // 10 minute free session
        let totalSeconds = 10 * 60  // 10 minutes in seconds
        freeMinutesRemaining = 10
        freeSecondsRemaining = 0
        licenseState = .free(minutesRemaining: 10)
        NSLog("⏰ Starting 10 minute free session")

        // Start countdown timer - runs every second on main thread
        freeTimer?.invalidate()

        var secondsLeft = totalSeconds
        freeTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            // Ensure main thread for @Published property updates
            DispatchQueue.main.async {
                guard let self = self else { return }

                secondsLeft -= 1

                // Update minutes and seconds
                self.freeMinutesRemaining = secondsLeft / 60
                self.freeSecondsRemaining = secondsLeft % 60

                if secondsLeft <= 0 {
                    self.freeTimer?.invalidate()

                    // Change state to expired
                    self.licenseState = .freeExpired
                    NSLog("🔒 Free session expired - features locked to basic")

                    // Force settings to update
                    let settings = CrosshairsSettings.shared
                    settings.isPurchased = false

                    // Post settings changed to force UI update
                    NotificationCenter.default.post(name: .init("CrosshairsSettingsChanged"), object: nil)

                    // Post notification to show restart dialog
                    NotificationCenter.default.post(name: .init("FreeSessionExpired"), object: nil)
                } else {
                    self.licenseState = .free(minutesRemaining: self.freeMinutesRemaining)
                }
            }
        }
    }

    // Purchase through StoreKit
    func purchase() async -> Bool {
        let success = await StoreKitManager.shared.purchase()

        if success {
            // Update state
            licenseState = .licensed
            CrosshairsSettings.shared.isPurchased = true

            // Stop free timer if running
            freeTimer?.invalidate()
        }

        return success
    }

    func restorePurchases() async {
        await StoreKitManager.shared.restorePurchases()
        checkLicenseStatus()
    }

    // MARK: - Storage

    func loadTrialData() -> TrialData? {
        guard let data = try? Data(contentsOf: trialDataURL) else { return nil }
        return try? JSONDecoder().decode(TrialData.self, from: data)
    }

    func saveTrialData(_ trialData: TrialData) {
        guard let data = try? JSONEncoder().encode(trialData) else { return }
        try? data.write(to: trialDataURL)
    }


    // MARK: - Helper

    func resetTrial() {
        // For testing purposes
        NSLog("🔄 Resetting trial data...")

        // Stop any running timers
        freeTimer?.invalidate()
        freeTimer = nil
        NSLog("  ✅ Timer stopped")

        // Clear UserDefaults flags
        CrosshairsSettings.shared.isPurchased = false
        UserDefaults.standard.removeObject(forKey: "isPurchased")
        // Note: synchronize() is deprecated - UserDefaults auto-saves
        NSLog("  ✅ UserDefaults cleared")

        // Remove trial file
        if FileManager.default.fileExists(atPath: trialDataURL.path) {
            try? FileManager.default.removeItem(at: trialDataURL)
            NSLog("  ✅ Trial data removed")
        }

        // Reset state and create new trial
        licenseState = .checking
        NSLog("  ✅ State reset to .checking")

        // Check license status (will create new 7-day trial)
        checkLicenseStatus()
        NSLog("  ✅ New trial created")

        // Force UI update
        NotificationCenter.default.post(name: .init("LicenseStateChanged"), object: nil)
        NotificationCenter.default.post(name: .init("CrosshairsSettingsChanged"), object: nil)
        NSLog("  ✅ UI notifications sent")

        NSLog("✅ Trial reset complete!")
    }
}

