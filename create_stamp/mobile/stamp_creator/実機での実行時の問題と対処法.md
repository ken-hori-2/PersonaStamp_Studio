# 実機での実行時の問題と対処法

## 🔍 よくある問題と対処法

### 1. 署名エラー（Signing Error）

#### エラーメッセージ例
```
Code signing is required for product type 'Application' in SDK 'iOS'
```

#### 対処法

1. **Xcodeでプロジェクトを開く**
2. **プロジェクトナビゲーターでプロジェクトを選択**
3. **ターゲット `stamp_creator` を選択**
4. **Signing & Capabilities タブを開く**
5. **以下の設定を確認:**
   - ✅ **Automatically manage signing** にチェックが入っている
   - ✅ **Team** が選択されている（自分のApple ID）
   - ✅ **Bundle Identifier** が一意である（例: `com.ken.init-test`）

6. **Teamが選択されていない場合:**
   - Teamドロップダウンから自分のApple IDを選択
   - または、「Add Account...」からApple IDを追加

---

### 2. プロビジョニングプロファイルの問題

#### エラーメッセージ例
```
No provisioning profiles found
Provisioning profile doesn't match bundle identifier
```

#### 対処法

1. **自動署名を有効にする**
   - Signing & Capabilities → **Automatically manage signing** にチェック
   - Xcodeが自動的にプロビジョニングプロファイルを作成

2. **Bundle Identifierを確認**
   - 一意のBundle Identifierを使用
   - 例: `com.yourname.init-test`（`yourname`を自分の名前に変更）

3. **Xcodeを再起動**
   - 時々、Xcodeのキャッシュが原因の場合がある

---

### 3. デバイスの信頼設定

#### エラーメッセージ例
```
Could not launch "stamp_creator"
```

#### 対処法

1. **iPhone/iPadで設定を開く**
2. **一般 → VPNとデバイス管理** をタップ
3. **開発者アプリ** セクションを確認
4. **自分のApple ID** をタップ
5. **「信頼」** をタップ
6. **確認ダイアログで「信頼」** をタップ

**注意**: 初回実行時のみ必要です。

---

### 4. デバイスが認識されない

#### エラーメッセージ例
```
No devices are available
```

#### 対処法

1. **USBケーブルを確認**
   - 充電専用ケーブルではなく、データ転送対応のケーブルを使用
   - 別のUSBポートを試す

2. **デバイスで「このコンピュータを信頼する」を確認**
   - iPhone/iPadに「このコンピュータを信頼しますか？」というメッセージが表示されたら「信頼」をタップ

3. **Xcodeでデバイスを確認**
   - Window → Devices and Simulators
   - デバイスが表示されているか確認

4. **デバイスのロックを解除**
   - デバイスのロックを解除してから接続

---

### 5. iOSバージョンの不一致

#### エラーメッセージ例
```
The app's Info.plist must contain an LSMinimumSystemVersion key
```

#### 対処法

1. **Deployment Targetを確認**
   - プロジェクト設定 → General → Deployment Info
   - **iOS Deployment Target** を確認（現在: iOS 15.0以上推奨）

2. **デバイスのiOSバージョンを確認**
   - 設定 → 一般 → 情報 → ソフトウェアバージョン
   - Deployment Targetより新しいバージョンであることを確認

---

### 6. バンドルIDの競合

#### エラーメッセージ例
```
An App ID with Identifier 'com.ken.stamp-creator' is not available
```

#### 対処法

1. **Bundle Identifierを変更**
   - Signing & Capabilities → Bundle Identifier
   - 一意のIDに変更（例: `com.yourname.init-test-2024`）

2. **逆ドメイン表記を使用**
   - 例: `com.yourname.inittest`
   - 例: `com.yourname.bgremoval`

---

### 7. 開発者アカウントの問題

#### エラーメッセージ例
```
Your account does not have permission to create provisioning profiles
```

#### 対処法

1. **Apple Developer Programに加入しているか確認**
   - 無料のApple IDでも開発は可能ですが、一部機能が制限される場合があります

2. **Xcodeでアカウントを再ログイン**
   - Xcode → Settings → Accounts
   - アカウントを削除して再度追加

---

## 🔧 トラブルシューティング手順

### ステップ1: 基本的な確認

1. ✅ **デバイスが接続されているか確認**
2. ✅ **デバイスのロックが解除されているか確認**
3. ✅ **USBケーブルが正しく接続されているか確認**
4. ✅ **Xcodeが最新バージョンか確認**

### ステップ2: 署名設定の確認

1. ✅ **Signing & CapabilitiesでTeamが選択されているか**
2. ✅ **Automatically manage signingが有効か**
3. ✅ **Bundle Identifierが一意か**

### ステップ3: デバイスの信頼設定

1. ✅ **iPhone/iPadで「このコンピュータを信頼する」を確認**
2. ✅ **設定 → 一般 → VPNとデバイス管理で開発者を信頼**

### ステップ4: Xcodeのクリーンアップ

1. **Product → Clean Build Folder** (`Shift + Cmd + K`)
2. **Xcodeを再起動**
3. **デバイスを再接続**

---

## 📝 チェックリスト

実機で実行する前に確認:

- [ ] デバイスがMacに接続されている
- [ ] デバイスのロックが解除されている
- [ ] 「このコンピュータを信頼する」をタップした
- [ ] Xcodeでデバイスが認識されている
- [ ] Signing & CapabilitiesでTeamが選択されている
- [ ] Automatically manage signingが有効
- [ ] Bundle Identifierが一意である
- [ ] iOS Deployment TargetがデバイスのiOSバージョン以下
- [ ] デバイスで開発者を信頼した（初回のみ）

---

## 🆘 それでも解決しない場合

### 1. エラーメッセージを確認

Xcodeのエラーメッセージを正確に確認してください。エラーメッセージによって対処法が異なります。

### 2. ログを確認

Xcodeの下部のコンソールエリアで、より詳細なエラーメッセージを確認してください。

### 3. 一般的な解決策

```bash
# XcodeのDerivedDataをクリア
rm -rf ~/Library/Developer/Xcode/DerivedData

# Xcodeを再起動
```

---

## 💡 よくある質問

### Q: 無料のApple IDで実機にインストールできますか？

A: はい、可能です。ただし、7日間ごとに再署名が必要です。

### Q: Apple Developer Programに加入する必要がありますか？

A: 開発中は不要です。App Storeに公開する場合のみ必要です（年間$99）。

### Q: 複数のデバイスでテストできますか？

A: はい、同じApple IDで複数のデバイスを登録できます。

---

**具体的なエラーメッセージを教えていただければ、より詳細な対処法を提案できます！**

