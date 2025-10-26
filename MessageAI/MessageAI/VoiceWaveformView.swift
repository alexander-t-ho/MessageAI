//
//  VoiceWaveformView.swift
//  Cloudy
//
//  Animated waveform for voice message recording
//

import SwiftUI

struct VoiceWaveformView: View {
    let audioLevel: Float
    let isRecording: Bool
    
    @State private var animationPhase: CGFloat = 0
    
    private let barCount = 30
    private let barWidth: CGFloat = 3
    private let barSpacing: CGFloat = 2
    
    var body: some View {
        HStack(spacing: barSpacing) {
            ForEach(0..<barCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: barWidth / 2)
                    .fill(Color.blue)
                    .frame(width: barWidth, height: barHeight(for: index))
                    .animation(
                        .easeInOut(duration: 0.3)
                        .delay(Double(index) * 0.01),
                        value: audioLevel
                    )
            }
        }
        .frame(height: 50)
        .onAppear {
            if isRecording {
                withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                    animationPhase = 1
                }
            }
        }
    }
    
    private func barHeight(for index: Int) -> CGFloat {
        let baseHeight: CGFloat = 4
        let maxHeight: CGFloat = 50
        
        if !isRecording {
            return baseHeight
        }
        
        // Create wave pattern based on index and audio level
        let normalizedIndex = CGFloat(index) / CGFloat(barCount)
        let waveOffset = sin(normalizedIndex * .pi * 4 + animationPhase * .pi * 2)
        
        // Use audio level to modulate height
        let levelMultiplier = CGFloat(audioLevel) * 0.8 + 0.2 // 0.2 to 1.0
        let height = baseHeight + (maxHeight - baseHeight) * abs(waveOffset) * levelMultiplier
        
        return max(baseHeight, height)
    }
}

#Preview {
    VStack(spacing: 20) {
        VoiceWaveformView(audioLevel: 0.3, isRecording: true)
        VoiceWaveformView(audioLevel: 0.7, isRecording: true)
        VoiceWaveformView(audioLevel: 0.0, isRecording: false)
    }
    .padding()
}

