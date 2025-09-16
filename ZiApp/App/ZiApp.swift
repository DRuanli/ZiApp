//
//  ZiApp.swift
//  ZiApp
//
//  Main app entry point
//

import SwiftUI
import SwiftData

@main
struct ZiApp: App {
    @StateObject private var purchaseManager = PurchaseManager.shared
    @StateObject private var audioService = AudioService.shared
    
    init() {
        // Setup app appearance
        setupAppearance()
        
        // Initialize SwiftData container
        _ = SwiftDataContainer.shared
        
        // Perform any necessary migrations
        SwiftDataContainer.shared.performMigrationIfNeeded()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(purchaseManager)
                .environmentObject(audioService)
                .modelContainer(SwiftDataContainer.shared.container)
                .onAppear {
                    Task {
                        // Load products on app launch
                        await purchaseManager.loadProducts()
                        
                        // Update purchase status
                        await purchaseManager.updateCustomerProductStatus()
                    }
                }
        }
    }
    
    private func setupAppearance() {
        // Configure navigation bar appearance
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.systemBackground
        appearance.titleTextAttributes = [
            .foregroundColor: UIColor.label,
            .font: UIFont.systemFont(ofSize: 18, weight: .semibold)
        ]
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        
        // Configure tab bar appearance
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = UIColor.systemBackground
        
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
    }
}
