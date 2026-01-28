//
//  stamp_creatorApp.swift
//  stamp_creator
//
//  Created by 堀内健司 on 2025/11/15.
//

import SwiftUI

@main
struct stamp_creatorApp: App {
    @State private var showSplash = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                // メイン画面（常に表示、アニメーションでフェードイン）
                ContentView()
                    .opacity(showSplash ? 0 : 1)
                    .animation(.easeInOut(duration: 0.6), value: showSplash)
                
                // スプラッシュ画面（アニメーションで下にスライドアウト + フェードアウト）
                if showSplash {
                    SplashView(onFinish: { showSplash = false })
                        .transition(.asymmetric(
                            insertion: .opacity,
                            removal: .move(edge: .bottom).combined(with: .opacity)
                        ))
                }
            }
        }
    }
}

