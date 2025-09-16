//
//  Logger.swift
//  ZiApp
//
//  Centralized logging system for debugging and analytics
//

import Foundation
import os.log

/// Centralized logging utility for the app
final class Logger {
    static let shared = Logger()
    
    private let subsystem = "com.ziapp.chinese"
    private let osLog: OSLog
    
    private init() {
        self.osLog = OSLog(subsystem: subsystem, category: "general")
    }
    
    // MARK: - Log Levels
    enum LogLevel: String {
        case debug = "DEBUG"
        case info = "INFO"
        case warning = "WARNING"
        case error = "ERROR"
        case critical = "CRITICAL"
        
        var osLogType: OSLogType {
            switch self {
            case .debug:
                return .debug
            case .info:
                return .info
            case .warning:
                return .default
            case .error:
                return .error
            case .critical:
                return .fault
            }
        }
        
        var emoji: String {
            switch self {
            case .debug: return "🔍"
            case .info: return "ℹ️"
            case .warning: return "⚠️"
            case .error: return "❌"
            case .critical: return "🔥"
            }
        }
    }
    
    // MARK: - Public Logging Methods
    func log(_ message: String,
             level: LogLevel = .info,
             file: String = #file,
             function: String = #function,
             line: Int = #line) {
        
        let filename = URL(fileURLWithPath: file).lastPathComponent
        let formattedMessage = formatMessage(message,
                                            level: level,
                                            file: filename,
                                            function: function,
                                            line: line)
        
        // OS Log
        os_log("%{public}@", log: osLog, type: level.osLogType, formattedMessage)
        
        // Console log for debugging
        #if DEBUG
        print(formattedMessage)
        #endif
        
        // Store in memory for later analysis
        storeLog(formattedMessage, level: level)
    }
    
    func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .debug, file: file, function: function, line: line)
    }
    
    func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .info, file: file, function: function, line: line)
    }
    
    func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .warning, file: file, function: function, line: line)
    }
    
    func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .error, file: file, function: function, line: line)
    }
    
    func critical(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .critical, file: file, function: function, line: line)
    }
    
    // MARK: - Performance Logging
    func logPerformance<T>(operation: String, block: () throws -> T) rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        defer {
            let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
            log("⏱ \(operation) took \(String(format: "%.3f", timeElapsed)) seconds", level: .debug)
        }
        return try block()
    }
    
    // MARK: - Private Methods
    private func formatMessage(_ message: String,
                              level: LogLevel,
                              file: String,
                              function: String,
                              line: Int) -> String {
        let timestamp = DateFormatter.logTimestamp.string(from: Date())
        return "\(level.emoji) [\(timestamp)] [\(level.rawValue)] [\(file):\(line)] \(function) - \(message)"
    }
    
    private var logBuffer: [LogEntry] = []
    private let maxBufferSize = 1000
    
    private func storeLog(_ message: String, level: LogLevel) {
        let entry = LogEntry(timestamp: Date(), message: message, level: level)
        
        if logBuffer.count >= maxBufferSize {
            logBuffer.removeFirst()
        }
        logBuffer.append(entry)
    }
    
    // MARK: - Log Export
    func exportLogs() -> String {
        return logBuffer.map { entry in
            "\(DateFormatter.logTimestamp.string(from: entry.timestamp)) [\(entry.level.rawValue)] \(entry.message)"
        }.joined(separator: "\n")
    }
    
    func clearLogs() {
        logBuffer.removeAll()
        log("Log buffer cleared", level: .info)
    }
}

// MARK: - Log Entry Model
private struct LogEntry {
    let timestamp: Date
    let message: String
    let level: Logger.LogLevel
}

// MARK: - DateFormatter Extension
private extension DateFormatter {
    static let logTimestamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()
}
