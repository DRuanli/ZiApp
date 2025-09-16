//
//  ZiApp.swift
//  ZiApp
//
//  Main app entry point and configuration
//

import SwiftUI
import SwiftData

@main
struct ZiApp: App {
    @StateObject private var dataContainer = SwiftDataContainer.shared
    @StateObject private var purchaseManager = PurchaseManager.shared
    @StateObject private var appState = AppState()
    
    @Environment(\.scenePhase) private var scenePhase
    
    init() {
        setupAppearance()
        Logger.shared.info("App launched - Version \(AppInfo.version)")
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .withDataContainer()
                .environmentObject(purchaseManager)
                .environmentObject(appState)
                .preferredColorScheme(appState.colorScheme)
                .onAppear {
                    handleFirstLaunch()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    handleScenePhaseChange(newPhase)
                }
        }
    }
    
    // MARK: - Setup Methods
    
    private func setupAppearance() {
        // Configure navigation bar appearance
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.titleTextAttributes = [
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold)
        ]
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        
        // Configure tab bar appearance
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
    }
    
    private func handleFirstLaunch() {
        Task { @MainActor in
            // Initialize StoreKit
            await purchaseManager.initialize()
            
            // Check if this is first launch
            if !appState.hasLaunchedBefore {
                appState.showOnboarding = true
                appState.hasLaunchedBefore = true
            }
            
            // Update user settings
            let settings = UserSettings.getOrCreate(in: dataContainer.mainContext)
            if settings.lastActivityDate.isToday {
                settings.updateStreak()
                dataContainer.save()
            }
        }
    }
    
    private func handleScenePhaseChange(_ phase: ScenePhase) {
        switch phase {
        case .active:
            Logger.shared.info("App became active")
            // Resume any paused operations
            
        case .inactive:
            Logger.shared.info("App became inactive")
            // Save any pending changes
            dataContainer.save()
            
        case .background:
            Logger.shared.info("App entered background")
            // Schedule notifications if needed
            scheduleReviewNotifications()
            
        @unknown default:
            break
        }
    }
    
    private func scheduleReviewNotifications() {
        let settings = UserSettings.getOrCreate(in: dataContainer.mainContext)
        
        guard settings.enabledNotifications,
              let notificationTime = settings.notificationTime else {
            return
        }
        
        // Schedule notification logic here
        NotificationManager.shared.scheduleDaily(at: notificationTime)
    }
}

// MARK: - App State

@MainActor
class AppState: ObservableObject {
    @AppStorage("hasLaunchedBefore") var hasLaunchedBefore = false
    @AppStorage("selectedTab") var selectedTab = 0
    @AppStorage("colorScheme") private var colorSchemeString = "system"
    
    @Published var showOnboarding = false
    @Published var showPremiumModal = false
    @Published var currentLearningSesion: LearningSession?
    
    var colorScheme: ColorScheme? {
        switch colorSchemeString {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }
    
    func setColorScheme(_ scheme: ColorScheme?) {
        switch scheme {
        case .light: colorSchemeString = "light"
        case .dark: colorSchemeString = "dark"
        case nil: colorSchemeString = "system"
        @unknown default: colorSchemeString = "system"
        }
    }
}

// MARK: - App Info

struct AppInfo {
    static let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    static let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    static let bundleId = Bundle.main.bundleIdentifier ?? "com.zi.app"
    static let appName = Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String ?? "Zi"
}

// MARK: - Content View

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var purchaseManager: PurchaseManager
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        if appState.showOnboarding {
            OnboardingView(isPresented: $appState.showOnboarding)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .leading)
                ))
        } else {
            MainTabView()
                .sheet(isPresented: $appState.showPremiumModal) {
                    PremiumUpgradeView()
                        .interactiveDismissDisabled()
                }
        }
    }
}

// MARK: - Main Tab View

struct MainTabView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var purchaseManager: PurchaseManager
    
    var body: some View {
        TabView(selection: $appState.selectedTab) {
            LearningView()
                .tabItem {
                    Label("Learn", systemImage: "book.fill")
                }
                .tag(0)
            
            if purchaseManager.isPremium {
                StatisticsView()
                    .tabItem {
                        Label("Stats", systemImage: "chart.bar.fill")
                    }
                    .tag(1)
            }
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(purchaseManager.isPremium ? 2 : 1)
        }
        .accentColor(.blue)
    }
}

// MARK: - Date Extensions

extension Date {
    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }
    
    var isYesterday: Bool {
        Calendar.current.isDateInYesterday(self)
    }
}
