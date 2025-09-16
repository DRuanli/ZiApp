//
//  StatisticsView.swift
//  Zi
//
//  Statistics and analytics dashboard for premium users
//

import SwiftUI
import SwiftData
import Charts

struct StatisticsView: View {
    @StateObject private var viewModel = StatisticsViewModel()
    @State private var selectedTimeRange: TimeRange = .week
    @State private var selectedTab: StatTab = .overview
    
    enum TimeRange: String, CaseIterable {
        case week = "Week"
        case month = "Month"
        case year = "Year"
        case all = "All Time"
        
        var days: Int {
            switch self {
            case .week: return 7
            case .month: return 30
            case .year: return 365
            case .all: return 9999
            }
        }
    }
    
    enum StatTab: String, CaseIterable {
        case overview = "Overview"
        case progress = "Progress"
        case performance = "Performance"
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Time Range Picker
                    Picker("Time Range", selection: $selectedTimeRange) {
                        ForEach(TimeRange.allCases, id: \.self) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .onChange(of: selectedTimeRange) { _, newValue in
                        Task {
                            await viewModel.loadStats(for: newValue.days)
                        }
                    }
                    
                    // Tab Selection
                    Picker("Tab", selection: $selectedTab) {
                        ForEach(StatTab.allCases, id: \.self) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
                    // Content based on selected tab
                    Group {
                        switch selectedTab {
                        case .overview:
                            overviewContent
                        case .progress:
                            progressContent
                        case .performance:
                            performanceContent
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Statistics")
            .navigationBarTitleDisplayMode(.large)
            .task {
                await viewModel.loadStats(for: selectedTimeRange.days)
            }
        }
    }
    
    // MARK: - Overview Tab
    
    @ViewBuilder
    private var overviewContent: some View {
        VStack(spacing: 20) {
            // Summary Cards
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 15) {
                StatCard(
                    title: "Total Words",
                    value: "\(viewModel.totalWordsLearned)",
                    icon: "book.fill",
                    color: .blue
                )
                
                StatCard(
                    title: "Study Streak",
                    value: "\(viewModel.currentStreak) days",
                    icon: "flame.fill",
                    color: .orange
                )
                
                StatCard(
                    title: "Accuracy",
                    value: String(format: "%.0f%%", viewModel.averageAccuracy * 100),
                    icon: "target",
                    color: .green
                )
                
                StatCard(
                    title: "Study Time",
                    value: viewModel.formattedStudyTime,
                    icon: "clock.fill",
                    color: .purple
                )
            }
            .padding(.horizontal)
            
            // Daily Activity Chart
            if !viewModel.dailyStats.isEmpty {
                DailyActivityChart(data: viewModel.dailyStats)
                    .frame(height: 250)
                    .padding(.horizontal)
            }
            
            // Recent Sessions
            recentSessionsCard
        }
    }
    
    // MARK: - Progress Tab
    
    @ViewBuilder
    private var progressContent: some View {
        VStack(spacing: 20) {
            // HSK Progress
            HSKProgressCard(wordsByLevel: viewModel.wordsByLevel)
                .padding(.horizontal)
            
            // Learning Curve
            if !viewModel.dailyStats.isEmpty {
                LearningCurveChart(data: viewModel.dailyStats)
                    .frame(height: 250)
                    .padding(.horizontal)
            }
            
            // Milestones
            milestonesCard
        }
    }
    
    // MARK: - Performance Tab
    
    @ViewBuilder
    private var performanceContent: some View {
        VStack(spacing: 20) {
            // Performance Metrics
            performanceMetricsCard
            
            // Accuracy Trend
            if !viewModel.dailyStats.isEmpty {
                AccuracyTrendChart(data: viewModel.dailyStats)
                    .frame(height: 250)
                    .padding(.horizontal)
            }
            
            // Difficult Words
            difficultWordsCard
        }
    }
    
    // MARK: - Cards
    
    private var recentSessionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Sessions")
                .font(.headline)
                .padding(.horizontal)
            
            VStack(spacing: 0) {
                ForEach(viewModel.recentSessions.prefix(5)) { session in
                    SessionRow(session: session)
                    
                    if session.id != viewModel.recentSessions.prefix(5).last?.id {
                        Divider()
                            .padding(.leading, 50)
                    }
                }
            }
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }
    
    private var milestonesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Milestones")
                .font(.headline)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                MilestoneRow(
                    icon: "star.fill",
                    title: "First 100 Words",
                    subtitle: "Learn your first 100 words",
                    progress: min(1.0, Double(viewModel.totalWordsLearned) / 100),
                    isCompleted: viewModel.totalWordsLearned >= 100
                )
                
                MilestoneRow(
                    icon: "flame.fill",
                    title: "7 Day Streak",
                    subtitle: "Study for 7 days in a row",
                    progress: min(1.0, Double(viewModel.currentStreak) / 7),
                    isCompleted: viewModel.currentStreak >= 7
                )
                
