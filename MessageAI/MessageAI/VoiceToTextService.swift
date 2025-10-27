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
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    override init() {
        super.init()
        // Don't request permissions immediately - wait until first use
    }
    
    /// Request permission for speech recognition
    private func requestSpeechRecognitionPermission(completion: @escaping (Bool) -> Void) {
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
        
        switch authStatus {
        case .notDetermined:
            print("🎤 Requesting speech recognition permission...")
            requestSpeechRecognitionPermission { [weak self] granted in
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
        
        DispatchQueue.main.async {
            self.isTranscribing = true
            self.errorMessage = nil
        }
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        guard let recognitionRequest = recognitionRequest else {
            completion(.failure(VoiceToTextError.recognitionRequestFailed))
            return
        }
        
        recognitionRequest.shouldReportPartialResults = false
        
        // Create audio file recognition request
        let fileRecognitionRequest = SFSpeechURLRecognitionRequest(url: url)
        fileRecognitionRequest.shouldReportPartialResults = false
        
        recognitionTask = speechRecognizer?.recognitionTask(with: fileRecognitionRequest) { [weak self] result, error in
            DispatchQueue.main.async {
                self?.isTranscribing = false
                
                if let error = error {
                    print("❌ Speech recognition error: \(error)")
                    completion(.failure(error))
                    return
                }
                
                guard let result = result else {
                    completion(.failure(VoiceToTextError.noResult))
                    return
                }
                
                let transcribedText = result.bestTranscription.formattedString
                print("✅ Transcribed text: \(transcribedText)")
                completion(.success(transcribedText))
            }
        }
    }
    
    /// Cancel current transcription
    /// Cancel ongoing transcription
    func cancelTranscription() {
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        
        DispatchQueue.main.async {
            self.isTranscribing = false
            self.errorMessage = "Transcription cancelled"
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
