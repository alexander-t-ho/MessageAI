//
//  ProfileCustomizationView.swift
//  MessageAI
//
//  Profile picture, message color, and dark mode settings
//

import SwiftUI
import PhotosUI

struct ProfileCustomizationView: View {
    @StateObject private var preferences = UserPreferences.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showColorPicker = false
    
    var body: some View {
        NavigationStack {
            List {
                // Profile Picture Section
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 16) {
                            // Profile picture display
                            if let imageData = preferences.profileImageData,
                               let uiImage = UIImage(data: imageData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 120, height: 120)
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle()
                                            .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                                    )
                            } else {
                                // Default avatar
                                Circle()
                                    .fill(preferences.messageBubbleColor.opacity(0.2))
                                    .frame(width: 120, height: 120)
                                    .overlay(
                                        Image(systemName: "person.fill")
                                            .font(.system(size: 50))
                                            .foregroundColor(preferences.messageBubbleColor)
                                    )
                                    .overlay(
                                        Circle()
                                            .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                                    )
                            }
                            
                            // Photo picker button
                            PhotosPicker(selection: $selectedPhoto,
                                       matching: .images) {
                                Label(preferences.profileImageData == nil ? "Add Photo" : "Change Photo", 
                                     systemImage: "camera.fill")
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
                            }
                            
                            // Remove photo button
                            if preferences.profileImageData != nil {
                                Button(action: {
                                    preferences.profileImageData = nil
                                }) {
                                    Text("Remove Photo")
                                        .font(.subheadline)
                                        .foregroundColor(.red)
                                }
                            }
                        }
                        Spacer()
                    }
                    .padding(.vertical, 20)
                } header: {
                    Text("Profile Picture")
                }
                
                // Message Color Section
                Section {
                    Button(action: { showColorPicker = true }) {
                        HStack {
                            Text("Message Bubble Color")
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            // Color preview
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(preferences.messageBubbleColor)
                                    .frame(width: 30, height: 30)
                                
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    
                    // Preview message bubble
                    HStack {
                        Spacer()
                        Text("Preview")
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(preferences.messageBubbleColor)
                            .foregroundColor(.white)
                            .cornerRadius(20)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Appearance")
                } footer: {
                    Text("Choose your message bubble color")
                }
                
                // Dark Mode Section
                Section {
                    HStack {
                        Image(systemName: "moon.fill")
                            .foregroundColor(.purple)
                        Text("Dark Mode")
                        
                        Spacer()
                        
                        Picker("", selection: $preferences.preferredColorScheme) {
                            Text("System").tag(nil as ColorScheme?)
                            Text("Light").tag(ColorScheme.light as ColorScheme?)
                            Text("Dark").tag(ColorScheme.dark as ColorScheme?)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 200)
                    }
                } header: {
                    Text("Theme")
                } footer: {
                    Text("Choose your preferred app theme")
                }
                
                // Reset Section
                Section {
                    Button(action: resetToDefaults) {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Reset to Defaults")
                        }
                        .foregroundColor(.red)
                    }
                } footer: {
                    Text("Reset all customization settings to defaults")
                }
            }
            .navigationTitle("Customize Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showColorPicker) {
                ColorPickerView(selectedColor: $preferences.messageBubbleColor)
            }
            .onChange(of: selectedPhoto) { _, newValue in
                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self) {
                        preferences.profileImageData = data
                        print("✅ Profile picture updated")
                    }
                }
            }
        }
    }
    
    private func resetToDefaults() {
        preferences.profileImageData = nil
        preferences.messageBubbleColor = .blue
        preferences.preferredColorScheme = nil
        print("🔄 Reset to defaults")
    }
}

// MARK: - Color Picker with Wheel

struct ColorPickerView: View {
    @Binding var selectedColor: Color
    @Environment(\.dismiss) private var dismiss
    @State private var hue: Double = 0.5
    @State private var saturation: Double = 0.8
    @State private var brightness: Double = 0.9
    
