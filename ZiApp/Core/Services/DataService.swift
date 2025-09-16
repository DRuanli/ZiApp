//
//  DataService.swift
//  ZiApp
//
//  Core data management and business logic service
//

import Foundation
import SwiftData

@MainActor
final class DataService {
    static let shared = DataService()
    
    private let container = SwiftDataContainer.shared
    private let logger = Logger.shared
    
    private init() {}
    
    // MARK: - Initial Data Bootstrap
    func bootstrapInitialData(from jsonFile: String, version: String) async {
        // Check if data already loaded
        let currentVersion = UserDefaults.standard.string(forKey: "data_version")
        if currentVersion == version {
            logger.log("Data already at version \(version), skipping bootstrap", level: .info)
            return
        }
        
        do {
            // Load JSON file
            guard let url = Bundle.main.url(forResource: jsonFile, withExtension: nil) else {
                throw DataServiceError.fileNotFound
            }
            
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let vocabularyItems = try decoder.decode([VocabularyItem].self, from: data)
            
            // Convert to Word models and insert
            for item in vocabularyItems {
                let word = Word(
                    id: item.id,
                    hanzi: item.hanzi,
                    pinyin: item.pinyin,
                    meaning: item.meaning,
                    hskLevel: item.hskLevel,
                    exampleSentence: item.exampleSentence,
                    audioFileName: item.audioFileName
                )
                container.insert(word)
            }
            
            container.save()
            UserDefaults.standard.set(version, forKey: "data_version")
            logger.log("Successfully imported \(vocabularyItems.count) words", level: .info)
            
        } catch {
            logger.log("Failed to bootstrap data: \(error)", level: .error)
        }
    }
    
    // MARK: - Fetch Words for Session
    func fetchWordsForSession(levels: [Int], isPro: Bool, dailyLimit: Int = 30) async -> [Word] {
        do {
            var words: [Word] = []
            
            if isPro {
                // Pro users: Get words due for review + new words
                words = try await fetchDueWords(levels: levels)
                let newWords = try await fetchNewWords(levels: levels, limit: max(0, dailyLimit - words.count))
                words.append(contentsOf: newWords)
            } else {
                // Free users: Priority-based selection
                words = try await fetchPriorityWords(levels: levels, limit: dailyLimit)
            }
            
            logger.log("Fetched \(words.count) words for session", level: .debug)
            return words.shuffled()
            
        } catch {
            logger.log("Failed to fetch words for session: \(error)", level: .error)
            return []
        }
    }
    
    // MARK: - Record Review
    func recordReview(for word: Word, quality: Int) async {
        // Create review record
        let review = ReviewRecord(wordId: word.id, quality: quality)
        container.insert(review)
        
        // Update word statistics
        word.timesSeen += 1
        word.lastSeen = Date()
        
        if quality >= 3 {
            word.timesCorrect += 1
        }
        
        // Apply SRS algorithm for Pro users
        if PurchaseManager.shared.isPremium {
            applySpacedRepetition(to: word, quality: quality)
        }
        
        container.save()
        logger.log("Recorded review for word: \(word.hanzi)", level: .debug)
    }
    
    // MARK: - Statistics
    func getDailyReviewStats(for pastDays: Int = 30) async -> [Date: Int] {
        do {
            let calendar = Calendar.current
            let endDate = Date()
            let startDate = calendar.date(byAdding: .day, value: -pastDays, to: endDate)!
            
            let predicate = #Predicate<ReviewRecord> { review in
                review.reviewDate >= startDate && review.reviewDate <= endDate
            }
            
            let reviews = try container.fetch(ReviewRecord.self, predicate: predicate)
            
            // Group by date
            var stats: [Date: Int] = [:]
            for review in reviews {
                let dayStart = calendar.startOfDay(for: review.reviewDate)
                stats[dayStart, default: 0] += 1
            }
            
            return stats
            
        } catch {
            logger.log("Failed to get daily review stats: \(error)", level: .error)
            return [:]
        }
    }
    
    // MARK: - Private Helper Methods
    private func fetchDueWords(levels: [Int]) async throws -> [Word] {
        let now = Date()
        let predicate = #Predicate<Word> { word in
            levels.contains(word.hskLevel) && word.nextReviewDate <= now
        }
        
        return try container.fetch(Word.self, predicate: predicate)
    }
    
    private func fetchNewWords(levels: [Int], limit: Int) async throws -> [Word] {
        let predicate = #Predicate<Word> { word in
            levels.contains(word.hskLevel) && word.timesSeen == 0
        }
        
        var descriptor = FetchDescriptor<Word>(predicate: predicate)
        descriptor.fetchLimit = limit
        
        return try container.mainContext.fetch(descriptor)
    }
    
    private func fetchPriorityWords(levels: [Int], limit: Int) async throws -> [Word] {
        let predicate = #Predicate<Word> { word in
            levels.contains(word.hskLevel)
        }
        
        let words = try container.fetch(Word.self, predicate: predicate)
        
        // Calculate priority scores
        let scoredWords = words.map { word -> (Word, Double) in
            let daysSinceLastSeen = Date().timeIntervalSince(word.lastSeen) / 86400
            let score = Double(word.timesCorrect * 20) + (daysSinceLastSeen < 1 ? 50 : 0)
            return (word, score)
        }
        
        // Sort by score (lower is higher priority) and take limit
        let sortedWords = scoredWords.sorted { $0.1 < $1.1 }
        return Array(sortedWords.prefix(limit).map { $0.0 })
    }
    
    private func applySpacedRepetition(to word: Word, quality: Int) {
        // SM-2 algorithm implementation
        let algorithm = SRSAlgorithm()
        let (newEaseFactor, newInterval) = algorithm.calculate(
            quality: quality,
            previousEaseFactor: word.easeFactor,
            previousInterval: word.interval
        )
        
        word.easeFactor = newEaseFactor
        word.interval = newInterval
        word.nextReviewDate = Calendar.current.date(
            byAdding: .day,
            value: newInterval,
            to: Date()
        ) ?? Date()
    }
}

// MARK: - Error Types
enum DataServiceError: LocalizedError {
    case fileNotFound
    case invalidData
    case saveFailed
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "Data file not found"
        case .invalidData:
            return "Invalid data format"
        case .saveFailed:
            return "Failed to save data"
        }
    }
}

// MARK: - Vocabulary Item for JSON Decoding
private struct VocabularyItem: Codable {
    let id: Int
    let hanzi: String
    let pinyin: String
    let meaning: String
    let hskLevel: Int
    let exampleSentence: String?
    let audioFileName: String?
}
