//
//  ContentView.swift
//  PersonaStampStudio
//
//  Created on 2025-11-23.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authManager: AuthManager
    
    var body: some View {
        Group {
            if authManager.isAuthenticated {
                MainTabView()
            } else {
                LoginView()
            }
        }
        .onAppear {
            print("✅ ContentView appeared")
            print("🔐 isAuthenticated: \(authManager.isAuthenticated)")
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthManager())
}

