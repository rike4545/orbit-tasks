import Foundation
import StoreKit
import Combine

enum OrbitMonetizationKeys {
    static let adsRemovedEntitlement = "orbit.adsRemovedEntitlement"
}

@MainActor
final class OrbitPurchaseManager: ObservableObject {
    static let removeAdsProductID = "orbit.remove_ads"

    @Published private(set) var removeAdsProduct: Product?
    @Published private(set) var hasRemovedAds: Bool
    @Published private(set) var isLoadingProducts = false
    @Published private(set) var isPurchasing = false
    @Published var statusMessage: String?

    private var updatesTask: Task<Void, Never>?

    init() {
        hasRemovedAds = UserDefaults.standard.bool(forKey: OrbitMonetizationKeys.adsRemovedEntitlement)
        OrbitInterstitialAdManager.shared.setAdsRemoved(hasRemovedAds)
        OrbitAppOpenAdManager.shared.setAdsRemoved(hasRemovedAds)

        updatesTask = observeTransactionUpdates()

        Task {
            await refreshEntitlements()
            await loadProducts()
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    var removeAdsPriceText: String {
        removeAdsProduct?.displayPrice ?? "$4.99"
    }

    func loadProducts() async {
        if isLoadingProducts { return }
        isLoadingProducts = true
        defer { isLoadingProducts = false }

        do {
            let products = try await Product.products(for: [Self.removeAdsProductID])
            removeAdsProduct = products.first
        } catch {
            statusMessage = L10n.string("purchases.status.load_failed")
        }
    }

    func purchaseRemoveAds() async {
        if isPurchasing { return }
        isPurchasing = true
        defer { isPurchasing = false }

        if removeAdsProduct == nil {
            await loadProducts()
        }

        guard let product = removeAdsProduct else {
            statusMessage = L10n.string("purchases.status.unavailable")
            return
        }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try Self.checkVerified(verification)
                await transaction.finish()
                await refreshEntitlements()
                statusMessage = hasRemovedAds ? L10n.string("purchases.status.success") : L10n.string("purchases.status.completed")

            case .userCancelled:
                statusMessage = L10n.string("purchases.status.cancelled")

            case .pending:
                statusMessage = L10n.string("purchases.status.pending")

            @unknown default:
                statusMessage = L10n.string("purchases.status.unknown")
            }
        } catch {
            statusMessage = L10n.string("purchases.status.failed")
        }
    }

    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            statusMessage = hasRemovedAds ? L10n.string("purchases.status.restored") : L10n.string("purchases.status.none_to_restore")
        } catch {
            statusMessage = L10n.string("purchases.status.restore_failed")
        }
    }

    func refreshEntitlements() async {
        var entitled = false

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard transaction.productID == Self.removeAdsProductID else { continue }
            guard transaction.revocationDate == nil else { continue }
            entitled = true
        }

        hasRemovedAds = entitled
        UserDefaults.standard.set(entitled, forKey: OrbitMonetizationKeys.adsRemovedEntitlement)
        OrbitInterstitialAdManager.shared.setAdsRemoved(entitled)
        OrbitAppOpenAdManager.shared.setAdsRemoved(entitled)
    }

    private func observeTransactionUpdates() -> Task<Void, Never> {
        Task.detached { [weak self] in
            guard let self else { return }
            for await result in Transaction.updates {
                do {
                    let transaction = try Self.checkVerified(result)
                    await transaction.finish()
                    await self.refreshEntitlements()
                } catch {
                    await MainActor.run {
                        self.statusMessage = L10n.string("purchases.status.verify_failed")
                    }
                }
            }
        }
    }

    nonisolated private static func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let safe):
            return safe
        case .unverified:
            throw PurchaseError.failedVerification
        }
    }
}

private enum PurchaseError: Error {
    case failedVerification
}
