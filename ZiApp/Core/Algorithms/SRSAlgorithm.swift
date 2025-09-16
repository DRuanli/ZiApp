//
//  SRSAlgorithm.swift
//  ZiApp
//
//  SuperMemo SM-2 algorithm implementation for spaced repetition
//

import Foundation

/// Spaced Repetition System using SM-2 algorithm
class SRSAlgorithm {
    
    // MARK: - Constants
    private let minEaseFactor: Double = 1.3
    private let defaultEaseFactor: Double = 2.5
    private let easyBonus: Double = 1.3
    private let hardPenalty: Double = 0.8
    
    // MARK: - Main Algorithm
    
    /// Calculate next review parameters based on SM-2 algorithm
    /// - Parameters:
    ///   - quality: Quality of recall (1-5 scale)
    ///   - repetitions: Number of consecutive correct responses
    ///   - easeFactor: Current ease factor
    ///   - interval: Current interval in days
    /// - Returns: Updated SRS parameters
    func calculateNext(
        quality: Int,
        repetitions: Int,
        easeFactor: Double,
        interval: Int
    ) -> SRSResult {
        
        var newRepetitions = repetitions
        var newEaseFactor = easeFactor
        var newInterval = interval
        
        // Quality should be 1-5
        let q = max(1, min(5, quality))
        
        // Update ease factor
        // EF' = EF + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02))
        if q >= 3 {
            newEaseFactor = easeFactor + (0.1 - Double(5 - q) * (0.08 + Double(5 - q) * 0.02))
        } else {
            // For quality < 3, reduce ease factor more aggressively
            newEaseFactor = easeFactor - 0.2
        }
        
        // Ensure ease factor doesn't go below minimum
        newEaseFactor = max(minEaseFactor, newEaseFactor)
        
        // Calculate new interval
        if q < 3 {
            // Failed recall - reset to beginning
            newRepetitions = 0
            newInterval = 1
        } else {
            // Successful recall
            newRepetitions += 1
            
            switch newRepetitions {
            case 1:
                newInterval = 1
            case 2:
                newInterval = 3
            default:
                // For repetitions >= 3, use the ease factor
                newInterval = Int(round(Double(interval) * newEaseFactor))
            }
            
            // Apply quality-based adjustments
            if q == 5 {
                // Perfect recall - apply easy bonus
                newInterval = Int(Double(newInterval) * easyBonus)
            } else if q == 3 {
                // Barely recalled - apply hard penalty
                newInterval = Int(Double(newInterval) * hardPenalty)
            }
        }
        
        // Add some randomization to prevent clustering (±15%)
        let variance = Double.random(in: 0.85...1.15)
        newInterval = Int(Double(newInterval) * variance)
        
        // Ensure minimum interval
        newInterval = max(1, newInterval)
        
        // Calculate next review date
        let nextReviewDate = Calendar.current.date(
            byAdding: .day,
            value: newInterval,
            to: Date()
        ) ?? Date()
        
        Logger.shared.debug("""
            SRS Calculation:
            Quality: \(q), Reps: \(repetitions) → \(newRepetitions)
            EF: \(String(format: "%.2f", easeFactor)) → \(String(format: "%.2f", newEaseFactor))
            Interval: \(interval) → \(newInterval) days
            """)
        
        return SRSResult(
            repetitions: newRepetitions,
            easeFactor: newEaseFactor,
            interval: newInterval,
            nextReviewDate: nextReviewDate
        )
    }
    
    // MARK: - Helper Methods
    
    /// Get initial parameters for a new word
    func getInitialParameters() -> SRSResult {
        return SRSResult(
            repetitions: 0,
            easeFactor: defaultEaseFactor,
            interval: 0,
            nextReviewDate: Date()
        )
    }
    
    /// Calculate quality based on user response
    /// - Parameters:
    ///   - wasCorrect: Whether the user knew the word
    ///   - responseTime: Time taken to respond (optional)
    /// - Returns: Quality rating (1-5)
    func calculateQuality(wasCorrect: Bool, responseTime: TimeInterval? = nil) -> Int {
        if !wasCorrect {
            return 1 // Complete blackout
        }
        
        // If correct, determine quality based on response time
        guard let time = responseTime else {
            return wasCorrect ? 5 : 1 // Default to perfect if correct, worst if not
        }
        
        // Response time thresholds (in seconds)
        switch time {
        case 0..<2:
            return 5 // Perfect - instant recall
        case 2..<5:
            return 4 // Good - quick recall
        case 5..<10:
            return 3 // Pass - hesitation
        default:
            return 2 // Fail - struggled but got it
        }
    }
    
    /// Get review intervals for different stages
    func getReviewIntervals() -> [Int] {
        return [1, 3, 7, 14, 30, 90, 180, 365]
    }
    
