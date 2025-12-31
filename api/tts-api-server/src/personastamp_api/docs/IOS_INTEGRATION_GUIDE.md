# iOSアプリ統合ガイド

## 📱 iOSアプリ側の実装

Firebase Authentication（Apple Sign In）を使用してバックエンドAPIにアクセスする方法です。

### 1. Firebase SDKのインストール

#### Swift Package Manager

1. Xcodeでプロジェクトを開く
2. File → Add Packages...
3. `https://github.com/firebase/firebase-ios-sdk` を追加
4. 以下のパッケージを選択：
   - FirebaseAuth
   - FirebaseCore

#### CocoaPods

```ruby
pod 'FirebaseAuth'
pod 'FirebaseCore'
```

### 2. Firebase初期化

`AppDelegate.swift` または `App.swift`:

```swift
import SwiftUI
import FirebaseCore

@main
struct PersonaStampApp: App {
    init() {
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

### 3. Apple Sign In実装

[Firebase公式ドキュメント](https://firebase.google.com/docs/auth/ios/apple?hl=ja)を参考に実装：

```swift
import SwiftUI
import FirebaseAuth
import AuthenticationServices

class AuthManager: NSObject, ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var idToken: String?
    
    // Apple Sign In
    func signInWithApple() async throws {
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        
        // 認証を開始
        authorizationController.performRequests()
    }
    
    // Firebase IDトークンを取得
    func getIDToken() async throws -> String {
        guard let user = Auth.auth().currentUser else {
            throw AuthError.userNotFound
        }
        
        let token = try await user.getIDToken()
        return token
    }
}

extension AuthManager: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, 
                                didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let nonce = currentNonce else {
            return
        }
        
        guard let appleIDToken = appleIDCredential.identityToken,
              let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            return
        }
        
        // Firebase認証情報を作成
        let credential = OAuthProvider.credential(withProviderID: "apple.com",
                                                  idToken: idTokenString,
                                                  rawNonce: nonce)
        
        // Firebaseにサインイン
        Task {
            do {
                let result = try await Auth.auth().signIn(with: credential)
                await MainActor.run {
                    self.currentUser = result.user
                    self.isAuthenticated = true
                }
                
                // IDトークンを取得
                let token = try await result.user.getIDToken()
                await MainActor.run {
                    self.idToken = token
                }
            } catch {
                print("Firebase sign in error: \(error)")
            }
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, 
                                didCompleteWithError error: Error) {
        print("Apple Sign In error: \(error)")
    }
}

extension AuthManager: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return UIApplication.shared.windows.first { $0.isKeyWindow }!
    }
}
```

### 4. APIクライアント実装

```swift
import Foundation

class APIClient {
    let baseURL = "http://localhost:8000"  // 本番環境では適切なURLに変更
    
    // TTS生成
    func generateTTS(text: String, modelId: String? = nil) async throws -> Data {
        guard let token = try await AuthManager.shared.getIDToken() else {
            throw APIError.unauthorized
        }
        
        let url = URL(string: "\(baseURL)/api/v2/tts/generate")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var body: [String: Any] = ["text": text]
        if let modelId = modelId {
            body["model_id"] = modelId
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw APIError.httpError(httpResponse.statusCode)
        }
        
        return data
    }
    
    // Voice Cloning
    func cloneVoice(audioData: Data, referenceName: String) async throws -> CloneResponse {
        guard let token = try await AuthManager.shared.getIDToken() else {
            throw APIError.unauthorized
        }
        
        let url = URL(string: "\(baseURL)/api/v2/clone")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let audioBase64 = audioData.base64EncodedString()
        let body: [String: Any] = [
            "audio_base64": audioBase64,
            "reference_name": referenceName
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let detail = errorData["detail"] as? String {
                throw APIError.serverError(detail)
            }
            throw APIError.httpError(httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(CloneResponse.self, from: data)
    }
    
    // モデル一覧取得
    func getVoiceModels() async throws -> [VoiceModel] {
        guard let token = try await AuthManager.shared.getIDToken() else {
            throw APIError.unauthorized
        }
        
        let url = URL(string: "\(baseURL)/api/v2/models")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw APIError.httpError(httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode([VoiceModel].self, from: data)
    }
}

// レスポンスモデル
struct CloneResponse: Codable {
    let model_id: String
    let reference_name: String
    let message: String
}

struct VoiceModel: Codable {
    let model_id: String
    let reference_name: String
    let created_at: String
}

enum APIError: Error {
    case unauthorized
    case invalidResponse
    case httpError(Int)
    case serverError(String)
}
```

### 5. 使用例

```swift
struct ContentView: View {
    @StateObject private var authManager = AuthManager()
    @StateObject private var apiClient = APIClient()
    
    var body: some View {
        VStack {
            if authManager.isAuthenticated {
                Text("ログイン済み")
                Button("TTS生成") {
                    Task {
                        do {
                            let audioData = try await apiClient.generateTTS(text: "こんにちは")
                            // 音声を再生
                        } catch {
                            print("Error: \(error)")
                        }
                    }
                }
            } else {
                Button("Apple Sign In") {
                    Task {
                        try await authManager.signInWithApple()
                    }
                }
            }
        }
    }
}
```

---

## 🧪 テスト方法

### 1. バックエンドAPIのテスト

Firebase IDトークンを使用してAPIをテスト：

```bash
# 1. iOSアプリからFirebase IDトークンを取得（ログ出力などで確認）

# 2. APIをテスト
curl -X POST "http://localhost:8000/api/v2/tts/generate" \
  -H "Authorization: Bearer <Firebase ID Token>" \
  -H "Content-Type: application/json" \
  -d '{"text": "テスト"}'
```

### 2. エンドポイント一覧

| エンドポイント | メソッド | 説明 |
|--------------|---------|------|
| `/health` | GET | ヘルスチェック（認証不要） |
| `/api/v2/clone` | POST | Voice Cloning |
| `/api/v2/tts/generate` | POST | TTS生成 |
| `/api/v2/models` | GET | モデル一覧取得 |
| `/api/v2/models/{model_id}` | DELETE | モデル削除 |
| `/api/v2/users/me/stats` | GET | 利用統計取得 |

---

## 📝 注意事項

1. **本番環境**: `baseURL`を本番環境のURLに変更してください
2. **HTTPS**: 本番環境では必ずHTTPSを使用してください
3. **トークン更新**: Firebase IDトークンは1時間で期限切れになります。自動的にリフレッシュされます
4. **エラーハンドリング**: 適切なエラーハンドリングを実装してください

---

## 🔗 参考リンク

- [Firebase Authentication - Apple Sign In (iOS)](https://firebase.google.com/docs/auth/ios/apple?hl=ja)
- [Firebase iOS SDK](https://github.com/firebase/firebase-ios-sdk)
- [API仕様書](../../specs/03_API_SPECIFICATION.md)

