import Foundation
import StoreKit

@MainActor
class StoreKitManager: ObservableObject {
    static let shared = StoreKitManager()

    // Product ID - must match App Store Connect configuration
    private let productID = "com.mouseguide.fullversion"

    @Published var purchaseState: PurchaseState = .notPurchased
    @Published var product: Product?

    private var updateListenerTask: Task<Void, Error>?

    enum PurchaseState {
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

    func loadProducts() async {
        do {
            let products = try await Product.products(for: [productID])
            if let product = products.first {
                self.product = product
                NSLog("✅ Loaded product: \(product.displayName) - \(product.displayPrice)")
            } else {
                NSLog("❌ No products found for ID: \(productID)")
            }
        } catch {
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
