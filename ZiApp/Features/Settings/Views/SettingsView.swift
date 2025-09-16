//
//  SettingsView.swift
//  Zi
//
//  Settings interface for user preferences and app configuration
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var purchaseManager: PurchaseManager
    @EnvironmentObject var appState: AppState
    
    @State private var settings: UserSettings?
    @State private var showingResetAlert = false
    @State private var showingPurchaseView = false
    @State private var showingAboutView = false
    @State private var selectedHSKLevels: Set<Int> = []
    @State private var dailyGoal: Int = 20
    @State private var notificationsEnabled: Bool = false
    @State private var notificationTime = Date()
    @State private var fontSize: FontSize = .medium
    @State private var showPinyin: Bool = true
    @State private var autoPlayAudio: Bool = false
    @State private var hapticEnabled: Bool = true
    @State private var soundEnabled: Bool = true
    @State private var wordCounts: [Int: Int] = [:]
    
    var body: some View {
        NavigationView {
            List {
                // Account Section
                accountSection
                
                // Learning Preferences
                learningSection
                
                // Display Settings
                displaySection
                
                // Notifications
                if purchaseManager.isPremium {
                    notificationSection
                }
                
                // Data Management
                dataSection
                
                // About
                aboutSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        saveSettings()
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadSettings()
                loadWordCounts()
            }
            .alert("Reset Progress", isPresented: $showingResetAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    resetAllProgress()
                }
            } message: {
                Text("Are you sure you want to reset all your learning progress? This action cannot be undone.")
            }
            .sheet(isPresented: $showingPurchaseView) {
                PremiumUpgradeView()
            }
            .sheet(isPresented: $showingAboutView) {
                AboutView()
            }
        }
    }
    
    // MARK: - Sections
    
    private var accountSection: some View {
        Section {
            // Subscription Status
            HStack {
                Image(systemName: purchaseManager.isPremium ? "crown.fill" : "person.circle")
                    .foregroundColor(purchaseManager.isPremium ? .yellow : .gray)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(purchaseManager.isPremium ? "Premium Member" : "Free Account")
                        .font(.headline)
                    
                    if purchaseManager.userStatus == .pro {
                        if let expiryDate = purchaseManager.subscriptionExpiryDate {
                            Text("Expires: \(expiryDate.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else if purchaseManager.userStatus == .proLifetime {
                        Text("Lifetime Access")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Limited to HSK 1-2 • 20 words/day")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if !purchaseManager.isPremium {
                    Button("Upgrade") {
                        showingPurchaseView = true
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.vertical, 4)
            
            // Restore Purchases
            if !purchaseManager.isPremium {
                Button(action: {
                    Task {
                        await purchaseManager.restore()
                    }
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Restore Purchases")
                    }
                }
            }
            
            // Statistics Summary
            if let settings = settings {
                VStack(alignment: .leading, spacing: 8) {
                    StatisticRow(
                        icon: "book.fill",
                        label: "Words Learned",
                        value: "\(settings.totalWordsLearned)"
                    )
                    
                    StatisticRow(
                        icon: "flame.fill",
                        label: "Current Streak",
                        value: "\(settings.currentStreak) days",
                        color: settings.currentStreak > 0 ? .orange : .secondary
                    )
                    
                    StatisticRow(
                        icon: "trophy.fill",
                        label: "Longest Streak",
                        value: "\(settings.longestStreak) days",
                        color: .yellow
                    )
                }
                .padding(.vertical, 4)
            }
        } header: {
            Text("Account")
        }
    }
    
    private var learningSection: some View {
        Section {
            // HSK Level Selection
            VStack(alignment: .leading, spacing: 12) {
                Text("HSK Levels")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HSKLevelGrid(
                    selectedLevels: $selectedHSKLevels,
                    availableLevels: purchaseManager.isPremium ? Array(1...6) : [1, 2],
                    wordCounts: wordCounts,
                    isPremium: purchaseManager.isPremium
                )
            }
            .padding(.vertical, 4)
            
            // Daily Goal
            HStack {
                Label("Daily Goal", systemImage: "target")
                
                Spacer()
                
                Picker("Daily Goal", selection: $dailyGoal) {
                    ForEach([10, 20, 30, 50], id: \.self) { count in
                        Text("\(count) words").tag(count)
                    }
                }
                .pickerStyle(.menu)
            }
            
            // Session Length
            if purchaseManager.isPremium {
                HStack {
                    Label("Session Length", systemImage: "timer")
                    
                    Spacer()
                    
                    Text("\(settings?.sessionLength ?? 20) words")
                        .foregroundColor(.secondary)
                }
            }
        } header: {
            Text("Learning Preferences")
        } footer: {
            if !selectedHSKLevels.isEmpty {
                let totalWords = selectedHSKLevels.reduce(0) { sum, level in
                    sum + (wordCounts[level] ?? 0)
                }
                Text("Total words available: \(totalWords)")
            }
        }
    }
    
    private var displaySection: some View {
        Section {
            // Font Size
            HStack {
                Label("Font Size", systemImage: "textformat.size")
                
                Spacer()
                
                Picker("Font Size", selection: $fontSize) {
                    Text("Small").tag(FontSize.small)
                    Text("Medium").tag(FontSize.medium)
                    Text("Large").tag(FontSize.large)
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }
            
            // Show Pinyin
            Toggle(isOn: $showPinyin) {
                Label("Show Pinyin", systemImage: "character.book.closed")
            }
            
            // Auto-play Audio (Premium)
            if purchaseManager.isPremium {
                Toggle(isOn: $autoPlayAudio) {
                    Label("Auto-play Audio", systemImage: "speaker.wave.2")
                }
            }
            
            // Haptic Feedback
            Toggle(isOn: $hapticEnabled) {
                Label("Haptic Feedback", systemImage: "hand.tap")
            }
            
            // Sound Effects
            Toggle(isOn: $soundEnabled) {
                Label("Sound Effects", systemImage: "speaker.wave.3")
            }
            
            // Theme
            HStack {
                Label("Appearance", systemImage: "circle.lefthalf.filled")
                
                Spacer()
                
                Picker("Appearance", selection: $appState.selectedTab) {
                    Text("System").tag(0)
                    Text("Light").tag(1)
                    Text("Dark").tag(2)
                }
                .pickerStyle(.menu)
            }
        } header: {
            Text("Display & Sound")
        }
    }
    
    private var notificationSection: some View {
        Section {
            Toggle(isOn: $notificationsEnabled) {
                Label("Daily Reminders", systemImage: "bell")
            }
            
            if notificationsEnabled {
                DatePicker(
                    "Reminder Time",
                    selection: $notificationTime,
                    displayedComponents: .hourAndMinute
                )
            }
        } header: {
            Text("Notifications")
        } footer: {
            Text("Get daily reminders to maintain your streak")
        }
    }
    
    private var dataSection: some View {
        Section {
            // Reset Progress
            Button(action: {
                showingResetAlert = true
            }) {
                HStack {
                    Label("Reset All Progress", systemImage: "arrow.counterclockwise")
                        .foregroundColor(.red)
                    Spacer()
                }
            }
            
            // Export Data (Premium)
            if purchaseManager.isPremium {
                Button(action: exportData) {
                    HStack {
                        Label("Export Learning Data", systemImage: "square.and.arrow.up")
                        Spacer()
                    }
                }
            }
            
            // Cache Size
            HStack {
                Label("Cache Size", systemImage: "internaldrive")
                Spacer()
                Text("12.3 MB")
                    .foregroundColor(.secondary)
            }
            
            // Clear Cache
            Button(action: clearCache) {
                HStack {
                    Label("Clear Cache", systemImage: "trash")
                    Spacer()
                }
            }
        } header: {
            Text("Data Management")
        }
    }
    
    private var aboutSection: some View {
        Section {
            // Version
            HStack {
                Label("Version", systemImage: "info.circle")
                Spacer()
                Text("\(AppInfo.version) (\(AppInfo.build))")
                    .foregroundColor(.secondary)
            }
            
            // About
            Button(action: { showingAboutView = true }) {
                HStack {
                    Label("About Zi", systemImage: "questionmark.circle")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Rate App
            Button(action: rateApp) {
                HStack {
                    Label("Rate Zi", systemImage: "star")
                    Spacer()
                }
            }
            
            // Share App
            Button(action: shareApp) {
                HStack {
                    Label("Share Zi", systemImage: "square.and.arrow.up")
                    Spacer()
                }
            }
            
            // Support
            Link(destination: URL(string: Constants.App.supportEmail)!) {
                HStack {
                    Label("Contact Support", systemImage: "envelope")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Privacy Policy
            Link(destination: URL(string: Constants.App.privacyPolicyURL)!) {
                HStack {
                    Label("Privacy Policy", systemImage: "hand.raised")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Terms of Service
            Link(destination: URL(string: Constants.App.termsOfServiceURL)!) {
                HStack {
                    Label("Terms of Service", systemImage: "doc.text")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        } header: {
            Text("About")
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadSettings() {
        settings = UserSettings.getOrCreate(in: modelContext)
        
        guard let settings = settings else { return }
        
        selectedHSKLevels = Set(settings.selectedHSKLevels)
        dailyGoal = settings.dailyGoal
        notificationsEnabled = settings.enabledNotifications
        notificationTime = settings.notificationTime ?? Date()
        fontSize = settings.fontSize
        showPinyin = settings.showPinyin
        autoPlayAudio = settings.autoPlayAudio
        hapticEnabled = settings.hapticFeedback
        soundEnabled = true // From UserDefaults
    }
    
    private func saveSettings() {
        guard let settings = settings else { return }
        
        settings.selectedHSKLevels = Array(selectedHSKLevels).sorted()
        settings.dailyGoal = dailyGoal
        settings.enabledNotifications = notificationsEnabled
        settings.notificationTime = notificationTime
        settings.fontSize = fontSize
        settings.showPinyin = showPinyin
        settings.autoPlayAudio = autoPlayAudio
        settings.hapticFeedback = hapticEnabled
        
        SwiftDataContainer.shared.save()
        
        Logger.shared.info("Settings saved")
    }
    
    private func loadWordCounts() {
        Task {
            do {
                wordCounts = try await DataService.shared.getWordCountByLevel()
            } catch {
                Logger.shared.error("Failed to load word counts: \(error)")
            }
        }
    }
    
    private func resetAllProgress() {
        Task {
            do {
                try await DataService.shared.resetAllProgress()
                Logger.shared.info("All progress reset")
            } catch {
                Logger.shared.error("Failed to reset progress: \(error)")
            }
        }
    }
    
    private func exportData() {
        // TODO: Implement data export
        Logger.shared.info("Export data requested")
    }
    
    private func clearCache() {
        // TODO: Implement cache clearing
        Logger.shared.info("Clear cache requested")
    }
    
    private func rateApp() {
        if let url = URL(string: Constants.App.appStoreReviewURL) {
            UIApplication.shared.open(url)
        }
    }
    
    private func shareApp() {
        // TODO: Implement share sheet
        Logger.shared.info("Share app requested")
    }
}

// MARK: - Supporting Views

struct HSKLevelGrid: View {
    @Binding var selectedLevels: Set<Int>
    let availableLevels: [Int]
    let wordCounts: [Int: Int]
    let isPremium: Bool
    
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(1...6, id: \.self) { level in
                HSKLevelCard(
                    level: level,
                    isSelected: selectedLevels.contains(level),
                    isAvailable: availableLevels.contains(level),
                    wordCount: wordCounts[level] ?? 0,
                    action: {
                        if availableLevels.contains(level) {
                            if selectedLevels.contains(level) {
                                selectedLevels.remove(level)
                            } else {
                                selectedLevels.insert(level)
                            }
                        }
                    }
                )
            }
        }
    }
}

struct HSKLevelCard: View {
    let level: Int
    let isSelected: Bool
    let isAvailable: Bool
    let wordCount: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text("HSK \(level)")
                    .font(.headline)
                    .foregroundColor(isSelected ? .white : (isAvailable ? .primary : .secondary))
                
                Text("\(wordCount)")
                    .font(.caption)
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.blue : (isAvailable ? Color(UIColor.secondarySystemBackground) : Color(UIColor.tertiarySystemBackground)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
            .overlay(
                Group {
                    if !isAvailable {
                        Image(systemName: "lock.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .position(x: 10, y: 10)
                    }
                }
            )
        }
        .disabled(!isAvailable)
    }
}

struct StatisticRow: View {
    let icon: String
    let label: String
    let value: String
    var color: Color = .primary
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 20)
            
            Text(label)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .foregroundColor(color)
                .fontWeight(.medium)
        }
        .font(.subheadline)
    }
}

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 30) {
                    // App Icon and Name
                    VStack(spacing: 12) {
                        Image(systemName: "character.book.closed.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.blue)
                        
                        Text("Zì")
                            .font(.largeTitle)
                            .bold()
                        
                        Text("Learn Chinese Characters")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 40)
                    
                    // Description
                    Text("Zì is a minimalist Chinese learning app focused on helping you master HSK vocabulary through scientifically proven spaced repetition techniques.")
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    // Features
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Features")
                            .font(.headline)
                        
                        FeatureRow(icon: "brain", text: "Smart SRS algorithm")
                        FeatureRow(icon: "speaker.wave.2", text: "Native pronunciation")
                        FeatureRow(icon: "chart.line.uptrend.xyaxis", text: "Progress tracking")
                        FeatureRow(icon: "books.vertical", text: "Complete HSK coverage")
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    // Credits
                    VStack(spacing: 8) {
                        Text("Made with ❤️ in Vietnam")
                            .font(.footnote)
                        
                        Text("© 2025 Your Company")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    struct FeatureRow: View {
        let icon: String
        let text: String
        
        var body: some View {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                    .frame(width: 24)
                
                Text(text)
                    .font(.subheadline)
                
                Spacer()
            }
        }
    }
}
