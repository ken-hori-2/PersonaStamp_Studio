# 画面が黒い問題の修正ガイド

## 🔴 問題

ビルドは成功したが、画面が黒いまま表示される。

## ✅ 修正内容

以下の修正を実施しました：

1. **PersonaStampApp.swiftにFirebase初期化を追加**
   - `import FirebaseCore`を追加
   - `init()`で`FirebaseApp.configure()`を呼び出し

2. **AuthManagerをEnvironmentObjectとして注入**
   - `@StateObject private var authManager = AuthManager()`を追加
   - `.environmentObject(authManager)`を追加

3. **GoogleService-Info.plistをコピー**
   - `PersonaStamp/GoogleService-Info.plist`にコピー済み

4. **ContentViewにデバッグログを追加**
   - `onAppear`でログを出力

## 📝 次のステップ

### 1. XcodeでGoogleService-Info.plistを追加

`GoogleService-Info.plist`がXcodeプロジェクトに追加されているか確認：

1. Xcodeで`PersonaStamp.xcworkspace`を開く
2. プロジェクトナビゲーターで`PersonaStamp`グループを確認
3. `GoogleService-Info.plist`が表示されていない場合：
   - `PersonaStamp/GoogleService-Info.plist`をドラッグ&ドロップ
   - ✅ "Copy items if needed" をチェック**しない**（既にファイルがあるため）
   - ✅ "Add to targets: PersonaStamp" をチェック
   - "Add"をクリック

### 2. Clean Build Folder

1. `Product` → `Clean Build Folder` (Shift + Cmd + K)

### 3. 再度ビルド・実行

1. `Product` → `Build` (Cmd + B)
2. `Product` → `Run` (Cmd + R)

### 4. コンソールログを確認

Xcodeのコンソールで以下が表示されるか確認：

```
✅ ContentView appeared
🔐 isAuthenticated: false
```

### 5. もし画面がまだ黒い場合

以下の可能性を確認：

1. **Firebase初期化エラー**
   - コンソールにエラーメッセージが表示されていないか確認
   - `GoogleService-Info.plist`が正しく追加されているか確認

2. **ContentViewが表示されていない**
   - コンソールに`✅ ContentView appeared`が表示されない場合、ContentViewが読み込まれていない可能性
   - `PersonaStampApp.swift`が正しく設定されているか確認

3. **AuthManagerの初期化エラー**
   - `AuthManager`の`init()`でエラーが発生していないか確認

## 🔍 デバッグ方法

### テストビューを表示

`PersonaStampApp.swift`を一時的に以下のように変更して、ContentViewが表示されるか確認：

```swift
var body: some Scene {
    WindowGroup {
        VStack {
            Text("Hello, World!")
                .font(.largeTitle)
                .foregroundColor(.blue)
        }
    }
}
```

これで画面に「Hello, World!」が表示されれば、ContentViewの問題です。
表示されない場合は、アプリの初期化に問題があります。

## 🚀 トラブルシューティング

### Firebase初期化エラー

もしFirebaseの初期化でエラーが発生する場合：

1. `GoogleService-Info.plist`の内容を確認
2. Bundle IDが正しいか確認
3. Firebase ConsoleでiOSアプリが正しく登録されているか確認

### ContentViewが表示されない

1. `PersonaStampApp.swift`が正しく設定されているか確認
2. `ContentView.swift`がプロジェクトに追加されているか確認
3. ビルドエラーがないか確認

