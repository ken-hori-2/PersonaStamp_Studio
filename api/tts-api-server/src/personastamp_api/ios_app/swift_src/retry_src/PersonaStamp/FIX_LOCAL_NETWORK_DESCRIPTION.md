# ローカルネットワーク設定が表示されない問題の解決方法

## 🔴 問題

- XcodeのInfoタブで「Allows Local Networking」は`YES`に設定されている
- しかし、iPhoneの設定 → プライバシーとセキュリティ → ローカルネットワークにアプリが表示されない

## ✅ 原因

`NSLocalNetworkUsageDescription`が設定されていないため、iOSがローカルネットワークへのアクセス許可を要求していません。

iOS 14以降では、アプリが初めてローカルネットワークにアクセスしようとしたときに、ユーザーに許可を求めるダイアログが表示されます。しかし、`NSLocalNetworkUsageDescription`が設定されていない場合、このダイアログが表示されず、アクセスが拒否される可能性があります。

## ✅ 解決方法

### 方法1: XcodeのInfoタブで設定（推奨）

1. **Xcodeでプロジェクトを開く**

2. **プロジェクトナビゲーターでプロジェクト（青いアイコン）を選択**

3. **ターゲット`PersonaStamp`を選択**

4. **"Info"タブを開く**

5. **"Custom iOS Target Properties"セクションで以下を追加：**

   - "+"ボタンをクリック
   - Key: `Privacy - Local Network Usage Description`（または`NSLocalNetworkUsageDescription`）
   - Type: `String`
   - Value: `バックエンドAPIサーバーに接続するためにローカルネットワークへのアクセスが必要です`

6. **設定を確認**
   - `App Transport Security Settings` → `Allows Local Networking`: `YES` ✅
   - `Privacy - Local Network Usage Description`: 設定済み ✅

### 方法2: Info.plistファイルを直接編集

もし`PersonaStamp/Info.plist`ファイルが存在する場合：

1. **Info.plistファイルを開く**

2. **以下のキーを追加：**

```xml
<key>NSLocalNetworkUsageDescription</key>
<string>バックエンドAPIサーバーに接続するためにローカルネットワークへのアクセスが必要です</string>
```

## 📝 次のステップ

1. **完全にクリーンビルド**
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData
   ```
   - Xcodeで `Product` → `Clean Build Folder` (Shift + Cmd + K)
   - Xcodeを完全に終了（Cmd + Q）
   - Xcodeを再起動

2. **アプリを実機から削除**
   - 実機でアプリを長押し
   - "削除"を選択

3. **再度ビルド・実行**
   - `Product` → `Run` (Cmd + R)

4. **アプリを起動してAPIリクエストを実行**
   - アプリがローカルネットワークにアクセスしようとすると、許可を求めるダイアログが表示されます
   - "許可"を選択

5. **iOSの設定で確認**
   - 設定 → プライバシーとセキュリティ → ローカルネットワーク
   - PersonaStampアプリが表示されることを確認
   - スイッチがONになっていることを確認

## 🔍 確認事項

### XcodeのInfoタブで確認

- ✅ `App Transport Security Settings` → `Allow Arbitrary Loads`: `YES`
- ✅ `App Transport Security Settings` → `Allows Local Networking`: `YES`
- ✅ `Privacy - Local Network Usage Description`: 設定済み

### Info.plistファイルで確認

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
    <key>NSAllowsLocalNetworking</key>
    <true/>
</dict>
<key>NSLocalNetworkUsageDescription</key>
<string>バックエンドAPIサーバーに接続するためにローカルネットワークへのアクセスが必要です</string>
```

## 🚨 トラブルシューティング

### まだ表示されない場合

1. **アプリが実際にローカルネットワークにアクセスしようとしているか確認**
   - アプリを起動して、APIリクエストを実行
   - エラーログを確認

2. **完全にクリーンビルド**
   - DerivedDataを削除
   - Clean Build Folder
   - Xcodeを再起動
   - アプリを再インストール

3. **実機を再起動**
   - 実機を再起動してみる

4. **iOSのバージョンを確認**
   - iOS 14以降が必要です
   - 設定 → 一般 → 情報 で確認

## 📝 まとめ

1. ✅ `NSLocalNetworkUsageDescription`を追加
2. ✅ 完全にクリーンビルド
3. ✅ アプリを再インストール
4. ✅ アプリを起動してAPIリクエストを実行
5. ✅ 許可ダイアログで"許可"を選択
6. ✅ iOSの設定で確認

これで、iOSの設定にアプリが表示され、ローカルネットワークへのアクセスが許可されるようになります。


