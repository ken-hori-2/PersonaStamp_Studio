# Apple Developer Program 登録後の設定ガイド

## ✅ 登録完了

Apple Developer Programへの登録が完了しました。これで、すべての機能が使用可能になります。

## 📝 次のステップ

### ステップ1: Apple Developer ConsoleでBundle IDを登録

1. **Apple Developer Consoleにアクセス**
   - [Apple Developer Console](https://developer.apple.com/account/)にアクセス
   - Apple IDでログイン

2. **Identifiersに移動**
   - 左側のメニューから「Certificates, Identifiers & Profiles」をクリック
   - 「Identifiers」を選択

3. **Bundle IDを登録**
   - 右上の「+」ボタンをクリック
   - 「App IDs」を選択
   - 「Continue」をクリック
   - 「App」を選択
   - 「Continue」をクリック

4. **Bundle IDを入力**
   - Description: `PersonaStamp Studio`
   - Bundle ID: `Explicit`
   - Bundle ID: `com.ken.PersonaStampStudio`
   - 「Continue」をクリック

5. **Capabilitiesを選択**
   - 「Sign in with Apple」にチェックを入れる
   - その他の必要なCapabilityも選択（例：Push Notificationsなど）
   - 「Continue」をクリック

6. **登録を完了**
   - 内容を確認
   - 「Register」をクリック

### ステップ2: XcodeでTeamを更新

1. **Xcodeを開く**
   - `PersonaStamp.xcworkspace`を開く

2. **SettingsでTeamを確認**
   - `Xcode` → `Settings`（または `Preferences`）
   - 「Accounts」タブを選択
   - Apple IDを選択
   - 右側に「Team」が表示されることを確認
   - 「Team」が「Personal Team」から「（あなたの名前）(Individual)」または組織名に変わっていることを確認

3. **プロジェクトにTeamを設定**
   - プロジェクトナビゲーターでプロジェクト（青いアイコン）を選択
   - ターゲット`PersonaStamp`を選択
   - 「Signing & Capabilities」タブを開く
   - 「Team」ドロップダウンから、登録したTeamを選択
   - 「Automatically manage signing」がチェックされていることを確認

### ステップ3: Sign in with Apple Capabilityを追加

1. **Capabilityを追加**
   - 「+ Capability」ボタンをクリック
   - 検索バーに「Sign in with Apple」と入力
   - 「Sign in with Apple」を選択して追加

2. **確認**
   - 「Sign in with Apple」がCapabilitiesリストに表示されることを確認
   - エラーが表示されないことを確認

### ステップ4: Provisioning Profileを更新

1. **自動更新を確認**
   - 「Automatically manage signing」が有効になっている場合、Xcodeが自動的にProvisioning Profileを更新します

2. **手動で更新する場合**
   - 「Signing & Capabilities」タブで「Download Manual Profiles」をクリック
   - または、Xcodeを再起動して自動更新を待つ

### ステップ5: Clean Build Folder

1. **Clean Build Folder**
   - `Product` → `Clean Build Folder`（Shift + Cmd + K）

2. **DerivedDataをクリア（必要に応じて）**
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData
   ```

### ステップ6: 再度ビルド・実行

1. **ビルド**
   - `Product` → `Build`（Cmd + B）
   - エラーがないことを確認

2. **実行**
   - `Product` → `Run`（Cmd + R）
   - シミュレーターまたは実機で実行

3. **Apple Sign Inをテスト**
   - アプリを起動
   - 「Sign in with Apple」ボタンをタップ
   - 正常に動作することを確認

## 🔍 確認事項

### Apple Developer Console

- ✅ Bundle ID `com.ken.PersonaStampStudio` が登録されている
- ✅ 「Sign in with Apple」が有効化されている
- ✅ ステータスが「Active」になっている

### Xcode

- ✅ Teamが正しく選択されている（Personal Teamではない）
- ✅ Bundle Identifierが `com.ken.PersonaStampStudio` になっている
- ✅ 「Sign in with Apple」Capabilityが追加されている
- ✅ 「Automatically manage signing」が有効になっている
- ✅ Provisioning Profileが正しく生成されている

### Firebase Console

- ✅ Bundle ID `com.ken.PersonaStampStudio` が設定されている
- ✅ Apple Sign Inが有効化されている

## 🚨 トラブルシューティング

### Teamが表示されない場合

1. **Xcodeを再起動**
   - Xcodeを完全に終了（Cmd + Q）
   - 再度起動

2. **Settingsで再確認**
   - `Xcode` → `Settings` → `Accounts`
   - Apple IDを削除して再度追加

3. **Apple Developer Consoleで確認**
   - 登録が完了しているか確認
   - 承認待ちの状態でないか確認

### "Sign in with Apple" Capabilityが追加できない場合

1. **Bundle IDが登録されているか確認**
   - Apple Developer Consoleで確認

2. **「Sign in with Apple」が有効化されているか確認**
   - Apple Developer Console → Identifiers → Bundle IDを選択
   - 「Sign in with Apple」にチェックが入っているか確認

3. **Provisioning Profileを更新**
   - 「Signing & Capabilities」タブで「Download Manual Profiles」をクリック

### ビルドエラーが発生する場合

1. **Clean Build Folder**
   - `Product` → `Clean Build Folder`（Shift + Cmd + K）

2. **DerivedDataをクリア**
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData
   ```

3. **Xcodeを再起動**

4. **再度ビルド**

## 📝 次のステップ

1. ✅ Apple Developer ConsoleでBundle IDを登録
2. ✅ 「Sign in with Apple」を有効化
3. ✅ Xcodeで「Sign in with Apple」Capabilityを追加
4. ✅ アプリをビルド・実行
5. ✅ Apple Sign Inをテスト

## 🎉 完了

すべての設定が完了すると、Apple Sign Inが正常に動作するようになります。

実機でのテストも可能になり、App Storeへの公開準備も整います。

