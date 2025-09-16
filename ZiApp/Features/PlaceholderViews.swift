//
//  PlaceholderViews.swift
//  ZiApp
//
//  Temporary views for testing the app structure
//

import SwiftUI
import SwiftData

// MARK: - Learning View
struct LearningView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Word.id) private var words: [Word]
    
    var body: some View {
        NavigationView {
            VStack {
                Text("学习")
                    .font(.largeTitle)
                    .padding()
                
                Text("Total words: \(words.count)")
                    .font(.headline)
                
                if let firstWord = words.first {
                    VStack(spacing: 20) {
                        Text(firstWord.hanzi)
                            .font(.system(size: 60))
                        
                        Text(firstWord.pinyin)
                            .font(.title2)
                        
                        Text(firstWord.meaning)
                            .font(.title3)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(20)
                    .padding()
                }
                
                Spacer()
            }
            .navigationTitle("Learn")
        }
    }
}

// MARK: - Settings View
struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var purchaseManager: PurchaseManager
    
    var body: some View {
        NavigationView {
            List {
                Section("Account") {
                    HStack {
                        Text("Status")
                        Spacer()
                        Text(purchaseManager.isPremium ? "Premium" : "Free")
                            .foregroundColor(purchaseManager.isPremium ? .green : .gray)
                    }
                    
                    if !purchaseManager.isPremium {
                        Button("Upgrade to Premium") {
                            // Show upgrade modal
                        }
                        .foregroundColor(.blue)
                    }
                }
                
                Section("Learning") {
                    HStack {
                        Text("HSK Levels")
                        Spacer()
                        Text("1, 2")
                    }
                    
                    HStack {
                        Text("Daily Goal")
                        Spacer()
                        Text("20 words")
                    }
                }
                
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(AppInfo.version)
                            .foregroundColor(.gray)
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}

// MARK: - Statistics View
struct StatisticsView: View {
    var body: some View {
        NavigationView {
            VStack {
                Text("📊")
                    .font(.system(size: 60))
                    .padding()
                
                Text("Statistics")
                    .font(.largeTitle)
                
                Text("Premium Feature")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                Spacer()
            }
            .navigationTitle("Statistics")
        }
    }
}

// MARK: - Onboarding View
struct OnboardingView: View {
    @Binding var isPresented: Bool
    @State private var currentPage = 0
    
    var body: some View {
        VStack {
            TabView(selection: $currentPage) {
                // Page 1
                VStack(spacing: 20) {
                    Text("欢迎")
                        .font(.system(size: 60))
                    
                    Text("Welcome to Zi")
                        .font(.largeTitle)
                        .bold()
                    
                    Text("Learn Chinese characters the smart way")
                        .font(.title3)
                        .foregroundColor(.gray)
                }
                .tag(0)
                
                // Page 2
                VStack(spacing: 20) {
                    Text("👈 👉")
                        .font(.system(size: 60))
                    
                    Text("Swipe to Learn")
                        .font(.largeTitle)
                        .bold()
                    
                    Text("Swipe left if you don't know\nSwipe right if you know")
                        .font(.title3)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .tag(1)
                
                // Page 3
                VStack(spacing: 20) {
                    Text("🚀")
                        .font(.system(size: 60))
                    
                    Text("Let's Start!")
                        .font(.largeTitle)
                        .bold()
                    
                    Button(action: {
                        isPresented = false
                    }) {
                        Text("Begin Learning")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 40)
                }
                .tag(2)
            }
            .tabViewStyle(PageTabViewStyle())
            .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
        }
    }
}

// MARK: - Premium Upgrade View
struct PremiumUpgradeView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Text("🌟")
                    .font(.system(size: 80))
                
                Text("Upgrade to Premium")
                    .font(.largeTitle)
                    .bold()
                
                VStack(alignment: .leading, spacing: 15) {
                    FeatureRow(icon: "checkmark.circle.fill", text: "All HSK Levels (1-6)")
                    FeatureRow(icon: "checkmark.circle.fill", text: "Smart SRS Algorithm")
                    FeatureRow(icon: "checkmark.circle.fill", text: "Audio Pronunciation")
                    FeatureRow(icon: "checkmark.circle.fill", text: "Example Sentences")
                    FeatureRow(icon: "checkmark.circle.fill", text: "Progress Statistics")
                }
                .padding(.horizontal, 40)
                
                VStack(spacing: 15) {
                    PriceButton(title: "Monthly", price: "$2.99/month", isPopular: false)
                    PriceButton(title: "Yearly", price: "$19.99/year", isPopular: true)
                    PriceButton(title: "Lifetime", price: "$49.99", isPopular: false)
                }
                .padding(.horizontal, 20)
                
                Spacer()
            }
            .navigationBarItems(trailing: Button("Close") { dismiss() })
        }
    }
    
    struct FeatureRow: View {
        let icon: String
        let text: String
        
        var body: some View {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.green)
                Text(text)
                    .font(.body)
            }
        }
    }
    
    struct PriceButton: View {
        let title: String
        let price: String
        let isPopular: Bool
        
        var body: some View {
            VStack {
                if isPopular {
                    Text("MOST POPULAR")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.orange)
                        .cornerRadius(4)
                }
                
                HStack {
                    VStack(alignment: .leading) {
                        Text(title)
                            .font(.headline)
                        Text(price)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
            }
        }
    }
}

// MARK: - Temporary Purchase Manager
class PurchaseManager: ObservableObject {
    static let shared = PurchaseManager()
    
    @Published var isPremium = false
    
    func initialize() async {
        // Temporary implementation
        print("PurchaseManager initialized")
    }
}

// MARK: - Temporary Notification Manager
struct NotificationManager {
    static let shared = NotificationManager()
    
    func scheduleDaily(at time: Date) {
        print("Scheduling notification at \(time)")
    }
}
