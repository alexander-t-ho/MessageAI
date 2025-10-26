//
//  UserPreferences.swift
//  MessageAI
//
//  User customization preferences
//

import SwiftUI
import Combine

class UserPreferences: ObservableObject {
    static let shared = UserPreferences()
    
    // Profile picture
    @Published var profileImageData: Data? {
        didSet {
            if let data = profileImageData {
                UserDefaults.standard.set(data, forKey: userKey("profileImageData"))
            } else {
                UserDefaults.standard.removeObject(forKey: userKey("profileImageData"))
            }
        }
    }
    
    // Message bubble color
    @Published var messageBubbleColor: Color {
        didSet {
            saveColor(messageBubbleColor, key: "messageBubbleColor")
        }
    }
    
    // Dark mode preference
    @Published var preferredColorScheme: ColorScheme? {
        didSet {
            if let scheme = preferredColorScheme {
                UserDefaults.standard.set(scheme == .dark ? "dark" : "light", forKey: userKey("preferredColorScheme"))
            } else {
                UserDefaults.standard.removeObject(forKey: userKey("preferredColorScheme"))
            }
        }
    }
    
    private init() {
        // Initialize with defaults first
        self.profileImageData = nil
        self.messageBubbleColor = .blue
        self.preferredColorScheme = nil
        
        // Then load saved preferences
        self.reloadForCurrentUser()
    }
    
    // Helper to create user-specific keys
    private func userKey(_ key: String) -> String {
        if let userId = UserDefaults.standard.string(forKey: "userId") {
            return "\(userId)_\(key)"
        }
        return key // Fallback to global key
    }
    
    // Reload preferences when user logs in
    func reloadForCurrentUser() {
        // Reload profile picture
        if let data = UserDefaults.standard.data(forKey: userKey("profileImageData")) {
            self.profileImageData = data
        } else {
            self.profileImageData = nil
        }
        
        // Reload message color
        self.messageBubbleColor = self.loadColor(key: "messageBubbleColor") ?? .blue
        
        // Reload dark mode preference
        if let schemeString = UserDefaults.standard.string(forKey: userKey("preferredColorScheme")) {
            self.preferredColorScheme = schemeString == "dark" ? .dark : .light
        } else {
            self.preferredColorScheme = nil
        }
    }
    
    // Save color to UserDefaults
    private func saveColor(_ color: Color, key: String) {
        if let components = UIColor(color).cgColor.components, components.count >= 3 {
            let colorData: [String: Double] = [
                "red": Double(components[0]),
                "green": Double(components[1]),
                "blue": Double(components[2]),
                "alpha": components.count == 4 ? Double(components[3]) : 1.0
            ]
            if let data = try? JSONEncoder().encode(colorData) {
                UserDefaults.standard.set(data, forKey: userKey(key))
            }
        }
    }
    
    // Load color from UserDefaults with user-specific key
    private func loadColor(key: String) -> Color? {
        guard let data = UserDefaults.standard.data(forKey: userKey(key)),
              let colorData = try? JSONDecoder().decode([String: Double].self, from: data),
              let red = colorData["red"],
              let green = colorData["green"],
              let blue = colorData["blue"] else {
            return nil
        }
        let alpha = colorData["alpha"] ?? 1.0
        return Color(red: red, green: green, blue: blue, opacity: alpha)
    }
}

