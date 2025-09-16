//
//  SwiftDataContainer.swift
//  ZiApp
//
//  SwiftData container configuration and management
//

import Foundation
import SwiftData
import SwiftUI

@MainActor
class SwiftDataContainer: ObservableObject {
    static let shared = SwiftDataContainer()
    
    let container: ModelContainer
    let mainContext: ModelContext
    
    // Background context for heavy operations
    private let backgroundQueue = DispatchQueue(label: "com.zi.database", qos: .background)
    
    private init() {
        // Define schema
        let schema = Schema([
            Word.self,
            UserSettings.self,
            LearningSession.self,
            ReviewRecord.self
        ])
        
        // Configure model
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true,
            groupContainer: .automatic,
            cloudKitDatabase: .none // Offline only for v1.0
        )
        
        do {
            // Initialize container
            container = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
            
            // Create main context
            mainContext = ModelContext(container)
            mainContext.autosaveEnabled = true
            
            // Perform initial setup
            Task { @MainActor in
                await setupInitialData()
            }
            
        } catch {
            fatalError("Failed to initialize SwiftData container: \(error)")
        }
    }
    
    // MARK: - Context Creation
    
    func createBackgroundContext() -> ModelContext {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        return context
    }
    
    // MARK: - Save Operations
    
    func save(context: ModelContext? = nil) {
        let contextToSave = context ?? mainContext
        
        do {
            if contextToSave.hasChanges {
                try contextToSave.save()
                Logger.shared.info("Database saved successfully")
            }
        } catch {
            Logger.shared.error("Failed to save context: \(error)")
        }
    }
    
    // MARK: - Initial Data Setup
    
    @MainActor
    private func setupInitialData() async {
        // Check if data already exists
        let descriptor = FetchDescriptor<Word>(
            predicate: nil,
            sortBy: [SortDescriptor(\.id)]
        )
        
        do {
            let existingWords = try mainContext.fetch(descriptor)
            
            if existingWords.isEmpty {
                Logger.shared.info("No existing data found. Importing initial vocabulary...")
                await importInitialVocabulary()
            } else {
                Logger.shared.info("Found \(existingWords.count) existing words")
                await checkForDataUpdates()
            }
            
            // Ensure UserSettings exists
            _ = UserSettings.getOrCreate(in: mainContext)
            save()
            
        } catch {
            Logger.shared.error("Failed to fetch existing data: \(error)")
        }
    }
    
    // MARK: - Data Import
    
    @MainActor
    private func importInitialVocabulary() async {
        guard let url = Bundle.main.url(forResource: "vocabulary_v1.2", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            Logger.shared.error("Failed to load vocabulary JSON file")
            return
        }
        
        do {
            let decoder = JSONDecoder()
            let vocabularyItems = try decoder.decode([VocabularyItem].self, from: data)
            
            Logger.shared.info("Importing \(vocabularyItems.count) words...")
            
            // Use background context for bulk import
            await withTaskGroup(of: Void.self) { group in
                for item in vocabularyItems {
                    group.addTask { @MainActor in
                        let word = Word(
                            id: item.id,
                            hanzi: item.hanzi,
                            pinyin: item.pinyin,
                            meaning: item.meaning,
                            hskLevel: item.hskLevel,
                            exampleSentence: item.exampleSentence,
                            exampleTranslation: item.exampleTranslation,
                            audioFileName: item.audioFileName
                        )
                        self.mainContext.insert(word)
                    }
                }
            }
            
            save()
            Logger.shared.info("Successfully imported vocabulary")
            
        } catch {
            Logger.shared.error("Failed to decode vocabulary JSON: \(error)")
        }
    }
    
    // MARK: - Data Updates
    
    @MainActor
    private func checkForDataUpdates() async {
        // Check if newer version is available
        let settings = UserSettings.getOrCreate(in: mainContext)
        let currentVersion = settings.dataVersion
        let bundledVersion = "1.2" // This should come from a config file
        
        if currentVersion < bundledVersion {
            Logger.shared.info("Data update available: \(currentVersion) -> \(bundledVersion)")
            await performDataMigration(from: currentVersion, to: bundledVersion)
        }
    }
    
    @MainActor
    private func performDataMigration(from oldVersion: String, to newVersion: String) async {
        // Implement migration logic based on version differences
        // For now, just update the version
        let settings = UserSettings.getOrCreate(in: mainContext)
        settings.dataVersion = newVersion
        save()
        
        Logger.shared.info("Data migrated from \(oldVersion) to \(newVersion)")
    }
    
    // MARK: - Batch Operations
    
    @MainActor
    func batchUpdate<T: PersistentModel>(_ type: T.Type, updates: @escaping (T) -> Void) async throws {
        let descriptor = FetchDescriptor<T>()
        let items = try mainContext.fetch(descriptor)
        
        for item in items {
            updates(item)
        }
        
        save()
    }
    
    // MARK: - Reset Operations
    
    @MainActor
    func resetAllProgress() async {
        do {
            // Reset all words
            let wordDescriptor = FetchDescriptor<Word>()
            let words = try mainContext.fetch(wordDescriptor)
            
            for word in words {
                word.resetProgress()
            }
            
            // Reset user settings
            let settings = UserSettings.getOrCreate(in: mainContext)
            settings.resetAllProgress()
            
            // Delete all sessions and reviews
            try mainContext.delete(model: LearningSession.self)
            try mainContext.delete(model: ReviewRecord.self)
            
            save()
            
            Logger.shared.info("All progress reset successfully")
            
        } catch {
            Logger.shared.error("Failed to reset progress: \(error)")
        }
    }
}

// MARK: - Supporting Types

struct VocabularyItem: Codable {
    let id: Int
    let hanzi: String
    let pinyin: String
    let meaning: String
    let hskLevel: Int
    let exampleSentence: String?
    let exampleTranslation: String?
    let audioFileName: String?
}

// MARK: - SwiftUI Environment

extension View {
    func withDataContainer() -> some View {
        self
            .modelContainer(SwiftDataContainer.shared.container)
            .environment(\.modelContext, SwiftDataContainer.shared.mainContext)
            .environmentObject(SwiftDataContainer.shared)
    }
}
