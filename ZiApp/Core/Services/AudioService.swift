//
//  AudioService.swift
//  Zi
//
//  Audio playback service for word pronunciation
//

import Foundation
import AVFoundation
import SwiftUI

@MainActor
class AudioService: NSObject, ObservableObject {
    static let shared = AudioService()
    
    // MARK: - Properties
    @Published var isPlaying: Bool = false
    @Published var currentWord: String?
    @Published var volume: Float = 1.0
    @Published var playbackRate: Float = 1.0
    
    private var audioPlayer: AVAudioPlayer?
    private var audioSession: AVAudioSession
    private var audioCache: [String: Data] = [:]
    private let cacheLimit = 50 // Cache up to 50 audio files
    
    // MARK: - Initialization
    
    override init() {
        self.audioSession = AVAudioSession.sharedInstance()
        super.init()
        setupAudioSession()
    }
    
    // MARK: - Audio Session Setup
    
    private func setupAudioSession() {
        do {
            // Configure audio session for playback
            try audioSession.setCategory(
                .playback,
                mode: .spokenAudio,
                options: [.duckOthers, .allowBluetooth, .allowBluetoothA2DP]
            )
            
            try audioSession.setActive(true)
            
            Logger.shared.info("Audio session configured successfully")
            
            // Register for interruption notifications
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleInterruption),
                name: AVAudioSession.interruptionNotification,
                object: audioSession
            )
            
            // Register for route change notifications
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleRouteChange),
                name: AVAudioSession.routeChangeNotification,
                object: audioSession
            )
            
        } catch {
            Logger.shared.error("Failed to setup audio session: \(error)")
        }
    }
    
    // MARK: - Public Methods
    
    /// Play pronunciation for a word
    func playPronunciation(filename: String, word: String? = nil) {
        Logger.shared.debug("Attempting to play audio: \(filename)")
        
        currentWord = word ?? filename
        
        // Check cache first
        if let cachedData = audioCache[filename] {
            playAudioData(cachedData, filename: filename)
            return
        }
        
        // Load from bundle
        if let audioData = loadAudioFile(filename: filename) {
            // Add to cache
            addToCache(filename: filename, data: audioData)
            
            // Play audio
            playAudioData(audioData, filename: filename)
        } else {
            Logger.shared.error("Audio file not found: \(filename)")
            
            // Fallback to system speech synthesis
            speakWord(word ?? filename)
        }
    }
    
    /// Play a sequence of words
    func playSequence(words: [(filename: String, word: String)], delay: TimeInterval = 0.5) {
        guard !words.isEmpty else { return }
        
        var currentIndex = 0
        
        func playNext() {
            guard currentIndex < words.count else {
                isPlaying = false
                return
            }
            
            let item = words[currentIndex]
            playPronunciation(filename: item.filename, word: item.word)
            
            currentIndex += 1
            
            // Schedule next word
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                playNext()
            }
        }
        
        isPlaying = true
        playNext()
    }
    
    /// Stop current playback
    func stop() {
        audioPlayer?.stop()
        isPlaying = false
        currentWord = nil
        
        Logger.shared.debug("Audio playback stopped")
    }
    
    /// Pause current playback
    func pause() {
        guard audioPlayer?.isPlaying == true else { return }
        
        audioPlayer?.pause()
        isPlaying = false
        
        Logger.shared.debug("Audio playback paused")
    }
    
    /// Resume playback
    func resume() {
        guard audioPlayer?.isPlaying == false else { return }
        
        audioPlayer?.play()
        isPlaying = true
        
        Logger.shared.debug("Audio playback resumed")
    }
    
    /// Set playback volume
    func setVolume(_ volume: Float) {
        self.volume = max(0, min(1, volume))
        audioPlayer?.volume = self.volume
    }
    
    /// Set playback rate
    func setPlaybackRate(_ rate: Float) {
        self.playbackRate = max(0.5, min(2.0, rate))
        
        if let player = audioPlayer {
            player.enableRate = true
            player.rate = self.playbackRate
        }
    }
    
    /// Clear audio cache
    func clearCache() {
        audioCache.removeAll()
        Logger.shared.info("Audio cache cleared")
    }
    
    // MARK: - Private Methods
    
    private func loadAudioFile(filename: String) -> Data? {
        // Remove extension if provided
        let name = filename.replacingOccurrences(of: ".mp3", with: "")
            .replacingOccurrences(of: ".m4a", with: "")
            .replacingOccurrences(of: ".wav", with: "")
        
        // Try different audio formats
        let formats = ["mp3", "m4a", "wav", "aac"]
        
        for format in formats {
            if let url = Bundle.main.url(forResource: name, withExtension: format) {
                do {
                    return try Data(contentsOf: url)
                } catch {
                    Logger.shared.error("Failed to load audio file: \(error)")
                }
            }
        }
        
        return nil
    }
    
    private func playAudioData(_ data: Data, filename: String) {
        do {
            audioPlayer = try AVAudioPlayer(data: data)
            audioPlayer?.delegate = self
            audioPlayer?.volume = volume
            audioPlayer?.enableRate = true
            audioPlayer?.rate = playbackRate
            audioPlayer?.prepareToPlay()
            
            let success = audioPlayer?.play() ?? false
            isPlaying = success
            
            if success {
                Logger.shared.debug("Playing audio: \(filename)")
            } else {
                Logger.shared.error("Failed to play audio: \(filename)")
            }
            
        } catch {
            Logger.shared.error("Error creating audio player: \(error)")
            
            // Fallback to speech synthesis
            if let word = currentWord {
                speakWord(word)
            }
        }
    }
    
    private func addToCache(filename: String, data: Data) {
        // Check cache limit
        if audioCache.count >= cacheLimit {
            // Remove oldest entry
            if let oldestKey = audioCache.keys.first {
                audioCache.removeValue(forKey: oldestKey)
            }
        }
        
        audioCache[filename] = data
    }
    
    /// Fallback speech synthesis
    private func speakWord(_ text: String) {
        Logger.shared.info("Using speech synthesis for: \(text)")
        
        let synthesizer = AVSpeechSynthesizer()
        
        // Create utterance with Chinese text
        let utterance = AVSpeechUtterance(string: text)
        
        // Configure for Chinese
        utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
        utterance.rate = 0.4 // Slower for language learning
        utterance.pitchMultiplier = 1.0
        utterance.volume = volume
        
        // Speak
        synthesizer.speak(utterance)
        
        isPlaying = true
        
        // Reset state after estimated duration
        let estimatedDuration = Double(text.count) * 0.5
        DispatchQueue.main.asyncAfter(deadline: .now() + estimatedDuration) {
            self.isPlaying = false
        }
    }
    
    // MARK: - Notification Handlers
    
    @objc private func handleInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSession.interruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            // Interruption began, pause playback
            pause()
            Logger.shared.info("Audio interrupted")
            
        case .ended:
            // Interruption ended, resume if needed
            if let optionsValue = userInfo[AVAudioSession.interruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    resume()
                    Logger.shared.info("Audio resumed after interruption")
                }
            }
            
        @unknown default:
            break
        }
    }
    
    @objc private func handleRouteChange(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSession.routeChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }
        
        switch reason {
        case .oldDeviceUnavailable:
            // Headphones unplugged, pause
            pause()
            Logger.shared.info("Audio route changed - device unavailable")
            
        case .newDeviceAvailable:
            Logger.shared.info("New audio device available")
            
        default:
            break
        }
    }
    
    // MARK: - Preloading
    
    /// Preload audio files for better performance
    func preloadAudio(filenames: [String]) {
        Task.detached { [weak self] in
            for filename in filenames {
                guard let self = self else { break }
                
                // Skip if already cached
                if self.audioCache[filename] != nil {
                    continue
                }
                
                // Load and cache
                if let data = self.loadAudioFile(filename: filename) {
                    await MainActor.run {
                        self.addToCache(filename: filename, data: data)
                    }
                }
                
                // Small delay to avoid blocking
                try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
            }
            
            Logger.shared.info("Preloaded \(filenames.count) audio files")
        }
    }
}

