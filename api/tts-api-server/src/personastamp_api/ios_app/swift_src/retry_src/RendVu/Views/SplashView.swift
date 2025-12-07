//
//  SplashView.swift
//  RendVu
//
//  Created on 2025-12-07.
//

import SwiftUI
import UIKit

struct SplashView: View {
    @State private var isAnimating = false
    @State private var opacity: Double = 0
    
    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // アプリアイコン
                if let imagePath = Bundle.main.path(forResource: "ios_icon_rendvu", ofType: "jpg"),
                   let image = UIImage(contentsOfFile: imagePath) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 120, height: 120)
                        .cornerRadius(26)
                        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                        .scaleEffect(isAnimating ? 1.0 : 0.8)
                        .opacity(opacity)
                        .animation(.easeInOut(duration: 0.6), value: isAnimating)
                        .animation(.easeInOut(duration: 0.6), value: opacity)
                } else {
                    // フォールバック: システムアイコンを使用
                    Image(systemName: "app.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)
                        .scaleEffect(isAnimating ? 1.0 : 0.8)
                        .opacity(opacity)
                        .animation(.easeInOut(duration: 0.6), value: isAnimating)
                        .animation(.easeInOut(duration: 0.6), value: opacity)
                }
            }
        }
        .onAppear {
            // アニメーション開始
            withAnimation {
                isAnimating = true
                opacity = 1.0
            }
        }
    }
}

#Preview {
    SplashView()
}

