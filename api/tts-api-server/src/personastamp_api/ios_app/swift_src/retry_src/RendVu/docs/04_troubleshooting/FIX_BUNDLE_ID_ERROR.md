# Bundle ID不一致エラー修正ガイド

## 🔴 エラー内容

```
The project's Bundle ID is inconsistent with either the Bundle ID in 'GoogleService-Info.plist'
```

プロジェクトのBundle ID (`com.ken.PersonaStamp`) と `GoogleService-Info.plist` のBundle ID (`com.ken.PersonaStampStudio`) が一致していません。

## ✅ 修正内容

プロジェクトのBundle IDを `com.ken.PersonaStampStudio` に変更しました。

## 📝 次のステップ

### 1. XcodeでBundle IDを確認

1. Xcodeで`PersonaStamp.xcworkspace`を開く
2. プロジェクトナビゲーターでプロジェクトを選択
3. ターゲット`PersonaStamp`を選択
4. "Signing & Capabilities"タブを開く
5. Bundle Identifierが`com.ken.PersonaStampStudio`になっているか確認

### 2. Apple Developer ConsoleでBundle IDを確認

もしApple Developer Programに登録している場合：

1. [Apple Developer Console](https://developer.apple.com/account/)にアクセス
2. "Certificates, Identifiers & Profiles" → "Identifiers"を開く
3. `com.ken.PersonaStampStudio`が登録されているか確認
4. 登録されていない場合：
   - "+"ボタンをクリック
   - "App IDs"を選択
   - Bundle ID: `com.ken.PersonaStampStudio`を入力
   - Capabilities: "Sign in with Apple"を有効化
   - "Continue" → "Register"

### 3. Firebase ConsoleでBundle IDを確認

1. [Firebase Console](https://console.firebase.google.com/)にアクセス
2. プロジェクト「personastamp-studio」を選択
3. プロジェクト設定 → 全般
4. iOSアプリのBundle IDが`com.ken.PersonaStampStudio`になっているか確認

### 4. Clean Build Folder

1. `Product` → `Clean Build Folder` (Shift + Cmd + K)

### 5. 再度ビルド・実行

1. `Product` → `Build` (Cmd + B)
2. `Product` → `Run` (Cmd + R)

## 🔍 その他のエラーについて

### App Delegateエラー

```
App Delegate does not conform to UIApplicationDelegate protocol
```

これはSwiftUIアプリでAppDelegateを使っていない場合、無視できる警告です。
Firebaseは自動的にAppDelegateを検出しようとしますが、SwiftUIアプリでは`@main`の`App`構造体で初期化するため、この警告は表示されますが動作には影響しません。

### Apple Sign Inエラー (Code=-7026, Code=1000)

Bundle IDを修正した後、以下の点を確認してください：

1. **Xcodeで"Sign in with Apple" Capabilityが追加されているか**
   - プロジェクトナビゲーターでプロジェクトを選択
   - ターゲット`PersonaStamp`を選択
   - "Signing & Capabilities"タブ
   - "Sign in with Apple"が追加されているか確認

2. **Apple Developer Consoleで"Sign in with Apple"が有効化されているか**
   - [Apple Developer Console](https://developer.apple.com/account/)にアクセス
   - "Certificates, Identifiers & Profiles" → "Identifiers"
   - `com.ken.PersonaStampStudio`を選択
   - "Sign in with Apple"が有効化されているか確認

3. **Firebase ConsoleでApple Sign Inが有効化されているか**
   - [Firebase Console](https://console.firebase.google.com/)にアクセス
   - Authentication → Sign-in method
   - "Apple"が有効化されているか確認

### LaunchServicesエラー

```
LaunchServices: store (null) or url (null) was nil
```

これはシミュレーターの問題で、実際のアプリ動作には影響しないことが多いです。
実機でテストするか、シミュレーターを再起動してみてください。

## 🚀 トラブルシューティング

### Bundle IDを変更した後もエラーが続く場合

1. Xcodeを完全に終了（Cmd + Q）
2. DerivedDataをクリア：
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData
   ```
3. Xcodeを再起動
4. `.xcworkspace`を開く
5. Clean Build Folder
6. 再度ビルド

### Apple Sign Inがまだ動作しない場合

1. 実機でテストしてみる（シミュレーターでは動作しない場合がある）
2. Apple Developer Programに登録しているか確認
3. 無料アカウントの場合、一部機能が制限される可能性があります

