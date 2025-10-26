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
    
    // Profile picture (saved globally - persists across logins)
    @Published var profileImageData: Data? {
        didSet {
            if let data = profileImageData {
                UserDefaults.standard.set(data, forKey: "profileImageData")
            } else {
                UserDefaults.standard.removeObject(forKey: "profileImageData")
            }
        }
    }
    
    // Message bubble color (saved globally - persists across logins)
    @Published var messageBubbleColor: Color {
        didSet {
            saveColor(messageBubbleColor, key: "messageBubbleColor")
        }
    }
    
    // Dark mode preference (saved globally - persists across logins)
    @Published var preferredColorScheme: ColorScheme? {
        didSet {
            if let scheme = preferredColorScheme {
                UserDefaults.standard.set(scheme == .dark ? "dark" : "light", forKey: "preferredColorScheme")
            } else {
                UserDefaults.standard.removeObject(forKey: "preferredColorScheme")
            }
        }
    }
    
    private init() {
        // Load profile picture
        if let data = UserDefaults.standard.data(forKey: "profileImageData") {
            self.profileImageData = data
        } else {
            self.profileImageData = nil
        }
        
        // Load message color
        self.messageBubbleColor = UserPreferences.loadColor(key: "messageBubbleColor") ?? .blue
        
        // Load dark mode preference
        if let schemeString = UserDefaults.standard.string(forKey: "preferredColorScheme") {
            self.preferredColorScheme = schemeString == "dark" ? .dark : .light
        } else {
            self.preferredColorScheme = nil
        }
    }
    
    // Reload preferences (kept for compatibility, but now loads from global keys)
    func reloadForCurrentUser() {
        // Reload profile picture
        if let data = UserDefaults.standard.data(forKey: "profileImageData") {
            self.profileImageData = data
        } else {
            self.profileImageData = nil
        }
        
        // Reload message color
        self.messageBubbleColor = UserPreferences.loadColor(key: "messageBubbleColor") ?? .blue
        
        // Reload dark mode preference
        if let schemeString = UserDefaults.standard.string(forKey: "preferredColorScheme") {
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
                UserDefaults.standard.set(data, forKey: key)
            }
        }
    }
    
    // Load color from UserDefaults
    private static func loadColor(key: String) -> Color? {
        guard let data = UserDefaults.standard.data(forKey: key),
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

