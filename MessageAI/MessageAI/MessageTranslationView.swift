import SwiftUI
import SwiftData

struct MessageTranslationView: View {
    let message: MessageData
    let isFromCurrentUser: Bool
    @StateObject private var aiService = AITranslationService.shared
    @State private var showTranslation = false
    @State private var showCulturalHints = false
    @State private var isTranslating = false
    @State private var selectedFormality: String = "neutral"
    
    private var hasTranslation: Bool {
        aiService.translations[message.id] != nil
    }
    
    private var hasCulturalHints: Bool {
        !(aiService.culturalHints[message.id] ?? []).isEmpty
    }
    
    var body: some View {
        VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 8) {
            // Original message bubble
            messageContent
            
            // Translation controls
            if !isFromCurrentUser {
                translationControls
            }
            
            // Translated text
            if showTranslation, let translation = aiService.translations[message.id] {
                translatedContent(translation)
            }
            
            // Cultural hints
            if showCulturalHints, let hints = aiService.culturalHints[message.id] {
                culturalHintsView(hints)
            }
        }
    }
    
    @ViewBuilder
    private var messageContent: some View {
        VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
            // Reply indicator
            if let replyTo = message.replyToMessageId {
                ReplyIndicatorView(
                    replyToMessageId: replyTo,
                    isFromCurrentUser: isFromCurrentUser
                )
            }
            
            // Main message content
            Text(message.content)
                .foregroundColor(isFromCurrentUser ? .white : .primary)
                .contextMenu {
                    if !isFromCurrentUser {
                        Button(action: { translateMessage() }) {
                            Label("Translate", systemImage: "globe")
                        }
                        
                        if hasTranslation {
                            Menu("Adjust Formality") {
                                Button("Casual") { adjustFormality("casual") }
                                Button("Neutral") { adjustFormality("neutral") }
                                Button("Formal") { adjustFormality("formal") }
                                Button("Very Formal") { adjustFormality("very_formal") }
                            }
                        }
                    }
                    
                    Button(action: { copyToClipboard() }) {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                }
            
            // Timestamp and status
            HStack(spacing: 4) {
                if let editedAt = message.editedAt {
                    Text("Edited")
                        .font(.caption2)
                        .foregroundColor(isFromCurrentUser ? .white.opacity(0.7) : .gray)
                }
                
                Text(formatTimestamp(message.timestamp))
                    .font(.caption2)
                    .foregroundColor(isFromCurrentUser ? .white.opacity(0.7) : .gray)
                
                if isFromCurrentUser {
                    messageStatusIndicator
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            isFromCurrentUser ? Color.blue : Color(.systemGray5)
        )
        .cornerRadius(16)
    }
    
    @ViewBuilder
    private var translationControls: some View {
        HStack(spacing: 12) {
            // Translate button
            Button(action: { translateMessage() }) {
                HStack(spacing: 4) {
                    Image(systemName: "globe")
                        .font(.system(size: 12))
                    Text(hasTranslation && showTranslation ? "Hide" : "Translate")
                        .font(.caption)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.1))
                .foregroundColor(.blue)
                .cornerRadius(12)
                .overlay(
                    isTranslating ? ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(0.5) : nil
                )
            }
            .disabled(isTranslating)
            
            // Cultural hints indicator
            if hasCulturalHints {
                Button(action: { showCulturalHints.toggle() }) {
                    HStack(spacing: 2) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 12))
                        Text("Context")
                            .font(.caption)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.1))
                    .foregroundColor(.orange)
                    .cornerRadius(12)
                }
            }
            
            // Language indicator
            if let translation = aiService.translations[message.id],
               let detectedLang = translation.detectedLanguage {
                Text(languageFlag(for: detectedLang))
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            }
        }
    }
    
    @ViewBuilder
    private func translatedContent(_ translation: TranslationResult) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "arrow.turn.down.right")
                    .font(.system(size: 10))
                    .foregroundColor(.blue)
                
                Text("Translated to \(aiService.preferredLanguage.displayName)")
                    .font(.caption2)
                    .foregroundColor(.blue)
                
                if translation.fromCache == true {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                }
            }
            
            Text(translation.translatedText ?? message.content)
                .foregroundColor(.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.05))
                .cornerRadius(12)
                .contextMenu {
                    Button(action: { copyTranslation(translation.translatedText ?? "") }) {
                        Label("Copy Translation", systemImage: "doc.on.doc")
                    }
                    
                    Menu("Adjust Formality") {
                        Button("Casual") { adjustFormality("casual") }
                        Button("Neutral") { adjustFormality("neutral") }
                        Button("Formal") { adjustFormality("formal") }
                        Button("Very Formal") { adjustFormality("very_formal") }
                    }
                }
            
            // Confidence indicator
            if let confidence = translation.confidence {
                HStack(spacing: 4) {
                    Text("Confidence:")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    
                    ProgressView(value: confidence)
                        .progressViewStyle(LinearProgressViewStyle())
                        .frame(width: 50)
                        .scaleEffect(0.7)
                    
                    Text("\(Int(confidence * 100))%")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
        }
        .transition(.scale.combined(with: .opacity))
    }
    
    @ViewBuilder
    private func culturalHintsView(_ hints: [CulturalHint]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.orange)
                
                Text("Cultural Context")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.orange)
            }
            
            ForEach(hints, id: \.phrase) { hint in
                VStack(alignment: .leading, spacing: 4) {
                    Text("**\"\(hint.phrase)\"**")
                        .font(.caption)
                    
                    if !hint.literalMeaning.isEmpty {
                        HStack(alignment: .top, spacing: 4) {
                            Text("Literal:")
                                .font(.caption2)
                                .foregroundColor(.gray)
                                .fontWeight(.medium)
                            Text(hint.literalMeaning)
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    HStack(alignment: .top, spacing: 4) {
                        Text("Means:")
                            .font(.caption2)
                            .foregroundColor(.orange)
                            .fontWeight(.medium)
                        Text(hint.actualMeaning)
                            .font(.caption2)
                            .foregroundColor(.primary)
                    }
                    
                    if !hint.explanation.isEmpty {
                        Text(hint.explanation)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .italic()
                    }
                    
                    Divider()
                        .opacity(0.3)
                }
            }
        }
        .padding(10)
        .background(Color.orange.opacity(0.05))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.orange.opacity(0.2), lineWidth: 1)
        )
    }
    
    @ViewBuilder
    private var messageStatusIndicator: some View {
        if message.isEdited {
            // Message has been edited - could show edited indicator if needed
        } else if !message.readByUserNames.isEmpty {
            // Group chat read receipts
            HStack(spacing: -8) {
                ForEach(Array(message.readByUserNames.prefix(3)), id: \.self) { userName in
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 16, height: 16)
                        .overlay(
                            Text(String(userName.prefix(1)))
                                .font(.system(size: 10))
                                .foregroundColor(.white)
                        )
                }
                if message.readByUserNames.count > 3 {
                    Text("+\(message.readByUserNames.count - 3)")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.leading, 4)
                }
            }
        } else {
            // Standard status indicators
            Image(systemName: statusIcon(for: message.status))
                .font(.system(size: 10))
                .foregroundColor(statusColor(for: message.status))
        }
    }
    
    // MARK: - Helper Functions
    
    private func translateMessage() {
        if hasTranslation && showTranslation {
            showTranslation = false
        } else {
            showTranslation = true
            if !hasTranslation {
                isTranslating = true
                Task {
                    await aiService.translateMessage(
                        message.content,
                        messageId: message.id
                    )
                    isTranslating = false
                    
                    // Check for cultural context
                    await aiService.getCulturalContext(
                        for: message.content,
                        targetLang: aiService.preferredLanguage,
                        messageId: message.id
                    )
                }
            }
        }
    }
    
    private func adjustFormality(_ level: String) {
        selectedFormality = level
        isTranslating = true
        
        Task {
            let textToAdjust = aiService.translations[message.id]?.translatedText ?? message.content
            if let adjustedText = await aiService.adjustFormality(text: textToAdjust, to: level) {
                // Update the translation with adjusted text
                var updatedTranslation = aiService.translations[message.id] ?? TranslationResult(
                    translatedText: adjustedText,
                    detectedLanguage: nil,
                    confidence: 1.0,
                    fromCache: false,
                    hasContext: nil,
                    hints: nil,
                    adjustedText: nil,
                    originalLevel: nil,
                    changes: nil,
                    replies: nil
                )
                
                // Create new result with adjusted text
                aiService.translations[message.id] = TranslationResult(
                    translatedText: adjustedText,
                    detectedLanguage: updatedTranslation.detectedLanguage,
                    confidence: updatedTranslation.confidence,
                    fromCache: false,
                    hasContext: updatedTranslation.hasContext,
                    hints: updatedTranslation.hints,
                    adjustedText: adjustedText,
                    originalLevel: "neutral",
                    changes: ["Formality adjusted to \(level)"],
                    replies: updatedTranslation.replies
                )
            }
            isTranslating = false
        }
    }
    
    private func copyToClipboard() {
        UIPasteboard.general.string = message.content
    }
    
    private func copyTranslation(_ text: String) {
        UIPasteboard.general.string = text
    }
    
    private func languageFlag(for code: String) -> String {
        if let lang = SupportedLanguage(rawValue: code) {
            return "\(lang.flag) \(lang.displayName)"
        }
        return "🌐 \(code.uppercased())"
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        
        if calendar.isDateInToday(date) {
            formatter.dateFormat = "h:mm a"
        } else {
            formatter.dateFormat = "MMM d, h:mm a"
        }
        
        return formatter.string(from: date)
    }
    
    private func statusIcon(for status: String) -> String {
        switch status {
        case "sending": return "arrow.up.circle"
        case "sent": return "checkmark"
        case "delivered": return "checkmark.circle"
        case "read": return "checkmark.circle.fill"
        case "failed": return "exclamationmark.circle"
        default: return "questionmark.circle"
        }
    }
    
    private func statusColor(for status: String) -> Color {
        switch status {
        case "sending": return .gray
        case "sent": return .gray
        case "delivered": return .gray
        case "read": return .blue
        case "failed": return .red
        default: return .gray
        }
    }
}

// Reply Indicator View (referenced from original)
struct ReplyIndicatorView: View {
    let replyToMessageId: String
    let isFromCurrentUser: Bool
    @Query private var allMessages: [MessageData]
    
    private var replyToMessage: MessageData? {
        allMessages.first { $0.id == replyToMessageId }
    }
    
    var body: some View {
        if let replyMessage = replyToMessage {
            HStack(spacing: 4) {
                Rectangle()
                    .fill(Color.blue.opacity(0.5))
                    .frame(width: 3)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(replyMessage.senderName ?? "Unknown")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(isFromCurrentUser ? .white.opacity(0.8) : .secondary)
                    
                    Text(replyMessage.content)
                        .font(.caption)
                        .foregroundColor(isFromCurrentUser ? .white.opacity(0.7) : .secondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                isFromCurrentUser ? 
                Color.white.opacity(0.1) : 
                Color.black.opacity(0.05)
            )
            .cornerRadius(8)
        }
    }
}
