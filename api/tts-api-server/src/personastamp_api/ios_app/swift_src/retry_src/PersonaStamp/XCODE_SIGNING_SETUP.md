# Xcode Signing & Capabilities 設定ガイド

## 📋 手順

### 1. Bundle IDの確認

1. Xcodeで`PersonaStamp.xcworkspace`を開く
2. プロジェクトナビゲーターで**プロジェクト（青いアイコン）**を選択
3. ターゲット`PersonaStamp`を選択
4. **"Signing & Capabilities"タブ**を開く
5. **"Signing"セクション**を展開（下向き矢印をクリック）
6. **Bundle Identifier**が`com.ken.PersonaStampStudio`になっているか確認

### 2. Teamの設定

1. "Signing"セクションで**"Team"**ドロップダウンを確認
2. Teamが選択されていない場合：
   - **Xcode → Settings → Accounts**を開く
   - 左下の"+"ボタンをクリック
   - "Apple ID"を選択
   - Apple IDとパスワードを入力
   - "Sign In"をクリック
   - 追加したApple IDを選択
   - 右側の"Team"ドロップダウンからTeamを選択
   - プロジェクトの"Signing & Capabilities"タブに戻る
   - "Team"ドロップダウンから先ほど選択したTeamを選択

### 3. Sign in with Apple Capabilityの追加

1. **"+ Capability"ボタン**をクリック
2. 検索バーに**"Sign in with Apple"**と入力
3. **"Sign in with Apple"**を選択
4. 追加されたことを確認

### 4. Bundle IDが表示されない場合

もしBundle Identifierが表示されない、または変更できない場合：

1. **"General"タブ**を開く
2. **"Identity"セクション**で**Bundle Identifier**を確認
3. `com.ken.PersonaStampStudio`に変更

### 5. 確認事項

正しく設定されている場合：

- ✅ Bundle Identifier: `com.ken.PersonaStampStudio`
- ✅ Team: （あなたのTeam名）
- ✅ "Sign in with Apple" Capabilityが追加されている
- ✅ "Automatically manage signing"が有効になっている

## 🔍 トラブルシューティング

### "Sign in with Apple"が表示されない場合

1. **Apple Developer Accountにサインインしているか確認**
   - Xcode → Settings → Accounts
   - Apple IDが追加されているか確認

2. **Teamが選択されているか確認**
   - "Signing & Capabilities"タブでTeamが選択されているか確認

3. **Bundle IDがApple Developer Consoleに登録されているか確認**
   - [Apple Developer Console](https://developer.apple.com/account/)にアクセス
   - "Certificates, Identifiers & Profiles" → "Identifiers"
   - `com.ken.PersonaStampStudio`が登録されているか確認
   - 登録されていない場合、登録する

### Bundle IDが変更できない場合

1. **"Automatically manage signing"を無効化**
2. **"General"タブ**でBundle Identifierを変更
3. **"Automatically manage signing"を再度有効化**

### Teamが表示されない場合

1. **Xcode → Settings → Accounts**を開く
2. Apple IDが追加されているか確認
3. 追加されていない場合、追加する
4. Teamが表示されない場合、Apple Developer Programに加入しているか確認

## 📝 スクリーンショットの確認ポイント

正しく設定されている場合、以下のように表示されます：

```
Signing & Capabilities
├── Signing
│   ├── Team: （あなたのTeam名）
│   ├── Bundle Identifier: com.ken.PersonaStampStudio
│   └── Automatically manage signing: ✅
└── Capabilities
    └── Sign in with Apple ✅
```

