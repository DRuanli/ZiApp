//
//  DataService.swift
//  Zi
//
//  Core data service for managing vocabulary and learning progress
//

import Foundation
import SwiftData
import SwiftUI

@MainActor
class DataService: ObservableObject {
    static let shared = DataService()
    
    private let container: SwiftDataContainer
    private let context: ModelContext
    
    // Cache for performance
    private var wordCache: [Int: Word] = [:]
    private var lastCacheUpdate: Date = Date()
    
    private init() {
        self.container = SwiftDataContainer.shared
        self.context = container.mainContext
    }
    
    // MARK: - Word Management
    
    /// Fetch words for a learning session
    func fetchWordsForSession(
        levels: [Int],
        isPremium: Bool,
        dailyLimit: Int = Constants.Learning.dailyFreeLimit
    ) async throws -> [Word] {
        
        Logger.shared.info("Fetching words for session - Levels: \(levels), Premium: \(isPremium)")
        
        if isPremium {
            return try await fetchPremiumWords(levels: levels, limit: dailyLimit)
        } else {
            return try await fetchFreeWords(levels: levels, limit: dailyLimit)
        }
    }
    
    /// Fetch words for free users using priority scoring
    private func fetchFreeWords(levels: [Int], limit: Int) async throws -> [Word] {
        let descriptor = FetchDescriptor<Word>(
            predicate: #Predicate<Word> { word in
                levels.contains(word.hskLevel)
            },
            sortBy: [SortDescriptor(\.id)]
        )
        
        let allWords = try context.fetch(descriptor)
        
        // Calculate priority scores
        let scoredWords = allWords.map { word -> (Word, Int) in
            let score = calculatePriorityScore(for: word)
            return (word, score)
        }
        
        // Sort by priority (lower score = higher priority)
        let sortedWords = scoredWords
            .sorted { $0.1 < $1.1 }
            .prefix(limit * 2) // Get more for variety
            .map { $0.0 }
            .shuffled()
            .prefix(limit)
        