    /// Calculate retention probability (Ebbinghaus forgetting curve)
    /// - Parameters:
    ///   - daysSinceReview: Days since last review
    ///   - easeFactor: Current ease factor
    /// - Returns: Estimated retention probability (0-1)
    func calculateRetention(daysSinceReview: Int, easeFactor: Double) -> Double {
        // Simplified forgetting curve: R = e^(-t/S)
        // Where S is stability (related to ease factor)
        let stability = easeFactor * 5.0 // Convert EF to stability measure
        let retention = exp(-Double(daysSinceReview) / stability)
        return max(0, min(1, retention))
    }
}

// MARK: - Priority Scoring for Free Users

class PriorityScoring {
    
    /// Calculate priority score for word selection (free tier)
    /// Lower score = higher priority
    func calculateScore(for word: Word) -> Int {
        var score = 0
        
        // Base score from correct answers
        score += word.timesCorrect * 20
        
        // Penalty for recently seen words
        if word.daysSinceLastSeen < 1 {
            score += 50
        } else if word.daysSinceLastSeen < 3 {
            score += 20
        }
        
        // Bonus for words that haven't been seen
        if word.timesSeen == 0 {
            score -= 100 // High priority for new words
        }
        
        // Bonus for words with low accuracy
        if word.timesSeen > 0 && word.accuracyRate < 0.5 {
            score -= 30 // Need more practice
        }
        
        // Small random factor to add variety
        score += Int.random(in: -10...10)
        
        return score
    }
    
    /// Select words for a session based on priority
    func selectWords(from words: [Word], count: Int) -> [Word] {
        // Calculate scores for all words
        let scoredWords = words.map { word -> (Word, Int) in
            (word, calculateScore(for: word))
        }
        
        // Sort by priority (lower score = higher priority)
        let sortedWords = scoredWords.sorted { $0.1 < $1.1 }
        
        // Take top words and shuffle for variety
        let selectedWords = Array(sortedWords.prefix(count * 2).map { $0.0 })
        return Array(selectedWords.shuffled().prefix(count))
    }
}

// MARK: - Session Builder

class SessionBuilder {
    private let dataService = DataService.shared
    private let priorityScoring = PriorityScoring()
    private let srsAlgorithm = SRSAlgorithm()
    
    /// Build a learning session based on user settings
    func buildSession(
        settings: UserSettings,
        sessionLength: Int,
        focusLevels: [Int]
    ) async throws -> SessionConfiguration {
        
        let isPremium = settings.isPremium
        
        var words: [Word] = []
        
        if isPremium {
            // Premium: Use SRS to select due words
            words = try await dataService.fetchWordsForSession(
                levels: focusLevels,
                isPremium: true,
                dailyLimit: sessionLength
            )
        } else {
            // Free: Use priority scoring
            words = try await dataService.fetchWordsForSession(
                levels: focusLevels,
                isPremium: false,
                dailyLimit: sessionLength
            )
        }
        
        // Categorize words
        let newWords = words.filter { $0.timesSeen == 0 }
        let reviewWords = words.filter { $0.timesSeen > 0 && $0.isDue }
        let practiceWords = words.filter { $0.timesSeen > 0 && !$0.isDue }
        
        return SessionConfiguration(
            words: words,
            newWords: newWords,
            reviewWords: reviewWords,
            practiceWords: practiceWords,
            sessionType: determineSessionType(
                new: newWords.count,
                review: reviewWords.count,
                practice: practiceWords.count
            ),
            estimatedDuration: estimateDuration(wordCount: words.count)
        )
    }
    
    private func determineSessionType(new: Int, review: Int, practice: Int) -> String {
        let total = new + review + practice
        guard total > 0 else { return "empty" }
        
        if Double(new) / Double(total) > 0.5 {
            return "learning"
        } else if Double(review) / Double(total) > 0.5 {
            return "review"
        } else {
            return "mixed"
        }
    }
    
    private func estimateDuration(wordCount: Int) -> TimeInterval {
        // Estimate 5 seconds per word on average
        return TimeInterval(wordCount * 5)
    }
}

// MARK: - Supporting Types

struct SRSResult {
    let repetitions: Int
    let easeFactor: Double
    let interval: Int
    let nextReviewDate: Date
}

struct SessionConfiguration {
    let words: [Word]
    let newWords: [Word]
    let reviewWords: [Word]
    let practiceWords: [Word]
    let sessionType: String
    let estimatedDuration: TimeInterval
    
    var formattedDuration: String {
        let minutes = Int(estimatedDuration / 60)
        return "\(minutes) min"
    }
    
    var isEmpty: Bool {
        words.isEmpty
    }
}
