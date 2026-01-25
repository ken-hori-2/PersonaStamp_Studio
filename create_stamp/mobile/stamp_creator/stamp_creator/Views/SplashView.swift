//
//  SplashView.swift
//  stamp_creator
//
//  アプリ起動時に表示するスプラッシュ（AXiV — Rendezvous with the Moment）
//

import SwiftUI

struct SplashView: View {
    let onFinish: () -> Void

    @State private var opacity: Double = 0
    @State private var scale: CGFloat = 0.9

    var body: some View {
        ZStack {
            // 背景（他画面と同様のグラデーション）
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.08, blue: 0.18),
                    Color(red: 0.15, green: 0.12, blue: 0.28)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 12) {
                Text("AXiV")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text("Rendezvous with the Moment")
                    .font(.system(size: 16, weight: .medium, design: .default))
                    .foregroundColor(.white.opacity(0.85))
                    .tracking(1.2)
            }
            .opacity(opacity)
            .scaleEffect(scale)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                opacity = 1
                scale = 1
            }
            // 約2秒表示してからメイン画面へ
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.easeInOut(duration: 0.35)) {
                    opacity = 0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    onFinish()
                }
            }
        }
    }
}

#Preview {
    SplashView(onFinish: {})
}
