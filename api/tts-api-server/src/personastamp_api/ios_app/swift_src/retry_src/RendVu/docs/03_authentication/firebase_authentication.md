# Firebase Authentication設定ガイド

## 📋 概要

Firebase Authenticationの設定と使用方法について説明します。

---

## 🚀 初期設定

### ステップ1: Firebase ConsoleでAuthenticationを有効化

1. **Firebase Consoleにアクセス**
   - https://console.firebase.google.com/
   - プロジェクト: `personastamp-studio` を選択

2. **「Authentication」を開く**
   - 左側のメニューから「Authentication」をクリック

3. **「始める」をクリック**（まだの場合）
   - 初回のみ必要

---

### ステップ2: Apple Sign Inを有効化

1. **Firebase Console > Authentication > Sign-in method**

2. **「Apple」を選択**
   - 「Apple」をクリック

3. **「有効にする」をトグル**
   - 「有効にする」をオンにする

4. **「保存」をクリック**

---

## 📱 iOSアプリでの実装

### コード例

```swift
import FirebaseAuth
import AuthenticationServices

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
    
    // Firebase認証情報を作成
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
```

---

## 🔍 認証フロー

### iOSアプリの認証フロー

```
iOSアプリ
  ↓
Firebase Authentication（直接アクセス）
  ↓
Firebase IDトークンを取得
  ↓
バックエンドAPI（Firebase IDトークンで認証）
```

### 詳細なフロー

1. **iOSアプリ → Firebase Authentication（直接アクセス）**
   - `Auth.auth().signIn(with: credential)`を使用
   - APIキーを使用（`GoogleService-Info.plist`の`API_KEY`）
   - Firebase Authentication SDKがAPIキーを使用してFirebaseにアクセス

2. **iOSアプリ → バックエンドAPI**
   - Firebase IDトークンを取得（`user.getIDToken()`）
   - バックエンドAPIにリクエストを送信（`Authorization: Bearer {idToken}`）
   - APIキーは使用しない

3. **バックエンド → Firebase IDトークンの検証**
   - サービスアカウントキーを使用（APIキーではない）
   - Firebase Admin SDKがサービスアカウントキーを使用

---

## ✅ 確認方法

### Firebase Consoleで確認

1. **Firebase Console > Authentication > Users**
   - ユーザーが正常に作成されているか確認

2. **Firebase Console > Authentication > Sign-in method**
   - Apple Sign Inが有効化されているか確認

### アプリで確認

1. **アプリを実行**
2. **Apple Sign Inを試す**
3. **認証が正常に完了するか確認**
4. **Firebase IDトークンが取得できるか確認**

---

## 🔍 トラブルシューティング

### エラー: "認証トークンがない"

**原因**: Token Service APIが選択されていない

**解決方法**: Google Cloud ConsoleでToken Service APIを追加

詳細は `04_troubleshooting/authentication_errors.md` を参照

### エラー: "Firebase Authentication error"

**原因**: Identity Toolkit APIが選択されていない

**解決方法**: Google Cloud ConsoleでIdentity Toolkit APIを追加

詳細は `04_troubleshooting/authentication_errors.md` を参照

---

## 📚 参考資料

- [Firebase Authentication](https://firebase.google.com/docs/auth)
- [Apple Sign In with Firebase](https://firebase.google.com/docs/auth/ios/apple)
- [Firebase ID Tokens](https://firebase.google.com/docs/auth/admin/verify-id-tokens)

---

**更新日**: 2025年1月  
**作成者**: AI Assistant

