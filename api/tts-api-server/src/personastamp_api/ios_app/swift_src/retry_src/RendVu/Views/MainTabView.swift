//
//  MainTabView.swift
//  RendVu
//
//  Created on 2025-11-23.
//

import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var authManager: AuthManager
    
    var body: some View {
        TabView {
            VoiceCloneView()
                .tabItem {
                    Label("Voice Clone", systemImage: "waveform")
                }
            
            TTSView()
                .tabItem {
                    Label("TTS", systemImage: "text.bubble")
                }
            
            ModelsView()
                .tabItem {
                    Label("Models", systemImage: "list.bullet")
                }
            
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.circle")
                }
        }
        .environmentObject(authManager)
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthManager())
}

