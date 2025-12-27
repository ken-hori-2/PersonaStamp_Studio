# マイクの使用許可エラー修正ガイド

## 🔴 エラー内容

```
This app has crashed because it attempted to access privacy-sensitive data without a usage description.  
The app's Info.plist must contain an NSMicrophoneUsageDescription key with a string value explaining 
to the user how the app uses this data.
```

アプリがマイクにアクセスしようとしましたが、Info.plistにマイクの使用許可の説明（`NSMicrophoneUsageDescription`）が含まれていないため、アプリがクラッシュしました。

## ✅ 修正内容

`project.pbxproj`に`INFOPLIST_KEY_NSMicrophoneUsageDescription`を追加しました。

- Debug設定とRelease設定の両方に追加
- 値: `音声を録音してVoice Cloningに使用します`

## 📝 確認方法

### Xcodeで確認

1. Xcodeで`PersonaStamp.xcworkspace`を開く
2. プロジェクトナビゲーターでプロジェクト（青いアイコン）を選択
3. ターゲット`PersonaStamp`を選択
4. **"Info"タブ**を開く
5. **"Custom iOS Target Properties"**セクションを確認
6. **"Privacy - Microphone Usage Description"**が表示されていることを確認
7. 値が`音声を録音してVoice Cloningに使用します`になっていることを確認

### または、"Build Settings"で確認

1. **"Build Settings"タブ**を開く
2. 検索バーに`INFOPLIST_KEY_NSMicrophoneUsageDescription`と入力
3. 値が`音声を録音してVoice Cloningに使用します`になっていることを確認

## 🚀 次のステップ

1. **Clean Build Folder**
   - `Product` → `Clean Build Folder` (Shift + Cmd + K)

2. **再度ビルド・実行**
   - `Product` → `Build` (Cmd + B)
   - `Product` → `Run` (Cmd + R)

3. **マイクの使用許可をテスト**
   - アプリを起動
   - Voice Clone機能を使用
   - マイクの使用許可ダイアログが表示されることを確認
   - 許可を選択
   - 正常に録音できることを確認

## 🔍 その他のエラーについて

### App Delegateエラー

```
App Delegate does not conform to UIApplicationDelegate protocol
```

これはSwiftUIアプリでAppDelegateを使っていない場合、無視できる警告です。
Firebaseは自動的にAppDelegateを検出しようとしますが、SwiftUIアプリでは`@main`の`App`構造体で初期化するため、この警告は表示されますが動作には影響しません。

## 📝 まとめ

- ✅ `NSMicrophoneUsageDescription`を追加
- ✅ マイクの使用許可ダイアログが表示されるようになる
- ✅ アプリがクラッシュしなくなる

これで、Voice Clone機能でマイクを使用できるようになります。


