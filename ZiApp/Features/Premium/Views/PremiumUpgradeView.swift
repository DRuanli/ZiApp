//
//  PremiumUpgradeView.swift
//  Zi
//
//  Premium upgrade modal with subscription options
//

import SwiftUI
import StoreKit

struct PremiumUpgradeView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var purchaseManager: PurchaseManager
    @State private var selectedProduct: Product?
    @State private var isProcessing = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccessAnimation = false
    
    private let features = [
        PremiumFeature(
            icon: "books.vertical.fill",
            title: "All HSK Levels",
            description: "Access all 6 HSK levels with 5000+ words"
        ),
        PremiumFeature(
            icon: "brain.head.profile",
            title: "Smart SRS Algorithm",
            description: "Scientifically proven spaced repetition"
        ),
        PremiumFeature(
            icon: "speaker.wave.3.fill",
            title: "Audio Pronunciation",
            description: "Native speaker audio for every word"
        ),
        PremiumFeature(
            icon: "quote.bubble.fill",
            title: "Example Sentences",
            description: "Learn words in context with real examples"
        ),
        PremiumFeature(
            icon: "chart.line.uptrend.xyaxis",
            title: "Detailed Statistics",
            description: "Track your progress with advanced analytics"
        ),
        PremiumFeature(
            icon: "infinity",
            title: "Unlimited Learning",
            description: "No daily limits - learn at your own pace"
        )
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [
                        Color.blue.opacity(0.1),
                        Color.purple.opacity(0.1)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 30) {
                        // Header
                        headerSection
                        
                        // Features
                        featuresSection
                        
                        // Pricing Options
                        pricingSection
                        
                        // CTA Button
                        subscribeButton
                        
                        // Terms and Restore
                        footerSection
                    }
                    .padding()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .overlay(
                Group {
                    if showSuccessAnimation {
                        SuccessAnimationView()
                            .transition(.scale.combined(with: .opacity))
                    }
                }
            )
        }
    }
    
    // MARK: - Sections
    
    private var headerSection: some View {
        VStack(spacing: 20) {
            // Crown icon with animation
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.yellow, .orange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                    .shadow(color: .orange.opacity(0.3), radius: 20, y: 10)
                
                Image(systemName: "crown.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.white)
            }
            .scaleEffect(showSuccessAnimation ? 1.2 : 1.0)
            .animation(.spring(response: 0.5, dampingFraction: 0.6), value: showSuccessAnimation)
            
            VStack(spacing: 10) {
                Text("Unlock Premium")
                    .font(.largeTitle)
                    .bold()
                
                Text("Master Chinese with unlimited access")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, 20)
    }
    
    private var featuresSection: some View {
        VStack(spacing: 16) {
            ForEach(features, id: \.title) { feature in
                FeatureRow(feature: feature)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(UIColor.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
        )
    }
    
    private var pricingSection: some View {
        VStack(spacing: 12) {
            Text("Choose Your Plan")
                .font(.headline)
            
            if purchaseManager.products.isEmpty {
                ProgressView()
                    .padding()
            } else {
                VStack(spacing: 12) {
                    // Monthly
                    if let monthly = purchaseManager.monthlyProduct {
                        PricingCard(
                            product: monthly,
                            isSelected: selectedProduct?.id == monthly.id,
                            badge: nil,
                            description: "Billed monthly",
                            onTap: { selectedProduct = monthly }
                        )
                    }
                    
                    // Yearly with badge
                    if let yearly = purchaseManager.yearlyProduct {
                        PricingCard(
                            product: yearly,
                            isSelected: selectedProduct?.id == yearly.id,
                            badge: purchaseManager.yearlySavings() ?? "BEST VALUE",
                            description: "Billed annually",
                            onTap: { selectedProduct = yearly }
                        )
                    }
                    
                    // Lifetime
                    if let lifetime = purchaseManager.lifetimeProduct {
                        PricingCard(
                            product: lifetime,
                            isSelected: selectedProduct?.id == lifetime.id,
                            badge: "ONE TIME",
                            description: "Pay once, own forever",
                            onTap: { selectedProduct = lifetime }
                        )
                    }
                }
            }
        }
    }
    
    private var subscribeButton: some View {
        Button(action: subscribe) {
            HStack {
                if isProcessing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Text(subscribeButtonText)
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                LinearGradient(
                    colors: selectedProduct != nil ? [.blue, .purple] : [.gray],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundColor(.white)
            .cornerRadius(16)
            .disabled(selectedProduct == nil || isProcessing)
            .shadow(color: .blue.opacity(0.3), radius: 10, y: 5)
        }
    }
    
    private var subscribeButtonText: String {
        guard let product = selectedProduct else {
            return "Select a Plan"
        }
        
        if purchaseManager.hasTrial(for: product) {
            if let trial = purchaseManager.trialPeriod(for: product) {
                return "Start \(trial) Trial"
            }
        }
        
        return "Subscribe for \(product.displayPrice)"
    }
    
    private var footerSection: some View {
        VStack(spacing: 20) {
            // Restore button
            Button(action: restore) {
                Text("Restore Purchases")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .underline()
            }
            
            // Terms
            VStack(spacing: 8) {
                Text("By subscribing, you agree to our")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 16) {
                    Link("Terms of Service", destination: URL(string: Constants.App.termsOfServiceURL)!)
                        .font(.caption)
                        .underline()
                    
                    Link("Privacy Policy", destination: URL(string: Constants.App.privacyPolicyURL)!)
                        .font(.caption)
                        .underline()
                }
            }
            
            // Subscription details
            if let product = selectedProduct,
               let period = product.subscription?.subscriptionPeriod {
                SubscriptionDetailsText(product: product, period: period)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Actions
    
    private func subscribe() {
        guard let product = selectedProduct else { return }
        
        isProcessing = true
        
        Task {
            do {
                if let transaction = try await purchaseManager.purchase(product) {
                    // Success
                    await MainActor.run {
                        showSuccessAnimation = true
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            dismiss()
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
            
            await MainActor.run {
                isProcessing = false
            }
        }
    }
    
    private func restore() {
        Task {
            await purchaseManager.restore()
            
            if purchaseManager.isPremium {
                await MainActor.run {
                    showSuccessAnimation = true
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct PremiumFeature: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let description: String
}

struct FeatureRow: View {
    let feature: PremiumFeature
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: feature.icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(feature.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(feature.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

struct PricingCard: View {
    let product: Product
    let isSelected: Bool
    let badge: String?
    let description: String
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .topTrailing) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(purchaseManager.subscriptionPeriod(for: product))
                            .font(.headline)
                        
                        Text(product.displayPrice)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundColor(isSelected ? .blue : .secondary)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isSelected ? Color.blue.opacity(0.1) : Color(UIColor.secondarySystemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
                        )
                )
                
                // Badge
                if let badge = badge {
                    Text(badge)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(badge.contains("SAVE") || badge.contains("VALUE") ? Color.green : Color.orange)
                        )
                        .offset(x: -10, y: -10)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct SubscriptionDetailsText: View {
    let product: Product
    let period: Product.SubscriptionPeriod
    
    var body: some View {
        Group {
            if product.id.contains("monthly") {
                Text("Subscription automatically renews monthly unless cancelled at least 24 hours before the end of the current period. Payment will be charged to your Apple ID account.")
            } else if product.id.contains("yearly") {
                Text("Subscription automatically renews yearly unless cancelled at least 24 hours before the end of the current period. Payment will be charged to your Apple ID account.")
            } else {
                Text("One-time purchase. No subscription required.")
            }
        }
    }
}

struct SuccessAnimationView: View {
    @State private var scale = 0.5
    @State private var opacity = 0.0
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)
            
            Text("Welcome to Premium!")
                .font(.title)
                .bold()
        }
        .padding(40)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(UIColor.systemBackground))
                .shadow(radius: 20)
        )
        .scaleEffect(scale)
        .opacity(opacity)
        .onAppear {
            withAnimation(.spring()) {
                scale = 1.0
                opacity = 1.0
            }
        }
    }
}
