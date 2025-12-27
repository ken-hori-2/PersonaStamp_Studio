# プロジェクト初期セットアップ

## 📋 概要

PersonaStamp Studio iOSアプリの初期セットアップ手順を説明します。

---

## 🚀 セットアップ手順

### ステップ1: Firebaseプロジェクトの作成

1. **Firebase Consoleにアクセス**
   - https://console.firebase.google.com/
   - Googleアカウントでログイン

2. **「プロジェクトを追加」をクリック**

3. **プロジェクト名を入力**
   - プロジェクト名: `PersonaStamp Studio`（または任意の名前）
   - プロジェクトID: `personastamp-studio`（自動生成されるが、変更可能）

4. **Google Analyticsの設定**
   - 必要に応じて有効化（推奨: 有効化）

5. **「プロジェクトを作成」をクリック**
   - 数分かかる場合があります

---

### ステップ2: iOSアプリを追加

1. **Firebase Consoleでプロジェクトを選択**

2. **「アプリを追加」をクリック**
   - iOSアイコンを選択

3. **iOSアプリの情報を入力**
   - Bundle ID: `com.ken.PersonaStampStudio`
   - アプリのニックネーム: `RendVu`（任意）
   - App Store ID: 空白（App Storeに公開していない場合）

4. **「アプリを登録」をクリック**

5. **`GoogleService-Info.plist`をダウンロード**
   - ダウンロードボタンをクリック
   - ファイルを保存

---

### ステップ3: GoogleService-Info.plistを配置

1. **ダウンロードした`GoogleService-Info.plist`を確認**
   - ファイルを開く
   - `API_KEY`が含まれているか確認

2. **Xcodeプロジェクトに配置**
   - `RendVu/RendVu/GoogleService-Info.plist`に配置
   - Xcodeでプロジェクトを開く
   - ファイルをドラッグ&ドロップ
   - ✅ "Copy items if needed" をチェック
   - ✅ "Add to targets: RendVu" をチェック

---

### ステップ4: Firebase Authenticationを設定

1. **Firebase Console > Authentication**

2. **「始める」をクリック**（まだの場合）

3. **「Sign-in method」タブを開く**

4. **Apple Sign Inを有効化**
   - 「Apple」をクリック
   - 「有効にする」をトグル
   - 「保存」をクリック

---

### ステップ5: APIキーの制限を設定

1. **Google Cloud Consoleにアクセス**
   - https://console.cloud.google.com/
   - プロジェクト: `personastamp-studio` を選択

2. **APIとサービス > 認証情報**

3. **APIキーを選択**（FirebaseプロジェクトのAPIキー）

4. **制限を設定**
   - アプリケーションの制限: iOSアプリ、Bundle ID `com.ken.PersonaStampStudio`
   - APIの制限: Identity Toolkit API、Firebase Installations API、Token Service API

詳細は `02_api_key/api_key_restrictions.md` を参照

---

## ✅ セットアップ完了後の確認

### Firebase Console

- [ ] Firebase Authenticationが有効化されている
- [ ] Apple Sign Inが有効化されている
- [ ] `GoogleService-Info.plist`がダウンロード可能

### Google Cloud Console

- [ ] APIキーが正しいプロジェクト（`personastamp-studio`）に関連付けられている
- [ ] APIキーの制限が設定されている

### Xcodeプロジェクト

- [ ] Bundle IDが `com.ken.PersonaStampStudio` になっている
- [ ] `GoogleService-Info.plist`がプロジェクトに含まれている
- [ ] `GoogleService-Info.plist`のターゲットメンバーシップが正しい

---

## 📚 参考資料

- [Firebase iOS セットアップ](https://firebase.google.com/docs/ios/setup)
- [Firebase Authentication](https://firebase.google.com/docs/auth)

---

**更新日**: 2025年1月  
**作成者**: AI Assistant

