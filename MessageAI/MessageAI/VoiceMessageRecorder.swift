//
//  VoiceMessageRecorder.swift
//  Cloudy
//
//  Service for recording voice messages
//

import Foundation
import AVFoundation
import SwiftUI
import Combine

class VoiceMessageRecorder: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var hasPermission = false
    @Published var audioLevel: Float = 0 // For waveform visualization
    
    private var audioRecorder: AVAudioRecorder?
    private var recordingTimer: Timer?
    private var levelTimer: Timer?
    private var recordingStartTime: Date?
    private var currentRecordingURL: URL?
    
    // Maximum recording duration (2 minutes)
    private let maxDuration: TimeInterval = 120
    
    override init() {
        super.init()
        checkMicrophonePermission()
    }
    
    // MARK: - Permissions
    
    func checkMicrophonePermission() {
        if #available(iOS 17.0, *) {
            switch AVAudioApplication.shared.recordPermission {
            case .granted:
                hasPermission = true
                print("🎤 Microphone permission granted")
            case .denied:
                hasPermission = false
                print("❌ Microphone permission denied")
            case .undetermined:
                requestMicrophonePermission()
            @unknown default:
                hasPermission = false
            }
        } else {
            switch AVAudioSession.sharedInstance().recordPermission {
            case .granted:
                hasPermission = true
                print("🎤 Microphone permission granted")
            case .denied:
                hasPermission = false
                print("❌ Microphone permission denied")
            case .undetermined:
                requestMicrophonePermission()
            @unknown default:
                hasPermission = false
            }
        }
    }
    
    func requestMicrophonePermission() {
        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission { [weak self] granted in
                DispatchQueue.main.async {
                    self?.hasPermission = granted
                    print(granted ? "✅ Microphone permission granted" : "❌ Microphone permission denied")
                }
            }
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
                DispatchQueue.main.async {
                    self?.hasPermission = granted
                    print(granted ? "✅ Microphone permission granted" : "❌ Microphone permission denied")
                }
            }
        }
    }
    
    // MARK: - Recording
    
    func startRecording() {
        guard hasPermission else {
            print("❌ No microphone permission")
            requestMicrophonePermission()
            return
        }
        
        guard !isRecording else {
            print("⚠️ Recording already in progress - ignoring start request")
            return
        }
        
        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try audioSession.setActive(true)
        } catch {
            print("❌ Failed to set up audio session: \(error)")
            return
        }
        
        // Create file URL for recording
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileName = "voice_\(UUID().uuidString).m4a"
        let audioURL = documentsPath.appendingPathComponent(fileName)
        currentRecordingURL = audioURL
        
        // Recording settings (AAC format, 64kbps for voice)
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1, // Mono
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue,
            AVEncoderBitRateKey: 64000 // 64 kbps
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: audioURL, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true // For audio level monitoring
            audioRecorder?.prepareToRecord()
            audioRecorder?.record()
            
            isRecording = true
            recordingStartTime = Date()
            recordingDuration = 0
            
            // Start timer to update duration
            recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                self?.updateRecordingDuration()
            }
            
            // Start timer to monitor audio level (for waveform)
            levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
                self?.updateAudioLevel()
            }
            
            print("🎤 Started recording to: \(audioURL.lastPathComponent)")
        } catch {
            print("❌ Failed to start recording: \(error)")
            isRecording = false
        }
    }
    
    func stopRecording() -> URL? {
        guard isRecording else { 
            print("⚠️ No recording in progress - ignoring stop request")
            return nil 
        }
        
        print("🎤 Stopping recording...")
        
        // Step 1: Stop timers first
        print("🔧 Step 1: Stopping timers...")
        recordingTimer?.invalidate()
        levelTimer?.invalidate()
        recordingTimer = nil
        levelTimer = nil
        print("✅ Timers stopped")
        
        // Step 2: Stop recording
        print("🔧 Step 2: Stopping audio recorder...")
        audioRecorder?.stop()
        isRecording = false
        print("✅ Audio recorder stopped")
        
        let url = currentRecordingURL
        let duration = recordingDuration
        
        print("🎤 Stopped recording - Duration: \(String(format: "%.1f", duration))s")
        print("📁 File: \(url?.lastPathComponent ?? "unknown")")
        
        // Step 3: Reset state
        print("🔧 Step 3: Resetting state...")
        recordingDuration = 0
        audioLevel = 0
        print("✅ State reset")
        
        // Step 4: Deactivate audio session on background queue to prevent crashes
        print("🔧 Step 4: Deactivating audio session...")
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try AVAudioSession.sharedInstance().setActive(false)
                print("✅ Audio session deactivated successfully")
            } catch {
                print("❌ Failed to deactivate audio session: \(error)")
            }
        }
        
        return url
    }
    
    func cancelRecording() {
        guard isRecording else { 
            print("⚠️ No recording in progress - ignoring cancel request")
            return 
        }
        
        print("🗑️ Cancelling recording...")
        
        // Step 1: Stop timers first
        print("🔧 Step 1: Stopping timers...")
        recordingTimer?.invalidate()
        levelTimer?.invalidate()
        recordingTimer = nil
        levelTimer = nil
        print("✅ Timers stopped")
        
        // Step 2: Stop recording
        print("🔧 Step 2: Stopping audio recorder...")
        audioRecorder?.stop()
        isRecording = false
        print("✅ Audio recorder stopped")
        
        // Step 3: Delete the recording file
        print("🔧 Step 3: Deleting recording file...")
        if let url = currentRecordingURL {
            do {
                try FileManager.default.removeItem(at: url)
                print("✅ Recording file deleted: \(url.lastPathComponent)")
            } catch {
                print("❌ Failed to delete recording file: \(error)")
            }
        }
        
        // Step 4: Reset state
        print("🔧 Step 4: Resetting state...")
        currentRecordingURL = nil
        recordingDuration = 0
        audioLevel = 0
        print("✅ State reset")
        
        // Step 5: Deactivate audio session on background queue to prevent crashes
        print("🔧 Step 5: Deactivating audio session...")
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try AVAudioSession.sharedInstance().setActive(false)
                print("✅ Audio session deactivated successfully")
            } catch {
                print("❌ Failed to deactivate audio session: \(error)")
            }
        }
    }
    
    // MARK: - Private Helpers
    
    private func updateRecordingDuration() {
        guard let startTime = recordingStartTime else { return }
        recordingDuration = Date().timeIntervalSince(startTime)
        
        // Auto-stop if max duration reached
        if recordingDuration >= maxDuration {
            print("⏱️ Max duration reached, stopping recording")
            _ = stopRecording()
        }
    }
    
    private func updateAudioLevel() {
        audioRecorder?.updateMeters()
        let averagePower = audioRecorder?.averagePower(forChannel: 0) ?? -160
        // Convert decibels to 0-1 range
        let normalizedLevel = powf(10, averagePower / 20)
        audioLevel = normalizedLevel
    }
    
    // Get file size
    func getFileSize(url: URL) -> Int64? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path) else {
            return nil
        }
        return attributes[.size] as? Int64
    }
}

// MARK: - AVAudioRecorderDelegate

extension VoiceMessageRecorder: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if flag {
            print("✅ Recording finished successfully")
            print("📁 Finalized file: \(currentRecordingURL?.lastPathComponent ?? "unknown")")
        } else {
            print("❌ Recording finished with error")
        }
        
        // Now it's safe to reset the recording URL
        currentRecordingURL = nil
    }
    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        print("❌ Recording encode error: \(error?.localizedDescription ?? "Unknown")")
        isRecording = false
    }
}