                MilestoneRow(
                    icon: "trophy.fill",
                    title: "HSK 1 Master",
                    subtitle: "Master all HSK 1 words",
                    progress: viewModel.hsk1Progress,
                    isCompleted: viewModel.hsk1Progress >= 1.0
                )
                
                MilestoneRow(
                    icon: "graduationcap.fill",
                    title: "1000 Words",
                    subtitle: "Learn 1000 words total",
                    progress: min(1.0, Double(viewModel.totalWordsLearned) / 1000),
                    isCompleted: viewModel.totalWordsLearned >= 1000
                )
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }
    
    private var performanceMetricsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Performance Metrics")
                .font(.headline)
                .padding(.horizontal)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                MetricCard(
                    label: "Avg Response Time",
                    value: String(format: "%.1fs", viewModel.averageResponseTime),
                    trend: .neutral
                )
                
                MetricCard(
                    label: "Words/Session",
                    value: "\(viewModel.averageWordsPerSession)",
                    trend: .up
                )
                
                MetricCard(
                    label: "Retention Rate",
                    value: String(format: "%.0f%%", viewModel.retentionRate * 100),
                    trend: viewModel.retentionTrend
                )
                
                MetricCard(
                    label: "Mastery Rate",
                    value: String(format: "%.0f%%", viewModel.masteryRate * 100),
                    trend: .up
                )
            }
            .padding(.horizontal)
        }
    }
    
    private var difficultWordsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Most Difficult Words")
                    .font(.headline)
                
                Spacer()
                
                Button("View All") {
                    // Navigate to difficult words list
                }
                .font(.caption)
            }
            .padding(.horizontal)
            
            VStack(spacing: 0) {
                ForEach(viewModel.difficultWords.prefix(5)) { word in
                    DifficultWordRow(word: word)
                    
                    if word.id != viewModel.difficultWords.prefix(5).last?.id {
                        Divider()
                            .padding(.leading, 20)
                    }
                }
            }
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
            }
            
            Text(value)
                .font(.title2)
                .bold()
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct DailyActivityChart: View {
    let data: [DailyStats]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Daily Activity")
                .font(.headline)
            
            Chart(data) { stat in
                BarMark(
                    x: .value("Date", stat.date, unit: .day),
                    y: .value("Words", stat.totalReviews)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .cornerRadius(4)
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct LearningCurveChart: View {
    let data: [DailyStats]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Learning Progress")
                .font(.headline)
            
            Chart(data) { stat in
                LineMark(
                    x: .value("Date", stat.date, unit: .day),
                    y: .value("Cumulative", stat.cumulativeWords)
                )
                .foregroundStyle(Color.blue)
                .interpolationMethod(.catmullRom)
                
                AreaMark(
                    x: .value("Date", stat.date, unit: .day),
                    y: .value("Cumulative", stat.cumulativeWords)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.blue.opacity(0.3), Color.blue.opacity(0.1)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct AccuracyTrendChart: View {
    let data: [DailyStats]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Accuracy Trend")
                .font(.headline)
            
            Chart(data) { stat in
                LineMark(
                    x: .value("Date", stat.date, unit: .day),
                    y: .value("Accuracy", stat.accuracy * 100)
                )
                .foregroundStyle(Color.green)
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 2))
                
                PointMark(
                    x: .value("Date", stat.date, unit: .day),
                    y: .value("Accuracy", stat.accuracy * 100)
                )
                .foregroundStyle(Color.green)
            }
            .chartYScale(domain: 0...100)
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisValueLabel {
                        if let intValue = value.as(Int.self) {
                            Text("\(intValue)%")
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct HSKProgressCard: View {
    let wordsByLevel: [Int: Int]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("HSK Level Progress")
                .font(.headline)
            
            VStack(spacing: 8) {
                ForEach(1...6, id: \.self) { level in
                    HSKLevelProgress(
                        level: level,
                        learned: wordsByLevel[level] ?? 0,
                        total: totalWordsForLevel(level)
                    )
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private func totalWordsForLevel(_ level: Int) -> Int {
        // Approximate HSK word counts
        switch level {
        case 1: return 150
        case 2: return 150
        case 3: return 300
        case 4: return 600
        case 5: return 1300
        case 6: return 2500
        default: return 0
        }
    }
}

struct HSKLevelProgress: View {
    let level: Int
    let learned: Int
    let total: Int
    
    private var progress: Double {
        guard total > 0 else { return 0 }
        return Double(learned) / Double(total)
    }
    
    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text("HSK \(level)")
                    .font(.caption)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text("\(learned)/\(total)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(UIColor.tertiarySystemBackground))
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [colorForLevel(level), colorForLevel(level).opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * progress)
                }
            }
            .frame(height: 8)
        }
    }
    
    private func colorForLevel(_ level: Int) -> Color {
        switch level {
        case 1: return .green
        case 2: return .blue
        case 3: return .purple
        case 4: return .orange
        case 5: return .red
        case 6: return .pink
        default: return .gray
        }
    }
}

struct SessionRow: View {
    let session: LearningSession
    
    var body: some View {
        HStack {
            Circle()
                .fill(Color.blue)
                .frame(width: 8, height: 8)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(session.startDate.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline)
                
                HStack {
                    Text("\(session.wordsReviewed) words")
                    Text("•")
                    Text(String(format: "%.0f%% accuracy", session.accuracyRate * 100))
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(session.formattedDuration)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

struct MilestoneRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let progress: Double
    let isCompleted: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(isCompleted ? .yellow : .gray)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(UIColor.tertiarySystemBackground))
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(isCompleted ? Color.yellow : Color.blue)
                            .frame(width: geometry.size.width * progress)
                    }
                }
                .frame(height: 4)
            }
            
            if isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
        }
    }
}

struct MetricCard: View {
    let label: String
    let value: String
    let trend: Trend
    
    enum Trend {
        case up, down, neutral
        
        var icon: String {
            switch self {
            case .up: return "arrow.up.right"
            case .down: return "arrow.down.right"
            case .neutral: return "minus"
            }
        }
        
        var color: Color {
            switch self {
            case .up: return .green
            case .down: return .red
            case .neutral: return .gray
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Image(systemName: trend.icon)
                    .font(.caption)
                    .foregroundColor(trend.color)
            }
            
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
        }
        .padding()
        .background(Color(UIColor.tertiarySystemBackground))
        .cornerRadius(8)
    }
}

struct DifficultWordRow: View {
    let word: Word
    
    var body: some View {
        HStack {
            Text(word.hanzi)
                .font(.title3)
            
            VStack(alignment: .leading) {
                Text(word.pinyin)
                    .font(.caption)
                Text(word.meaning)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text("\(word.timesIncorrect) misses")
                    .font(.caption)
                    .foregroundColor(.red)
                
                Text(String(format: "%.0f%%", word.accuracyRate * 100))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}

// MARK: - View Model

@MainActor
class StatisticsViewModel: ObservableObject {
    @Published var dailyStats: [DailyStats] = []
    @Published var recentSessions: [LearningSession] = []
    @Published var totalWordsLearned: Int = 0
    @Published var currentStreak: Int = 0
    @Published var averageAccuracy: Double = 0
    @Published var totalStudyTime: TimeInterval = 0
    @Published var wordsByLevel: [Int: Int] = [:]
    @Published var difficultWords: [Word] = []
    @Published var averageResponseTime: Double = 3.5
    @Published var averageWordsPerSession: Int = 18
    @Published var retentionRate: Double = 0.75
    @Published var retentionTrend: MetricCard.Trend = .up
    @Published var masteryRate: Double = 0.45
    @Published var hsk1Progress: Double = 0.6
    
    var formattedStudyTime: String {
        let hours = Int(totalStudyTime) / 3600
        let minutes = (Int(totalStudyTime) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    func loadStats(for days: Int) async {
        do {
            // Load daily stats
            dailyStats = try await DataService.shared.getDailyReviewStats(for: days)
            
            // Add cumulative count
            var cumulative = 0
            for i in 0..<dailyStats.count {
                cumulative += dailyStats[i].totalReviews
                dailyStats[i].cumulativeWords = cumulative
            }
            
            // Load progress summary
            let progress = try await DataService.shared.getLearningProgress()
            totalWordsLearned = progress.totalWordsLearned
            currentStreak = progress.currentStreak
            averageAccuracy = progress.averageAccuracy
            totalStudyTime = progress.totalStudyTime
            wordsByLevel = progress.wordsByLevel
            
            // Load recent sessions
            loadRecentSessions()
            
            // Load difficult words
            loadDifficultWords()
            
        } catch {
            Logger.shared.error("Failed to load statistics: \(error)")
        }
    }
    
    private func loadRecentSessions() {
        // Fetch recent sessions from database
        // This is a simplified version
        let context = SwiftDataContainer.shared.mainContext
        let descriptor = FetchDescriptor<LearningSession>(
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        
        do {
            recentSessions = try context.fetch(descriptor)
        } catch {
            Logger.shared.error("Failed to load sessions: \(error)")
        }
    }
    
    private func loadDifficultWords() {
        // Fetch words with low accuracy
        let context = SwiftDataContainer.shared.mainContext
        let descriptor = FetchDescriptor<Word>(
            predicate: #Predicate<Word> { word in
                word.timesSeen > 3 && word.timesIncorrect > word.timesCorrect
            },
            sortBy: [SortDescriptor(\.timesIncorrect, order: .reverse)]
        )
        
        do {
            difficultWords = try context.fetch(descriptor)
        } catch {
            Logger.shared.error("Failed to load difficult words: \(error)")
        }
    }
}

// Extension to DailyStats
extension DailyStats {
    var cumulativeWords: Int {
        get { 0 } // Default value
        set { } // Allow setting for cumulative calculation
    }
}
