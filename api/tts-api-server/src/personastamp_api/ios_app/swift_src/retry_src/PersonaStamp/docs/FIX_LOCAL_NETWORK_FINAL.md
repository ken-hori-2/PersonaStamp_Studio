# ローカルネットワーク接続エラー最終修正ガイド

## 🔴 エラー内容

```
Local network prohibited
Error Domain=NSURLErrorDomain Code=-1009 "The Internet connection appears to be offline."
```

`NSAllowsLocalNetworking`を追加したにもかかわらず、まだエラーが発生しています。

## ✅ 解決方法

### 方法1: XcodeのUIで設定（推奨）

1. **Xcodeでプロジェクトを開く**

2. **プロジェクトナビゲーターでプロジェクト（青いアイコン）を選択**

3. **ターゲット`PersonaStamp`を選択**

4. **"Info"タブを開く**

5. **"Custom iOS Target Properties"セクションで以下を確認・追加：**

   a. **"Allow Local Network Usage"**
      - 存在しない場合："+"ボタンをクリック
      - Key: `Allow Local Network Usage`（または`NSAllowsLocalNetworking`）
      - Type: `Boolean`
      - Value: `YES`

   b. **"Privacy - Local Network Usage Description"**（オプションだが推奨）
      - "+"ボタンをクリック
      - Key: `Privacy - Local Network Usage Description`（または`NSLocalNetworkUsageDescription`）
      - Type: `String`
      - Value: `バックエンドAPIサーバーに接続するためにローカルネットワークへのアクセスが必要です`

6. **"App Transport Security Settings"を確認**
   - 存在しない場合："+"ボタンをクリック
   - Type: `Dictionary`
   - その中に：
     - Key: `Allow Arbitrary Loads`
     - Type: `Boolean`
     - Value: `YES`

### 方法2: Info.plistファイルを直接編集

もし`PersonaStamp/Info.plist`ファイルが存在する場合：

1. **Info.plistファイルを開く**

2. **以下のキーを追加：**

```xml
<key>NSAllowsLocalNetworking</key>
<true/>
<key>NSLocalNetworkUsageDescription</key>
<string>バックエンドAPIサーバーに接続するためにローカルネットワークへのアクセスが必要です</string>
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```

### 方法3: 実機での設定確認

実機でテストしている場合、iOSの設定でローカルネットワークへのアクセス許可が必要な場合があります：

1. **実機の「設定」アプリを開く**
2. **「プライバシーとセキュリティ」を選択**
3. **「ローカルネットワーク」を選択**
4. **アプリ名（PersonaStamp）を探す**
5. **スイッチをONにする**

## 🔍 確認事項

### 1. project.pbxprojの設定を確認

以下の設定が両方（DebugとRelease）にあることを確認：

```
INFOPLIST_KEY_NSAllowsLocalNetworking = YES;
```

### 2. XcodeのInfoタブで確認

- `Allow Local Network Usage`: `YES`
- `App Transport Security Settings` → `Allow Arbitrary Loads`: `YES`

### 3. 実機の場合

- iOSの設定でローカルネットワークへのアクセスが許可されているか確認

## 🚨 トラブルシューティング

### まだ接続できない場合

1. **完全にクリーンビルド**
   ```bash
   # DerivedDataを削除
   rm -rf ~/Library/Developer/Xcode/DerivedData
   ```
   - Xcodeで `Product` → `Clean Build Folder` (Shift + Cmd + K)
   - Xcodeを完全に終了（Cmd + Q）
   - Xcodeを再起動

2. **アプリを実機から削除**
   - 実機でアプリを長押し
   - "削除"を選択
   - 再度インストール

3. **ネットワークを確認**
   - MacとiOSデバイスが同じWi-Fiネットワークに接続されているか確認
   - ファイアウォールがブロックしていないか確認

4. **サーバーが起動しているか確認**
   ```bash
   curl http://localhost:8000/health
   ```

5. **MacのIPアドレスが正しいか確認**
   ```bash
   ipconfig getifaddr en0
   ```

### シミュレーターでテストする場合

シミュレーターでは`localhost:8000`を使用できるはずです。実機でのみ`10.90.222.45:8000`を使用してください。

`APIClient.swift`の設定を確認：

```swift
#if DEBUG
#if targetEnvironment(simulator)
let baseURL = "http://localhost:8000"
#else
let baseURL = "http://10.90.222.45:8000"
#endif
#else
let baseURL = "https://your-api-domain.com"
#endif
```

## 📝 まとめ

1. ✅ XcodeのInfoタブで`Allow Local Network Usage`を`YES`に設定
2. ✅ `App Transport Security Settings` → `Allow Arbitrary Loads`を`YES`に設定
3. ✅ 実機の場合、iOSの設定でローカルネットワークへのアクセスを許可
4. ✅ 完全にクリーンビルド
5. ✅ アプリを再インストール

これで、iOSアプリからバックエンドサーバーに接続できるようになります。


