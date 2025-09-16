//
//  Logger.swift
//  ZiApp
//
//  Centralized logging system
//

import Foundation
import os.log

class Logger {
    static let shared = Logger()
    
    private let subsystem = Bundle.main.bundleIdentifier ?? "com.zi.app"
    private var loggers: [String: OSLog] = [:]
    
    enum LogLevel: String {
        case debug = "🔍 DEBUG"
        case info = "ℹ️ INFO"
        case warning = "⚠️ WARNING"
        case error = "❌ ERROR"
        case critical = "🔥 CRITICAL"
        
        var osLogType: OSLogType {
            switch self {
            case .debug: return .debug
            case .info: return .info
            case .warning: return .default
            case .error: return .error
            case .critical: return .fault
            }
        }
    }
    
    private init() {}
    
    // MARK: - Public Methods
    
    func debug(_ message: String, category: String = "General", file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .debug, category: category, file: file, function: function, line: line)
    }
    
    func info(_ message: String, category: String = "General", file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .info, category: category, file: file, function: function, line: line)
    }
    
    func warning(_ message: String, category: String = "General", file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .warning, category: category, file: file, function: function, line: line)
    }
    
    func error(_ message: String, category: String = "General", file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .error, category: category, file: file, function: function, line: line)
    }
    
    func critical(_ message: String, category: String = "General", file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .critical, category: category, file: file, function: function, line: line)
    }
    
    // MARK: - Private Methods
    
    private func log(_ message: String, level: LogLevel, category: String, file: String, function: String, line: Int) {
        let logger = getLogger(for: category)
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        
        let logMessage = "\(level.rawValue) [\(fileName):\(line)] \(function): \(message)"
        
        // OS Log
        os_log("%{public}@", log: logger, type: level.osLogType, logMessage)
        
        // Console log in debug mode
        #if DEBUG
        print(logMessage)
        #endif
        
        // Send to analytics for errors
        if level == .error || level == .critical {
            recordError(message: message, metadata: [
                "file": fileName,
                "function": function,
                "line": "\(line)",
                "category": category
            ])
        }
    }
    
    private func getLogger(for category: String) -> OSLog {
        if let existingLogger = loggers[category] {
            return existingLogger
        }
        
        let newLogger = OSLog(subsystem: subsystem, category: category)
        loggers[category] = newLogger
        return newLogger
    }
    
    private func recordError(message: String, metadata: [String: String]) {
        // Send to analytics service (Firebase, Crashlytics, etc.)
        // AnalyticsService.shared.logError(message, metadata: metadata)
    }
    
    // MARK: - Performance Logging
    
    func measureTime<T>(label: String, operation: () throws -> T) rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        defer {
            let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
            
            if timeElapsed > 1.0 {
                warning("Slow operation: \(label) took \(String(format: "%.2f", timeElapsed))s")
            } else {
                debug("Operation \(label) completed in \(String(format: "%.3f", timeElapsed))s")
            }
        }
        
        return try operation()
    }
    
    // MARK: - Network Logging
    
    func logNetworkRequest(url: String, method: String, headers: [String: String]? = nil) {
        var message = "Network Request: \(method) \(url)"
        
        if let headers = headers, !headers.isEmpty {
            message += "\nHeaders: \(headers)"
        }
        
        debug(message, category: "Network")
    }
    
    func logNetworkResponse(url: String, statusCode: Int, responseTime: TimeInterval) {
        let message = "Network Response: \(url)\nStatus: \(statusCode)\nTime: \(String(format: "%.3f", responseTime))s"
        
        if statusCode >= 400 {
            error(message, category: "Network")
        } else {
            debug(message, category: "Network")
        }
    }
    
    // MARK: - Database Logging
    
    func logDatabaseOperation(_ operation: String, success: Bool, recordCount: Int? = nil) {
        var message = "Database: \(operation)"
        
        if let count = recordCount {
            message += " (\(count) records)"
        }
        
        if success {
            debug("\(message) - Success", category: "Database")
        } else {
            error("\(message) - Failed", category: "Database")
        }
    }
}
