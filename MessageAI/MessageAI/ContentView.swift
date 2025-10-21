//
//  ContentView.swift
//  MessageAI
//
//  Created by Alex Ho on 10/20/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var authViewModel = AuthViewModel()
    
    var body: some View {
        Group {
            if authViewModel.isAuthenticated {
                HomeView()
                    .environmentObject(authViewModel)
            } else {
                AuthenticationView()
                    .environmentObject(authViewModel)
            }
        }
    }
}

#Preview {
    ContentView()
}
