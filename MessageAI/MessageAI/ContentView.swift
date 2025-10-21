//
//  ContentView.swift
//  MessageAI
//
//  Created by Alex Ho on 10/20/25.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        ZStack {
            // Bright red background so we KNOW the app is running
            Color.red
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Image(systemName: "message.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.white)
                
                Text("Hello, World!")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("MessageAI is running! ✅")
                    .font(.title2)
                    .foregroundColor(.yellow)
                
                Text("Phase 0: Environment Setup Complete")
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding(.top, 20)
                
                Text("Ready to build your messaging app!")
                    .font(.body)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding()
                
                Text("If you see RED, it's working! 🎉")
                    .font(.headline)
                    .foregroundColor(.yellow)
                    .padding()
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(10)
            }
            .padding()
        }
    }
}

#Preview {
    ContentView()
}
