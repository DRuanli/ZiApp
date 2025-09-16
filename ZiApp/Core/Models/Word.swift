//
//  Word.swift
//  ZiApp
//
//  Core data model for Chinese vocabulary words
//

import Foundation
import SwiftData

@Model
final class Word {
    // MARK: - Core Properties
    @Attribute(.unique)
    var id: Int
    var hanzi: String
    var pinyin: String
    var meaning: String
    var hskLevel: Int
    
    // MARK: - Premium Content
    var exampleSentence: String?
    var exampleTranslation: String?
    var audioFileName: String?
    
    // MARK: - Learning Progress
    var timesSeen: Int = 0
    var timesCorrect: Int = 0
    var timesIncorrect: Int = 0
    var lastSeenDate: Date = Date.distantPast
    var firstSeenDate: Date?
    
    // MARK: - SRS Properties (Premium)
    var easeFactor: Double = 2.5
    var interval: Int = 0
    var repetitions: Int = 0
    var nextReviewDate: Date = Date()
    var lastReviewQuality: Int?
    
    // MARK: - User Interaction
    var isFavorited: Bool = false
    var userNotes: String?
    
    // MARK: - Metadata
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var dataVersion: String = "1.2"
    
    // MARK: - Computed Properties
    var isNewWord: Bool {
        timesSeen == 0
    }
    
    var isDue: Bool {
        nextReviewDate <= Date()
    }
    
    var accuracyRate: Double {
        guard timesCorrect + timesIncorrect > 0 else { return 0 }
        return Double(timesCorrect) / Double(timesCorrect + timesIncorrect)
    }
    
    var daysSinceLastSeen: Int {
        Calendar.current.dateComponents([.day], from: lastSeenDate, to: Date()).day ?? 0
    }
    
    // MARK: - Priority Score for Free Users
    var priorityScore: Int {
        let correctPenalty = timesCorrect * 20
        let recentPenalty = daysSinceLastSeen < 1 ? 50 : 0
        return correctPenalty + recentPenalty
    }
    
    // MARK: - Initialization
    init(
        id: Int,
        hanzi: String,
        pinyin: String,
        meaning: String,
        hskLevel: Int,
        exampleSentence: String? = nil,
        exampleTranslation: String? = nil,
        audioFileName: String? = nil
    ) {
        self.id = id
        self.hanzi = hanzi
        self.pinyin = pinyin
        self.meaning = meaning
        self.hskLevel = hskLevel
        self.exampleSentence = exampleSentence
        self.exampleTranslation = exampleTranslation
        self.audioFileName = audioFileName
    }
    
    // MARK: - Methods
    func markAsSeen(wasCorrect: Bool) {
        timesSeen += 1
        lastSeenDate = Date()
        
        if firstSeenDate == nil {
            firstSeenDate = Date()
        }
        
        if wasCorrect {
            timesCorrect += 1
        } else {
            timesIncorrect += 1
        }
        
        updatedAt = Date()
    }
    
    func resetProgress() {
        timesSeen = 0
        timesCorrect = 0
        timesIncorrect = 0
        lastSeenDate = Date.distantPast
        firstSeenDate = nil
        
        // Reset SRS
        easeFactor = 2.5
        interval = 0
        repetitions = 0
        nextReviewDate = Date()
        lastReviewQuality = nil
        
        updatedAt = Date()
    }
}
