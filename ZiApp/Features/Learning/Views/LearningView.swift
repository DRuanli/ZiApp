//
//  LearningView.swift
//  Zi
//
//  Main learning interface with swipeable cards
//

import SwiftUI
import SwiftData

struct LearningView: View {
    @StateObject private var viewModel = LearningViewModel()
    @State private var showingSettings = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [
                        Color(UIColor.systemBackground),
                        Color(UIColor.secondarySystemBackground)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                if viewModel.isLoading {
                    LoadingView()
                } else if let error = viewModel.errorMessage {
                    ErrorView(message: error) {
                        Task { await viewModel.startNewSession() }
                    }
                } else if viewModel.showSessionComplete {
                    SessionCompleteView(
                        summary: viewModel.sessionSummary,
                        onContinue: {
                            Task { await viewModel.startNewSession() }
                        }
                    )
                } else if viewModel.showPremiumPrompt {
                    DailyLimitReachedView()
                } else if let word = viewModel.currentWord {
                    VStack(spacing: 20) {
                        // Progress bar
                        ProgressHeader(
                            progress: viewModel.sessionProgress,
                            progressText: viewModel.progressText,
                            correctCount: viewModel.correctCount,
                            incorrectCount: viewModel.incorrectCount
                        )
                        
                        // Word card
                        WordCardView(
                            word: word,
                            isFlipped: $viewModel.isFlipped,
                            cardOffset: viewModel.cardOffset,
                            cardRotation: viewModel.cardRotation,
                            backgroundColor: viewModel.cardBackgroundColor
                        )
                        .onTapGesture {
                            viewModel.handleCardTap()
                        }
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    viewModel.handleSwipe(translation: value.translation)
                                }
                                .onEnded { value in
                                    viewModel.handleSwipeEnd(
                                        translation: value.translation,
                                        predictedEndTranslation: value.predictedEndTranslation
                                    )
                                }
                        )
                        
                        // Action buttons
                        ActionButtons(
                            onUnknown: { viewModel.markWord(asKnown: false) },
                            onKnown: { viewModel.markWord(asKnown: true) },
                            onAudio: { viewModel.playAudio() },
                            isPremium: viewModel.settings?.isPremium ?? false
                        )
                    }
                    .padding()
                } else {
                    EmptyStateView()
                }
            }
            .navigationTitle("学习")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
        }
    }
}

// MARK: - Word Card View

struct WordCardView: View {
    let word: Word
    @Binding var isFlipped: Bool
    let cardOffset: CGSize
    let cardRotation: Double
    let backgroundColor: Color
    
    @State private var flipRotation: Double = 0
    
