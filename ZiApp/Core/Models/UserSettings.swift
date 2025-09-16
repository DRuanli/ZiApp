//
//  UserSettings.swift
//  ZiApp
//
//  User preferences and settings model
//

import Foundation
import SwiftData

@Model
final class UserSettings {
    @Attribute(.unique) var id: UUID
    
    // Learning preferences
    var selectedHSKLevels: [Int]
    var dailyGoal: Int
    var sessionLength: Int
    var showPinyin: Bool
    var showExampleSentences: Bool
    var autoPlayAudio: Bool
    
    // Display preferences
    var fontSize: FontSize
    var colorTheme: ColorTheme
    var useSimplifiedCharacters: Bool
    
    // Notification settings
    var enableNotifications: Bool
    var notificationTime: Date
    var notificationFrequency: NotificationFrequency
    
    // Audio settings
    var audioVolume: Float
    var playbackSpeed: Float
    var enableHapticFeedback: Bool
    
    // Statistics preferences
    var showStreak: Bool
    var showAccuracy: Bool
    var showTimeSpent: Bool
    
    // App metadata
    var firstLaunchDate: Date
    var lastActiveDate: Date
    var appVersion: String
    var dataVersion: String?
    
    init() {
        self.id = UUID()
        
        // Default learning preferences
        self.selectedHSKLevels = [1, 2]
        self.dailyGoal = 30
        self.sessionLength = 10
        self.showPinyin = true
        self.showExampleSentences = true
        self.autoPlayAudio = false
        
        // Default display preferences
        self.fontSize = .medium
        self.colorTheme = .system
        self.useSimplifiedCharacters = true
        
        // Default notification settings
        self.enableNotifications = false
        self.notificationTime = Calendar.current.date(from: DateComponents(hour: 20, minute: 0)) ?? Date()
        self.notificationFrequency = .daily
        
        // Default audio settings
        self.audioVolume = 1.0
        self.playbackSpeed = 1.0
        self.enableHapticFeedback = true
        
        // Default statistics preferences
        self.showStreak = true
        self.showAccuracy = true
        self.showTimeSpent = true
        
        // App metadata
        self.firstLaunchDate = Date()
        self.lastActiveDate = Date()
        self.appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    
    // MARK: - Computed Properties
    var isNewUser: Bool {
        let daysSinceFirstLaunch = Calendar.current.dateComponents([.day],
                                                                   from: firstLaunchDate,
                                                                   to: Date()).day ?? 0
        return daysSinceFirstLaunch < 7
    }
    
    var hasCompletedOnboarding: Bool {
        return UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    }
    
    // MARK: - Methods
    func updateLastActiveDate() {
        lastActiveDate = Date()
    }
    
    func toggleHSKLevel(_ level: Int) {
        if selectedHSKLevels.contains(level) {
            selectedHSKLevels.removeAll { $0 == level }
        } else {
            selectedHSKLevels.append(level)
            selectedHSKLevels.sort()
        }
    }
    
    func resetToDefaults() {
        selectedHSKLevels = [1, 2]
        dailyGoal = 30
        sessionLength = 10
        showPinyin = true
        showExampleSentences = true
        autoPlayAudio = false
        fontSize = .medium
        colorTheme = .system
        audioVolume = 1.0
        playbackSpeed = 1.0
        enableHapticFeedback = true
    }
}

// MARK: - Font Size Enum
enum FontSize: String, CaseIterable, Codable {
    case small = "Small"
    case medium = "Medium"
    case large = "Large"
    case extraLarge = "Extra Large"
    
    var multiplier: CGFloat {
        switch self {
        case .small: return 0.85
        case .medium: return 1.0
        case .large: return 1.15
        case .extraLarge: return 1.3
        }
    }
}

// MARK: - Color Theme Enum
enum ColorTheme: String, CaseIterable, Codable {
    case light = "Light"
    case dark = "Dark"
    case system = "System"
    case sepia = "Sepia"
}

// MARK: - Notification Frequency Enum
enum NotificationFrequency: String, CaseIterable, Codable {
    case daily = "Daily"
    case twiceDaily = "Twice Daily"
    case weekdays = "Weekdays Only"
    case custom = "Custom"
    
    var displayName: String {
        switch self {
        case .daily: return "Hàng ngày"
        case .twiceDaily: return "Hai lần mỗi ngày"
        case .weekdays: return "Ngày trong tuần"
        case .custom: return "Tùy chỉnh"
        }
    }
}
