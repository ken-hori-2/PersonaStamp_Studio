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
    @State private var scale: Double = 0.8
    @State private var showIcon: Bool = true
    @State private var backgroundOffset: CGFloat = 0
    @State private var iconRotation: Double = 0
    @State private var blurRadius: CGFloat = 0
    
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
    private let fadeDuration: Double = 1.0
    
    enum SplashStep {
        case title(String)
        case subtitle(String)
        case explanation([(String, String)])
    }
    
    var body: some View {
        ZStack {
            // 動的なグラデーション背景（パララックス効果）
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.05, blue: 0.1),
                        Color(red: 0.1, green: 0.05, blue: 0.15),
                        Color(red: 0.05, green: 0.1, blue: 0.2)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                // 動的な光の効果
                RadialGradient(
                    colors: [
                        Color.blue.opacity(0.3),
                        Color.purple.opacity(0.2),
                        Color.clear
                    ],
                    center: UnitPoint(
                        x: 0.5 + backgroundOffset * 0.1,
                        y: 0.3 + backgroundOffset * 0.05
                    ),
                    startRadius: 100,
                    endRadius: 500
                )
            }
            .ignoresSafeArea()
            .blur(radius: blurRadius)
            .offset(y: backgroundOffset)
            
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
                            .shadow(color: .black.opacity(0.4), radius: 30, x: 0, y: 15)
                            .shadow(color: .blue.opacity(0.3), radius: 40, x: 0, y: 20)
                            .scaleEffect(scale)
                            .rotationEffect(.degrees(iconRotation))
                            .opacity(opacity > 0 ? 1.0 : 0.0)
                            .animation(
                                .spring(response: 0.8, dampingFraction: 0.7, blendDuration: 0),
                                value: scale
                            )
                            .animation(
                                .easeInOut(duration: fadeDuration),
                                value: opacity
                            )
                            .animation(
                                .easeInOut(duration: 2.0).repeatForever(autoreverses: true),
                                value: iconRotation
                            )
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
                            .rotationEffect(.degrees(iconRotation))
                            .opacity(opacity > 0 ? 1.0 : 0.0)
                            .shadow(color: .blue.opacity(0.5), radius: 20, x: 0, y: 10)
                            .animation(
                                .spring(response: 0.8, dampingFraction: 0.7, blendDuration: 0),
                                value: scale
                            )
                            .animation(
                                .easeInOut(duration: fadeDuration),
                                value: opacity
                            )
                            .animation(
                                .easeInOut(duration: 2.0).repeatForever(autoreverses: true),
                                value: iconRotation
                            )
                    }
                }
                
                // テキスト表示エリア
                VStack(spacing: 0) {
                    if currentStep < steps.count {
                        stepView(for: steps[currentStep])
                            .opacity(opacity)
                            .scaleEffect(opacity > 0 ? 1.0 : 0.85)
                            .blur(radius: opacity > 0 ? 0 : 10)
                            .animation(
                                .spring(response: 0.9, dampingFraction: 0.8, blendDuration: 0),
                                value: opacity
                            )
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
            startBackgroundAnimation()
            startAnimationSequence()
        }
    }
    
    private func startBackgroundAnimation() {
        // 背景のパララックスアニメーション
        withAnimation(
            .easeInOut(duration: 8.0)
            .repeatForever(autoreverses: true)
        ) {
            backgroundOffset = 20
        }
        
        // ブラー効果のアニメーション
        withAnimation(
            .easeInOut(duration: 4.0)
            .repeatForever(autoreverses: true)
        ) {
            blurRadius = 5
        }
        
        // アイコンの微細な回転
        iconRotation = 5
    }
    
    @ViewBuilder
    private func stepView(for step: SplashStep) -> some View {
        switch step {
        case .title(let text):
            Text(text)
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(red: 0.4, green: 0.6, blue: 1.0),
                            Color(red: 0.7, green: 0.4, blue: 1.0),
                            Color(red: 0.9, green: 0.5, blue: 0.8)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .shadow(color: .blue.opacity(0.5), radius: 15, x: 0, y: 5)
                .shadow(color: .purple.opacity(0.3), radius: 25, x: 0, y: 10)
                .padding(.vertical, 20)
                
        case .subtitle(let text):
            Text(text)
                .font(.system(size: 22, weight: .medium, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.9),
                            Color.white.opacity(0.7)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .multilineTextAlignment(.center)
                .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
                
        case .explanation(let parts):
            VStack(spacing: 16) {
                // 「=」を最初に表示
                Text("=")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.9),
                                Color.white.opacity(0.6)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                    .padding(.bottom, 8)
                
                ForEach(Array(parts.enumerated()), id: \.offset) { index, part in
                    HStack(spacing: 12) {
                        Text(part.0)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.4, green: 0.6, blue: 1.0),
                                        Color(red: 0.7, green: 0.4, blue: 1.0)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        
                        Text(part.1)
                            .font(.system(size: 18, weight: .regular, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.9),
                                        Color.white.opacity(0.7)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.15),
                                        Color.white.opacity(0.05)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.white.opacity(0.1))
                                    .blur(radius: 10)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.3),
                                                Color.white.opacity(0.1)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            )
                            .shadow(color: .black.opacity(0.3), radius: 15, x: 0, y: 8)
                            .shadow(color: .blue.opacity(0.2), radius: 20, x: 0, y: 10)
                    )
                    
                    if index < parts.count - 1 {
                        Text("+")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.9),
                                        Color.white.opacity(0.6)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
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
        
        // アイコンのスケールアニメーション（Netflix風のエレガントな登場）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(
                .spring(response: 0.8, dampingFraction: 0.7, blendDuration: 0)
            ) {
                self.scale = 1.0
            }
        }
        
        // 最初のテキストをフェードイン（スプリングアニメーション）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            print("📝 Step 0: Showing title")
            withAnimation(
                .spring(response: 0.9, dampingFraction: 0.8, blendDuration: 0)
            ) {
                self.opacity = 1.0
            }
        }
        
        // 各ステップのタイミングを計算
        var totalTime: Double = 0.3 + fadeDuration // 最初のフェードイン時間
        
        // Step 0: 表示 → フェードアウト（アイコンも一緒にフェードアウト）
        totalTime += displayDurations[0]
        DispatchQueue.main.asyncAfter(deadline: .now() + totalTime) {
            print("📝 Step 0: Fading out")
            withAnimation(
                .easeInOut(duration: self.fadeDuration)
            ) {
                self.opacity = 0.0
                self.scale = 0.9
            }
        }
        
        // アイコンを非表示にする
        totalTime += fadeDuration
        DispatchQueue.main.asyncAfter(deadline: .now() + totalTime) {
            withAnimation(
                .easeInOut(duration: 0.3)
            ) {
                self.showIcon = false
            }
        }
        
        // Step 1: フェードイン → 表示 → フェードアウト（説明文）
        DispatchQueue.main.asyncAfter(deadline: .now() + totalTime + 0.1) {
            print("📝 Step 1: Showing explanation")
            self.currentStep = 1
            self.scale = 0.95
            withAnimation(
                .spring(response: 0.9, dampingFraction: 0.8, blendDuration: 0)
            ) {
                self.opacity = 1.0
                self.scale = 1.0
            }
        }
        
        totalTime += displayDurations[1]
        DispatchQueue.main.asyncAfter(deadline: .now() + totalTime) {
            print("📝 Step 1: Fading out")
            withAnimation(
                .easeInOut(duration: self.fadeDuration)
            ) {
                self.opacity = 0.0
                self.scale = 0.9
            }
        }
        
        // Step 2: フェードイン → 表示 → フェードアウト（一言）
        totalTime += fadeDuration
        DispatchQueue.main.asyncAfter(deadline: .now() + totalTime + 0.1) {
            print("📝 Step 2: Showing subtitle")
            self.currentStep = 2
            self.scale = 0.95
            withAnimation(
                .spring(response: 0.9, dampingFraction: 0.8, blendDuration: 0)
            ) {
                self.opacity = 1.0
                self.scale = 1.0
            }
        }
        
        totalTime += displayDurations[2]
        DispatchQueue.main.asyncAfter(deadline: .now() + totalTime) {
            print("📝 Step 2: Fading out")
            withAnimation(
                .easeInOut(duration: self.fadeDuration)
            ) {
                self.opacity = 0.0
                self.scale = 0.85
            }
        }
    }
}

#Preview {
    SplashView()
}

