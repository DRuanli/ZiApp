//
//  PurchaseManager.swift
//  Zi
//
//  StoreKit 2 integration for managing in-app purchases
//

import Foundation
import StoreKit
import SwiftUI

@MainActor
class PurchaseManager: ObservableObject {
    static let shared = PurchaseManager()
    
    // MARK: - Published Properties
    @Published var products: [Product] = []
    @Published var purchasedProductIDs: Set<String> = []
    @Published var userStatus: SubscriptionStatus = .free
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showSuccessAlert: Bool = false
    
    // MARK: - Private Properties
    private var updateListenerTask: Task<Void, Error>?
    private let productIds = Constants.IAP.productIds
    private var transactionListener: Task<Void, Never>?
    
    // MARK: - Computed Properties
    
    var isPremium: Bool {
        userStatus != .free
    }
    
    var hasLifetime: Bool {
        userStatus == .proLifetime
    }
    
    var subscriptionExpiryDate: Date? {
        // Get from transaction
        return nil // Will be implemented with actual transaction check
    }
    
    var monthlyProduct: Product? {
        products.first { $0.id == Constants.IAP.proMonthlyId }
    }
    
    var yearlyProduct: Product? {
        products.first { $0.id == Constants.IAP.proYearlyId }
    }
    
    var lifetimeProduct: Product? {
        products.first { $0.id == Constants.IAP.proLifetimeId }
    }
    
    // MARK: - Initialization
    
    private init() {
        // Start transaction listener
        transactionListener = listenForTransactions()
        
        Task {
            await initialize()
        }
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    // MARK: - Public Methods
    
    /// Initialize the purchase manager
    func initialize() async {
        Logger.shared.info("Initializing PurchaseManager")
        
        // Load products
        await loadProducts()
        
        // Check current entitlements
        await updateCustomerProductStatus()
        
        // Update user settings
        updateUserSettings()
    }
    
    /// Load products from App Store
    func loadProducts() async {
        isLoading = true
        errorMessage = nil
        
        do {
            Logger.shared.info("Loading products: \(productIds)")
            products = try await Product.products(for: productIds)
            
            Logger.shared.info("Loaded \(products.count) products")
            
            // Sort products by price
            products.sort { $0.price < $1.price }
            
        } catch {
            Logger.shared.error("Failed to load products: \(error)")
            errorMessage = "Failed to load products. Please try again."
        }
        
        isLoading = false
    }
    
    /// Purchase a product
    func purchase(_ product: Product) async throws -> Transaction? {
        Logger.shared.info("Attempting to purchase: \(product.id)")
        
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        // Attempt the purchase
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            // Check verification
            let transaction = try checkVerified(verification)
            
            // Update purchase status
            await updateCustomerProductStatus()
            
            // Finish the transaction
            await transaction.finish()
            
            // Show success
            showSuccessAlert = true
            
            // Log analytics
            logPurchaseEvent(product: product, success: true)
            
            Logger.shared.info("Purchase successful: \(product.id)")
            return transaction
            
        case .userCancelled:
            Logger.shared.info("User cancelled purchase")
            return nil
            
        case .pending:
            Logger.shared.info("Purchase pending")
            errorMessage = "Purchase is pending approval"
            return nil
            
        @unknown default:
            Logger.shared.error("Unknown purchase result")
            return nil
        }
    }
    
    /// Restore purchases
    func restore() async {
        Logger.shared.info("Restoring purchases")
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Sync with App Store
            try await AppStore.sync()
            
            // Update status
            await updateCustomerProductStatus()
            
            if isPremium {
                showSuccessAlert = true
                Logger.shared.info("Purchases restored successfully")
            } else {
                errorMessage = "No purchases to restore"
                Logger.shared.info("No purchases found to restore")
            }
        } catch {
            Logger.shared.error("Restore failed: \(error)")
            errorMessage = "Failed to restore purchases. Please try again."
        }
        
