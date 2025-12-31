# APIキーの制限設定手順

## 📋 概要

Firebase APIキーに適切な制限を設定する手順を説明します。

---

## 🚀 設定手順

### ステップ1: Google Cloud ConsoleでAPIキーを開く

1. **Google Cloud Consoleにアクセス**
   - https://console.cloud.google.com/
   - プロジェクト: `personastamp-studio` を選択

2. **APIとサービス > 認証情報**を開く
   - 左側のメニューから「APIとサービス」>「認証情報」を選択

3. **APIキーを選択**
   - 「iOS key (auto created by Firebase)」をクリック
   - または、使用中のAPIキーを選択

---

### ステップ2: アプリケーションの制限を設定

1. **「アプリケーションの制限」セクション**
   - 現在「なし」が選択されている場合、**「iOSアプリ」を選択**

2. **「+ アプリを追加」をクリック**
   - Bundle ID: `com.ken.PersonaStampStudio` を入力
   - **重要**: 大文字・小文字に注意（`com.ken.PersonaStampStudio`）
   - 「完了」をクリック

3. **「保存」をクリック**

---

### ステップ3: APIの制限を設定

1. **「APIの制限」セクション**
   - **「APIキーを制限」を選択**

2. **「APIを選択」をクリック**
   - ドロップダウンを開く

3. **すべてのAPIの選択を解除**
   - チェックボックスをすべて外す

4. **必要なAPIのみを選択**:
   - ✅ **Identity Toolkit API**（Firebase Authentication用）
   - ✅ **Firebase Installations API**（Firebase SDK用）
   - ✅ **Token Service API**（認証トークンの取得に必須）

5. **「保存」をクリック**

---

## ✅ 設定後の確認

### アプリケーションの制限

- ✅ **iOSアプリ**が選択されている
- ✅ Bundle ID: `com.ken.PersonaStampStudio` が追加されている

### APIの制限

- ✅ **キーを制限**が選択されている
- ✅ **3個のAPIのみ**が選択されている:
  1. Identity Toolkit API
  2. Firebase Installations API
  3. Token Service API

---

## 🔍 トラブルシューティング

### エラー: "認証トークンがない"

**原因**: Token Service APIが選択されていない

**解決方法**: Token Service APIを追加

### エラー: "Firebase Authentication error"

**原因**: Identity Toolkit APIが選択されていない

**解決方法**: Identity Toolkit APIを追加

### エラー: "Firebase SDK initialization failed"

**原因**: Firebase Installations APIが選択されていない

**解決方法**: Firebase Installations APIを追加

---

## ⚠️ 注意事項

### 最小権限の原則

**必要なAPIのみを選択してください：**

- ✅ Identity Toolkit API（必須）
- ✅ Firebase Installations API（必須）
- ✅ Token Service API（必須）

**不要なAPIは選択しないでください：**

- ❌ Cloud SQL Admin API（使用していない）
- ❌ Cloud Datastore API（使用していない）
- ❌ Cloud Logging API（使用していない）
- ❌ Firebase Realtime Database Management API（使用していない）
- ❌ Gemini API（使用していない）
- ❌ Google Maps API（使用していない）
- ❌ その他、使用していないFirebaseサービス

---

## 📚 参考資料

- [APIキーの制限](https://cloud.google.com/docs/authentication/api-keys#api_key_restrictions)
- [Firebase Authentication](https://firebase.google.com/docs/auth)

---

**更新日**: 2025年1月  
**作成者**: AI Assistant

