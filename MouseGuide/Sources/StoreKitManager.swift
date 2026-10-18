import Foundation
import StoreKit

@MainActor
class StoreKitManager: ObservableObject {
    static let shared = StoreKitManager()

    // Product ID - must match App Store Connect configuration
    private let productID = "dk.netdot.sightline.fullversion"

    /// Feature gating reads a cached flag rather than StoreKit itself, so the
    /// overlay does not flash the free rendering during the async entitlement
    /// check at launch. This is the only place that writes it.
    @Published var purchaseState: PurchaseState = .checking {
        didSet {
            // Only resolved states update the cache - .checking and .purchasing
            // are transient, and .failed tells us nothing about entitlement.
            switch purchaseState {
            case .purchased:
                UserDefaults.standard.set(true, forKey: CrosshairsSettings.purchaseCacheKey)
            case .notPurchased:
                UserDefaults.standard.set(false, forKey: CrosshairsSettings.purchaseCacheKey)
            case .checking, .purchasing, .failed:
                break
            }
            NotificationCenter.default.post(name: .init("PurchaseStateChanged"), object: nil)
        }
    }
    @Published var product: Product?

    /// True when the last attempt to load the product came back empty or failed.
    /// The purchase button is disabled without a product, and App Review rejected
    /// a disabled button with no explanation (guideline 2.1(b), August 2026).
    @Published private(set) var productUnavailable = false
    private var isLoadingProducts = false

    private var updateListenerTask: Task<Void, Error>?

    enum PurchaseState {
        case checking
        case notPurchased
        case purchasing
        case purchased
        case failed(Error)
    }

    private init() {
        // Start listening for transaction updates
        updateListenerTask = listenForTransactions()

        Task {
            await loadProducts()
            await checkPurchaseStatus()
        }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    // MARK: - Load Products

    /// Runs at launch and again whenever the License pane opens without a
    /// product, so a launch before the network was up does not leave the
    /// purchase button disabled for the rest of the session.
    func loadProducts() async {
        guard !isLoadingProducts else { return }
        isLoadingProducts = true
        defer { isLoadingProducts = false }

        do {
            let products = try await Product.products(for: [productID])
            if let product = products.first {
                self.product = product
                productUnavailable = false
                NSLog("✅ Loaded product: \(product.displayName) - \(product.displayPrice)")
            } else {
                productUnavailable = true
                NSLog("❌ No products found for ID: \(productID)")
            }
        } catch {
            productUnavailable = true
            NSLog("❌ Failed to load products: \(error.localizedDescription)")
        }
    }

    // MARK: - Purchase

    func purchase() async -> Bool {
        guard let product = product else {
            NSLog("❌ No product available to purchase")
            return false
        }

        purchaseState = .purchasing

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                // Check verification
                let transaction = try checkVerified(verification)

                // Update purchase state
                purchaseState = .purchased

                // Finish the transaction
                await transaction.finish()

                NSLog("✅ Purchase successful!")
                return true

            case .userCancelled:
                NSLog("⚠️ User cancelled purchase")
                purchaseState = .notPurchased
                return false

            case .pending:
                NSLog("⏳ Purchase pending approval")
                purchaseState = .notPurchased
                return false

            @unknown default:
                NSLog("❌ Unknown purchase result")
                purchaseState = .notPurchased
                return false
            }
        } catch {
            NSLog("❌ Purchase failed: \(error.localizedDescription)")
            purchaseState = .failed(error)
            return false
        }
    }

    // MARK: - Check Purchase Status

    func checkPurchaseStatus() async {
        // Check for existing entitlements
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)

                if transaction.productID == productID {
                    purchaseState = .purchased
                    NSLog("✅ User has valid purchase entitlement")
                    return
                }
            } catch {
                NSLog("❌ Transaction verification failed: \(error.localizedDescription)")
            }
        }

        // No valid entitlement found
        purchaseState = .notPurchased
        NSLog("ℹ️ No valid purchase found")
    }

    // MARK: - Restore Purchases

    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await checkPurchaseStatus()
            NSLog("✅ Purchases restored")
        } catch {
            NSLog("❌ Failed to restore purchases: \(error.localizedDescription)")
        }
    }

    // MARK: - Transaction Listener

    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            // Iterate through any transactions that don't come from direct call to `purchase()`
            for await result in Transaction.updates {
                do {
                    let transaction = try await self.checkVerified(result)

                    // Deliver products to the user
                    await self.updatePurchaseState()

                    // Always finish a transaction
                    await transaction.finish()
                } catch {
                    NSLog("❌ Transaction verification failed: \(error.localizedDescription)")
                }
            }
        }
    }

    private func updatePurchaseState() async {
        await checkPurchaseStatus()
    }

    // MARK: - Verification

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        // Check whether the JWS passes StoreKit verification
        switch result {
        case .unverified:
            // StoreKit parses the JWS, but it fails verification
            throw StoreError.failedVerification
        case .verified(let safe):
            // The result is verified, return the unwrapped value
            return safe
        }
    }

    // MARK: - Helper

    var isPurchased: Bool {
        if case .purchased = purchaseState {
            return true
        }
        return false
    }
}

enum StoreError: Error {
    case failedVerification
}
