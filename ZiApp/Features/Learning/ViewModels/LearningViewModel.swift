//
//  LearningViewModel.swift
//  Zi
//
//  ViewModel for learning view - manages learning session logic
//

import Foundation
import SwiftUI
import SwiftData

@MainActor
class LearningViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var currentWord: Word?
    @Published var sessionWords: [Word] = []
    @Published var currentIndex: Int = 0
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showSessionComplete: Bool = false
    @Published var showPremiumPrompt: Bool = false
    
    // Card states
    @Published var cardOffset: CGSize = .zero
    @Published var cardRotation: Double = 0
    @Published var showingAnswer: Bool = false
    @Published var isFlipped: Bool = false
    
    // Session statistics
    @Published var correctCount: Int = 0
    @Published var incorrectCount: Int = 0
    @Published var sessionProgress: Double = 0
    
    // MARK: - Private Properties
    private let dataService = DataService.shared
    private let hapticService = HapticService.shared
    private let audioService = AudioService.shared
    private var currentSession: LearningSession?
    private var responseStartTime: Date = Date()
    private var settings: UserSettings?
    
    // Swipe thresholds
    private let swipeThreshold: CGFloat = Constants.UI.cardSwipeThreshold
    private let rotationMultiplier: Double = Constants.UI.cardRotationAngle / 100
    
    // MARK: - Initialization
    
    init() {
        Task {
            await loadSettings()
            await startNewSession()
        }
    }
    
    // MARK: - Public Methods
    
    /// Start a new learning session
    func startNewSession() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Load user settings
            await loadSettings()
            
            guard let settings = settings else {
                throw AppError.settingsNotFound
            }
            
            // Check daily limit for free users
            if !settings.isPremium && hasReachedDailyLimit() {
                showPremiumPrompt = true
                isLoading = false
                return
            }
            
            // Fetch words for session
            let words = try await dataService.fetchWordsForSession(
                levels: settings.selectedHSKLevels,
                isPremium: settings.isPremium,
                dailyLimit: settings.sessionLength
            )
            
            if words.isEmpty {
                errorMessage = "No words available for selected HSK levels"
                isLoading = false
                return
            }
            
            // Create new session
            currentSession = dataService.startLearningSession(
                type: "learning",
                goal: min(words.count, settings.sessionLength),
                levels: settings.selectedHSKLevels
            )
            
            // Set up session
            sessionWords = words
            currentIndex = 0
            correctCount = 0
            incorrectCount = 0
            showSessionComplete = false
            
            // Load first word
            loadCurrentWord()
            
        } catch {
            errorMessage = "Failed to start session: \(error.localizedDescription)"
            Logger.shared.error("Failed to start session: \(error)")
        }
        
        isLoading = false
    }
    
    /// Handle swipe gesture
    func handleSwipe(translation: CGSize) {
        cardOffset = translation
        cardRotation = Double(translation.width) * rotationMultiplier / 100
    }
    
    /// Handle swipe end
    func handleSwipeEnd(translation: CGSize, predictedEndTranslation: CGSize) {
        let shouldSwipe = abs(translation.width) > swipeThreshold ||
                         abs(predictedEndTranslation.width) > swipeThreshold * 2
        
        if shouldSwipe {
            let isCorrect = translation.width > 0
            completeCard(wasCorrect: isCorrect)
        } else {
            // Snap back to center
            withAnimation(.spring()) {
                cardOffset = .zero
                cardRotation = 0
            }
        }
    }
    
    /// Handle tap on card (show pinyin/flip card)
    func handleCardTap() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isFlipped.toggle()
        }
        
        // Play audio if premium
        if settings?.isPremium == true {
            playAudio()
        }
        
        hapticService.impact(.light)
    }
    
    /// Mark current word as known/unknown
    func markWord(asKnown: Bool) {
        completeCard(wasCorrect: asKnown)
    }
    
    /// Play audio for current word
    func playAudio() {
        guard let word = currentWord,
              let audioFileName = word.audioFileName,
              settings?.isPremium == true else {
            return
        }
        
        audioService.playPronunciation(filename: audioFileName)
    }
    
    /// Reset current card position
    func resetCard() {
        withAnimation(.spring()) {
            cardOffset = .zero
            cardRotation = 0
            isFlipped = false
        }
    }
    
    /// Skip to next word without marking
    func skipWord() {
        moveToNextWord()
    }
    
    // MARK: - Private Methods
    
    private func loadSettings() async {
        let context = SwiftDataContainer.shared.mainContext
        settings = UserSettings.getOrCreate(in: context)
    }
    
    private func loadCurrentWord() {
        guard currentIndex < sessionWords.count else {
            completeSession()
            return
        }
        
        currentWord = sessionWords[currentIndex]
        responseStartTime = Date()
        isFlipped = false
        updateProgress()
        
        // Reset card position
        resetCard()
    }
    
    private func completeCard(wasCorrect: Bool) {
        guard let word = currentWord else { return }
        
        // Calculate response time
        let responseTime = Date().timeIntervalSince(responseStartTime)
        
        // Animate card off screen
        let offscreenOffset = wasCorrect ? CGSize(width: 500, height: 0) : CGSize(width: -500, height: 0)
        
        withAnimation(.easeOut(duration: 0.3)) {
            cardOffset = offscreenOffset
            cardRotation = wasCorrect ? 30 : -30
        }
        
        // Update statistics
        if wasCorrect {
            correctCount += 1
        } else {
            incorrectCount += 1
        }
        
        // Record review
        Task {
            do {
                try await dataService.recordReview(
                    for: word,
                    wasCorrect: wasCorrect,
                    responseTime: responseTime,
                    session: currentSession
                )
            } catch {
                Logger.shared.error("Failed to record review: \(error)")
            }
        }
        
        // Haptic feedback
        hapticService.notification(wasCorrect ? .success : .warning)
        
        // Move to next word after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.moveToNextWord()
        }
    }
    
    private func moveToNextWord() {
        currentIndex += 1
        
        if currentIndex < sessionWords.count {
            loadCurrentWord()
        } else {
            completeSession()
        }
    }
    
    private func completeSession() {
        guard let session = currentSession else { return }
        
        // Complete the session
        dataService.completeSession(session)
        
        // Show completion
        showSessionComplete = true
        
        // Haptic feedback
        hapticService.notification(.success)
        
        Logger.shared.info("Session completed: \(correctCount) correct, \(incorrectCount) incorrect")
    }
    
    private func updateProgress() {
        let total = sessionWords.count
        guard total > 0 else {
            sessionProgress = 0
            return
        }
        
        sessionProgress = Double(currentIndex) / Double(total)
    }
    
    private func hasReachedDailyLimit() -> Bool {
        // Check if free user has reached daily limit
        guard let settings = settings, !settings.isPremium else {
            return false
        }
        
        // Check today's review count
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // This would need to be implemented with actual review count check
        // For now, return false
        return false
    }
    
    // MARK: - Computed Properties
    
    var progressText: String {
        "\(currentIndex + 1) / \(sessionWords.count)"
    }
    
    var accuracyRate: Double {
        let total = correctCount + incorrectCount
        guard total > 0 else { return 0 }
        return Double(correctCount) / Double(total)
    }
    
    var sessionSummary: SessionSummary {
        SessionSummary(
            totalWords: sessionWords.count,
            correctCount: correctCount,
            incorrectCount: incorrectCount,
            accuracy: accuracyRate,
            duration: currentSession?.duration ?? 0
        )
    }
    
    var cardBackgroundColor: Color {
        if abs(cardOffset.width) < 20 {
            return Color(UIColor.systemBackground)
        }
        
        return cardOffset.width > 0
            ? Color.green.opacity(Double(abs(cardOffset.width)) / 200)
            : Color.red.opacity(Double(abs(cardOffset.width)) / 200)
    }
}

// MARK: - Supporting Types

struct SessionSummary {
    let totalWords: Int
    let correctCount: Int
    let incorrectCount: Int
    let accuracy: Double
    let duration: TimeInterval
    
    var formattedDuration: String {
        let minutes = Int(duration / 60)
        let seconds = Int(duration.truncatingRemainder(dividingBy: 60))
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    var formattedAccuracy: String {
        String(format: "%.0f%%", accuracy * 100)
    }
}

enum AppError: LocalizedError {
    case settingsNotFound
    case noWordsAvailable
    case sessionNotFound
    
    var errorDescription: String? {
        switch self {
        case .settingsNotFound:
            return "User settings not found"
        case .noWordsAvailable:
            return "No words available for selected levels"
        case .sessionNotFound:
            return "Learning session not found"
        }
    }
}

// MARK: - Mock Services (Temporary)

class HapticService {
    static let shared = HapticService()
    
    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }
    
    func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
    }
}

class AudioService {
    static let shared = AudioService()
    
    func playPronunciation(filename: String) {
        // TODO: Implement audio playback
        Logger.shared.debug("Playing audio: \(filename)")
    }
}