        return Array(sortedWords)
    }
    
    /// Fetch words for premium users using SRS
    private func fetchPremiumWords(levels: [Int], limit: Int) async throws -> [Word] {
        let today = Date()
        
        // First, get due reviews
        let dueDescriptor = FetchDescriptor<Word>(
            predicate: #Predicate<Word> { word in
                levels.contains(word.hskLevel) && word.nextReviewDate <= today
            },
            sortBy: [SortDescriptor(\.nextReviewDate)]
        )
        
        let dueWords = try context.fetch(dueDescriptor)
        
        // If we need more words, get new ones
        var sessionWords = Array(dueWords.prefix(limit))
        
        if sessionWords.count < limit {
            let newWordsNeeded = limit - sessionWords.count
            let newWordsDescriptor = FetchDescriptor<Word>(
                predicate: #Predicate<Word> { word in
                    levels.contains(word.hskLevel) && word.timesSeen == 0
                },
                sortBy: [SortDescriptor(\.id)]
            )
            
            let newWords = try context.fetch(newWordsDescriptor)
            sessionWords.append(contentsOf: newWords.prefix(newWordsNeeded))
        }
        
        return sessionWords.shuffled()
    }
    
    /// Calculate priority score for free tier algorithm
    private func calculatePriorityScore(for word: Word) -> Int {
        let correctPenalty = word.timesCorrect * 20
        let recentPenalty = word.daysSinceLastSeen < 1 ? 50 : 0
        return correctPenalty + recentPenalty
    }
    
    // MARK: - Review Recording
    
    /// Record a review for a word
    func recordReview(
        for word: Word,
        wasCorrect: Bool,
        responseTime: TimeInterval = 0,
        session: LearningSession? = nil
    ) async throws {
        
        Logger.shared.debug("Recording review for word \(word.id): \(wasCorrect ? "Correct" : "Incorrect")")
        
        // Update word statistics
        word.markAsSeen(wasCorrect: wasCorrect)
        
        // For premium users, update SRS
        let settings = UserSettings.getOrCreate(in: context)
        if settings.isPremium {
            let quality = wasCorrect ? 5 : 1
            updateSRS(for: word, quality: quality)
        }
        
        // Create review record
        let review = ReviewRecord(
            wordId: word.id,
            quality: wasCorrect ? 5 : 1,
            wasCorrect: wasCorrect
        )
        review.responseTime = responseTime
        review.sessionId = session?.id
        
        context.insert(review)
        
        // Update session if provided
        if let session = session {
            session.recordReview(word: word, wasCorrect: wasCorrect, responseTime: responseTime)
        }
        
        // Save changes
        try context.save()
        
        // Update cache
        wordCache[word.id] = word
    }
    
    /// Update SRS properties for a word
    private func updateSRS(for word: Word, quality: Int) {
        let algorithm = SRSAlgorithm()
        let result = algorithm.calculateNext(
            quality: quality,
            repetitions: word.repetitions,
            easeFactor: word.easeFactor,
            interval: word.interval
        )
        
        word.easeFactor = result.easeFactor
        word.interval = result.interval
        word.repetitions = result.repetitions
        word.nextReviewDate = result.nextReviewDate
        word.lastReviewQuality = quality
    }
    
    // MARK: - Statistics
    
    /// Get daily review statistics for chart
    func getDailyReviewStats(for pastDays: Int = 30) async throws -> [DailyStats] {
        let startDate = Calendar.current.date(byAdding: .day, value: -pastDays, to: Date()) ?? Date()
        
        let descriptor = FetchDescriptor<ReviewRecord>(
            predicate: #Predicate<ReviewRecord> { review in
                review.reviewDate >= startDate
            },
            sortBy: [SortDescriptor(\.reviewDate)]
        )
        
        let reviews = try context.fetch(descriptor)
        
        // Group by date
        let grouped = Dictionary(grouping: reviews) { review in
            Calendar.current.startOfDay(for: review.reviewDate)
        }
        
        // Create stats for each day
        var dailyStats: [DailyStats] = []
        
        for day in 0..<pastDays {
            let date = Calendar.current.date(byAdding: .day, value: -day, to: Date()) ?? Date()
            let dayStart = Calendar.current.startOfDay(for: date)
            
            let dayReviews = grouped[dayStart] ?? []
            let correct = dayReviews.filter { $0.wasCorrect }.count
            let total = dayReviews.count
            
            dailyStats.append(DailyStats(
                date: dayStart,
                totalReviews: total,
                correctReviews: correct,
                accuracy: total > 0 ? Double(correct) / Double(total) : 0
            ))
        }
        
        return dailyStats.reversed()
    }
    
    /// Get learning progress summary
    func getLearningProgress() async throws -> LearningProgress {
        let settings = UserSettings.getOrCreate(in: context)
        
        // Get total words learned
        let learnedDescriptor = FetchDescriptor<Word>(
            predicate: #Predicate<Word> { word in
                word.timesSeen > 0
            }
        )
        let learnedWords = try context.fetch(learnedDescriptor)
        
        // Get mastered words (seen 5+ times with 80%+ accuracy)
        let masteredWords = learnedWords.filter { word in
            word.timesSeen >= 5 && word.accuracyRate >= 0.8
        }
        
        // Get words by HSK level
        var wordsByLevel: [Int: Int] = [:]
        for level in 1...6 {
            let levelDescriptor = FetchDescriptor<Word>(
                predicate: #Predicate<Word> { word in
                    word.hskLevel == level && word.timesSeen > 0
                }
            )
            wordsByLevel[level] = try context.fetch(levelDescriptor).count
        }
        
        return LearningProgress(
            totalWordsLearned: learnedWords.count,
            masteredWords: masteredWords.count,
            currentStreak: settings.currentStreak,
            longestStreak: settings.longestStreak,
            totalStudyTime: settings.totalStudyTime,
            wordsByLevel: wordsByLevel,
            averageAccuracy: calculateAverageAccuracy(from: learnedWords)
        )
    }
    
    private func calculateAverageAccuracy(from words: [Word]) -> Double {
        let totalCorrect = words.reduce(0) { $0 + $1.timesCorrect }
        let totalAttempts = words.reduce(0) { $0 + $1.timesSeen }
        
        guard totalAttempts > 0 else { return 0 }
        return Double(totalCorrect) / Double(totalAttempts)
    }
    
    // MARK: - HSK Level Management
    
    /// Get available words count for each HSK level
    func getWordCountByLevel() async throws -> [Int: Int] {
        var counts: [Int: Int] = [:]
        
        for level in 1...6 {
            let descriptor = FetchDescriptor<Word>(
                predicate: #Predicate<Word> { word in
                    word.hskLevel == level
                }
            )
            counts[level] = try context.fetchCount(descriptor)
        }
        
        return counts
    }
    
    /// Get words for specific HSK level
    func getWords(for level: Int, limit: Int? = nil) async throws -> [Word] {
        var descriptor = FetchDescriptor<Word>(
            predicate: #Predicate<Word> { word in
                word.hskLevel == level
            },
            sortBy: [SortDescriptor(\.id)]
        )
        
        if let limit = limit {
            descriptor.fetchLimit = limit
        }
        
        return try context.fetch(descriptor)
    }
    
    // MARK: - Session Management
    
    /// Start a new learning session
    func startLearningSession(type: String = "learning", goal: Int = 20, levels: [Int]) -> LearningSession {
        let session = LearningSession(
            sessionType: type,
            sessionGoal: goal,
            hskLevels: levels
        )
        
        let settings = UserSettings.getOrCreate(in: context)
        session.isPremiumSession = settings.isPremium
        
        context.insert(session)
        
        // Update activity date
        settings.lastActivityDate = Date()
        settings.updateStreak()
        
        try? context.save()
        
        Logger.shared.info("Started new \(type) session with goal: \(goal)")
        
        return session
    }
    
    /// Complete a learning session
    func completeSession(_ session: LearningSession) {
        session.complete()
        
        let settings = UserSettings.getOrCreate(in: context)
        settings.recordSession(
            duration: session.duration,
            wordsLearned: session.wordsReviewed
        )
        
        try? context.save()
        
        Logger.shared.info("Completed session: \(session.wordsReviewed) words in \(session.formattedDuration)")
    }
    
    // MARK: - Reset Functions
    
    /// Reset progress for specific HSK levels
    func resetProgress(for levels: [Int]) async throws {
        let descriptor = FetchDescriptor<Word>(
            predicate: #Predicate<Word> { word in
                levels.contains(word.hskLevel)
            }
        )
        
        let words = try context.fetch(descriptor)
        
        for word in words {
            word.resetProgress()
        }
        
        Logger.shared.info("Reset progress for HSK levels: \(levels)")
        
        try context.save()
    }
    
    /// Reset all user progress
    func resetAllProgress() async throws {
        await container.resetAllProgress()
        Logger.shared.info("Reset all user progress")
    }
    
    // MARK: - Search Functions
    
    /// Search words by pinyin or meaning
    func searchWords(query: String, in levels: [Int]? = nil) async throws -> [Word] {
        let lowercaseQuery = query.lowercased()
        
        var predicate: Predicate<Word>
        
        if let levels = levels {
            predicate = #Predicate<Word> { word in
                levels.contains(word.hskLevel) &&
                (word.pinyin.localizedStandardContains(lowercaseQuery) ||
                 word.meaning.localizedStandardContains(lowercaseQuery))
            }
        } else {
            predicate = #Predicate<Word> { word in
                word.pinyin.localizedStandardContains(lowercaseQuery) ||
                word.meaning.localizedStandardContains(lowercaseQuery)
            }
        }
        
        let descriptor = FetchDescriptor<Word>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.hskLevel), SortDescriptor(\.id)]
        )
        
        return try context.fetch(descriptor)
    }
    
    // MARK: - Favorites Management
    
    /// Toggle favorite status for a word
    func toggleFavorite(for word: Word) {
        word.isFavorited.toggle()
        word.updatedAt = Date()
        
        try? context.save()
        
        Logger.shared.debug("Toggled favorite for word \(word.id): \(word.isFavorited)")
    }
    
    /// Get all favorited words
    func getFavoriteWords() async throws -> [Word] {
        let descriptor = FetchDescriptor<Word>(
            predicate: #Predicate<Word> { word in
                word.isFavorited == true
            },
            sortBy: [SortDescriptor(\.hskLevel), SortDescriptor(\.id)]
        )
        
        return try context.fetch(descriptor)
    }
}

// MARK: - Supporting Types

struct DailyStats: Identifiable {
    let id = UUID()
    let date: Date
    let totalReviews: Int
    let correctReviews: Int
    let accuracy: Double
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

struct LearningProgress {
    let totalWordsLearned: Int
    let masteredWords: Int
    let currentStreak: Int
    let longestStreak: Int
    let totalStudyTime: TimeInterval
    let wordsByLevel: [Int: Int]
    let averageAccuracy: Double
    
    var formattedStudyTime: String {
        let hours = Int(totalStudyTime) / 3600
        let minutes = (Int(totalStudyTime) % 3600) / 60
        return "\(hours)h \(minutes)m"
    }
    
    var masteryRate: Double {
        guard totalWordsLearned > 0 else { return 0 }
        return Double(masteredWords) / Double(totalWordsLearned)
    }
}
