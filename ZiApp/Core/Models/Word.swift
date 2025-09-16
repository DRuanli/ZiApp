//
//  Word.swift
//  ZiApp
//
//  SwiftData model for Chinese vocabulary words
//

import Foundation
import SwiftData

@Model
final class Word {
    @Attribute(.unique) var id: Int
    var hanzi: String
    var pinyin: String
    var meaning: String
    var hskLevel: Int
    
    // Premium features
    var exampleSentence: String?
    var audioFileName: String?
    
    // Progress tracking
    var timesSeen: Int
    var timesCorrect: Int
    var lastSeen: Date
    
    // SRS properties for Premium
    var easeFactor: Double
    var interval: Int
    var nextReviewDate: Date
    
    // User customization
    var isFavorite: Bool
    var userNotes: String?
    var tags: [String]
    
    // Statistics
    var averageResponseTime: TimeInterval
    var lastResponseTime: TimeInterval?
    
    init(id: Int,
         hanzi: String,
         pinyin: String,
         meaning: String,
         hskLevel: Int,
         exampleSentence: String? = nil,
         audioFileName: String? = nil) {
        
        self.id = id
        self.hanzi = hanzi
        self.pinyin = pinyin
        self.meaning = meaning
        self.hskLevel = hskLevel
        self.exampleSentence = exampleSentence
        self.audioFileName = audioFileName
        
        // Initialize progress tracking
        self.timesSeen = 0
        self.timesCorrect = 0
        self.lastSeen = Date.distantPast
        
        // Initialize SRS properties
        self.easeFactor = 2.5
        self.interval = 0
        self.nextReviewDate = Date()
        
        // Initialize user customization
        self.isFavorite = false
        self.tags = []
        
        // Initialize statistics
        self.averageResponseTime = 0
    }
    
    // MARK: - Computed Properties
    var accuracy: Double {
        guard timesSeen > 0 else { return 0 }
        return Double(timesCorrect) / Double(timesSeen)
    }
    
    var masteryLevel: MasteryLevel {
        switch accuracy {
        case 0..<0.3:
            return .beginner
        case 0.3..<0.6:
            return .learning
        case 0.6..<0.85:
            return .familiar
        default:
            return .mastered
        }
    }
    
    var isNewWord: Bool {
        return timesSeen == 0
    }
    
    var isDue: Bool {
        return nextReviewDate <= Date()
    }
    
    var daysSinceLastSeen: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: lastSeen, to: Date())
        return components.day ?? 0
    }
    
    // MARK: - Methods
    func recordReview(quality: Int, responseTime: TimeInterval) {
        timesSeen += 1
        lastSeen = Date()
        
        if quality >= 3 {
            timesCorrect += 1
        }
        
        // Update response time statistics
        lastResponseTime = responseTime
        if averageResponseTime == 0 {
            averageResponseTime = responseTime
        } else {
            averageResponseTime = (averageResponseTime * Double(timesSeen - 1) + responseTime) / Double(timesSeen)
        }
    }
    
    func toggleFavorite() {
        isFavorite.toggle()
    }
    
    func addTag(_ tag: String) {
        if !tags.contains(tag) {
            tags.append(tag)
        }
    }
    
    func removeTag(_ tag: String) {
        tags.removeAll { $0 == tag }
    }
}

// MARK: - Mastery Level
enum MasteryLevel: String, CaseIterable {
    case beginner = "Beginner"
    case learning = "Learning"
    case familiar = "Familiar"
    case mastered = "Mastered"
    
    var color: String {
        switch self {
        case .beginner:
            return "red"
        case .learning:
            return "orange"
        case .familiar:
            return "yellow"
        case .mastered:
            return "green"
        }
    }
    
    var icon: String {
        switch self {
        case .beginner:
            return "star"
        case .learning:
            return "star.lefthalf.fill"
        case .familiar:
            return "star.fill"
        case .mastered:
            return "star.circle.fill"
        }
    }
}