// MARK: - AVAudioPlayerDelegate

extension AudioService: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
        currentWord = nil
        
        Logger.shared.debug("Audio playback finished: \(flag ? "success" : "failure")")
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        isPlaying = false
        
        if let error = error {
            Logger.shared.error("Audio decode error: \(error)")
        }
        
        // Try fallback
        if let word = currentWord {
            speakWord(word)
        }
    }
}

// MARK: - SwiftUI Audio Player View

struct AudioPlayerButton: View {
    let word: Word
    @StateObject private var audioService = AudioService.shared
    @State private var isAnimating = false
    
    var body: some View {
        Button(action: playAudio) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 44, height: 44)
                
                Image(systemName: audioService.isPlaying && audioService.currentWord == word.hanzi ? "speaker.wave.3.fill" : "speaker.wave.2.fill")
                    .foregroundColor(.blue)
                    .scaleEffect(isAnimating ? 1.2 : 1.0)
            }
        }
        .disabled(audioService.isPlaying && audioService.currentWord != word.hanzi)
        .onChange(of: audioService.isPlaying) { _, isPlaying in
            withAnimation(.easeInOut(duration: 0.3)) {
                isAnimating = isPlaying && audioService.currentWord == word.hanzi
            }
        }
    }
    
    private func playAudio() {
        if let audioFile = word.audioFileName {
            audioService.playPronunciation(filename: audioFile, word: word.hanzi)
        } else {
            // Use text-to-speech as fallback
            audioService.speakWord(word.hanzi)
        }
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.prepare()
        impactFeedback.impactOccurred()
    }
}

// MARK: - Audio Settings View

struct AudioSettingsView: View {
    @StateObject private var audioService = AudioService.shared
    
    var body: some View {
        VStack(spacing: 20) {
            // Volume control
            VStack(alignment: .leading) {
                Text("Volume")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack {
                    Image(systemName: "speaker.fill")
                        .foregroundColor(.secondary)
                    
                    Slider(value: $audioService.volume, in: 0...1) { _ in
                        audioService.setVolume(audioService.volume)
                    }
                    
                    Image(systemName: "speaker.wave.3.fill")
                        .foregroundColor(.secondary)
                }
            }
            
            // Playback speed
            VStack(alignment: .leading) {
                Text("Playback Speed")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Picker("Speed", selection: $audioService.playbackRate) {
                    Text("0.5x").tag(Float(0.5))
                    Text("0.75x").tag(Float(0.75))
                    Text("1.0x").tag(Float(1.0))
                    Text("1.25x").tag(Float(1.25))
                    Text("1.5x").tag(Float(1.5))
                }
                .pickerStyle(.segmented)
                .onChange(of: audioService.playbackRate) { _, newValue in
                    audioService.setPlaybackRate(newValue)
                }
            }
            
            // Clear cache button
            Button(action: { audioService.clearCache() }) {
                Label("Clear Audio Cache", systemImage: "trash")
                    .foregroundColor(.red)
            }
        }
        .padding()
    }
}
