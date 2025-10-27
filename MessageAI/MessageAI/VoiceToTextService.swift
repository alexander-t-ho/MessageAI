//
//  VoiceToTextService.swift
//  MessageAI
//
//  Voice-to-text conversion service using iOS Speech framework
//

import Foundation
import Speech
import AVFoundation
import Combine

class VoiceToTextService: NSObject, ObservableObject {
    @Published var isTranscribing = false
    @Published var transcribedText = ""
    @Published var errorMessage: String?
    
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    override init() {
        super.init()
        // Initialize speech recognizer with proper locale
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        print("🎤 Speech recognizer initialized: \(speechRecognizer != nil)")
        // Don't request permissions immediately - wait until first use
    }
    
    /// Request permission for speech recognition
    private func requestSpeechRecognitionPermission(completion: @escaping (Bool) -> Void) {
        // Request permission on main thread to avoid crashes
        DispatchQueue.main.async {
            SFSpeechRecognizer.requestAuthorization { authStatus in
                DispatchQueue.main.async {
                    switch authStatus {
                    case .authorized:
                        print("✅ Speech recognition authorized")
                        completion(true)
                    case .denied:
                        print("❌ Speech recognition denied")
                        self.errorMessage = "Speech recognition permission denied"
                        completion(false)
                    case .restricted:
                        print("❌ Speech recognition restricted")
                        self.errorMessage = "Speech recognition restricted"
                        completion(false)
                    case .notDetermined:
                        print("❌ Speech recognition not determined")
                        self.errorMessage = "Speech recognition permission not determined"
                        completion(false)
                    @unknown default:
                        print("❌ Speech recognition unknown error")
                        self.errorMessage = "Speech recognition unknown error"
                        completion(false)
                    }
                }
            }
        }
    }
    
    /// Convert audio file to text
    func transcribeAudioFile(url: URL, completion: @escaping (Result<String, Error>) -> Void) {
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            print("❌ Speech recognizer not available")
            completion(.failure(VoiceToTextError.speechRecognizerNotAvailable))
            return
        }
        
        // Handle permission status
        let authStatus = SFSpeechRecognizer.authorizationStatus()
        print("🎤 Speech recognition authorization status: \(authStatus.rawValue)")
        print("🎤 Speech recognizer available: \(speechRecognizer?.isAvailable ?? false)")
        
