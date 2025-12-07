//
//  ContentView.swift
//  RendVu
//
//  Created on 2025-11-23.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var showSplash = true
    
    var body: some View {
        Group {
            if showSplash {
                SplashView()
                    .onAppear {
                        // スプラッシュ画面を2秒間表示
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            withAnimation {
                                showSplash = false
                            }
                        }
                    }
            } else {
                if authManager.isAuthenticated {
                    MainTabView()
                } else {
                    LoginView()
                }
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

