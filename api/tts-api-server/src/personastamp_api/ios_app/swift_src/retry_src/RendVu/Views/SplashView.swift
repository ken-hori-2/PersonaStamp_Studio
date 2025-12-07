//
//  SplashView.swift
//  RendVu
//
//  Created on 2025-12-07.
//

import SwiftUI
import UIKit

struct SplashView: View {
    @State private var currentStep: Int = 0
    @State private var opacity: Double = 0
    @State private var scale: Double = 0.9
    @State private var showIcon: Bool = true
    
    // 表示するテキストの配列
    private let steps: [SplashStep] = [
        .title("Re:ndVu"),
        .explanation([
            ("Re:", "Revive / Replay"),
            ("ndVu", "Rendezvous / Encounter"),
            ("Vu", "View & Voice")
        ]),
        .subtitle("Relive that View and Voice. Again.")
    ]
    
    // 各ステップの表示時間（秒）
    private let displayDurations: [Double] = [2.0, 4.0, 2.5]
    private let fadeDuration: Double = 0.8
    
    enum SplashStep {
        case title(String)
        case subtitle(String)
        case explanation([(String, String)])
    }
    
    var body: some View {
        ZStack {
            // グラデーション背景
            LinearGradient(
                colors: [Color.white, Color(white: 0.98)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                // アプリアイコン（最初のステップのみ表示）
                if showIcon {
                    if let imagePath = Bundle.main.path(forResource: "ios_icon_rendvu", ofType: "jpg"),
                       let image = UIImage(contentsOfFile: imagePath) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 140, height: 140)
                            .cornerRadius(30)
                            .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
                            .scaleEffect(scale)
                            .opacity(opacity > 0 ? 1.0 : 0.0)
                            .animation(.easeInOut(duration: 0.6), value: scale)
                            .animation(.easeInOut(duration: fadeDuration), value: opacity)
                    } else {
                        Image(systemName: "app.fill")
                            .font(.system(size: 80))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .scaleEffect(scale)
                            .opacity(opacity > 0 ? 1.0 : 0.0)
                            .animation(.easeInOut(duration: 0.6), value: scale)
                            .animation(.easeInOut(duration: fadeDuration), value: opacity)
                    }
                }
                
                // テキスト表示エリア
                VStack(spacing: 0) {
                    if currentStep < steps.count {
                        stepView(for: steps[currentStep])
                            .opacity(opacity)
                            .scaleEffect(opacity > 0 ? 1.0 : 0.95)
                            .animation(.easeInOut(duration: fadeDuration), value: opacity)
                    }
                }
                .frame(minHeight: 200)
                .frame(maxWidth: .infinity)
                
                Spacer()
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 40)
        }
        .onAppear {
            print("🎬 SplashView appeared, starting animation")
            scale = 1.0
            startAnimationSequence()
        }
    }
    
    @ViewBuilder
    private func stepView(for step: SplashStep) -> some View {
        switch step {
        case .title(let text):
            Text(text)
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                .padding(.vertical, 20)
                
        case .subtitle(let text):
            Text(text)
                .font(.system(size: 22, weight: .medium, design: .rounded))
                .foregroundColor(.black)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
                
        case .explanation(let parts):
            VStack(spacing: 16) {
                // 「=」を最初に表示
                Text("=")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.black)
                    .padding(.bottom, 8)
                
                ForEach(Array(parts.enumerated()), id: \.offset) { index, part in
                    HStack(spacing: 12) {
                        Text(part.0)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        
                        Text(part.1)
                            .font(.system(size: 18, weight: .regular, design: .rounded))
                            .foregroundColor(.black)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white)
                            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                    )
                    
                    if index < parts.count - 1 {
                        Text("+")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.black)
                            .padding(.vertical, 4)
                    }
                }
            }
            .padding(.horizontal, 10)
        }
    }
    
    private func startAnimationSequence() {
        print("🎬 Starting animation sequence")
        
        // 最初のテキストを設定
        currentStep = 0
        
        // 最初のテキストをフェードイン
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            print("📝 Step 0: Showing title")
            withAnimation(.easeInOut(duration: self.fadeDuration)) {
                self.opacity = 1.0
            }
        }
        
        // 各ステップのタイミングを計算
        var totalTime: Double = 0.2 + fadeDuration // 最初のフェードイン時間
        
        // Step 0: 表示 → フェードアウト（アイコンも一緒にフェードアウト）
        totalTime += displayDurations[0]
        DispatchQueue.main.asyncAfter(deadline: .now() + totalTime) {
            print("📝 Step 0: Fading out")
            withAnimation(.easeInOut(duration: self.fadeDuration)) {
                self.opacity = 0.0
            }
        }
        
        // アイコンを非表示にする
        totalTime += fadeDuration
        DispatchQueue.main.asyncAfter(deadline: .now() + totalTime) {
            self.showIcon = false
        }
        
        // Step 1: フェードイン → 表示 → フェードアウト（説明文）
        DispatchQueue.main.asyncAfter(deadline: .now() + totalTime) {
            print("📝 Step 1: Showing explanation")
            self.currentStep = 1
            withAnimation(.easeInOut(duration: self.fadeDuration)) {
                self.opacity = 1.0
            }
        }
        
        totalTime += displayDurations[1]
        DispatchQueue.main.asyncAfter(deadline: .now() + totalTime) {
            print("📝 Step 1: Fading out")
            withAnimation(.easeInOut(duration: self.fadeDuration)) {
                self.opacity = 0.0
            }
        }
        
        // Step 2: フェードイン → 表示 → フェードアウト（一言）
        totalTime += fadeDuration
        DispatchQueue.main.asyncAfter(deadline: .now() + totalTime) {
            print("📝 Step 2: Showing subtitle")
            self.currentStep = 2
            withAnimation(.easeInOut(duration: self.fadeDuration)) {
                self.opacity = 1.0
            }
        }
        
        totalTime += displayDurations[2]
        DispatchQueue.main.asyncAfter(deadline: .now() + totalTime) {
            print("📝 Step 2: Fading out")
            withAnimation(.easeInOut(duration: self.fadeDuration)) {
                self.opacity = 0.0
            }
        }
    }
}

#Preview {
    SplashView()
}

