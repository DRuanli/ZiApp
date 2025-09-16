//
//  SRSAlgorithm.swift
//  ZiApp
//
//  SM-2 Spaced Repetition Algorithm implementation
//

import Foundation

/// Implements the SM-2 (SuperMemo 2) spaced repetition algorithm
final class SRSAlgorithm {
    
    // MARK: - Algorithm Constants
    private let minimumEaseFactor: Double = 1.3
    private let easyBonus: Double = 1.3
    private let hardInterval: Double = 1.2
    
    // MARK: - Main Algorithm
    /// Calculate next review interval using SM-2 algorithm
    /// - Parameters:
    ///   - quality: Quality of recall (1-5, where 1 is complete failure and 5 is perfect recall)
    ///   - previousEaseFactor: The previous ease factor (default 2.5 for new items)
    ///   - previousInterval: The previous interval in days
    /// - Returns: Tuple of (newEaseFactor, newInterval)
    func calculate(quality: Int,
                  previousEaseFactor: Double = 2.5,
                  previousInterval: Int = 0) -> (easeFactor: Double, interval: Int) {
        
        // Validate quality input
        let q = max(1, min(5, quality))
        
        // Calculate new ease factor
        let newEaseFactor = calculateEaseFactor(quality: q, previousEaseFactor: previousEaseFactor)
        
        // Calculate new interval
        let newInterval = calculateInterval(quality: q,
                                           previousInterval: previousInterval,
                                           easeFactor: newEaseFactor)
        
        Logger.shared.log("SRS calculated - Quality: \(q), EF: \(newEaseFactor), Interval: \(newInterval)",
                         level: .debug)
        
        return (newEaseFactor, newInterval)
    }
    
    // MARK: - Ease Factor Calculation
    private func calculateEaseFactor(quality: Int, previousEaseFactor: Double) -> Double {
        // SM-2 formula: EF' = EF + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02))
        let qualityFactor = Double(5 - quality)
        let adjustment = 0.1 - qualityFactor * (0.08 + qualityFactor * 0.02)
        var newEaseFactor = previousEaseFactor + adjustment
        
        // Ensure ease factor doesn't go below minimum
        newEaseFactor = max(minimumEaseFactor, newEaseFactor)
        
        return newEaseFactor
    }
    
    // MARK: - Interval Calculation
    private func calculateInterval(quality: Int,
                                  previousInterval: Int,
                                  easeFactor: Double) -> Int {
        
        var newInterval: Int
        
        if quality < 3 {
            // Failed recall - reset to beginning
            newInterval = 1
        } else if previousInterval == 0 {
            // First review
            newInterval = 1
        } else if previousInterval == 1 {
            // Second review
            newInterval = 6
        } else {
            // Subsequent reviews
            let calculatedInterval = Double(previousInterval) * easeFactor
            
            // Apply quality-based adjustments
            switch quality {
            case 3:
                // Hard - reduce interval slightly
                newInterval = Int(calculatedInterval * 0.8)
            case 4:
                // Good - use calculated interval
                newInterval = Int(calculatedInterval)
            case 5:
                // Easy - increase interval
                newInterval = Int(calculatedInterval * easyBonus)
            default:
                newInterval = Int(calculatedInterval)
            }
        }
        
        // Apply some randomization to prevent clustering
        newInterval = applyFuzzing(to: newInterval)
        
        // Ensure minimum interval of 1 day
        return max(1, newInterval)
    }
    
    // MARK: - Helper Methods
    
    /// Apply slight randomization to prevent review clustering
    private func applyFuzzing(to interval: Int) -> Int {
        guard interval > 2 else { return interval }
        
        let fuzzRange = max(1, interval / 10)
        let fuzz = Int.random(in: -fuzzRange...fuzzRange)
        
        return max(1, interval + fuzz)
    }
    
    /// Calculate retention probability based on interval and time elapsed
    func retentionProbability(interval: Int, daysSinceLastReview: Int, easeFactor: Double) -> Double {
        // Simplified forgetting curve model
        let stabilityFactor = easeFactor / 2.5
        let timeFactor = Double(daysSinceLastReview) / Double(interval)
        
        // Exponential decay model
        let retention = exp(-timeFactor / stabilityFactor)
        
        return max(0, min(1, retention))
    }
    
    /// Determine optimal review time based on current statistics
    func optimalReviewTime(for word: Word) -> Date {
        let baseInterval = word.interval
        
        // Calculate optimal time of day (morning is generally better for retention)
        let calendar = Calendar.current
        var components = DateComponents()
        components.day = baseInterval
        components.hour = 9 // 9 AM as optimal review time
        
        return calendar.date(byAdding: components, to: word.lastSeen) ?? Date()
    }
}

// MARK: - Review Quality Helper
extension SRSAlgorithm {
    
    /// Convert user response to quality rating
    static func qualityFromResponse(_ response: UserResponse) -> Int {
        switch response {
        case .forgot:
            return 1
        case .hard:
            return 3
        case .good:
            return 4
        case .easy:
            return 5
        }
    }
    
    enum UserResponse {
        case forgot
        case hard
        case good
        case easy
        
        var displayText: String {
            switch self {
            case .forgot:
                return "Quên"
            case .hard:
                return "Khó"
            case .good:
                return "Tốt"
            case .easy:
                return "Dễ"
            }
        }
        
        var color: String {
            switch self {
            case .forgot:
                return "red"
            case .hard:
                return "orange"
            case .good:
                return "blue"
            case .easy:
                return "green"
            }
        }
    }
}
