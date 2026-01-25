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
            if showSplash {
                SplashView(onFinish: { showSplash = false })
            } else {
                ContentView()
            }
        }
    }
}

