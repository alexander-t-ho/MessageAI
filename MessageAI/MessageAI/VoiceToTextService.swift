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
    private func requestSpeechRecognitionPermission() {
        SFSpeechRecognizer.requestAuthorization { [weak self] authStatus in
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    print("✅ Speech recognition authorized")
                case .denied:
                    print("❌ Speech recognition denied")
                    self?.errorMessage = "Speech recognition permission denied"
                case .restricted:
                    print("❌ Speech recognition restricted")
                    self?.errorMessage = "Speech recognition restricted"
                case .notDetermined:
                    print("❌ Speech recognition not determined")
                    self?.errorMessage = "Speech recognition permission not determined"
                @unknown default:
                    print("❌ Speech recognition unknown error")
                    self?.errorMessage = "Speech recognition unknown error"
                }
            }
        }
    }
    
    /// Convert audio file to text
    func transcribeAudioFile(url: URL, completion: @escaping (Result<String, Error>) -> Void) {
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            completion(.failure(VoiceToTextError.speechRecognizerNotAvailable))
            return
        }
        
        // Request permissions if not already authorized
        if SFSpeechRecognizer.authorizationStatus() == .notDetermined {
            requestSpeechRecognitionPermission()
            completion(.failure(VoiceToTextError.permissionDenied))
            return
        }
        
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            completion(.failure(VoiceToTextError.permissionDenied))
            return
        }
        
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
        
        recognitionTask = speechRecognizer.recognitionTask(with: fileRecognitionRequest) { [weak self] result, error in
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
    func cancelTranscription() {
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        
        DispatchQueue.main.async {
            self.isTranscribing = false
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
