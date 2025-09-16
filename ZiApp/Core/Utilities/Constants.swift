//
//  Constants.swift
//  ZiApp
//
//  Global app constants and configuration
//

import Foundation
import SwiftUI

enum Constants {
    
    // MARK: - App Configuration
    enum App {
        static let bundleId = Bundle.main.bundleIdentifier ?? "com.yourcompany.zi"
        static let appGroupId = "group.com.yourcompany.zi"
        static let keychainServiceName = "com.yourcompany.zi.keychain"
        static let supportEmail = "support@yourcompany.com"
        static let privacyPolicyURL = "https://yourcompany.com/zi/privacy"
        static let termsOfServiceURL = "https://yourcompany.com/zi/terms"
        static let appStoreURL = "https://apps.apple.com/app/zi/id1234567890"
        static let appStoreReviewURL = "https://apps.apple.com/app/zi/id1234567890?action=write-review"
    }
    
    // MARK: - Database
    enum Database {
        static let currentSchemaVersion = "1.2"
        static let vocabularyFileName = "vocabulary_v1.2"
        static let maxBatchSize = 50
        static let autosaveInterval: TimeInterval = 30 // seconds
    }
    
    // MARK: - In-App Purchase
    enum IAP {
        static let proMonthlyId = "com.yourcompany.zi.pro.monthly"
        static let proYearlyId = "com.yourcompany.zi.pro.yearly"
        static let proLifetimeId = "com.yourcompany.zi.pro.lifetime"
        
        static let productIds: Set<String> = [
            proMonthlyId,
            proYearlyId,
            proLifetimeId
        ]
        
        // Prices (for display only, actual prices from StoreKit)
        static let monthlyPrice = "$2.99"
        static let yearlyPrice = "$19.99"
        static let lifetimePrice = "$49.99"
        static let yearlySavings = "40%"
    }
    
    // MARK: - Learning Configuration
    enum Learning {
        // Free tier limits
        static let freeHSKLevels = [1, 2]
        static let dailyFreeLimit = 20
        static let freeWordCount = 300 // HSK 1 & 2 combined
        
        // Premium features
        static let premiumHSKLevels = [1, 2, 3, 4, 5, 6]
        static let totalWordCount = 5000 // All HSK levels
        
        // Session settings
        static let defaultSessionLength = 20
        static let minSessionLength = 5
        static let maxSessionLength = 100
        
        // SRS Algorithm
        static let defaultEaseFactor = 2.5
        static let minEaseFactor = 1.3
        static let maxEaseFactor = 3.0
        static let easyBonus = 1.3
        static let hardPenalty = 0.8
        
        // Review intervals (in days)
        static let initialInterval = 1
        static let reviewIntervals = [1, 3, 7, 14, 30, 90]
    }
    
    // MARK: - UI Configuration
    enum UI {
        // Animation
        static let defaultAnimationDuration = 0.3
        static let cardSwipeThreshold: CGFloat = 100
        static let cardRotationAngle: Double = 15
        
        // Layout
        static let defaultPadding: CGFloat = 16
        static let cardCornerRadius: CGFloat = 20
        static let buttonCornerRadius: CGFloat = 12
        
        // Typography
        static let chineseFontName = "Noto Sans SC"
        static let defaultFontSize: CGFloat = 17
        static let largeFontSize: CGFloat = 24
        static let smallFontSize: CGFloat = 14
        
        // Colors
        static let primaryColor = Color.blue
        static let successColor = Color.green
        static let errorColor = Color.red
        static let warningColor = Color.orange
        
        // Card colors
        static let correctSwipeColor = Color.green.opacity(0.3)
        static let incorrectSwipeColor = Color.red.opacity(0.3)
    }
    
    // MARK: - Notifications
    enum Notifications {
        static let dailyReviewTitle = "Time to review! 📚"
        static let dailyReviewBody = "You have %d words ready for review"
        static let streakReminderTitle = "Keep your streak alive! 🔥"
        static let streakReminderBody = "Don't break your %d day streak"
        
        static let notificationCategories = ["daily_review", "streak_reminder", "achievement"]
    }
    
    // MARK: - Analytics Events
    enum Analytics {
        // User actions
        static let appLaunched = "app_launched"
        static let sessionStarted = "session_started"
        static let sessionCompleted = "session_completed"
        static let wordReviewed = "word_reviewed"
        static let wordMarkedKnown = "word_marked_known"
        static let wordMarkedUnknown = "word_marked_unknown"
        
        // Purchase events
        static let premiumViewShown = "premium_view_shown"
        static let purchaseInitiated = "purchase_initiated"
        static let purchaseCompleted = "purchase_completed"
        static let purchaseFailed = "purchase_failed"
        static let purchaseRestored = "purchase_restored"
        
        // Settings
        static let settingsChanged = "settings_changed"
        static let hskLevelChanged = "hsk_level_changed"
        static let notificationsToggled = "notifications_toggled"
    }
    
    // MARK: - User Defaults Keys
    enum UserDefaults {
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let lastReviewDate = "lastReviewDate"
        static let totalReviewCount = "totalReviewCount"
        static let currentStreak = "currentStreak"
        static let longestStreak = "longestStreak"
        static let preferredColorScheme = "preferredColorScheme"
        static let soundEffectsEnabled = "soundEffectsEnabled"
        static let hapticFeedbackEnabled = "hapticFeedbackEnabled"
        static let lastVersionPrompt = "lastVersionPrompt"
        static let hasRatedApp = "hasRatedApp"
        static let sessionCount = "sessionCount"
    }
    
    // MARK: - Feature Flags
    enum Features {
        static let enableAnalytics = true
        static let enableCrashReporting = true
        static let enableDebugMenu = false
        #if DEBUG
        static let showDebugInfo = true
        #else
        static let showDebugInfo = false
        #endif
    }
    
    // MARK: - API Configuration (for future use)
    enum API {
        static let baseURL = "https://api.yourcompany.com/v1"
        static let timeout: TimeInterval = 30
        static let maxRetries = 3
    }
}
