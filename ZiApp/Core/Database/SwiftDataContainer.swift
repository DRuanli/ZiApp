//
//  SwiftDataContainer.swift
//  ZiApp
//
//  SwiftData configuration and container management
//

import Foundation
import SwiftData

/// Manages the SwiftData model container for the app
@MainActor
final class SwiftDataContainer {
    static let shared = SwiftDataContainer()
    
    let container: ModelContainer
    private let logger = Logger.shared
    
    private init() {
        do {
            let schema = Schema([
                Word.self,
                LearningSession.self,
                ReviewRecord.self,
                UserProgress.self,
                UserSettings.self
            ])
            
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                allowsSave: true,
                groupContainer: .automatic,
                cloudKitDatabase: .none
            )
            
            container = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
            
            logger.log("SwiftData container initialized successfully", level: .info)
            
        } catch {
            logger.log("Failed to create ModelContainer: \(error)", level: .error)
            fatalError("Could not create ModelContainer: \(error)")
        }
    }
    
    // MARK: - Context Management
    var mainContext: ModelContext {
        container.mainContext
    }
    
    @MainActor
    func save() {
        do {
            try mainContext.save()
            logger.log("Context saved successfully", level: .debug)
        } catch {
            logger.log("Failed to save context: \(error)", level: .error)
        }
    }
    
    // MARK: - Data Operations
    func fetch<T: PersistentModel>(_ type: T.Type,
                                   predicate: Predicate<T>? = nil,
                                   sortBy: [SortDescriptor<T>] = []) throws -> [T] {
        var descriptor = FetchDescriptor<T>(predicate: predicate)
        descriptor.sortBy = sortBy
        
        return try mainContext.fetch(descriptor)
    }
    
    func delete<T: PersistentModel>(_ model: T) {
        mainContext.delete(model)
        logger.log("Deleted model: \(type(of: model))", level: .debug)
    }
    
    func insert<T: PersistentModel>(_ model: T) {
        mainContext.insert(model)
        logger.log("Inserted model: \(type(of: model))", level: .debug)
    }
    
    // MARK: - Migration Support
    func performMigrationIfNeeded() {
        // Check current schema version
        let currentVersion = UserDefaults.standard.string(forKey: "schema_version") ?? "1.0"
        let targetVersion = "1.2"
        
        if currentVersion < targetVersion {
            logger.log("Migrating from version \(currentVersion) to \(targetVersion)", level: .info)
            // Perform migration logic here
            UserDefaults.standard.set(targetVersion, forKey: "schema_version")
        }
    }
    
    // MARK: - Batch Operations
    func batchInsert<T: PersistentModel>(_ models: [T]) throws {
        for model in models {
            mainContext.insert(model)
        }
        try mainContext.save()
        logger.log("Batch inserted \(models.count) models", level: .info)
    }
    
    func deleteAll<T: PersistentModel>(_ type: T.Type) throws {
        let models = try fetch(type)
        for model in models {
            mainContext.delete(model)
        }
        try mainContext.save()
        logger.log("Deleted all models of type \(type)", level: .info)
    }
}
