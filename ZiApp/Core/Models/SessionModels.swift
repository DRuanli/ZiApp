//
//  SessionModels.swift
//  ZiApp
//
//  Models for learning sessions and review records
//

import Foundation
import SwiftData

// MARK: - Learning Session Model

@Model
final class LearningSession {
    // MARK: - Properties
    @Attribute(.unique)
    var id: UUID = UUID()
    
    var startDate: Date
    var endDate: Date?
    var wordsReviewed: Int = 0
    var correctAnswers: Int = 0
    var incorrectAnswers: Int = 0
    var sessionType: String // "learning", "review", "mixed"
    var completionRate: Double = 0.0
    var averageResponseTime: TimeInterval = 0
    
    // Relationship to words reviewed
    @Relationship(deleteRule: .nullify, inverse: \Word.sessions)
    var reviewedWords: [Word]?
    
    // Session metadata
    var hskLevels: [Int] = []
    var isPremiumSession: Bool = false
    var sessionGoal: Int = 20
    var sessionNotes: String?
    
    // MARK: - Computed Properties
    var duration: TimeInterval {
        guard let endDate = endDate else {
            return Date().timeIntervalSince(startDate)
        }
        return endDate.timeIntervalSince(startDate)
    }
    
    var accuracyRate: Double {
        let total = correctAnswers + incorrectAnswers
        guard total > 0 else { return 0 }
        return Double(correctAnswers) / Double(total)
    }
    
    var isCompleted: Bool {
        endDate != nil
    }
    
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    // MARK: - Initialization
    init(sessionType: String = "learning", sessionGoal: Int = 20, hskLevels: [Int] = [1, 2]) {
        self.startDate = Date()
        self.sessionType = sessionType
        self.sessionGoal = sessionGoal
        self.hskLevels = hskLevels
    }
    
    // MARK: - Methods
    func recordReview(word: Word, wasCorrect: Bool, responseTime: TimeInterval) {
        wordsReviewed += 1
        
        if wasCorrect {
            correctAnswers += 1
        } else {
            incorrectAnswers += 1
        }
        
        // Update average response time
        let currentTotal = averageResponseTime * Double(wordsReviewed - 1)
        averageResponseTime = (currentTotal + responseTime) / Double(wordsReviewed)
        
        // Add word to reviewed list if not already there
        if reviewedWords == nil {
            reviewedWords = []
        }
        if let words = reviewedWords, !words.contains(where: { $0.id == word.id }) {
            reviewedWords?.append(word)
        }
        
        // Update completion rate
        completionRate = Double(wordsReviewed) / Double(sessionGoal)
    }
    
    func complete() {
        endDate = Date()
    }
    
    func abandon() {
        endDate = Date()
        sessionNotes = "Session abandoned"
    }
}

// MARK: - Review Record Model

@Model
final class ReviewRecord {
    // MARK: - Properties
    @Attribute(.unique)
    var id: UUID = UUID()
    
    var wordId: Int
    var reviewDate: Date
    var quality: Int // 1-5 scale for SRS
    var responseTime: TimeInterval
    var wasCorrect: Bool
    var reviewType: String // "new", "review", "relearn"
    
    // Additional context
    var sessionId: UUID?
    var previousInterval: Int?
    var newInterval: Int?
    var previousEaseFactor: Double?
    var newEaseFactor: Double?
    
    // User interaction data
    var swipeDirection: String? // "left", "right", "tap"
    var hintUsed: Bool = false
    var audioPlayed: Bool = false
    
    // MARK: - Computed Properties
    var isQuickResponse: Bool {
        responseTime < 2.0
    }
    
    var isSlowResponse: Bool {
        responseTime > 10.0
    }
    
    var difficultyLevel: String {
        switch quality {
        case 1...2: return "hard"
        case 3: return "medium"
        case 4...5: return "easy"
        default: return "unknown"
        }
    }
    
    // MARK: - Initialization
    init(wordId: Int, quality: Int, wasCorrect: Bool, reviewType: String = "new") {
        self.wordId = wordId
        self.reviewDate = Date()
        self.quality = quality
        self.wasCorrect = wasCorrect
        self.responseTime = 0
        self.reviewType = reviewType
    }
    
    // MARK: - Methods
    func recordSRSUpdate(previousEF: Double, newEF: Double, previousInt: Int, newInt: Int) {
        self.previousEaseFactor = previousEF
        self.newEaseFactor = newEF
        self.previousInterval = previousInt
        self.newInterval = newInt
    }
}

// MARK: - Word Extension for Sessions

extension Word {
    @Relationship(deleteRule: .nullify)
    var sessions: [LearningSession]?
}

// MARK: - Statistics Helper

struct SessionStatistics {
    let totalSessions: Int
    let totalWordsReviewed: Int
    let averageAccuracy: Double
    let averageDuration: TimeInterval
    let bestStreak: Int
    let totalStudyTime: TimeInterval
    
    static func calculate(from sessions: [LearningSession]) -> SessionStatistics {
        let completedSessions = sessions.filter { $0.isCompleted }
        
        let totalWords = completedSessions.reduce(0) { $0 + $1.wordsReviewed }
        let totalCorrect = completedSessions.reduce(0) { $0 + $1.correctAnswers }
        let totalAnswers = completedSessions.reduce(0) { $0 + $1.correctAnswers + $1.incorrectAnswers }
        
        let avgAccuracy = totalAnswers > 0 ? Double(totalCorrect) / Double(totalAnswers) : 0
        let totalTime = completedSessions.reduce(0) { $0 + $1.duration }
        let avgDuration = completedSessions.count > 0 ? totalTime / Double(completedSessions.count) : 0
        
        return SessionStatistics(
            totalSessions: completedSessions.count,
            totalWordsReviewed: totalWords,
            averageAccuracy: avgAccuracy,
            averageDuration: avgDuration,
            bestStreak: calculateBestStreak(from: completedSessions),
            totalStudyTime: totalTime
        )
    }
    
    private static func calculateBestStreak(from sessions: [LearningSession]) -> Int {
        // Sort sessions by date
        let sortedSessions = sessions.sorted { $0.startDate < $1.startDate }
        
        var currentStreak = 0
        var bestStreak = 0
        var lastDate: Date?
        
        for session in sortedSessions {
            if let last = lastDate {
                let daysBetween = Calendar.current.dateComponents([.day], from: last, to: session.startDate).day ?? 0
                
                if daysBetween == 1 {
                    currentStreak += 1
                } else if daysBetween > 1 {
                    currentStreak = 1
                }
            } else {
                currentStreak = 1
            }
            
            bestStreak = max(bestStreak, currentStreak)
            lastDate = session.startDate
        }
        
        return bestStreak
    }
}
