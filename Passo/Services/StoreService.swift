import StoreKit
import SwiftUI

// MARK: - Store Service

/// Handles StoreKit 2 product loading, purchases, and entitlement verification.
@MainActor
final class StoreService: ObservableObject {

    static let shared = StoreService()

    @Published var products: [Product] = []
    @Published var purchasedIDs: Set<String> = []
    @Published var isLoading = false
    @Published var purchaseError: String?

    var isPro: Bool { !purchasedIDs.isEmpty }

    static let productIDs = [
        "com.passo.pro.monthly",
        "com.passo.pro.yearly"
    ]

    private nonisolated(unsafe) var transactionListener: Task<Void, Never>?

    init() {
        transactionListener = listenForTransactions()
    }

    deinit { transactionListener?.cancel() }

    // MARK: - Load

    func load() async {
        isLoading = true
        defer { isLoading = false }
        products = (try? await Product.products(for: Self.productIDs))?.sorted {
            $0.id.contains("monthly") && !$1.id.contains("monthly")
        } ?? []
        await refreshEntitlements()
    }

    // MARK: - Purchase

    func purchase(_ product: Product) async {
        purchaseError = nil
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try verification.payloadValue
                purchasedIDs.insert(transaction.productID)
                await transaction.finish()
                syncProStatus()
            case .userCancelled:
                break
            case .pending:
                purchaseError = "购买待确认，请稍后检查"
            @unknown default:
                break
            }
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    // MARK: - Restore

    func restore() async {
        isLoading = true
        defer { isLoading = false }
        try? await AppStore.sync()
        await refreshEntitlements()
    }

    // MARK: - Entitlements

    func refreshEntitlements() async {
        var ids: Set<String> = []
        for await result in Transaction.currentEntitlements {
            guard case .verified(let tx) = result else { continue }
            if !tx.isUpgraded { ids.insert(tx.productID) }
        }
        purchasedIDs = ids
        syncProStatus()
    }

    // MARK: - Private

    private func syncProStatus() {
        UserDefaults.standard.set(isPro, forKey: "isPro")
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task { @MainActor [weak self] in
            for await result in Transaction.updates {
                guard case .verified(let tx) = result else { continue }
                self?.purchasedIDs.insert(tx.productID)
                self?.syncProStatus()
                await tx.finish()
            }
        }
    }
}
