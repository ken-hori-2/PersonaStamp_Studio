# iOSアプリからバックエンドサーバーに接続できない問題の解決方法

## 🔴 問題

APIサーバーは起動しているが、iOSアプリから接続できない。

## ✅ 解決方法

### シミュレーターでテストする場合

シミュレーターでは`localhost:8000`で接続できるはずですが、接続できない場合は以下を試してください：

1. **APIClient.swiftを確認**
   ```swift
   #if DEBUG
   let baseURL = "http://localhost:8000"
   #else
   let baseURL = "https://your-api-domain.com"
   #endif
   ```

2. **サーバーが`0.0.0.0`で起動していることを確認**
   - サーバーは既に`http://0.0.0.0:8000`で起動しているのでOK

3. **Info.plistにApp Transport Securityの設定を追加**
   - Xcodeでプロジェクトを選択
   - ターゲット`PersonaStamp`を選択
   - "Info"タブを開く
   - "+"ボタンをクリック
   - Key: `App Transport Security Settings`
   - Type: `Dictionary`
   - その中に：
     - Key: `Allow Arbitrary Loads`
     - Type: `Boolean`
     - Value: `YES`

### 実機でテストする場合

実機では`localhost`は使用できません。MacのIPアドレスを使用する必要があります。

1. **MacのIPアドレスを確認**
   ```bash
   ipconfig getifaddr en0
   ```
   または：
   ```bash
   ifconfig | grep "inet " | grep -v 127.0.0.1
   ```
   
   例: `10.90.222.45`（あなたのMacのIPアドレス）

2. **APIClient.swiftを修正**
   ```swift
   #if DEBUG
   // 実機用（MacのIPアドレスに変更）
   let baseURL = "http://10.90.222.45:8000"
   #else
   let baseURL = "https://your-api-domain.com"
   #endif
   ```

3. **サーバーが`0.0.0.0`で起動していることを確認**
   - サーバーは既に`http://0.0.0.0:8000`で起動しているのでOK

4. **ファイアウォールの設定**
   - システム環境設定 → セキュリティとプライバシー → ファイアウォール
   - 必要に応じて、Pythonまたはuvicornの接続を許可

5. **Info.plistにApp Transport Securityの設定を追加**
   - Xcodeでプロジェクトを選択
   - ターゲット`PersonaStamp`を選択
   - "Info"タブを開く
   - "+"ボタンをクリック
   - Key: `App Transport Security Settings`
   - Type: `Dictionary`
   - その中に：
     - Key: `Allow Arbitrary Loads`
     - Type: `Boolean`
     - Value: `YES`

## 🔍 確認事項

### 1. サーバーが起動しているか確認

ターミナルで以下を実行：
```bash
curl http://localhost:8000/health
```

正常な場合、レスポンスが返ってきます。

### 2. ネットワーク接続を確認

MacとiOSデバイス（実機の場合）が同じWi-Fiネットワークに接続されていることを確認してください。

### 3. CORS設定を確認

`api_server.py`のCORS設定を確認：
```python
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # 本番環境では適切に制限
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
```

## 🚨 トラブルシューティング

### エラー: "Could not connect to the server"

1. **サーバーが起動しているか確認**
   ```bash
   lsof -i :8000
   ```

2. **ファイアウォールを確認**
   - システム環境設定 → セキュリティとプライバシー → ファイアウォール
   - Pythonまたはuvicornの接続を許可

3. **ネットワークを確認**
   - MacとiOSデバイスが同じWi-Fiネットワークに接続されているか確認

### エラー: "App Transport Security has blocked a cleartext HTTP"

Info.plistにApp Transport Securityの設定を追加してください（上記参照）。

### シミュレーターで接続できない場合

1. **シミュレーターを再起動**
2. **Xcodeを再起動**
3. **MacのIPアドレスを使用してみる**
   ```swift
   let baseURL = "http://10.90.222.45:8000"
   ```

## 📝 推奨設定

### 開発環境用の設定

`APIClient.swift`を以下のように設定することを推奨：

```swift
#if DEBUG
// シミュレーターと実機の両方に対応
#if targetEnvironment(simulator)
let baseURL = "http://localhost:8000"
#else
// 実機用（MacのIPアドレス）
let baseURL = "http://10.90.222.45:8000"
#endif
#else
let baseURL = "https://your-api-domain.com"
#endif
```

これにより、シミュレーターでは`localhost`、実機ではMacのIPアドレスが自動的に使用されます。

## ✅ 確認手順

1. ✅ サーバーが起動している
2. ✅ `APIClient.swift`の`baseURL`が正しく設定されている
3. ✅ Info.plistにApp Transport Securityの設定が追加されている
4. ✅ ファイアウォールが適切に設定されている
5. ✅ MacとiOSデバイスが同じWi-Fiネットワークに接続されている（実機の場合）

これで、iOSアプリからバックエンドサーバーに接続できるようになります。