    var body: some View {
        ZStack {
            // Card background
            RoundedRectangle(cornerRadius: Constants.UI.cardCornerRadius)
                .fill(backgroundColor)
                .shadow(
                    color: Color.black.opacity(0.1),
                    radius: 10,
                    x: 0,
                    y: 5
                )
            
            // Card content
            VStack(spacing: 30) {
                if !isFlipped {
                    // Front side - Chinese character
                    Text(word.hanzi)
                        .font(.system(size: 80, weight: .medium))
                        .foregroundColor(.primary)
                    
                    if word.exampleSentence != nil {
                        Image(systemName: "quote.bubble")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                } else {
                    // Back side - Details
                    VStack(spacing: 20) {
                        Text(word.hanzi)
                            .font(.system(size: 60, weight: .medium))
                        
                        Text(word.pinyin)
                            .font(.system(size: 24))
                            .foregroundColor(.secondary)
                        
                        Text(word.meaning)
                            .font(.title2)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.primary)
                        
                        if let example = word.exampleSentence {
                            VStack(spacing: 8) {
                                Text(example)
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                
                                if let translation = word.exampleTranslation {
                                    Text(translation)
                                        .font(.caption)
                                        .foregroundColor(.tertiary)
                                }
                            }
                            .padding()
                            .background(Color(UIColor.tertiarySystemBackground))
                            .cornerRadius(10)
                        }
                        
                        HStack {
                            Label("HSK \(word.hskLevel)", systemImage: "book.circle")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding(30)
            .rotation3DEffect(
                .degrees(flipRotation),
                axis: (x: 0, y: 1, z: 0)
            )
        }
        .frame(maxWidth: .infinity, maxHeight: 500)
        .offset(cardOffset)
        .rotationEffect(.degrees(cardRotation))
        .animation(.spring(), value: cardOffset)
        .onChange(of: isFlipped) { _, newValue in
            withAnimation(.easeInOut(duration: 0.3)) {
                flipRotation = newValue ? 180 : 0
            }
        }
    }
}

// MARK: - Progress Header

struct ProgressHeader: View {
    let progress: Double
    let progressText: String
    let correctCount: Int
    let incorrectCount: Int
    
    var body: some View {
        VStack(spacing: 12) {
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(UIColor.systemGray5))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 10)
                        .fill(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * progress, height: 8)
                        .animation(.spring(), value: progress)
                }
            }
            .frame(height: 8)
            
            // Stats
            HStack {
                Text(progressText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                HStack(spacing: 15) {
                    Label("\(correctCount)", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    
                    Label("\(incorrectCount)", systemImage: "xmark.circle.fill")
                        .foregroundColor(.red)
                }
                .font(.caption)
            }
        }
    }
}

// MARK: - Action Buttons

struct ActionButtons: View {
    let onUnknown: () -> Void
    let onKnown: () -> Void
    let onAudio: () -> Void
    let isPremium: Bool
    
    var body: some View {
        HStack(spacing: 30) {
            // Unknown button
            Button(action: onUnknown) {
                VStack(spacing: 8) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.red)
                    
                    Text("不知道")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Audio button (Premium only)
            if isPremium {
                Button(action: onAudio) {
                    VStack(spacing: 8) {
                        Image(systemName: "speaker.wave.2.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.blue)
                        
                        Text("发音")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Known button
            Button(action: onKnown) {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.green)
                    
                    Text("知道")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.top, 20)
    }
}

// MARK: - Session Complete View

struct SessionCompleteView: View {
    let summary: SessionSummary
    let onContinue: () -> Void
    
    var body: some View {
        VStack(spacing: 30) {
            // Celebration icon
            Image(systemName: "star.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.yellow)
            
            Text("Session Complete!")
                .font(.largeTitle)
                .bold()
            
            // Statistics
            VStack(spacing: 20) {
                StatRow(
                    icon: "clock",
                    label: "Duration",
                    value: summary.formattedDuration
                )
                
                StatRow(
                    icon: "book",
                    label: "Words Reviewed",
                    value: "\(summary.totalWords)"
                )
                
                StatRow(
                    icon: "percent",
                    label: "Accuracy",
                    value: summary.formattedAccuracy,
                    color: accuracyColor(summary.accuracy)
                )
                
                HStack(spacing: 30) {
                    VStack {
                        Image(systemName: "checkmark.circle")
                            .font(.title)
                            .foregroundColor(.green)
                        Text("\(summary.correctCount)")
                            .font(.title2)
                            .bold()
                        Text("Correct")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack {
                        Image(systemName: "xmark.circle")
                            .font(.title)
                            .foregroundColor(.red)
                        Text("\(summary.incorrectCount)")
                            .font(.title2)
                            .bold()
                        Text("Incorrect")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(15)
            
            // Continue button
            Button(action: onContinue) {
                Text("Continue Learning")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(Constants.UI.buttonCornerRadius)
            }
        }
        .padding()
    }
    
    private func accuracyColor(_ accuracy: Double) -> Color {
        switch accuracy {
        case 0.8...1.0:
            return .green
        case 0.6..<0.8:
            return .orange
        default:
            return .red
        }
    }
}

struct StatRow: View {
    let icon: String
    let label: String
    let value: String
    var color: Color = .primary
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.secondary)
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .bold()
                .foregroundColor(color)
        }
    }
}

// MARK: - Supporting Views

struct LoadingView: View {
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading words...")
                .foregroundColor(.secondary)
        }
    }
}

struct ErrorView: View {
    let message: String
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            Text("Oops!")
                .font(.title)
                .bold()
            
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            Button(action: onRetry) {
                Text("Try Again")
                    .foregroundColor(.white)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(Constants.UI.buttonCornerRadius)
            }
        }
        .padding()
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "books.vertical")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Words Available")
                .font(.title2)
                .bold()
            
            Text("Please select HSK levels in Settings")
                .foregroundColor(.secondary)
        }
    }
}

struct DailyLimitReachedView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "lock.circle")
                .font(.system(size: 80))
                .foregroundColor(.orange)
            
            Text("Daily Limit Reached")
                .font(.largeTitle)
                .bold()
            
            Text("You've reached your daily limit of 20 words.\nUpgrade to Premium for unlimited learning!")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            Button(action: { appState.showPremiumModal = true }) {
                Text("Upgrade to Premium")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(Constants.UI.buttonCornerRadius)
            }
            .padding(.horizontal)
        }
        .padding()
    }
}
