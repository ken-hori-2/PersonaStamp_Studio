# 認証方式

## 🔐 認証概要

本システムでは、**Firebase Authentication**を使用してユーザー認証を行います。

### 認証フロー

```
1. iOSアプリ
   │
   ├─ Firebase Authenticationでログイン
   │  - Apple Sign In
   │  - Google Sign In（オプション）
   │  - メール/パスワード（オプション）
   │
   ├─ Firebase IDトークンを取得
   │
   ▼
2. APIリクエスト
   │
   ├─ Authorization: Bearer <Firebase ID Token>
   │
   ▼
3. バックエンド
   │
   ├─ Firebase Admin SDKでトークン検証
   ├─ ユーザーID（Firebase UID）を取得
   │
   ▼
4. 認証完了
```

---

## 🔑 Firebase Authentication設定

### 1. Firebaseプロジェクト作成

1. [Firebase Console](https://console.firebase.google.com/)にアクセス
2. 「プロジェクトを追加」をクリック
3. プロジェクト名を入力（例: `personastamp-studio`）
4. Google Analyticsの設定（オプション）

### 2. Authentication有効化

1. Firebase Consoleで「Authentication」を選択
2. 「始める」をクリック
3. サインイン方法を有効化:
   - **Apple**: 必須（iOSアプリの場合）
   - **Google**: オプション
   - **メール/パスワード**: オプション

### 3. Apple Sign In設定

1. 「Apple」を選択
2. 「有効にする」をクリック
3. サービスIDを設定（Apple Developer Consoleで作成）

### 4. Firebase Admin SDK認証情報取得

1. Firebase Consoleで「プロジェクトの設定」を選択
2. 「サービスアカウント」タブを選択
3. 「新しい秘密鍵の生成」をクリック
4. JSONファイルをダウンロード
5. 環境変数に設定（後述）

---

## 💻 実装

### バックエンド側（FastAPI）

#### 1. Firebase Admin SDKのインストール

```bash
pip install firebase-admin
```

#### 2. requirements.txtに追加

```txt
firebase-admin>=6.0.0
```

#### 3. Firebase Admin SDKの初期化

```python
# api_server.py
import firebase_admin
from firebase_admin import credentials, auth
import os

# Firebase Admin SDKの初期化
if not firebase_admin._apps:
    # 環境変数から認証情報を取得
    cred = credentials.Certificate({
        "type": "service_account",
        "project_id": os.environ.get("FIREBASE_PROJECT_ID"),
        "private_key_id": os.environ.get("FIREBASE_PRIVATE_KEY_ID"),
        "private_key": os.environ.get("FIREBASE_PRIVATE_KEY").replace('\\n', '\n'),
        "client_email": os.environ.get("FIREBASE_CLIENT_EMAIL"),
        "client_id": os.environ.get("FIREBASE_CLIENT_ID"),
        "auth_uri": "https://accounts.google.com/o/oauth2/auth",
        "token_uri": "https://oauth2.googleapis.com/token",
    })
    firebase_admin.initialize_app(cred)
```

#### 4. トークン検証関数

```python
# api_server.py
from fastapi import HTTPException, Header, Depends

def verify_firebase_token(
    authorization: str = Header(None, alias="Authorization")
) -> dict:
    """Firebase IDトークンを検証してユーザー情報を返す"""
    if not authorization:
        raise HTTPException(
            status_code=401,
            detail="Authorizationヘッダーが必要です"
        )
    
    # "Bearer "を除去
    if not authorization.startswith("Bearer "):
        raise HTTPException(
            status_code=401,
            detail="Authorizationヘッダーの形式が正しくありません"
        )
    
    token = authorization[7:]  # "Bearer "を除去
    
    try:
        # トークンを検証
        decoded_token = auth.verify_id_token(token)
        user_id = decoded_token['uid']
        email = decoded_token.get('email')
        
        # ユーザーがデータベースに存在するかチェック
        # 存在しない場合は作成
        ensure_user_exists(user_id, email)
        
        return {
            "user_id": user_id,
            "email": email,
            "firebase_uid": user_id
        }
    except auth.InvalidIdTokenError:
        raise HTTPException(
            status_code=401,
            detail="無効なトークンです"
        )
    except auth.ExpiredIdTokenError:
        raise HTTPException(
            status_code=401,
            detail="トークンの有効期限が切れています"
        )
    except Exception as e:
        raise HTTPException(
            status_code=401,
            detail=f"認証エラー: {str(e)}"
        )

def ensure_user_exists(user_id: str, email: str = None):
    """ユーザーがデータベースに存在しない場合は作成"""
    from database import get_user_by_id, create_user
    
    user = get_user_by_id(user_id)
    if not user:
        # 新規ユーザーを作成
        create_user(
            user_id=user_id,
            email=email
        )
```

#### 5. エンドポイントでの使用

```python
# api_server.py
@app.post("/api/v2/tts/generate")
async def generate_tts_audio(
    request: TTSRequest,
    user: dict = Depends(verify_firebase_token)  # Firebase認証を使用
):
    """TTS音声を生成（Firebase認証版）"""
    user_id = user["user_id"]
    # ... 既存の実装 ...
```

---

### iOSアプリ側（Swift）

#### 1. Firebase SDKのインストール

```swift
// Package.swift または CocoaPods
// Firebase Authentication SDKを追加
```

#### 2. Firebase初期化

```swift
// AppDelegate.swift または App.swift
import FirebaseCore

@main
struct MyApp: App {
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

#### 3. Apple Sign In実装

```swift
// AuthManager.swift
import FirebaseAuth
import AuthenticationServices

class AuthManager: NSObject, ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    
    // Apple Sign In
    func signInWithApple() async throws -> String {
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        
        // 認証結果を処理
        // ...
        
        // Firebase IDトークンを取得
        guard let user = Auth.auth().currentUser else {
            throw AuthError.userNotFound
        }
        
        let token = try await user.getIDToken()
        return token
    }
    
    // 自動ログイン（トークンが有効な場合）
    func checkAuthStatus() {
        if let user = Auth.auth().currentUser {
            self.currentUser = user
            self.isAuthenticated = true
        } else {
            self.isAuthenticated = false
        }
    }
}
```

#### 4. APIリクエストでの使用

```swift
// APIClient.swift
func generateTTS(text: String, modelId: String?) async throws -> Data {
    // Firebase IDトークンを取得
    guard let user = Auth.auth().currentUser else {
        throw AuthError.userNotFound
    }
    
    let token = try await user.getIDToken()
    
    // APIリクエスト
    let url = URL(string: "https://your-api.com/api/v2/tts/generate")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    let body: [String: Any] = [
        "text": text,
        "model_id": modelId ?? ""
    ]
    request.httpBody = try JSONSerialization.data(withJSONObject: body)
    
    let (data, response) = try await URLSession.shared.data(for: request)
    
    // エラーチェック
    if let httpResponse = response as? HTTPURLResponse {
        if httpResponse.statusCode != 200 {
            throw APIError.httpError(httpResponse.statusCode)
        }
    }
    
    return data
}
```

---

## 🔒 セキュリティ対策

### 1. トークンの有効期限

Firebase IDトークンは1時間で期限切れになります。iOSアプリ側で自動的にリフレッシュされます。

### 2. トークンの検証

バックエンドでは、すべてのリクエストでトークンを検証します：

- トークンの署名検証
- トークンの有効期限チェック
- トークンの発行者（Firebase）の確認

### 3. ユーザー情報の保護

- ユーザーID（Firebase UID）のみをデータベースに保存
- メールアドレスなどの個人情報は必要最小限に

### 4. CORS設定

本番環境では、適切なオリジンを指定してください：

```python
app.add_middleware(
    CORSMiddleware,
    allow_origins=["https://your-ios-app.com"],  # iOSアプリのドメイン
    allow_credentials=True,
    allow_methods=["GET", "POST", "DELETE"],
    allow_headers=["Authorization", "Content-Type"],
)
```

---

## 🔄 既存実装からの移行

### 段階的移行（推奨）

1. **Phase 1**: Firebase Authenticationを追加（既存のAPIキー方式と併用）
2. **Phase 2**: 新規ユーザーはFirebase Authenticationのみ
3. **Phase 3**: 既存ユーザーをFirebase Authenticationに移行

### 完全移行

1. Firebase Authenticationを実装
2. 既存ユーザーに移行を案内
3. APIキー方式を廃止

---

## 📝 環境変数設定

### バックエンド環境変数

```bash
# .env
FIREBASE_PROJECT_ID=your-project-id
FIREBASE_PRIVATE_KEY_ID=your-private-key-id
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"
FIREBASE_CLIENT_EMAIL=your-client-email@your-project.iam.gserviceaccount.com
FIREBASE_CLIENT_ID=your-client-id
```

### ホスティング環境変数（Railway）

Railwayのダッシュボードで環境変数を設定：

1. プロジェクトを選択
2. 「Variables」タブを開く
3. 上記の環境変数を追加

---

## 🧪 テスト

### トークン検証のテスト

```python
# test_auth.py
def test_verify_firebase_token_valid():
    """有効なトークンの検証テスト"""
    # 有効なFirebase IDトークンを使用
    token = "valid_firebase_id_token"
    result = verify_firebase_token(f"Bearer {token}")
    assert result["user_id"] is not None

def test_verify_firebase_token_invalid():
    """無効なトークンの検証テスト"""
    with pytest.raises(HTTPException) as exc_info:
        verify_firebase_token("Bearer invalid_token")
    assert exc_info.value.status_code == 401
```

---

## 🔗 関連ドキュメント

- [システム概要](./01_SYSTEM_OVERVIEW.md)
- [API仕様](./03_API_SPECIFICATION.md)
- [実装手順](./06_IMPLEMENTATION_GUIDE.md)
- [../docs/FIREBASE_AUTHENTICATION_GUIDE.md](../docs/FIREBASE_AUTHENTICATION_GUIDE.md) - Firebase認証詳細ガイド

