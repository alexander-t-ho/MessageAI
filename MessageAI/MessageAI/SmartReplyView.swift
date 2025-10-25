import SwiftUI

struct SmartReplyView: View {
    @Binding var messageText: String
    @StateObject private var aiService = AITranslationService.shared
    let conversation: ConversationData
    let messages: [MessageData]
    
    @State private var isGenerating = false
    @State private var showAllReplies = false
    @State private var selectedReplyIndex: Int? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isGenerating {
                generatingView
            } else if !aiService.smartReplies.isEmpty {
                repliesView
            } else if messages.count > 2 {
                generateButton
            }
        }
        .animation(.easeInOut(duration: 0.3), value: aiService.smartReplies.count)
    }
    
    @ViewBuilder
    private var generatingView: some View {
        HStack(spacing: 8) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(0.8)
            
            Text("Generating smart replies...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private var generateButton: some View {
        Button(action: { generateSmartReplies() }) {
            HStack(spacing: 6) {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 12))
                
                Text("Suggest replies")
                    .font(.caption)
                
                Text("AI")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(
                        LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.white)
                    .cornerRadius(4)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private var repliesView: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12))
                        .foregroundColor(.purple)
                    
                    Text("Smart Replies")
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    if let lang = SupportedLanguage(rawValue: aiService.preferredLanguage.rawValue) {
                        Text(lang.flag)
                            .font(.caption2)
                    }
                }
                
                Spacer()
                
                Button(action: { 
                    aiService.smartReplies.removeAll()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                
                Button(action: { generateSmartReplies() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12))
                        .foregroundColor(.blue)
                }
            }
            .padding(.bottom, 4)
            
            // Reply chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(aiService.smartReplies.enumerated()), id: \.offset) { index, reply in
                        SmartReplyChip(
                            reply: reply,
                            isSelected: selectedReplyIndex == index,
                            action: {
                                selectReply(reply, at: index)
                            }
                        )
                    }
                }
            }
            
            // Show/Hide more replies
            if aiService.smartReplies.count > 3 && !showAllReplies {
                Button(action: { showAllReplies = true }) {
                    Text("Show \(aiService.smartReplies.count - 3) more")
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func generateSmartReplies() {
        isGenerating = true
        Task {
            await aiService.generateSmartReplies(for: messages)
            isGenerating = false
        }
    }
    
    private func selectReply(_ reply: SmartReply, at index: Int) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            if selectedReplyIndex == index {
                // If already selected, use it
                messageText = reply.text
                selectedReplyIndex = nil
                aiService.smartReplies.removeAll()
            } else {
                // Show preview
                selectedReplyIndex = index
                messageText = reply.text
            }
        }
    }
}

struct SmartReplyChip: View {
    let reply: SmartReply
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isPressed = false
    
    private var toneIcon: String {
        switch reply.tone {
        case "casual": return "face.smiling"
        case "formal": return "briefcase"
        case "very_formal": return "building.columns"
        default: return "bubble.left"
        }
    }
    
    private var toneColor: Color {
        switch reply.tone {
        case "casual": return .green
        case "formal": return .blue
        case "very_formal": return .purple
        default: return .gray
        }
    }
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: toneIcon)
                        .font(.system(size: 10))
                        .foregroundColor(toneColor)
                    
                    Text(reply.tone.capitalized)
                        .font(.system(size: 10))
                        .fontWeight(.medium)
                        .foregroundColor(toneColor)
                }
                
                Text(reply.text)
                    .font(.caption)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                if !reply.intent.isEmpty {
                    Text(reply.intent)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                        .italic()
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: 200)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? toneColor.opacity(0.15) : Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? toneColor : Color(.systemGray4), lineWidth: 1)
                    )
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0.1, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

// Language selector for preferences
struct LanguageSelector: View {
    @StateObject private var aiService = AITranslationService.shared
    @State private var showingLanguagePicker = false
    
    var body: some View {
        Button(action: { showingLanguagePicker = true }) {
            HStack(spacing: 6) {
                Text(aiService.preferredLanguage.flag)
                    .font(.title3)
                Text(aiService.preferredLanguage.displayName)
                    .font(.caption)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
        .sheet(isPresented: $showingLanguagePicker) {
            NavigationView {
                List {
                    Section {
                        Toggle("Auto-translate messages", isOn: $aiService.autoTranslateEnabled)
                            .onChange(of: aiService.autoTranslateEnabled) { _, _ in
                                aiService.savePreferences()
                            }
                    }
                    
                    Section("Preferred Language") {
                        ForEach(SupportedLanguage.allCases, id: \.self) { language in
                            Button(action: {
                                aiService.preferredLanguage = language
                                aiService.savePreferences()
                                showingLanguagePicker = false
                            }) {
                                HStack {
                                    Text(language.flag)
                                        .font(.title2)
                                    
                                    VStack(alignment: .leading) {
                                        Text(language.displayName)
                                            .foregroundColor(.primary)
                                        Text(language.rawValue.uppercased())
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    if language == aiService.preferredLanguage {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                            .fontWeight(.medium)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                .navigationTitle("Translation Settings")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") { showingLanguagePicker = false }
                    }
                }
            }
        }
    }
}

// Auto-translate toggle for specific users
struct AutoTranslateToggle: View {
    let userId: String
    let userName: String
    @StateObject private var aiService = AITranslationService.shared
    
    var body: some View {
        Toggle(isOn: Binding(
            get: { aiService.autoTranslateUsers.contains(userId) },
            set: { enabled in
                if enabled {
                    aiService.autoTranslateUsers.insert(userId)
                } else {
                    aiService.autoTranslateUsers.remove(userId)
                }
                aiService.savePreferences()
            }
        )) {
            HStack {
                Image(systemName: "globe")
                    .foregroundColor(.blue)
                Text("Auto-translate \(userName)")
                    .font(.caption)
            }
        }
        .toggleStyle(SwitchToggleStyle(tint: .blue))
    }
}
