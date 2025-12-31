# 認証エラーのトラブルシューティング

## 🔴 よくあるエラーと解決方法

### エラー: "認証トークンがない"

**症状**: アプリで認証は成功するが、トークンが取得できない

**原因**: Token Service APIが選択されていない

**解決方法**:
1. Google Cloud Console > APIとサービス > 認証情報
2. APIキーを選択
3. 「APIの制限」セクションで「APIを選択」をクリック
4. **Token Service API**にチェックを入れる
5. 「保存」をクリック

詳細は `02_api_key/api_key_restrictions.md` を参照

---

### エラー: "Firebase Authentication error"

**症状**: Firebase Authenticationへの接続に失敗

**原因**: Identity Toolkit APIが選択されていない

**解決方法**:
1. Google Cloud Console > APIとサービス > 認証情報
2. APIキーを選択
3. 「APIの制限」セクションで「APIを選択」をクリック
4. **Identity Toolkit API**にチェックを入れる
5. 「保存」をクリック

詳細は `02_api_key/api_key_restrictions.md` を参照

---

### エラー: "Firebase SDK initialization failed"

**症状**: Firebase SDKの初期化に失敗

**原因**: Firebase Installations APIが選択されていない

**解決方法**:
1. Google Cloud Console > APIとサービス > 認証情報
2. APIキーを選択
3. 「APIの制限」セクションで「APIを選択」をクリック
4. **Firebase Installations API**にチェックを入れる
5. 「保存」をクリック

詳細は `02_api_key/api_key_restrictions.md` を参照

---

### エラー: "APIキーが無効です"

**症状**: APIキーが認識されない

**原因**: 
- APIキーが正しく設定されていない
- Bundle IDが一致していない

**解決方法**:
1. `GoogleService-Info.plist`の`API_KEY`を確認
2. Google Cloud ConsoleでAPIキーの設定を確認
3. 「アプリケーションの制限」でBundle IDが正しく設定されているか確認
4. Bundle ID: `com.ken.PersonaStampStudio` が追加されているか確認

詳細は `02_api_key/api_key_guide.md` を参照

---

## 🔍 デバッグ方法

### 1. Firebase SDKのログを有効化

`RendVuApp.swift`に以下を追加:

```swift
import FirebaseCore

init() {
    // Firebase初期化
    FirebaseApp.configure()
    
    // デバッグログを有効化
    #if DEBUG
    FirebaseConfiguration.shared.setLoggerLevel(.debug)
    #endif
}
```

### 2. コンソールログを確認

Xcodeのコンソールで以下のエラーメッセージを確認:
- `Firebase Authentication error`
- `API key error`
- `Invalid API key`

### 3. GoogleService-Info.plistの内容を確認

アプリ実行時に`GoogleService-Info.plist`の内容が正しく読み込まれているか確認:

```swift
if let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
   let plist = NSDictionary(contentsOfFile: path) {
    print("API_KEY: \(plist["API_KEY"] ?? "not found")")
    print("PROJECT_ID: \(plist["PROJECT_ID"] ?? "not found")")
    print("BUNDLE_ID: \(plist["BUNDLE_ID"] ?? "not found")")
}
```

---

## 📋 チェックリスト

### APIキーの設定

- [ ] Google Cloud ConsoleでAPIキーの制限が正しく設定されている
- [ ] アプリケーションの制限: iOSアプリ、Bundle ID `com.ken.PersonaStampStudio`
- [ ] APIの制限: Identity Toolkit API、Firebase Installations API、Token Service API

### Firebase設定

- [ ] Firebase Authenticationが有効化されている
- [ ] Apple Sign Inが有効化されている
- [ ] プロジェクト設定が正しい

### iOSアプリ

- [ ] Bundle IDが `com.ken.PersonaStampStudio` になっている
- [ ] `GoogleService-Info.plist`がプロジェクトに含まれている
- [ ] `GoogleService-Info.plist`のターゲットメンバーシップが正しい

---

## 📚 参考資料

- [Firebase Authentication エラー](https://firebase.google.com/docs/auth/ios/errors)
- [APIキーの制限](https://cloud.google.com/docs/authentication/api-keys#api_key_restrictions)

---

**更新日**: 2025年1月  
**作成者**: AI Assistant

