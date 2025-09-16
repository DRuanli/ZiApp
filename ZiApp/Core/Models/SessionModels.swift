//
//  SessionModels.swift
//  ZiApp
//
//  Core session and review tracking models
//

import Foundation
import SwiftData

// MARK: - Learning Session Model
@Model
final class LearningSession {
    @Attribute(.unique) var id: UUID
    var startTime: Date
    var endTime: Date?
    var wordsReviewed: Int
    var correctAnswers: Int
    var incorrectAnswers: Int
    var sessionType: SessionType
    var hskLevels: [Int]
    
    // Relationships
    var reviews: [ReviewRecord]?
    
    init(sessionType: SessionType = .practice, hskLevels: [Int] = []) {
        self.id = UUID()
        self.startTime = Date()
        self.wordsReviewed = 0
        self.correctAnswers = 0
        self.incorrectAnswers = 0
        self.sessionType = sessionType
        self.hskLevels = hskLevels
        self.reviews = []
    }
    
    func complete() {
        self.endTime = Date()
    }
    
    var accuracy: Double {
        let total = correctAnswers + incorrectAnswers
        return total > 0 ? Double(correctAnswers) / Double(total) : 0
    }
    
    var duration: TimeInterval {
        guard let endTime = endTime else {
            return Date().timeIntervalSince(startTime)
        }
        return endTime.timeIntervalSince(startTime)
    }
}

// MARK: - Review Record Model
@Model
final class ReviewRecord {
    @Attribute(.unique) var id: UUID
    var wordId: Int
    var reviewDate: Date
    var quality: Int // 1-5 rating (1=forgot, 5=perfect)
    var responseTime: TimeInterval
    var isCorrect: Bool
    
    // For SRS tracking
    var easeFactor: Double?
    var interval: Int?
    var repetition: Int?
    
    init(wordId: Int, quality: Int, responseTime: TimeInterval = 0) {
        self.id = UUID()
        self.wordId = wordId
        self.reviewDate = Date()
        self.quality = quality
        self.responseTime = responseTime
        self.isCorrect = quality >= 3
        self.repetition = 0
    }
}

// MARK: - Session Type Enum
enum SessionType: String, Codable, CaseIterable {
    case practice = "practice"
    case review = "review"
    case test = "test"
    case quickStudy = "quick_study"
    
    var displayName: String {
        switch self {
        case .practice:
            return "Luyện tập"
        case .review:
            return "Ôn tập"
        case .test:
            return "Kiểm tra"
        case .quickStudy:
            return "Học nhanh"
        }
    }
}

// MARK: - User Progress Model
@Model
final class UserProgress {
    @Attribute(.unique) var id: UUID
    var userId: String
    var totalWordsLearned: Int
    var totalReviewSessions: Int
    var totalPracticeTime: TimeInterval
    var currentStreak: Int
    var longestStreak: Int
    var lastPracticeDate: Date?
    var dailyGoal: Int
    var weeklyGoal: Int
    
    // Premium features
    var isPremium: Bool
    var premiumExpiryDate: Date?
    
    init(userId: String = "default") {
        self.id = UUID()
        self.userId = userId
        self.totalWordsLearned = 0
        self.totalReviewSessions = 0
        self.totalPracticeTime = 0
        self.currentStreak = 0
        self.longestStreak = 0
        self.dailyGoal = 30
        self.weeklyGoal = 150
        self.isPremium = false
    }
    
    func updateStreak() {
        guard let lastDate = lastPracticeDate else {
            currentStreak = 1
            lastPracticeDate = Date()
            return
        }
        
        let calendar = Calendar.current
        let daysDifference = calendar.dateComponents([.day], from: lastDate, to: Date()).day ?? 0
        
        if daysDifference == 1 {
            currentStreak += 1
            longestStreak = max(longestStreak, currentStreak)
        } else if daysDifference > 1 {
            currentStreak = 1
        }
        
        lastPracticeDate = Date()
    }
}
