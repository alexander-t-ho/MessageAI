//
//  VoiceMessagePlayer.swift
//  Cloudy
//
//  Service for playing voice messages
//

import Foundation
import AVFoundation
import Combine

class VoiceMessagePlayer: NSObject, ObservableObject {
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var playbackProgress: Double = 0 // 0.0 to 1.0
    
    // Callback properties for external updates
    var onPlaybackStateChanged: ((Bool) -> Void)?
    var onTimeUpdate: ((TimeInterval) -> Void)?
    var onError: ((String) -> Void)?
    
    private var audioPlayer: AVAudioPlayer?
    private var progressTimer: Timer?
    private var currentURL: URL?
    
    override init() {
        super.init()
    }
    
    // Play audio from URL (handles both local and S3 URLs)
    func play(url: URL, completion: @escaping (Bool) -> Void) {
        currentURL = url
        
        print("🎵 VoiceMessagePlayer.play() called")
        print("🎵 URL: \(url.absoluteString)")
        print("🎵 URL scheme: \(url.scheme ?? "nil")")
        print("🎵 URL host: \(url.host ?? "nil")")
        
        // Check if it's an S3 URL
        if url.absoluteString.contains("s3.amazonaws.com") || url.absoluteString.contains("lambda-url") || url.absoluteString.contains("cloudy-voice-messages") {
            print("🎵 Detected S3 URL, downloading...")
            downloadAndPlayS3Audio(url: url, completion: completion)
        } else {
            print("🎵 Detected local URL, playing directly...")
            // Local file
            loadAndPlayLocalAudio(url: url, completion: completion)
        }
    }
    
    // Download and play S3 audio
    private func downloadAndPlayS3Audio(url: URL, completion: @escaping (Bool) -> Void) {
        print("📥 Downloading audio from S3: \(url)")
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Failed to download audio: \(error)")
                    print("❌ Error details: \(error.localizedDescription)")
                    self?.onError?("Failed to download audio: \(error.localizedDescription)")
                    completion(false)
                    return
                }
                
                guard let data = data else {
                    print("❌ No audio data received")
                    self?.onError?("No audio data received")
                    completion(false)
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("❌ Invalid HTTP response")
                    self?.onError?("Invalid HTTP response")
                    completion(false)
                    return
                }
                
                guard (200...299).contains(httpResponse.statusCode) else {
                    print("❌ HTTP error: \(httpResponse.statusCode)")
                    self?.onError?("HTTP error: \(httpResponse.statusCode)")
                    completion(false)
                    return
                }
                
                print("📥 Downloaded \(data.count) bytes from S3")
                
                // Save to temporary file
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".m4a")
                
                do {
                    try data.write(to: tempURL)
                    print("💾 Saved audio to temp file: \(tempURL.path)")
                    self?.loadAndPlayLocalAudio(url: tempURL, completion: completion)
                } catch {
                    print("❌ Failed to save audio: \(error)")
                    print("❌ Error details: \(error.localizedDescription)")
                    self?.onError?("Failed to save audio: \(error.localizedDescription)")
                    completion(false)
                }
            }
        }.resume()
    }
    
    // Load and play local audio file
    private func loadAndPlayLocalAudio(url: URL, completion: @escaping (Bool) -> Void) {
        do {
            // Configure audio session for playback with proper options
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [.allowBluetooth, .allowBluetoothA2DP])
            try audioSession.setActive(true)
            
            // Create player
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            
            duration = audioPlayer?.duration ?? 0
            currentTime = 0
            playbackProgress = 0
            
            print("🔊 Loaded audio: \(String(format: "%.1f", duration))s")
            print("🔊 Audio file path: \(url.path)")
            
            // Start playing
            play()
            completion(true)
            
        } catch {
            print("❌ Failed to load audio: \(error)")
            print("❌ Error details: \(error.localizedDescription)")
            onError?("Failed to load audio: \(error.localizedDescription)")
            completion(false)
        }
    }
    
    // Legacy method for backward compatibility
    func loadAudio(url: URL) {
        loadAndPlayLocalAudio(url: url) { _ in }
    }
    
    // Play audio
    func play() {
        guard let player = audioPlayer else { return }
        
        player.play()
        isPlaying = true
        onPlaybackStateChanged?(true)
        
        // Start timer to update progress
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateProgress()
        }
        
        print("▶️ Playing audio")
    }
    
    // Pause audio
    func pause() {
        audioPlayer?.pause()
        isPlaying = false
        onPlaybackStateChanged?(false)
        progressTimer?.invalidate()
        progressTimer = nil
        
        print("⏸️ Paused audio")
    }
    
    // Stop and reset
    func stop() {
        audioPlayer?.stop()
        audioPlayer?.currentTime = 0
        isPlaying = false
        onPlaybackStateChanged?(false)
        currentTime = 0
        playbackProgress = 0
        progressTimer?.invalidate()
        progressTimer = nil
        
        print("⏹️ Stopped audio")
    }
    
    // Seek to specific time
    func seek(to time: TimeInterval) {
        audioPlayer?.currentTime = time
        currentTime = time
        updateProgress()
    }
    
    // Update progress
    private func updateProgress() {
        guard let player = audioPlayer else { return }
        
        currentTime = player.currentTime
        onTimeUpdate?(currentTime)
        
        if duration > 0 {
            playbackProgress = currentTime / duration
        }
        
        // Auto-stop at end
        if currentTime >= duration && isPlaying {
            stop()
        }
    }
    
    // Clean up
    func cleanup() {
        stop()
        audioPlayer = nil
    }
}

// MARK: - AVAudioPlayerDelegate

extension VoiceMessagePlayer: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
        onPlaybackStateChanged?(false)
        currentTime = 0
        playbackProgress = 0
        progressTimer?.invalidate()
        progressTimer = nil
        
        print("✅ Playback finished")
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        let errorMessage = error?.localizedDescription ?? "Unknown playback error"
        print("❌ Playback error: \(errorMessage)")
        onError?(errorMessage)
        isPlaying = false
        onPlaybackStateChanged?(false)
    }
}

