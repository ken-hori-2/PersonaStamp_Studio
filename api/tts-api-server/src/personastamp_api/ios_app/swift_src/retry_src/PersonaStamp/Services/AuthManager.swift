//
//  AuthManager.swift
//  PersonaStampStudio
//
//  Created on 2025-11-23.
//

import Foundation
import SwiftUI
import Combine
import FirebaseAuth
import AuthenticationServices
import CryptoKit

@MainActor
class AuthManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var idToken: String?
    @Published var errorMessage: String?
    
    private var currentNonce: String?
    
    init() {
        // 既存のセッションを確認
        if let user = Auth.auth().currentUser {
            self.currentUser = user
            self.isAuthenticated = true
            Task {
                await refreshIDToken()
            }
        }
    }
    
    // Apple Sign In処理
    func handleAppleSignIn(authorization: ASAuthorization) async throws {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            throw AuthError.invalidCredential
        }
        
        guard let nonce = currentNonce else {
            throw AuthError.invalidState
        }
        
        guard let appleIDToken = appleIDCredential.identityToken,
              let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            throw AuthError.tokenError
        }
        
        // Firebase認証情報を作成（Apple Sign In用）
        let credential = OAuthProvider.appleCredential(
            withIDToken: idTokenString,
            rawNonce: nonce,
            fullName: appleIDCredential.fullName
        )
        
        // Firebaseにサインイン
        let result = try await Auth.auth().signIn(with: credential)
        self.currentUser = result.user
        self.isAuthenticated = true
        
        // IDトークンを取得
        await refreshIDToken()
        
        // Nonceをクリア
        self.currentNonce = nil
    }
    
    // IDトークンをリフレッシュ
    func refreshIDToken() async {
        guard let user = Auth.auth().currentUser else { return }
        
        do {
            let token = try await user.getIDToken()
            self.idToken = token
        } catch {
            self.errorMessage = "トークンの取得に失敗しました: \(error.localizedDescription)"
        }
    }
    
    // ログアウト
    func signOut() {
        do {
            try Auth.auth().signOut()
            self.currentUser = nil
            self.isAuthenticated = false
            self.idToken = nil
        } catch {
            self.errorMessage = "ログアウトに失敗しました: \(error.localizedDescription)"
        }
    }
    
    // Nonceを生成（Apple Sign In用）
    // 戻り値はSHA256ハッシュ（SignInWithAppleButtonのrequest.nonceに設定）
    func generateNonce() -> String {
        let nonce = randomNonceString()
        currentNonce = nonce  // 元のnonceを保存（Firebase認証で使用）
        return sha256(nonce)  // ハッシュを返す（Apple Sign Inリクエストで使用）
    }
    
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] =
        Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        
        while remainingLength > 0 {
            let randoms: [UInt8] = (0..<16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
                }
                return random
            }
            
            randoms.forEach { random in
                if remainingLength == 0 {
                    return
                }
                
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        
        return result
    }
    
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
        
        return hashString
    }
}

enum AuthError: LocalizedError {
    case invalidCredential
    case invalidState
    case tokenError
    case userNotFound
    
    var errorDescription: String? {
        switch self {
        case .invalidCredential:
            return "無効な認証情報です"
        case .invalidState:
            return "無効な状態です"
        case .tokenError:
            return "トークンの取得に失敗しました"
        case .userNotFound:
            return "ユーザーが見つかりません"
        }
    }
}

