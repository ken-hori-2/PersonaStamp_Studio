//
//  RendVuApp.swift
//  RendVu
//
//  Created by 堀内健司 on 2025/11/23.
//

import SwiftUI
import FirebaseCore
import Network
import UIKit

@main
struct RendVuApp: App {
    @StateObject private var authManager = AuthManager()
    private let networkPermissionTrigger = LocalNetworkPermissionTrigger()
    
    // AppDelegateを設定してFirebaseの警告を抑制
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    init() {
        // Firebase初期化
        FirebaseApp.configure()
        networkPermissionTrigger.requestIfNeeded()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authManager)
        }
    }
}

private final class LocalNetworkPermissionTrigger {
    private var browser: NWBrowser?
    private var hasRequested = false
    
    func requestIfNeeded() {
        guard !hasRequested else { return }
        hasRequested = true
        
        let parameters = NWParameters()
        parameters.includePeerToPeer = true
        let browser = NWBrowser(for: .bonjour(type: "_http._tcp", domain: nil), using: parameters)
        self.browser = browser
        
        browser.stateUpdateHandler = { [weak self] state in
            if case .failed = state {
                self?.cleanup()
            }
        }
        
        browser.start(queue: .main)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.cleanup()
        }
    }
    
    private func cleanup() {
        browser?.cancel()
        browser = nil
    }
}

// AppDelegateクラスを追加してFirebaseの警告を抑制
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Firebaseは既にRendVuAppのinitで初期化されている
        return true
    }
}
