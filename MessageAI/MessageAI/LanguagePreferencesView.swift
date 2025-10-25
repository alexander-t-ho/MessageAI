import SwiftUI
import SwiftData

struct LanguagePreferencesView: View {
    @StateObject private var aiService = AITranslationService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedLanguage: SupportedLanguage
    @State private var autoTranslateEnabled: Bool
    @State private var showConfidenceScores: Bool = true
    @State private var showCulturalHints: Bool = true
    @State private var cacheEnabled: Bool = true
    @State private var defaultFormality: String = "neutral"
    
    init() {
        let service = AITranslationService.shared
        _selectedLanguage = State(initialValue: service.preferredLanguage)
        _autoTranslateEnabled = State(initialValue: service.autoTranslateEnabled)
        
        // Load additional preferences
        _showConfidenceScores = State(initialValue: UserDefaults.standard.bool(forKey: "showConfidenceScores"))
        _showCulturalHints = State(initialValue: UserDefaults.standard.bool(forKey: "showCulturalHints"))
        _cacheEnabled = State(initialValue: UserDefaults.standard.bool(forKey: "cacheEnabled"))
        _defaultFormality = State(initialValue: UserDefaults.standard.string(forKey: "defaultFormality") ?? "neutral")
    }
    
    var body: some View {
        NavigationStack {
            List {
                // Primary Language Section
                Section {
                    HStack {
                        Text("Your Language")
                            .font(.body)
                        Spacer()
                        Menu {
                            ForEach(SupportedLanguage.allCases, id: \.self) { language in
                                Button(action: {
                                    selectedLanguage = language
                                }) {
                                    Label {
                                        HStack {
                                            Text(language.displayName)
                                            if language == selectedLanguage {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    } icon: {
                                        Text(language.flag)
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Text(selectedLanguage.flag)
                                    .font(.title2)
                                Text(selectedLanguage.displayName)
                                    .foregroundColor(.primary)
                                Image(systemName: "chevron.down")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                    }
                    
                    // Language info
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Messages will be translated to this language")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("You can change this anytime")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 4)
                    
                } header: {
                    Text("Primary Language")
                } footer: {
                    Text("This is the language you prefer to read messages in. All translations will target this language.")
                }
                
                // Auto-Translation Section
                Section {
                    Toggle(isOn: $autoTranslateEnabled) {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .foregroundColor(.blue)
                            VStack(alignment: .leading) {
                                Text("Auto-Translate")
                                Text("Automatically translate incoming messages")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    if autoTranslateEnabled {
                        NavigationLink(destination: AutoTranslateUsersView()) {
                            HStack {
                                Image(systemName: "person.2")
                                    .foregroundColor(.orange)
                                VStack(alignment: .leading) {
                                    Text("Manage Users")
                                    Text("\(aiService.autoTranslateUsers.count) users selected")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                } header: {
                    Text("Auto-Translation")
                } footer: {
                    Text("Choose specific users whose messages should always be translated automatically.")
                }
                
                // Translation Features Section
                Section {
                    Toggle(isOn: $showConfidenceScores) {
                        HStack {
                            Image(systemName: "percent")
                                .foregroundColor(.green)
                            Text("Show Confidence Scores")
                        }
                    }
                    
                    Toggle(isOn: $showCulturalHints) {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.orange)
                            Text("Show Cultural Context")
                        }
                    }
                    
                    Toggle(isOn: $cacheEnabled) {
                        HStack {
                            Image(systemName: "clock.arrow.circlepath")
                                .foregroundColor(.purple)
                            Text("Cache Translations")
                        }
                    }
                    
                } header: {
                    Text("Translation Features")
                } footer: {
                    Text("Caching speeds up repeated translations and reduces costs.")
                }
                
                // Formality Settings Section
                Section {
                    Picker("Default Formality", selection: $defaultFormality) {
                        Text("Casual").tag("casual")
                        Text("Neutral").tag("neutral")
                        Text("Formal").tag("formal")
                        Text("Very Formal").tag("very_formal")
                    }
                    .pickerStyle(.menu)
                    
                } header: {
                    Text("Formality Preferences")
                } footer: {
                    Text("Set the default formality level for translated messages. You can adjust this per message.")
                }
                
                // Smart Replies Section
                Section {
                    NavigationLink(destination: SmartReplySettingsView()) {
                        HStack {
                            Image(systemName: "wand.and.stars")
                                .foregroundColor(.purple)
                            VStack(alignment: .leading) {
                                Text("Smart Reply Settings")
                                Text("Configure AI-powered quick replies")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                } header: {
                    Text("AI Features")
                }
                
                // Language Learning Section
                Section {
                    NavigationLink(destination: LanguageLearningView()) {
                        HStack {
                            Image(systemName: "book.fill")
                                .foregroundColor(.indigo)
                            VStack(alignment: .leading) {
                                Text("Language Learning Mode")
                                Text("Show original text with translations")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text("Beta")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.indigo.opacity(0.2))
                                .foregroundColor(.indigo)
                                .cornerRadius(4)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                } header: {
                    Text("Learning")
                }
                
                // About Section
                Section {
                    HStack {
                        Text("Powered by")
                        Spacer()
                        HStack(spacing: 4) {
                            Image(systemName: "cpu")
                                .font(.caption)
                            Text("Claude 3.5 Sonnet")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.blue)
                    }
                    
                    HStack {
                        Text("Languages Supported")
                        Spacer()
                        Text("20+")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Translation Accuracy")
                        Spacer()
                        Text("~95%")
                            .foregroundColor(.secondary)
                    }
                    
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Language & Translation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        savePreferences()
                        dismiss()
                    }
                    .fontWeight(.medium)
                }
            }
        }
    }
    
    private func savePreferences() {
        // Save to AITranslationService
        aiService.preferredLanguage = selectedLanguage
        aiService.autoTranslateEnabled = autoTranslateEnabled
        aiService.savePreferences()
        
        // Save additional preferences
        UserDefaults.standard.set(showConfidenceScores, forKey: "showConfidenceScores")
        UserDefaults.standard.set(showCulturalHints, forKey: "showCulturalHints")
        UserDefaults.standard.set(cacheEnabled, forKey: "cacheEnabled")
        UserDefaults.standard.set(defaultFormality, forKey: "defaultFormality")
    }
}

// MARK: - Auto-Translate Users View

struct AutoTranslateUsersView: View {
    @StateObject private var aiService = AITranslationService.shared
    @Environment(\.modelContext) private var modelContext
    @Query private var allConversations: [ConversationData]
    
    private var users: [(id: String, name: String)] {
        var uniqueUsers: [(id: String, name: String)] = []
        var seenIds = Set<String>()
        
        for conversation in allConversations {
            for (id, name) in zip(conversation.participantIds, conversation.participantNames) {
                if !seenIds.contains(id) {
                    seenIds.insert(id)
                    uniqueUsers.append((id: id, name: name))
                }
            }
        }
        
        return uniqueUsers.sorted { $0.name < $1.name }
    }
    
    var body: some View {
        List {
            Section {
                if users.isEmpty {
                    Text("No users found")
                        .foregroundColor(.secondary)
                        .italic()
                } else {
                    ForEach(users, id: \.id) { user in
                        HStack {
                            Circle()
                                .fill(Color.blue.opacity(0.2))
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Text(String(user.name.prefix(1)))
                                        .fontWeight(.medium)
                                        .foregroundColor(.blue)
                                )
                            
                            Text(user.name)
                            
                            Spacer()
                            
                            Toggle("", isOn: Binding(
                                get: { aiService.autoTranslateUsers.contains(user.id) },
                                set: { enabled in
                                    if enabled {
                                        aiService.autoTranslateUsers.insert(user.id)
                                    } else {
                                        aiService.autoTranslateUsers.remove(user.id)
                                    }
                                    aiService.savePreferences()
                                }
                            ))
                            .labelsHidden()
                        }
                        .padding(.vertical, 4)
                    }
                }
            } header: {
                Text("Select Users to Auto-Translate")
            } footer: {
                Text("Messages from selected users will automatically be translated to your preferred language.")
            }
        }
        .navigationTitle("Auto-Translate Users")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Smart Reply Settings View

struct SmartReplySettingsView: View {
    @State private var smartRepliesEnabled = UserDefaults.standard.bool(forKey: "smartRepliesEnabled")
    @State private var replyCount = UserDefaults.standard.integer(forKey: "smartReplyCount")
    @State private var learnFromStyle = UserDefaults.standard.bool(forKey: "learnFromStyle")
    @State private var includeTone = UserDefaults.standard.bool(forKey: "includeTone")
    
    var body: some View {
        List {
            Section {
                Toggle("Enable Smart Replies", isOn: $smartRepliesEnabled)
                    .onChange(of: smartRepliesEnabled) { _, newValue in
                        UserDefaults.standard.set(newValue, forKey: "smartRepliesEnabled")
                    }
                
                if smartRepliesEnabled {
                    Picker("Number of Suggestions", selection: $replyCount) {
                        Text("3 replies").tag(3)
                        Text("5 replies").tag(5)
                        Text("7 replies").tag(7)
                    }
                    .onChange(of: replyCount) { _, newValue in
                        UserDefaults.standard.set(newValue, forKey: "smartReplyCount")
                    }
                }
            } header: {
                Text("Smart Reply Options")
            } footer: {
                Text("AI will suggest contextually relevant quick replies based on your conversation.")
            }
            
            Section {
                Toggle("Learn from My Style", isOn: $learnFromStyle)
                    .onChange(of: learnFromStyle) { _, newValue in
                        UserDefaults.standard.set(newValue, forKey: "learnFromStyle")
                    }
                
                Toggle("Include Tone Indicators", isOn: $includeTone)
                    .onChange(of: includeTone) { _, newValue in
                        UserDefaults.standard.set(newValue, forKey: "includeTone")
                    }
            } header: {
                Text("Personalization")
            } footer: {
                Text("Smart replies will adapt to your communication style and show appropriate tone indicators.")
            }
        }
        .navigationTitle("Smart Reply Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Language Learning View

struct LanguageLearningView: View {
    @State private var learningModeEnabled = UserDefaults.standard.bool(forKey: "learningModeEnabled")
    @State private var showPronunciation = UserDefaults.standard.bool(forKey: "showPronunciation")
    @State private var showGrammarNotes = UserDefaults.standard.bool(forKey: "showGrammarNotes")
    
    var body: some View {
        List {
            Section {
                Toggle("Enable Learning Mode", isOn: $learningModeEnabled)
                    .onChange(of: learningModeEnabled) { _, newValue in
                        UserDefaults.standard.set(newValue, forKey: "learningModeEnabled")
                    }
                
                if learningModeEnabled {
                    Toggle("Show Pronunciation Guide", isOn: $showPronunciation)
                        .onChange(of: showPronunciation) { _, newValue in
                            UserDefaults.standard.set(newValue, forKey: "showPronunciation")
                        }
                    
                    Toggle("Show Grammar Notes", isOn: $showGrammarNotes)
                        .onChange(of: showGrammarNotes) { _, newValue in
                            UserDefaults.standard.set(newValue, forKey: "showGrammarNotes")
                        }
                }
            } header: {
                Text("Learning Options")
            } footer: {
                Text("Learning mode shows both original and translated text side-by-side to help you learn new languages.")
            }
            
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Dual Display", systemImage: "text.alignleft")
                        .font(.callout)
                        .foregroundColor(.blue)
                    Text("See original and translated text together")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Label("Interactive Learning", systemImage: "hand.tap")
                        .font(.callout)
                        .foregroundColor(.green)
                    Text("Tap words for detailed explanations")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Label("Progress Tracking", systemImage: "chart.line.uptrend.xyaxis")
                        .font(.callout)
                        .foregroundColor(.orange)
                    Text("Coming soon: Track your language learning progress")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            } header: {
                Text("Features")
            }
        }
        .navigationTitle("Language Learning")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    LanguagePreferencesView()
}
