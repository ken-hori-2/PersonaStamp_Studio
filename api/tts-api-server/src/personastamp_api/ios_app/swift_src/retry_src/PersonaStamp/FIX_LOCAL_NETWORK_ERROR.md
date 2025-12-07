# ローカルネットワーク接続エラー修正ガイド

## 🔴 エラー内容

```
Local network prohibited
Error Domain=NSURLErrorDomain Code=-1009 "The Internet connection appears to be offline."
```

iOS 14以降では、ローカルネットワーク（MacのIPアドレスなど）へのアクセスが制限されています。

## ✅ 解決方法

### 修正内容

`project.pbxproj`に`INFOPLIST_KEY_NSAllowsLocalNetworking = YES;`を追加しました。

これにより、iOSアプリがローカルネットワーク（MacのIPアドレス）にアクセスできるようになります。

### Xcodeでの確認方法

1. **Xcodeでプロジェクトを開く**
2. **プロジェクトナビゲーターでプロジェクト（青いアイコン）を選択**
3. **ターゲット`PersonaStamp`を選択**
4. **"Info"タブを開く**
5. **"Custom iOS Target Properties"セクションを確認**
6. **"Allow Local Network Usage"**が表示されていることを確認
7. **値が`YES`になっていることを確認**

### または、"Build Settings"で確認

1. **"Build Settings"タブを開く**
2. **検索バーに`NSAllowsLocalNetworking`と入力**
3. **値が`YES`になっていることを確認**

## 📝 次のステップ

1. **Clean Build Folder**
   - `Product` → `Clean Build Folder` (Shift + Cmd + K)

2. **再度ビルド・実行**
   - `Product` → `Build` (Cmd + B)
   - `Product` → `Run` (Cmd + R)

3. **接続を確認**
   - エラーが解消され、APIリクエストが成功することを確認

## 🔍 その他のエラーについて

### App Delegateエラー

```
App Delegate does not conform to UIApplicationDelegate protocol
```

これはSwiftUIアプリでAppDelegateを使っていない場合、無視できる警告です。動作には影響しません。

## 📋 確認事項

- ✅ `NSAllowsLocalNetworking`が`YES`に設定されている
- ✅ `App Transport Security Settings` → `Allow Arbitrary Loads`が`YES`に設定されている
- ✅ `APIClient.swift`の`baseURL`が正しく設定されている（実機: `http://10.90.222.45:8000`）
- ✅ バックエンドサーバーが起動している（`http://0.0.0.0:8000`）
- ✅ MacとiOSデバイスが同じWi-Fiネットワークに接続されている（実機の場合）

## 🚨 トラブルシューティング

### まだ接続できない場合

1. **Info.plistの設定を確認**
   - Xcodeの"Info"タブで以下が設定されているか確認：
     - `App Transport Security Settings` → `Allow Arbitrary Loads`: `YES`
     - `Allow Local Network Usage`: `YES`（または`NSAllowsLocalNetworking`）

2. **ファイアウォールを確認**
   - システム環境設定 → セキュリティとプライバシー → ファイアウォール
   - Pythonまたはuvicornの接続を許可

3. **ネットワークを確認**
   - MacとiOSデバイスが同じWi-Fiネットワークに接続されているか確認

4. **サーバーが起動しているか確認**
   ```bash
   curl http://localhost:8000/health
   ```

5. **MacのIPアドレスが正しいか確認**
   ```bash
   ipconfig getifaddr en0
   ```

## 📝 まとめ

- ✅ `NSAllowsLocalNetworking`を`YES`に設定
- ✅ ローカルネットワークへのアクセスが許可される
- ✅ 実機からMacのIPアドレスに接続できるようになる

これで、iOSアプリからバックエンドサーバーに接続できるようになります。


