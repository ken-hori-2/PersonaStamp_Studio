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
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    .onAppear {
                        // スプラッシュ画面を約10秒間表示（すべてのテキストアニメーションを表示）
                        DispatchQueue.main.asyncAfter(deadline: .now() + 10.5) {
                            withAnimation(
                                .easeInOut(duration: 0.8)
                            ) {
                                showSplash = false
                            }
                        }
                    }
            } else {
                Group {
                    if authManager.isAuthenticated {
                        MainTabView()
                    } else {
                        LoginView()
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
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