    // Predefined color options
    let presetColors: [Color] = [
        .blue, .green, .orange, .red, .purple, .pink,
        .indigo, .teal, .cyan, .mint, .yellow, .brown
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 30) {
                    // Color wheel
                    VStack(spacing: 20) {
                        Text("Color Wheel")
                            .font(.headline)
                        
                        ZStack {
                            // Color wheel background
                            Circle()
                                .fill(
                                    AngularGradient(
                                        gradient: Gradient(colors: colorWheelGradient()),
                                        center: .center
                                    )
                                )
                                .frame(width: 250, height: 250)
                            
                            // Brightness overlay
                            Circle()
                                .fill(
                                    RadialGradient(
                                        gradient: Gradient(colors: [
                                            Color.white.opacity(1 - brightness),
                                            Color.clear
                                        ]),
                                        center: .center,
                                        startRadius: 0,
                                        endRadius: 125
                                    )
                                )
                                .frame(width: 250, height: 250)
                            
                            // Saturation overlay
                            Circle()
                                .fill(
                                    RadialGradient(
                                        gradient: Gradient(colors: [
                                            Color.gray.opacity(1 - saturation),
                                            Color.clear
                                        ]),
                                        center: .center,
                                        startRadius: 0,
                                        endRadius: 125
                                    )
                                )
                                .frame(width: 250, height: 250)
                            
                            // Selected color indicator
                            Circle()
                                .fill(currentColor)
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: 3)
                                        .shadow(radius: 2)
                                )
                        }
                        
                        // Sliders
                        VStack(spacing: 16) {
                            HStack {
                                Text("Hue")
                                    .frame(width: 80, alignment: .leading)
                                Slider(value: $hue, in: 0...1)
                                    .tint(currentColor)
                            }
                            
                            HStack {
                                Text("Saturation")
                                    .frame(width: 80, alignment: .leading)
                                Slider(value: $saturation, in: 0...1)
                                    .tint(currentColor)
                            }
                            
                            HStack {
                                Text("Brightness")
                                    .frame(width: 80, alignment: .leading)
                                Slider(value: $brightness, in: 0...1)
                                    .tint(currentColor)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding()
                    
                    Divider()
                    
                    // Preset colors
                    VStack(spacing: 16) {
                        Text("Preset Colors")
                            .font(.headline)
                        
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 16) {
                            ForEach(presetColors, id: \.self) { color in
                                Button(action: {
                                    selectedColor = color
                                    dismiss()
                                }) {
                                    Circle()
                                        .fill(color)
                                        .frame(width: 50, height: 50)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                                        )
                                        .overlay(
                                            // Checkmark if selected
                                            Group {
                                                if colorsAreEqual(color, selectedColor) {
                                                    Image(systemName: "checkmark.circle.fill")
                                                        .foregroundColor(.white)
                                                        .font(.title2)
                                                        .shadow(radius: 2)
                                                }
                                            }
                                        )
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Preview section
                    VStack(spacing: 12) {
                        Text("Preview")
                            .font(.headline)
                        
                        Text("Your message bubble")
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(currentColor)
                            .foregroundColor(.white)
                            .cornerRadius(20)
                    }
                    .padding()
                }
            }
            .navigationTitle("Choose Color")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        selectedColor = currentColor
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private var currentColor: Color {
        Color(hue: hue, saturation: saturation, brightness: brightness)
    }
    
    private func colorWheelGradient() -> [Color] {
        var colors: [Color] = []
        for i in 0..<360 {
            colors.append(Color(hue: Double(i) / 360.0, saturation: 1.0, brightness: 1.0))
        }
        return colors
    }
    
    private func colorsAreEqual(_ color1: Color, _ color2: Color) -> Bool {
        let ui1 = UIColor(color1)
        let ui2 = UIColor(color2)
        
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        
        ui1.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        ui2.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        
        return abs(r1 - r2) < 0.01 && abs(g1 - g2) < 0.01 && abs(b1 - b2) < 0.01
    }
}

#Preview {
    ProfileCustomizationView()
}