        isLoading = false
    }
    
    // MARK: - Private Methods
    
    /// Listen for transaction updates
    private func listenForTransactions() -> Task<Void, Never> {
        return Task.detached {
            // Listen for transactions
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)
                    
                    // Update customer status
                    await self.updateCustomerProductStatus()
                    
                    // Always finish transactions
                    await transaction.finish()
                    
                } catch {
                    Logger.shared.error("Transaction verification failed: \(error)")
                }
            }
        }
    }
    
    /// Update customer product status
    @MainActor
    private func updateCustomerProductStatus() async {
        var newStatus = SubscriptionStatus.free
        var purchasedProducts: Set<String> = []
        
        // Check all current entitlements
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                
                // Add to purchased products
                purchasedProducts.insert(transaction.productID)
                
                // Check product type
                if transaction.productID == Constants.IAP.proLifetimeId {
                    newStatus = .proLifetime
                } else if transaction.productID == Constants.IAP.proMonthlyId ||
                          transaction.productID == Constants.IAP.proYearlyId {
                    
                    // Check if subscription is still valid
                    if let expirationDate = transaction.expirationDate,
                       expirationDate > Date() {
                        newStatus = .pro
                    }
                }
                
            } catch {
                Logger.shared.error("Failed to verify transaction: \(error)")
            }
        }
        
        // Update published properties
        self.userStatus = newStatus
        self.purchasedProductIDs = purchasedProducts
        
        // Update user settings
        updateUserSettings()
        
        Logger.shared.info("Updated user status: \(newStatus)")
    }
    
    /// Verify transaction
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
    
    /// Update user settings with purchase status
    private func updateUserSettings() {
        let context = SwiftDataContainer.shared.mainContext
        let settings = UserSettings.getOrCreate(in: context)
        
        settings.subscriptionStatus = userStatus
        settings.purchaseDate = isPremium ? Date() : nil
        
        // Save to database
        SwiftDataContainer.shared.save()
    }
    
    /// Log purchase event for analytics
    private func logPurchaseEvent(product: Product, success: Bool) {
        // Log to analytics service
        let eventName = success ? Constants.Analytics.purchaseCompleted : Constants.Analytics.purchaseFailed
        
        Logger.shared.info("\(eventName): \(product.id) - Price: \(product.displayPrice)")
        
        // Here you would send to your analytics service
        // AnalyticsService.shared.logEvent(eventName, parameters: [...])
    }
    
    // MARK: - Price Formatting
    
    /// Get formatted price for a product
    func formattedPrice(for product: Product) -> String {
        product.displayPrice
    }
    
    /// Calculate savings for yearly subscription
    func yearlySavings() -> String? {
        guard let monthly = monthlyProduct,
              let yearly = yearlyProduct else {
            return nil
        }
        
        let monthlyYearCost = monthly.price * 12
        let yearlyCost = yearly.price
        let savings = monthlyYearCost - yearlyCost
        
        if savings > 0 {
            let percentage = (savings / monthlyYearCost) * 100
            return String(format: "Save %.0f%%", percentage)
        }
        
        return nil
    }
    
    // MARK: - Product Information
    
    /// Get subscription period for a product
    func subscriptionPeriod(for product: Product) -> String {
        guard let subscription = product.subscription else {
            return "Lifetime"
        }
        
        let unit = subscription.subscriptionPeriod.unit
        let value = subscription.subscriptionPeriod.value
        
        switch unit {
        case .day:
            return value == 1 ? "Daily" : "\(value) Days"
        case .week:
            return value == 1 ? "Weekly" : "\(value) Weeks"
        case .month:
            return value == 1 ? "Monthly" : "\(value) Months"
        case .year:
            return value == 1 ? "Yearly" : "\(value) Years"
        @unknown default:
            return "Unknown"
        }
    }
    
    /// Check if product has free trial
    func hasTrial(for product: Product) -> Bool {
        product.subscription?.introductoryOffer?.type == .introductory
    }
    
    /// Get trial period for a product
    func trialPeriod(for product: Product) -> String? {
        guard let offer = product.subscription?.introductoryOffer,
              offer.type == .introductory else {
            return nil
        }
        
        let period = offer.period
        let unit = period.unit
        let value = period.value
        
        switch unit {
        case .day:
            return "\(value) day\(value > 1 ? "s" : "") free"
        case .week:
            return "\(value) week\(value > 1 ? "s" : "") free"
        case .month:
            return "\(value) month\(value > 1 ? "s" : "") free"
        case .year:
            return "\(value) year\(value > 1 ? "s" : "") free"
        @unknown default:
            return nil
        }
    }
}

// MARK: - Store Errors

enum StoreError: LocalizedError {
    case failedVerification
    case productNotFound
    case purchaseFailed
    case restoreFailed
    
    var errorDescription: String? {
        switch self {
        case .failedVerification:
            return "Transaction verification failed"
        case .productNotFound:
            return "Product not found"
        case .purchaseFailed:
            return "Purchase failed"
        case .restoreFailed:
            return "Restore failed"
        }
    }
}

// MARK: - Store Configuration (for testing)

#if DEBUG
extension PurchaseManager {
    /// Load test products for previews
    func loadTestProducts() {
        // Create mock products for testing
        // This would be used in SwiftUI previews
    }
}
#endif
