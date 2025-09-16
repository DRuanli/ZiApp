//
//  ContentView.swift
//  ZiApp
//
//  Main content view with tab navigation
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var purchaseManager = PurchaseManager.shared
    @StateObject private var audioService = AudioService.shared
    @State private var selectedTab = 0
    @State private var showingPremiumUpgrade = false
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Learning Tab
            NavigationStack {
                LearningView()
                    .environmentObject(purchaseManager)
                    .environmentObject(audioService)
            }
            .tabItem {
                Label("Học", systemImage: "book.fill")
            }
            .tag(0)
            
            // Statistics Tab
            NavigationStack {
                StatisticsView()
                    .environmentObject(purchaseManager)
            }
            .tabItem {
                Label("Thống kê", systemImage: "chart.bar.fill")
            }
            .tag(1)
            
            // Settings Tab
            NavigationStack {
                SettingsView()
                    .environmentObject(purchaseManager)
            }
            .tabItem {
                Label("Cài đặt", systemImage: "gear")
            }
            .tag(2)
        }
        .accentColor(.blue)
        .sheet(isPresented: $showingPremiumUpgrade) {
            PremiumUpgradeView()
                .environmentObject(purchaseManager)
        }
        .onAppear {
            setupInitialData()
        }
    }
    
    private func setupInitialData() {
        // Check if initial data needs to be loaded
        let hasLoadedData = UserDefaults.standard.bool(forKey: "hasLoadedInitialData")
        
        if !hasLoadedData {
            Task {
                await loadInitialVocabulary()
            }
        }
    }
    
    @MainActor
    private func loadInitialVocabulary() async {
        do {
            // Use DataService to bootstrap initial data
            let dataService = DataService.shared
            await dataService.bootstrapInitialData(from: "vocabulary_v1.2.json", version: "1.2")
            
            UserDefaults.standard.set(true, forKey: "hasLoadedInitialData")
            Logger.shared.log("Initial vocabulary loaded successfully", level: .info)
        } catch {
            Logger.shared.log("Failed to load initial vocabulary: \(error)", level: .error)
        }
    }
}
