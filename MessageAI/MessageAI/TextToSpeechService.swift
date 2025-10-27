//
//  TextToSpeechService.swift
//  MessageAI
//
//  Text-to-speech service using AVSpeechSynthesizer
//

import Foundation
import AVFoundation
import SwiftUI
import Combine

class TextToSpeechService: NSObject, ObservableObject {
    static let shared = TextToSpeechService()
    
    @Published var isSpeaking = false
    @Published var currentText = ""
    
    private let synthesizer = AVSpeechSynthesizer()
    private var currentUtterance: AVSpeechUtterance?
    
    override init() {
        super.init()
        synthesizer.delegate = self
    }
    
    /// Speak the given text with appropriate language detection
    func speakText(_ text: String, language: String? = nil) {
        guard !text.isEmpty else {
            print("⚠️ TTS: Cannot speak empty text")
            return
        }
        
        // Stop any current speech
        stopSpeaking()
        
        // Detect language if not provided
        let detectedLanguage = language ?? detectLanguage(from: text)
        print("🎤 TTS: Speaking text in language: \(detectedLanguage)")
        
        // Create utterance
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = 0.5 // Good default speed
        utterance.volume = 1.0
        
        // Set voice for detected language
        if let voice = getVoice(for: detectedLanguage) {
            utterance.voice = voice
            print("🎤 TTS: Using voice: \(voice.name)")
        } else {
            print("⚠️ TTS: No voice found for language: \(detectedLanguage)")
        }
        
        // Store current utterance and text
        currentUtterance = utterance
        currentText = text
        
        // Start speaking
        synthesizer.speak(utterance)
    }
    
    /// Stop current speech
    func stopSpeaking() {
        guard isSpeaking else { return }
        
        print("🔇 TTS: Stopping speech")
        synthesizer.stopSpeaking(at: .immediate)
        
        // Reset state
        currentUtterance = nil
        currentText = ""
    }
    
    /// Toggle speech (start if not speaking, stop if speaking)
    func toggleSpeech(for text: String, language: String? = nil) {
        if isSpeaking && currentText == text {
            stopSpeaking()
        } else {
            speakText(text, language: language)
        }
    }
    
    /// Clean up when view disappears
    func cleanup() {
        stopSpeaking()
    }
    
    // MARK: - Private Methods
    
    private func detectLanguage(from text: String) -> String {
        // Simple language detection based on character patterns
        // In a real app, you might use more sophisticated detection
        
        // Check for Spanish
        if text.contains("ñ") || text.contains("¿") || text.contains("¡") {
            return "es"
        }
        
        // Check for French
        if text.contains("é") || text.contains("è") || text.contains("ç") {
            return "fr"
        }
        
        // Check for German
        if text.contains("ä") || text.contains("ö") || text.contains("ü") || text.contains("ß") {
            return "de"
        }
        
        // Check for Japanese (hiragana/katakana)
        if text.contains(where: { $0.unicodeScalars.contains { scalar in
            scalar.value >= 0x3040 && scalar.value <= 0x309F || // Hiragana
            scalar.value >= 0x30A0 && scalar.value <= 0x30FF    // Katakana
        }}) {
            return "ja"
        }
        
        // Check for Chinese (CJK)
        if text.contains(where: { $0.unicodeScalars.contains { scalar in
            scalar.value >= 0x4E00 && scalar.value <= 0x9FFF    // CJK Unified Ideographs
        }}) {
            return "zh"
        }
        
        // Check for Arabic
        if text.contains(where: { $0.unicodeScalars.contains { scalar in
            scalar.value >= 0x0600 && scalar.value <= 0x06FF    // Arabic
        }}) {
            return "ar"
        }
        
        // Default to English
        return "en"
    }
    
    private func getVoice(for languageCode: String) -> AVSpeechSynthesisVoice? {
        // Try to get a voice for the specific language
        if let voice = AVSpeechSynthesisVoice(language: languageCode) {
            return voice
        }
        
        // Fallback to available voices
        let availableVoices = AVSpeechSynthesisVoice.speechVoices()
        
        // Try to find a voice that matches the language
        for voice in availableVoices {
            if voice.language.hasPrefix(languageCode) {
                return voice
            }
        }
        
        // Final fallback to default voice
        return AVSpeechSynthesisVoice(language: "en-US")
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension TextToSpeechService: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = true
            print("🎤 TTS: Started speaking")
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = false
            self.currentUtterance = nil
            self.currentText = ""
            print("🎤 TTS: Finished speaking")
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = false
            self.currentUtterance = nil
            self.currentText = ""
            print("🎤 TTS: Speech cancelled")
        }
    }
}
