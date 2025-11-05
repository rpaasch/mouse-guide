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
    private let licenseDataURL: URL

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

    struct LicenseData: Codable {
        let licenseKey: String
        let activationDate: Date
        let isValid: Bool
    }

    private init() {
        // Set up AppSupport directory
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        appSupportURL = appSupport.appendingPathComponent("com.mouseguide", isDirectory: true)
        trialDataURL = appSupportURL.appendingPathComponent("trial.json")
        licenseDataURL = appSupportURL.appendingPathComponent("license.json")

        // Create directory if needed
        try? fileManager.createDirectory(at: appSupportURL, withIntermediateDirectories: true)

        // Check license status
        checkLicenseStatus()
    }

    func checkLicenseStatus() {
        // First check if we have a valid license
        if let licenseData = loadLicenseData(), licenseData.isValid {
            licenseState = .licensed
            CrosshairsSettings.shared.isPurchased = true
            return
        }

        // No license, check trial status
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
        var trial = loadTrialData()!
        trial.sessionStartDate = Date()
        saveTrialData(trial)

        // 10 minute free session
        let totalSeconds = 10 * 60  // 10 minutes in seconds
        freeMinutesRemaining = 10
        freeSecondsRemaining = 0
        licenseState = .free(minutesRemaining: 10)
        NSLog("⏰ Starting 10 minute free session")

        // Start countdown timer - runs every second
        freeTimer?.invalidate()

        var secondsLeft = totalSeconds
        freeTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
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

    func activateLicense(_ licenseKey: String) async -> Result<Void, LicenseError> {
        try? "🔑 activateLicense() called with key: \(licenseKey)\n".appendToFile(at: "/tmp/mouse_debug.log")
        NSLog("🔑 activateLicense() called with key: \(licenseKey)")
        let trimmedKey = licenseKey.trimmingCharacters(in: .whitespacesAndNewlines)
        try? "🔑 Trimmed key: \(trimmedKey)\n".appendToFile(at: "/tmp/mouse_debug.log")
        NSLog("🔑 Trimmed key: \(trimmedKey)")

        // Basic validation - should be like XXXXXXXX-XXXXXXXX-XXXXXXXX-XXXXXXXX
        let keyPattern = "^[A-Z0-9]{8}-[A-Z0-9]{8}-[A-Z0-9]{8}-[A-Z0-9]{8}$"
        let keyPredicate = NSPredicate(format: "SELF MATCHES %@", keyPattern)

        if !keyPredicate.evaluate(with: trimmedKey.uppercased()) {
            try? "❌ Key format validation failed\n".appendToFile(at: "/tmp/mouse_debug.log")
            NSLog("❌ Key format validation failed")
            return .failure(.invalidFormat)
        }

        try? "✅ Key format valid, calling Gumroad API...\n".appendToFile(at: "/tmp/mouse_debug.log")
        NSLog("✅ Key format valid, calling Gumroad API...")
        // Validate with Gumroad API
        let result = await validateWithGumroad(licenseKey: trimmedKey)
        try? "🔙 Returned from validateWithGumroad\n".appendToFile(at: "/tmp/mouse_debug.log")
        NSLog("🔙 Returned from validateWithGumroad")

        switch result {
        case .success(let purchaseData):
            // Check if license is still valid (not refunded, not disputed)
            if purchaseData.refunded {
                return .failure(.refunded)
            }

            if purchaseData.disputed || purchaseData.chargedback {
                return .failure(.disputed)
            }

            // Check if subscription is still active (if it's a subscription product)
            if !purchaseData.isSubscriptionActive {
                return .failure(.subscriptionEnded)
            }

            // License is valid - save it
            let licenseData = LicenseData(
                licenseKey: trimmedKey.uppercased(),
                activationDate: Date(),
                isValid: true
            )

            saveLicenseData(licenseData)

            // Update state
            licenseState = .licensed
            CrosshairsSettings.shared.isPurchased = true

            // Stop free timer if running
            freeTimer?.invalidate()

            return .success(())

        case .failure(let error):
            return .failure(error)
        }
    }

    private func validateWithGumroad(licenseKey: String) async -> Result<GumroadPurchase, LicenseError> {
        try? "📥 validateWithGumroad() START\n".appendToFile(at: "/tmp/mouse_debug.log")
        NSLog("📥 validateWithGumroad() START")
        let productId = "j8sMwKf9S9uymY0eI_r6DA=="
        let urlString = "https://api.gumroad.com/v2/licenses/verify"

        guard let url = URL(string: urlString) else {
            try? "❌ Failed to create URL\n".appendToFile(at: "/tmp/mouse_debug.log")
            NSLog("❌ Failed to create URL")
            return .failure(.networkError)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        NSLog("✅ Created URLRequest")

        // Build request body
        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "product_id", value: productId),
            URLQueryItem(name: "license_key", value: licenseKey),
            URLQueryItem(name: "increment_uses_count", value: "false")
        ]

        guard let bodyString = components.query else {
            NSLog("❌ Failed to create query string")
            return .failure(.networkError)
        }

        request.httpBody = bodyString.data(using: .utf8)
        NSLog("✅ Request body set")

        do {
            try? "🌐 Calling Gumroad API...\n".appendToFile(at: "/tmp/mouse_debug.log")
            NSLog("🌐 Calling Gumroad API...")
            NSLog("   URL: \(urlString)")
            NSLog("   Body: \(bodyString)")

            let (data, response) = try await URLSession.shared.data(for: request)
            try? "📡 Got response from Gumroad\n".appendToFile(at: "/tmp/mouse_debug.log")

            guard let httpResponse = response as? HTTPURLResponse else {
                try? "❌ Invalid HTTP response\n".appendToFile(at: "/tmp/mouse_debug.log")
                NSLog("❌ Invalid HTTP response")
                return .failure(.networkError)
            }

            try? "📡 HTTP Status: \(httpResponse.statusCode)\n".appendToFile(at: "/tmp/mouse_debug.log")
            NSLog("📡 HTTP Status: \(httpResponse.statusCode)")

            if let responseString = String(data: data, encoding: .utf8) {
                try? "📦 Response: \(responseString)\n".appendToFile(at: "/tmp/mouse_debug.log")
                NSLog("📦 Response: \(responseString)")
            }

            // Gumroad returns 404 for invalid licenses, but still with valid JSON
            // So we don't check status code, just decode the JSON response
            let gumroadResponse = try JSONDecoder().decode(GumroadResponse.self, from: data)

            if !gumroadResponse.success {
                try? "❌ Gumroad returned success=false\n".appendToFile(at: "/tmp/mouse_debug.log")
                NSLog("❌ Gumroad returned success=false")
                return .failure(.invalidKey)
            }

            guard let purchase = gumroadResponse.purchase else {
                try? "❌ No purchase data in response\n".appendToFile(at: "/tmp/mouse_debug.log")
                NSLog("❌ No purchase data in response")
                return .failure(.invalidKey)
            }

            try? "✅ License validated successfully!\n".appendToFile(at: "/tmp/mouse_debug.log")
            NSLog("✅ License validated successfully!")
            return .success(purchase)

        } catch {
            try? "❌ Gumroad API error: \(error.localizedDescription)\n".appendToFile(at: "/tmp/mouse_debug.log")
            NSLog("❌ Gumroad API error: \(error.localizedDescription)")
            if let urlError = error as? URLError {
                try? "   URLError code: \(urlError.code.rawValue)\n".appendToFile(at: "/tmp/mouse_debug.log")
                NSLog("   URLError code: \(urlError.code.rawValue)")
                NSLog("   URLError description: \(urlError.localizedDescription)")
            }
            return .failure(.networkError)
        }
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

    private func loadLicenseData() -> LicenseData? {
        guard let data = try? Data(contentsOf: licenseDataURL) else { return nil }
        return try? JSONDecoder().decode(LicenseData.self, from: data)
    }

    private func saveLicenseData(_ licenseData: LicenseData) {
        guard let data = try? JSONEncoder().encode(licenseData) else { return }
        try? data.write(to: licenseDataURL)
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
        UserDefaults.standard.synchronize()
        NSLog("  ✅ UserDefaults cleared")

        // Remove trial and license files
        if FileManager.default.fileExists(atPath: trialDataURL.path) {
            try? FileManager.default.removeItem(at: trialDataURL)
            NSLog("  ✅ Trial data removed")
        }

        if FileManager.default.fileExists(atPath: licenseDataURL.path) {
            try? FileManager.default.removeItem(at: licenseDataURL)
            NSLog("  ✅ License data removed")
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

enum LicenseError: LocalizedError {
    case invalidFormat
    case invalidKey
    case networkError
    case alreadyUsed
    case refunded
    case disputed
    case subscriptionEnded

    var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return "license.error.invalidFormat".localized()
        case .invalidKey:
            return "license.error.invalidKey".localized()
        case .networkError:
            return "license.error.networkError".localized()
        case .alreadyUsed:
            return "license.error.alreadyUsed".localized()
        case .refunded:
            return "license.error.refunded".localized()
        case .disputed:
            return "license.error.disputed".localized()
        case .subscriptionEnded:
            return "license.error.subscriptionEnded".localized()
        }
    }
}

// MARK: - Gumroad API Response Models

struct GumroadResponse: Codable {
    let success: Bool
    let uses: Int?
    let purchase: GumroadPurchase?
}

struct GumroadPurchase: Codable {
    let sellerId: String
    let productId: String
    let productName: String
    let email: String
    let price: Int
    let currency: String
    let licenseKey: String
    let refunded: Bool
    let disputed: Bool
    let chargedback: Bool
    let subscriptionEndedAt: String?
    let subscriptionCancelledAt: String?
    let subscriptionFailedAt: String?
    let isMultiseatLicense: Bool?

    enum CodingKeys: String, CodingKey {
        case sellerId = "seller_id"
        case productId = "product_id"
        case productName = "product_name"
        case email
        case price
        case currency
        case licenseKey = "license_key"
        case refunded
        case disputed
        case chargedback = "chargebacked"
        case subscriptionEndedAt = "subscription_ended_at"
        case subscriptionCancelledAt = "subscription_cancelled_at"
        case subscriptionFailedAt = "subscription_failed_at"
        case isMultiseatLicense = "is_multiseat_license"
    }

    var isSubscriptionActive: Bool {
        // If any of these timestamps are not null, the subscription is no longer active
        return subscriptionEndedAt == nil &&
               subscriptionCancelledAt == nil &&
               subscriptionFailedAt == nil
    }
}
