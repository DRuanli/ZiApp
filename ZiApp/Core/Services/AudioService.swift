//
//  AudioService.swift
//  ZiApp
//
//  Handles audio playback for word pronunciations
//

import Foundation
import AVFoundation
import SwiftUI

/// Observable audio service for playing word pronunciations
@MainActor
final class AudioService: NSObject, ObservableObject {
    static let shared = AudioService()
    
    // MARK: - Published Properties
    @Published var isPlaying: Bool = false
    @Published var currentWordId: Int?
    @Published var playbackProgress: Double = 0
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    private var audioPlayer: AVAudioPlayer?
    private var audioSession: AVAudioSession
    private let logger = Logger.shared
    private var progressTimer: Timer?
    
    // MARK: - Initialization
    override init() {
        self.audioSession = AVAudioSession.sharedInstance()
        super.init()
        setupAudioSession()
    }
    
    // MARK: - Audio Session Setup
    private func setupAudioSession() {
        do {
            try audioSession.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try audioSession.setActive(true)
            logger.log("Audio session configured successfully", level: .info)
        } catch {
            logger.log("Failed to setup audio session: \(error)", level: .error)
            errorMessage = "Audio setup failed"
        }
    }
    
    // MARK: - Public Methods
    func playPronunciation(for word: Word) async {
        guard let audioFileName = word.audioFileName else {
            logger.log("No audio file for word: \(word.hanzi)", level: .warning)
            return
        }
        
        await playAudio(fileName: audioFileName, wordId: word.id)
    }
    
    func playAudio(fileName: String, wordId: Int? = nil) async {
        // Stop any current playback
        stop()
        
        // Update current word
        currentWordId = wordId
        
        // Find audio file
        guard let audioURL = Bundle.main.url(forResource: fileName, withExtension: nil) else {
            logger.log("Audio file not found: \(fileName)", level: .error)
            errorMessage = "Audio file not found"
            return
        }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: audioURL)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            
            isPlaying = true
            audioPlayer?.play()
            
            startProgressTimer()
            logger.log("Playing audio: \(fileName)", level: .debug)
            
        } catch {
            logger.log("Failed to play audio: \(error)", level: .error)
            errorMessage = "Playback failed"
            isPlaying = false
        }
    }
    
    func stop() {
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
        playbackProgress = 0
        stopProgressTimer()
        logger.log("Audio playback stopped", level: .debug)
    }
    
    func pause() {
        guard audioPlayer?.isPlaying == true else { return }
        audioPlayer?.pause()
        isPlaying = false
        stopProgressTimer()
        logger.log("Audio playback paused", level: .debug)
    }
    
    func resume() {
        guard audioPlayer?.isPlaying == false else { return }
        audioPlayer?.play()
        isPlaying = true
        startProgressTimer()
        logger.log("Audio playback resumed", level: .debug)
    }
    
    // MARK: - Volume Control
    func setVolume(_ volume: Float) {
        audioPlayer?.volume = max(0, min(1, volume))
    }
    
    // MARK: - Progress Timer
    private func startProgressTimer() {
        stopProgressTimer()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateProgress()
        }
    }
    
    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }
    
    private func updateProgress() {
        guard let player = audioPlayer else { return }
        if player.duration > 0 {
            playbackProgress = player.currentTime / player.duration
        }
    }
    
    // MARK: - Route Change Handling
    func handleRouteChange() {
        // Re-configure audio session if route changes
        setupAudioSession()
    }
    
    // MARK: - Interruption Handling
    func handleInterruption(type: AVAudioSession.InterruptionType, options: AVAudioSession.InterruptionOptions) {
        switch type {
        case .began:
            pause()
        case .ended:
            if options.contains(.shouldResume) {
                resume()
            }
        @unknown default:
            break
        }
    }
}

// MARK: - AVAudioPlayerDelegate
extension AudioService: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.isPlaying = false
            self?.playbackProgress = 0
            self?.stopProgressTimer()
            self?.logger.log("Audio playback finished", level: .debug)
        }
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        DispatchQueue.main.async { [weak self] in
            self?.isPlaying = false
            self?.errorMessage = "Decode error occurred"
            if let error = error {
                self?.logger.log("Audio decode error: \(error)", level: .error)
            }
        }
    }
}

// MARK: - StateObject Wrapper for Views
struct AudioServiceKey: EnvironmentKey {
    static let defaultValue = AudioService.shared
}

extension EnvironmentValues {
    var audioService: AudioService {
        get { self[AudioServiceKey.self] }
        set { self[AudioServiceKey.self] = newValue }
    }
}
