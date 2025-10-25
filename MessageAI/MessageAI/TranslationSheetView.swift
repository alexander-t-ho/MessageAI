import SwiftUI
import SwiftData

struct TranslationSheetView: View {
    let message: MessageData
    let translationType: TranslationType
    @StateObject private var aiService = AITranslationService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = false
    @State private var translation: TranslationResult?
    @State private var culturalHints: [CulturalHint] = []
    
    enum TranslationType {
        case translate
        case explainSlang
        case both
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Original Message Section
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Original Message")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                            
                            Spacer()
                            
                            Text(message.senderName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Text(message.content)
                            .font(.body)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    
                    Divider()
                    
                    // Translation Section
                    if translationType == .translate || translationType == .both {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "globe")
                                    .foregroundColor(.blue)
                                Text("Translation")
                                    .font(.headline)
                                
                                Spacer()
                                
                                if let lang = SupportedLanguage(rawValue: aiService.preferredLanguage.rawValue) {
                                    HStack(spacing: 4) {
                                        Text(lang.flag)
                                        Text(lang.displayName)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            
                            if isLoading && translation == nil {
                                HStack {
                                    ProgressView()
                                    Text("Translating...")
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                            } else if let trans = translation ?? aiService.translations[message.id] {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(trans.translatedText ?? message.content)
                                        .font(.title3)
                                        .fontWeight(.medium)
                                    
                                    if let confidence = trans.confidence {
                                        HStack {
                                            Text("Confidence:")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            ProgressView(value: confidence)
                                                .frame(width: 100)
                                            Text("\(Int(confidence * 100))%")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    
                                    if trans.fromCache == true {
                                        Label("From cache", systemImage: "clock.arrow.circlepath")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.blue.opacity(0.1))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.blue, lineWidth: 1)
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Slang Explanation Section
                    if (translationType == .explainSlang || translationType == .both) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "lightbulb.fill")
                                    .foregroundColor(.orange)
                                Text("Slang & Cultural Context")
                                    .font(.headline)
                                
                                Spacer()
                                
                                if !culturalHints.isEmpty || !(aiService.culturalHints[message.id] ?? []).isEmpty {
                                    Text("\((culturalHints.isEmpty ? aiService.culturalHints[message.id] : culturalHints)?.count ?? 0) terms")
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.orange.opacity(0.2))
                                        .foregroundColor(.orange)
                                        .cornerRadius(8)
                                }
                            }
                            
                            if isLoading && culturalHints.isEmpty {
                                HStack {
                                    ProgressView()
                                    Text("Analyzing slang...")
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                            } else {
                                let hints = culturalHints.isEmpty ? (aiService.culturalHints[message.id] ?? []) : culturalHints
                                
                                if hints.isEmpty {
                                    VStack(spacing: 8) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 40))
                                            .foregroundColor(.green)
                                        Text("No slang detected")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                        Text("This message uses standard language")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                } else {
                                    ForEach(Array(hints.enumerated()), id: \.offset) { index, hint in
                                        VStack(alignment: .leading, spacing: 8) {
                                            // Slang term header
                                            HStack {
                                                Text("\(index + 1).")
                                                    .font(.caption)
                                                    .foregroundColor(.orange)
                                                    .fontWeight(.bold)
                                                
                                                Text("\"\(hint.phrase)\"")
                                                    .font(.title3)
                                                    .fontWeight(.semibold)
                                                
                                                Spacer()
                                            }
                                            
                                            // Meaning
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text("Means:")
                                                    .font(.caption)
                                                    .foregroundColor(.orange)
                                                    .fontWeight(.semibold)
                                                    .textCase(.uppercase)
                                                
                                                Text(hint.actualMeaning)
                                                    .font(.body)
                                            }
                                            
                                            // Context/Explanation
                                            if !hint.explanation.isEmpty {
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text("Context:")
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                        .fontWeight(.semibold)
                                                        .textCase(.uppercase)
                                                    
                                                    Text(hint.explanation)
                                                        .font(.callout)
                                                        .foregroundColor(.secondary)
                                                }
                                            }
                                            
                                            // Literal meaning if different
                                            if !hint.literalMeaning.isEmpty {
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text("Literally:")
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                        .fontWeight(.semibold)
                                                        .textCase(.uppercase)
                                                    
                                                    Text(hint.literalMeaning)
                                                        .font(.callout)
                                                        .foregroundColor(.secondary)
                                                        .italic()
                                                }
                                            }
                                        }
                                        .padding()
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(Color.orange.opacity(0.1))
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                                        )
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Powered by attribution
                    HStack {
                        Spacer()
                        HStack(spacing: 4) {
                            Image(systemName: "cpu")
                                .font(.caption2)
                            Text("Powered by")
                                .font(.caption2)
                            Text(translationType == .translate ? "AI Translation" : "RAG + GPT-4")
                                .font(.caption2)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.vertical)
                }
                .padding(.vertical)
            }
            .navigationTitle(translationType == .translate ? "Translation" : translationType == .explainSlang ? "Slang Explained" : "Translation & Slang")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.medium)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: copyAll) {
                        Image(systemName: "doc.on.doc")
                    }
                }
            }
            .task {
                await loadData()
            }
        }
    }
    
    private func loadData() async {
        isLoading = true
        
        switch translationType {
        case .translate:
            await aiService.translateMessage(message.content, messageId: message.id)
            translation = aiService.translations[message.id]
            
        case .explainSlang:
            await aiService.getCulturalContext(
                for: message.content,
                targetLang: aiService.preferredLanguage,
                messageId: message.id
            )
            culturalHints = aiService.culturalHints[message.id] ?? []
            
        case .both:
            await aiService.translateMessage(message.content, messageId: message.id)
            translation = aiService.translations[message.id]
            
            await aiService.getCulturalContext(
                for: message.content,
                targetLang: aiService.preferredLanguage,
                messageId: message.id
            )
            culturalHints = aiService.culturalHints[message.id] ?? []
        }
        
        isLoading = false
    }
    
    private func copyAll() {
        var textToCopy = "Original: \(message.content)\n\n"
        
        if let trans = translation ?? aiService.translations[message.id],
           let translatedText = trans.translatedText {
            textToCopy += "Translation: \(translatedText)\n\n"
        }
        
        let hints = culturalHints.isEmpty ? (aiService.culturalHints[message.id] ?? []) : culturalHints
        if !hints.isEmpty {
            textToCopy += "Slang Explanations:\n"
            for (index, hint) in hints.enumerated() {
                textToCopy += "\(index + 1). \"\(hint.phrase)\": \(hint.actualMeaning)\n"
            }
        }
        
        UIPasteboard.general.string = textToCopy
    }
}

#Preview {
    TranslationSheetView(
        message: MessageData(
            conversationId: "test",
            senderId: "user1",
            senderName: "Test User",
            content: "Bro got major rizz no cap"
        ),
        translationType: .both
    )
}
