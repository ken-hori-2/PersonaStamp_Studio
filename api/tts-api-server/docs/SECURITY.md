# セキュリティに関する重要な注意事項

## ⚠️ iOSアプリへのAPIキー保存のリスク

### 問題点

**iOSアプリにAPIキーを保存すると、逆アセンブル（リバースエンジニアリング）で漏洩する可能性があります。**

refs.mdにも明記されています：
> ❌ iOS に API Key を絶対入れてはダメ
> - 逆コンパイルで100%盗まれる
> - あなたの Fish Audio アカウントが乗っ取られ高額請求

## 🔑 2種類のキーの違いとリスク

### 1. **アクセストークン**（`sk_xxxxx`）

**現在の実装**: iOSアプリに保存される

**リスク評価**:
- ⚠️ **中程度のリスク**: 逆アセンブルで漏洩する可能性
- ✅ **影響範囲は限定的**: ユーザーごとに異なるトークン
- ✅ **利用制限で保護**: 日次/月次制限があるため、悪用されても影響は限定的

**漏洩した場合の影響**:
- そのユーザーのアカウントが悪用される
- 利用制限内での不正利用
- 他のユーザーへの影響はなし

### 2. **Fish Audio APIキー**

**現在の実装**: サーバー側のみ（環境変数）

**リスク評価**:
- ✅ **低リスク**: iOSアプリからは絶対に見えない
- ✅ **保護されている**: サーバー側のみで使用

**漏洩した場合の影響**:
- ❌ **致命的**: すべてのユーザーが影響
- ❌ **高額請求**: 制限なく使用される可能性
- ❌ **アカウント乗っ取り**: 完全に制御される

## 🛡️ セキュリティ対策

### 現在の実装の安全性

#### ✅ 安全な点

1. **Fish Audio APIキーは保護されている**
   ```python
   # api_server.py
   def get_fish_api_key() -> str:
       api_key = os.environ.get("FISH_AUDIO_API_KEY", "")
       # 環境変数から取得（サーバー側のみ）
   ```
   - iOSアプリからは絶対に見えない
   - サーバー側のみで使用

2. **アクセストークンはユーザーごとに異なる**
   - 漏洩しても影響は限定的
   - 利用制限で保護

#### ⚠️ 改善が必要な点

1. **アクセストークンの保存方法**
   - 現在: 平文で保存（UserDefaults等）
   - 推奨: iOS Keychainに保存

2. **アクセストークンの有効期限**
   - 現在: 無期限
   - 推奨: 有効期限を設定

3. **トークンのリフレッシュ**
   - 現在: なし
   - 推奨: リフレッシュトークン機能

## 🔒 iOSアプリでの実装推奨事項

### 1. Keychainへの保存

```swift
import Security

// Keychainに保存
func saveAPIKey(_ apiKey: String) {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrAccount as String: "tts_api_key",
        kSecValueData as String: apiKey.data(using: .utf8)!
    ]
    
    SecItemDelete(query as CFDictionary) // 既存の削除
    SecItemAdd(query as CFDictionary, nil) // 新規追加
}

// Keychainから取得
func getAPIKey() -> String? {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrAccount as String: "tts_api_key",
        kSecReturnData as String: true
    ]
    
    var result: AnyObject?
    SecItemCopyMatching(query as CFDictionary, &result)
    
    if let data = result as? Data {
        return String(data: data, encoding: .utf8)
    }
    return nil
}
```

### 2. コード難読化（オプション）

- アクセストークンを直接コードに書かない
- 動的に取得する

### 3. サーバー側での追加保護

```python
# アクセストークンに有効期限を追加
class UserToken(BaseModel):
    user_id: str
    api_key: str
    expires_at: datetime  # 有効期限
    refresh_token: str    # リフレッシュトークン
```

## 📊 リスク比較

| 項目 | アクセストークン | Fish Audio APIキー |
|------|----------------|-------------------|
| iOSアプリに保存 | ⚠️ 可能（Keychain推奨） | ❌ 絶対にダメ |
| 漏洩時の影響 | 限定的（そのユーザーのみ） | 致命的（全ユーザー） |
| 逆アセンブルリスク | 中程度 | 高（保存しない） |
| 現在の実装 | iOSアプリに保存 | サーバー側のみ ✅ |

## 🎯 推奨される実装

### iOSアプリ側

1. **Keychainに保存**
   - UserDefaultsではなくKeychainを使用
   - 暗号化されて保存される

2. **コード難読化**
   - アクセストークンを直接コードに書かない
   - 動的に取得・保存

3. **セッション管理**
   - アプリ起動時に再認証
   - 定期的にトークンを更新

### サーバー側（将来の改善）

1. **トークンの有効期限**
   ```python
   # database.py
   expires_at TIMESTAMP,
   refresh_token TEXT
   ```

2. **IPアドレス制限**
   - トークンとIPアドレスを紐付け
   - 異常なアクセスを検知

3. **レート制限**
   - IPアドレスベースのレート制限
   - 異常なリクエストをブロック

## ✅ 現在の実装の評価

### 安全性

- ✅ **Fish Audio APIキー**: 完全に保護されている
- ⚠️ **アクセストークン**: 改善の余地あり（Keychain推奨）

### 結論

**現在の実装は基本的に安全です**が、以下の改善を推奨します：

1. iOSアプリでKeychainを使用
2. アクセストークンに有効期限を設定
3. サーバー側でIPアドレス制限を追加

**重要なのは、Fish Audio APIキーは絶対にiOSアプリに入れないことです。これは既に実装されています。✅**

