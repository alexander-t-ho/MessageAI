import Foundation
import SwiftUI
import Combine

// MARK: - AI Translation Models

struct TranslationRequest: Codable {
    let action: String
    let text: String
    let targetLang: String?
    let sourceLang: String?
    let desiredLevel: String?
    let conversationContext: String?
}

struct TranslationResponse: Codable {
    let success: Bool
    let action: String
    let result: TranslationResult?
    let error: String?
}

struct TranslationResult: Codable {
    // For translate action
    let translatedText: String?
    let detectedLanguage: String?
    let confidence: Double?
    let fromCache: Bool?
    
    // For cultural context
    let hasContext: Bool?
    let hints: [CulturalHint]?
    
    // For formality adjustment
    let adjustedText: String?
    let originalLevel: String?
    let changes: [String]?
    
    // For smart replies
    let replies: [SmartReply]?
}

struct CulturalHint: Codable {
    let phrase: String
    let explanation: String
    let literalMeaning: String
    let actualMeaning: String
}

struct SmartReply: Codable {
    let text: String
    let tone: String
    let intent: String
}

// MARK: - Language Support

enum SupportedLanguage: String, CaseIterable {
    case english = "en"
    case spanish = "es"
    case french = "fr"
    case german = "de"
    case italian = "it"
    case portuguese = "pt"
    case russian = "ru"
    case japanese = "ja"
    case korean = "ko"
    case chinese = "zh"
    case arabic = "ar"
    case hindi = "hi"
    case dutch = "nl"
    case swedish = "sv"
    case polish = "pl"
    case turkish = "tr"
    case vietnamese = "vi"
    case thai = "th"
    case indonesian = "id"
    case hebrew = "he"
    
    var displayName: String {
        switch self {
        case .english: return "English"
        case .spanish: return "Español"
        case .french: return "Français"
        case .german: return "Deutsch"
        case .italian: return "Italiano"
        case .portuguese: return "Português"
        case .russian: return "Русский"
        case .japanese: return "日本語"
        case .korean: return "한국어"
        case .chinese: return "中文"
        case .arabic: return "العربية"
        case .hindi: return "हिन्दी"
        case .dutch: return "Nederlands"
        case .swedish: return "Svenska"
        case .polish: return "Polski"
        case .turkish: return "Türkçe"
        case .vietnamese: return "Tiếng Việt"
        case .thai: return "ไทย"
        case .indonesian: return "Bahasa Indonesia"
        case .hebrew: return "עברית"
        }
    }
    
    var flag: String {
        switch self {
        case .english: return "🇬🇧"
        case .spanish: return "🇪🇸"
        case .french: return "🇫🇷"
        case .german: return "🇩🇪"
        case .italian: return "🇮🇹"
        case .portuguese: return "🇵🇹"
        case .russian: return "🇷🇺"
        case .japanese: return "🇯🇵"
        case .korean: return "🇰🇷"
        case .chinese: return "🇨🇳"
        case .arabic: return "🇸🇦"
        case .hindi: return "🇮🇳"
        case .dutch: return "🇳🇱"
        case .swedish: return "🇸🇪"
        case .polish: return "🇵🇱"
        case .turkish: return "🇹🇷"
        case .vietnamese: return "🇻🇳"
        case .thai: return "🇹🇭"
        case .indonesian: return "🇮🇩"
        case .hebrew: return "🇮🇱"
        }
    }
}

// MARK: - AI Translation Service

@MainActor
class AITranslationService: ObservableObject {
    static let shared = AITranslationService()
    
    @Published var isTranslating = false
    @Published var translations: [String: TranslationResult] = [:] // messageId -> translation
    @Published var culturalHints: [String: [CulturalHint]] = [:] // messageId -> hints
    @Published var smartReplies: [SmartReply] = []
    @Published var autoTranslateEnabled = false
    @Published var preferredLanguage: SupportedLanguage = .english
    @Published var autoTranslateUsers: Set<String> = [] // userIds to auto-translate
    
    private let apiEndpoint: String
    private var authToken: String?
    
    init() {
        // Get API endpoint from config
        if let url = Bundle.main.object(forInfoDictionaryKey: "API_GATEWAY_URL") as? String {
            self.apiEndpoint = "\(url)/translate"
        } else {
            self.apiEndpoint = "https://bnbr75tld0.execute-api.us-east-1.amazonaws.com/translate"
        }
        
        // Load preferences from UserDefaults
        loadPreferences()
    }
    
    // MARK: - Preferences Management
    
    private func loadPreferences() {
        if let langCode = UserDefaults.standard.string(forKey: "preferredLanguage"),
           let lang = SupportedLanguage(rawValue: langCode) {
            preferredLanguage = lang
        }
        
        autoTranslateEnabled = UserDefaults.standard.bool(forKey: "autoTranslateEnabled")
        
        if let users = UserDefaults.standard.array(forKey: "autoTranslateUsers") as? [String] {
            autoTranslateUsers = Set(users)
        }
    }
    
    func savePreferences() {
        UserDefaults.standard.set(preferredLanguage.rawValue, forKey: "preferredLanguage")
        UserDefaults.standard.set(autoTranslateEnabled, forKey: "autoTranslateEnabled")
        UserDefaults.standard.set(Array(autoTranslateUsers), forKey: "autoTranslateUsers")
    }
    
    func setAuthToken(_ token: String) {
        self.authToken = token
    }
    
