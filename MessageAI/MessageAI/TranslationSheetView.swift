import SwiftUI
import SwiftData

struct TranslationSheetView: View {
    let message: MessageData
    let translationType: TranslationType
    @StateObject private var aiService = AITranslationService.shared
    @EnvironmentObject var webSocketService: WebSocketService
    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = false
    @State private var translation: TranslationResult?
    @State private var culturalHints: [CulturalHint] = []
    @State private var loadingTimer: Timer?
    
    enum TranslationType {
        case translate
        case explainSlang
        case both
    }
    
    private var hintsCount: Int {
        culturalHints.isEmpty ? (aiService.culturalHints[message.id] ?? []).count : culturalHints.count
    }
    
    private var currentHints: [CulturalHint] {
        culturalHints.isEmpty ? (aiService.culturalHints[message.id] ?? []) : culturalHints
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    originalMessageSection
                    Divider()
                    
                    if translationType == .translate || translationType == .both {
                        translationSection
                    }
                    
                    if translationType == .explainSlang || translationType == .both {
                        slangSection
                    }
                    
                    poweredBySection
                }
                .padding(.vertical)
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }.fontWeight(.medium)
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
            .onChange(of: aiService.culturalHints[message.id]) { oldValue, newValue in
                if let hints = newValue {
                    culturalHints = hints
                    isLoading = false
                    loadingTimer?.invalidate()
                }
            }
            .onDisappear {
                loadingTimer?.invalidate()
            }
        }
    }
    
    private var navigationTitle: String {
        switch translationType {
        case .translate: return "Translation"
        case .explainSlang: return "Slang Explained"
        case .both: return "Translation & Slang"
        }
    }
    
    @ViewBuilder
    private var originalMessageSection: some View {
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
    }
    
    @ViewBuilder
    private var translationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            translationHeader
            
            if isLoading && translation == nil {
                loadingView(text: "Translating...")
            } else if let trans = translation ?? aiService.translations[message.id] {
                translationContent(trans)
            }
        }
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private var translationHeader: some View {
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
    }
    
    @ViewBuilder
    private func translationContent(_ trans: TranslationResult) -> some View {
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
    
    @ViewBuilder
    private var slangSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            slangHeader
            
            if isLoading && culturalHints.isEmpty {
                loadingView(text: "Analyzing slang...")
            } else if currentHints.isEmpty {
                noSlangView
            } else {
                slangCardsView
            }
        }
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private var slangHeader: some View {
        HStack {
            Image(systemName: "lightbulb.fill")
                .foregroundColor(.orange)
            Text("Slang & Cultural Context")
                .font(.headline)
            
            Spacer()
            
            if hintsCount > 0 {
                Text("\(hintsCount) terms")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.2))
                    .foregroundColor(.orange)
                    .cornerRadius(8)
            }
        }
    }
    
    @ViewBuilder
    private func loadingView(text: String) -> some View {
        HStack {
            ProgressView()
            Text(text)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
    
    @ViewBuilder
    private var noSlangView: some View {
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
    }
    
    @ViewBuilder
    private var slangCardsView: some View {
        ForEach(Array(currentHints.enumerated()), id: \.offset) { index, hint in
            slangCard(index: index, hint: hint)
        }
    }
    
    @ViewBuilder
    private func slangCard(index: Int, hint: CulturalHint) -> some View {
        VStack(alignment: .leading, spacing: 8) {
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
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Means:")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .fontWeight(.semibold)
                    .textCase(.uppercase)
                
                Text(hint.actualMeaning)
                    .font(.body)
            }
            
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
    
    @ViewBuilder
    private var poweredBySection: some View {
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
    
    private func loadData() async {
        isLoading = true
        
        switch translationType {
        case .translate:
            await aiService.translateMessage(message.content, messageId: message.id)
            translation = aiService.translations[message.id]
            isLoading = false
            
        case .explainSlang:
            aiService.getCulturalContext(
                for: message.content,
                targetLang: aiService.preferredLanguage,
                messageId: message.id,
                webSocketService: webSocketService
            )
            startLoadingTimeout()
            
        case .both:
            await aiService.translateMessage(message.content, messageId: message.id)
            translation = aiService.translations[message.id]
            
            aiService.getCulturalContext(
                for: message.content,
                targetLang: aiService.preferredLanguage,
                messageId: message.id,
                webSocketService: webSocketService
            )
            startLoadingTimeout()
        }
    }
    
    private func startLoadingTimeout() {
        loadingTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { _ in
            if aiService.culturalHints[message.id] != nil {
                culturalHints = aiService.culturalHints[message.id] ?? []
                isLoading = false
            } else {
                isLoading = false
                print("⏱️ Slang explanation timeout")
            }
        }
    }
    
    private func copyAll() {
        var textToCopy = "Original: \(message.content)\n\n"
        
        if let trans = translation ?? aiService.translations[message.id],
           let translatedText = trans.translatedText {
            textToCopy += "Translation: \(translatedText)\n\n"
        }
        
        if !currentHints.isEmpty {
            textToCopy += "Slang Explanations:\n"
            for (index, hint) in currentHints.enumerated() {
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