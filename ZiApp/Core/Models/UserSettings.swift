//
//  UserSettings.swift
//  ZiApp
//
//  User preferences and settings model
//

import Foundation
import SwiftData

enum SubscriptionStatus: String, Codable {
    case free = "free"
    case pro = "pro"
    case proLifetime = "proLifetime"
}

enum ReviewInterval: String, Codable {
    case adaptive = "adaptive"
    case aggressive = "aggressive"
    case relaxed = "relaxed"
}

enum FontSize: String, Codable {
    case small = "small"
    case medium = "medium"
    case large = "large"
    
    var systemSize: CGFloat {
        switch self {
        case .small: return 14
        case .medium: return 17
        case .large: return 20
        }
    }
}

@Model
final class UserSettings {
    // MARK: - Identification
    @Attribute(.unique)
    var id: UUID = UUID()
    
    // MARK: - Subscription
    var subscriptionStatusRaw: String = SubscriptionStatus.free.rawValue
    var subscriptionExpiryDate: Date?
    var purchaseDate: Date?
    var receiptData: Data?
    
    // MARK: - Learning Preferences
    var selectedHSKLevels: [Int] = [1, 2]
    var dailyGoal: Int = 20
    var enabledNotifications: Bool = false
    var notificationTime: Date?
    
    // MARK: - Display Preferences
    var fontSizeRaw: String = FontSize.medium.rawValue
    var showPinyin: Bool = true
    var autoPlayAudio: Bool = false
    var hapticFeedback: Bool = true
    
    // MARK: - Session Settings
    var sessionLength: Int = 20
    var prioritizeNewWords: Bool = true
    var reviewIntervalRaw: String = ReviewInterval.adaptive.rawValue
    
    // MARK: - Statistics
    var totalWordsLearned: Int = 0
    var currentStreak: Int = 0
    var longestStreak: Int = 0
    var lastActivityDate: Date = Date()
    var totalStudyTime: TimeInterval = 0
    var totalSessions: Int = 0
    
    // MARK: - App Metadata
    var dataVersion: String = "1.2"
    var lastSyncDate: Date?
    var onboardingCompleted: Bool = false
    var hasRatedApp: Bool = false
    var lastPromptDate: Date?
    
    // MARK: - Computed Properties
    var subscriptionStatus: SubscriptionStatus {
        get { SubscriptionStatus(rawValue: subscriptionStatusRaw) ?? .free }
        set { subscriptionStatusRaw = newValue.rawValue }
    }
    
    var fontSize: FontSize {
        get { FontSize(rawValue: fontSizeRaw) ?? .medium }
        set { fontSizeRaw = newValue.rawValue }
    }
    
    var reviewInterval: ReviewInterval {
        get { ReviewInterval(rawValue: reviewIntervalRaw) ?? .adaptive }
        set { reviewIntervalRaw = newValue.rawValue }
    }
    
    var isPremium: Bool {
        switch subscriptionStatus {
        case .pro, .proLifetime:
            return subscriptionExpiryDate == nil || subscriptionExpiryDate! > Date()
        case .free:
            return false
        }
    }
    
    var availableHSKLevels: [Int] {
        isPremium ? [1, 2, 3, 4, 5, 6] : [1, 2]
    }
    
    var isStreakActive: Bool {
        Calendar.current.isDateInToday(lastActivityDate) ||
        Calendar.current.isDateInYesterday(lastActivityDate)
    }
    
    // MARK: - Initialization
    init() {
        // Set default notification time to 8:00 AM
        var components = DateComponents()
        components.hour = 8
        components.minute = 0
        self.notificationTime = Calendar.current.date(from: components)
    }
    
    // MARK: - Methods
    func updateStreak() {
        let calendar = Calendar.current
        
        if calendar.isDateInToday(lastActivityDate) {
            // Already studied today
            return
        }
        
        if calendar.isDateInYesterday(lastActivityDate) {
            // Continue streak
            currentStreak += 1
            if currentStreak > longestStreak {
                longestStreak = currentStreak
            }
        } else {
            // Streak broken
            currentStreak = 1
        }
        
        lastActivityDate = Date()
    }
    
    func resetAllProgress() {
        totalWordsLearned = 0
        currentStreak = 0
        longestStreak = 0
        totalStudyTime = 0
        totalSessions = 0
        lastActivityDate = Date()
    }
    
    func recordSession(duration: TimeInterval, wordsLearned: Int) {
        totalStudyTime += duration
        totalSessions += 1
        totalWordsLearned += wordsLearned
        updateStreak()
    }
    
    static func getOrCreate(in context: ModelContext) -> UserSettings {
        let descriptor = FetchDescriptor<UserSettings>()
        
        do {
            let settings = try context.fetch(descriptor)
            if let existingSettings = settings.first {
                return existingSettings
            } else {
                let newSettings = UserSettings()
                context.insert(newSettings)
                return newSettings
            }
        } catch {
            print("Error fetching UserSettings: \(error)")
            let newSettings = UserSettings()
            context.insert(newSettings)
            return newSettings
        }
    }
}