    // MARK: - Translation Functions
    
    func translateMessage(_ text: String, to targetLang: SupportedLanguage? = nil, messageId: String) async {
        guard !text.isEmpty else { return }
        
        isTranslating = true
        defer { isTranslating = false }
        
        let target = targetLang ?? preferredLanguage
        
        do {
            let result = try await makeAPIRequest(
                action: "translate",
                text: text,
                targetLang: target.rawValue
            )
            
            if let result = result {
                translations[messageId] = result
                
                // Check for cultural context if translation has low confidence
                if let confidence = result.confidence, confidence < 0.9 {
                    await getCulturalContext(for: text, targetLang: target, messageId: messageId)
                }
            }
        } catch {
            print("Translation error: \(error)")
        }
    }
    
    func getCulturalContext(for text: String, targetLang: SupportedLanguage, messageId: String) async {
        do {
            let result = try await makeAPIRequest(
                action: "cultural_context",
                text: text,
                targetLang: targetLang.rawValue,
                sourceLang: detectLanguage(text)
            )
            
            if let hints = result?.hints {
                culturalHints[messageId] = hints
                print("🎯 Got cultural hints for \(messageId) in \(targetLang.displayName): \(hints.count) terms")
            }
        } catch {
            print("Cultural context error: \(error)")
        }
    }
    
    func adjustFormality(text: String, to level: String) async -> String? {
        do {
            let result = try await makeAPIRequest(
                action: "adjust_formality",
                text: text,
                targetLang: detectLanguage(text),
                desiredLevel: level
            )
            
            return result?.adjustedText
        } catch {
            print("Formality adjustment error: \(error)")
            return nil
        }
    }
    
    func generateSmartReplies(for conversation: [MessageData], limit: Int = 5) async {
        // Build conversation context (last 5 messages)
        let recentMessages = Array(conversation.suffix(limit))
        let context = recentMessages.map { msg in
            "\(msg.senderName ?? "User"): \(msg.content)"
        }.joined(separator: "\n")
        
        do {
            let result = try await makeAPIRequest(
                action: "smart_replies",
                text: "",
                targetLang: preferredLanguage.rawValue,
                conversationContext: context
            )
            
            if let replies = result?.replies {
                smartReplies = replies
            }
        } catch {
            print("Smart replies error: \(error)")
        }
    }
    
    // MARK: - Helper Functions
    
    private func detectLanguage(_ text: String) -> String {
        // Simple language detection based on character sets
        // In production, this would use the AI service for accurate detection
        
        let arabicCharSet = CharacterSet(charactersIn: "؀-ۿ")
        let chineseCharSet = CharacterSet(charactersIn: "一-龯")
        let japaneseCharSet = CharacterSet(charactersIn: "ぁ-ゟ゠-ヿ")
        let koreanCharSet = CharacterSet(charactersIn: "가-힣")
        let cyrillicCharSet = CharacterSet(charactersIn: "А-я")
        let hebrewCharSet = CharacterSet(charactersIn: "א-ת")
        
        if text.rangeOfCharacter(from: arabicCharSet) != nil { return "ar" }
        if text.rangeOfCharacter(from: chineseCharSet) != nil { return "zh" }
        if text.rangeOfCharacter(from: japaneseCharSet) != nil { return "ja" }
        if text.rangeOfCharacter(from: koreanCharSet) != nil { return "ko" }
        if text.rangeOfCharacter(from: cyrillicCharSet) != nil { return "ru" }
        if text.rangeOfCharacter(from: hebrewCharSet) != nil { return "he" }
        
        // Default to English for Latin scripts
        return "en"
    }
    
    private func makeAPIRequest(
        action: String,
        text: String,
        targetLang: String? = nil,
        sourceLang: String? = nil,
        desiredLevel: String? = nil,
        conversationContext: String? = nil
    ) async throws -> TranslationResult? {
        guard let authToken = authToken else {
            throw NSError(domain: "AITranslation", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        
        guard let url = URL(string: apiEndpoint) else {
            throw NSError(domain: "AITranslation", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        
        let requestBody = TranslationRequest(
            action: action,
            text: text,
            targetLang: targetLang,
            sourceLang: sourceLang,
            desiredLevel: desiredLevel,
            conversationContext: conversationContext
        )
        
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NSError(domain: "AITranslation", code: 500, userInfo: [NSLocalizedDescriptionKey: "Server error"])
        }
        
        let translationResponse = try JSONDecoder().decode(TranslationResponse.self, from: data)
        
        if !translationResponse.success {
            throw NSError(domain: "AITranslation", code: 500, 
                         userInfo: [NSLocalizedDescriptionKey: translationResponse.error ?? "Unknown error"])
        }
        
        return translationResponse.result
    }
    
    // MARK: - Auto-Translation
    
    func shouldAutoTranslate(for userId: String) -> Bool {
        return autoTranslateEnabled && autoTranslateUsers.contains(userId)
    }
    
    func toggleAutoTranslate(for userId: String) {
        if autoTranslateUsers.contains(userId) {
            autoTranslateUsers.remove(userId)
        } else {
            autoTranslateUsers.insert(userId)
        }
        savePreferences()
    }
    
    // MARK: - Clear Cache
    
    func clearTranslations() {
        translations.removeAll()
        culturalHints.removeAll()
        smartReplies.removeAll()
    }
}