        switch authStatus {
        case .notDetermined:
            print("🎤 Speech recognition permission not determined - attempting safe permission request")
            // Try a safer permission request approach
            requestSpeechRecognitionPermissionSafely { [weak self] granted in
                if granted {
                    self?.performTranscription(url: url, completion: completion)
                } else {
                    completion(.failure(VoiceToTextError.permissionDenied))
                }
            }
            return
        case .denied, .restricted:
            print("❌ Speech recognition permission denied or restricted")
            completion(.failure(VoiceToTextError.permissionDenied))
            return
        case .authorized:
            print("✅ Speech recognition authorized, proceeding with transcription")
            performTranscription(url: url, completion: completion)
            return
        @unknown default:
            print("❌ Unknown speech recognition authorization status")
            completion(.failure(VoiceToTextError.permissionDenied))
            return
        }
    }
    
    private func performTranscription(url: URL, completion: @escaping (Result<String, Error>) -> Void) {
        // Validate audio file exists and is accessible
        guard FileManager.default.fileExists(atPath: url.path) else {
            DispatchQueue.main.async {
                self.isTranscribing = false
                self.errorMessage = "Audio file not found at path: \(url.path)"
                completion(.failure(VoiceToTextError.noResult))
            }
            return
        }
        
        // Check file size to ensure it's not empty
        do {
            let fileAttributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let fileSize = fileAttributes[.size] as? Int64 ?? 0
            print("📁 Audio file size: \(fileSize) bytes")
            
            if fileSize == 0 {
                DispatchQueue.main.async {
                    self.isTranscribing = false
                    self.errorMessage = "Audio file is empty"
                    completion(.failure(VoiceToTextError.noResult))
                }
                return
            }
        } catch {
            print("❌ Failed to get file attributes: \(error)")
            DispatchQueue.main.async {
                self.isTranscribing = false
                self.errorMessage = "Failed to validate audio file"
                completion(.failure(VoiceToTextError.noResult))
            }
            return
        }
        
        DispatchQueue.main.async {
            self.isTranscribing = true
            self.errorMessage = nil
        }
        
        // Create audio file recognition request
        let fileRecognitionRequest = SFSpeechURLRecognitionRequest(url: url)
        fileRecognitionRequest.shouldReportPartialResults = false
        
        // Perform recognition on background queue to avoid blocking UI
        DispatchQueue.global(qos: .userInitiated).async {
            self.recognitionTask = self.speechRecognizer?.recognitionTask(with: fileRecognitionRequest) { [weak self] result, error in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    
                    self.isTranscribing = false
                    
                    if let error = error {
                        print("❌ Speech recognition error: \(error)")
                        self.errorMessage = "Transcription failed: \(error.localizedDescription)"
                        completion(.failure(error))
                        return
                    }
                    
                    guard let result = result else {
                        print("❌ No recognition result")
                        self.errorMessage = "No transcription result"
                        completion(.failure(VoiceToTextError.noResult))
                        return
                    }
                    
                    if result.isFinal {
                        let transcribedText = result.bestTranscription.formattedString
                        print("✅ Transcription completed: \(transcribedText)")
                        completion(.success(transcribedText))
                    }
                }
            }
            
            // Add timeout to prevent hanging
            DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
                if self.isTranscribing {
                    print("⏰ Transcription timeout - cancelling")
                    self.recognitionTask?.cancel()
                    self.isTranscribing = false
                    self.errorMessage = "Transcription timeout"
                    completion(.failure(VoiceToTextError.noResult))
                }
            }
        }
    }
    
    /// Cancel ongoing transcription
    func cancelTranscription() {
        print("🔧 Cancelling transcription...")
        
        // Step 1: Cancel recognition task
        print("🔧 Step 1: Cancelling recognition task...")
        recognitionTask?.cancel()
        recognitionTask = nil
        print("✅ Recognition task cancelled")
        
        // Step 2: Reset state
        print("🔧 Step 2: Resetting transcription state...")
        DispatchQueue.main.async {
            self.isTranscribing = false
            self.errorMessage = "Transcription cancelled"
            print("✅ Transcription state reset")
        }
    }
    
    /// Request permission for speech recognition with safer approach
    private func requestSpeechRecognitionPermissionSafely(completion: @escaping (Bool) -> Void) {
        print("🎤 Attempting safe speech recognition permission request...")
        
        // Use a timeout to prevent hanging
        var permissionCompleted = false
        let timeout: TimeInterval = 10.0
        
        DispatchQueue.main.async {
            SFSpeechRecognizer.requestAuthorization { authStatus in
                guard !permissionCompleted else { return }
                permissionCompleted = true
                
                DispatchQueue.main.async {
                    switch authStatus {
                    case .authorized:
                        print("✅ Speech recognition authorized safely")
                        completion(true)
                    case .denied:
                        print("❌ Speech recognition denied")
                        self.errorMessage = "Speech recognition permission denied"
                        completion(false)
                    case .restricted:
                        print("❌ Speech recognition restricted")
                        self.errorMessage = "Speech recognition restricted"
                        completion(false)
                    case .notDetermined:
                        print("❌ Speech recognition still not determined")
                        self.errorMessage = "Speech recognition permission not determined"
                        completion(false)
                    @unknown default:
                        print("❌ Speech recognition unknown error")
                        self.errorMessage = "Speech recognition unknown error"
                        completion(false)
                    }
                }
            }
        }
        
        // Add timeout protection
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
            if !permissionCompleted {
                print("⏰ Speech recognition permission request timed out")
                permissionCompleted = true
                self.errorMessage = "Speech recognition permission request timed out"
                completion(false)
            }
        }
    }
}

// MARK: - Error Types
enum VoiceToTextError: Error, LocalizedError {
    case speechRecognizerNotAvailable
    case permissionDenied
    case recognitionRequestFailed
    case noResult
    
    var errorDescription: String? {
        switch self {
        case .speechRecognizerNotAvailable:
            return "Speech recognizer is not available"
        case .permissionDenied:
            return "Speech recognition permission denied"
        case .recognitionRequestFailed:
            return "Failed to create recognition request"
        case .noResult:
            return "No transcription result"
        }
    }
}
