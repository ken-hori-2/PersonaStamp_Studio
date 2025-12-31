//
//  LoginView.swift
//  RendVu
//
//  Created on 2025-11-23.
//

import SwiftUI
import UIKit
import AuthenticationServices

struct LoginView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // アプリロゴ・タイトル
            VStack(spacing: 16) {
                // アプリアイコン
                if let imagePath = Bundle.main.path(forResource: "ios_icon_rendvu", ofType: "jpg"),
                   let image = UIImage(contentsOfFile: imagePath) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 120, height: 120)
                        .cornerRadius(26)
                        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                } else {
                    // フォールバック: システムアイコンを使用
                    Image(systemName: "app.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)
                }
                
                Text("Re:ndVu")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("あなたの声をクローンして、テキストを音声に変換")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Spacer()
            
            // Apple Sign In ボタン
            SignInWithAppleButton(
                onRequest: { request in
                    request.requestedScopes = [.fullName, .email]
                    // Nonceを生成して設定
                    let nonce = authManager.generateNonce()
                    request.nonce = nonce
                },
                onCompletion: { result in
                    handleSignInResult(result)
                }
            )
            .signInWithAppleButtonStyle(.black)
            .frame(height: 50)
            .padding(.horizontal, 40)
            .disabled(isLoading)
            
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal)
            }
            
            if isLoading {
                ProgressView()
                    .padding()
            }
            
            Spacer()
        }
        .padding()
    }
    
    private func handleSignInResult(_ result: Result<ASAuthorization, Error>) {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                switch result {
                case .success(let authorization):
                    try await authManager.handleAppleSignIn(authorization: authorization)
                case .failure(let error):
                    await MainActor.run {
                        errorMessage = "ログインに失敗しました: \(error.localizedDescription)"
                        isLoading = false
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = "エラーが発生しました: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthManager())
}

