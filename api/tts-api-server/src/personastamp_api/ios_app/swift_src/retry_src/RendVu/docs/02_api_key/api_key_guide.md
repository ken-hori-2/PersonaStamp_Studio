# Firebase APIキー完全ガイド

## 📋 概要

Firebase APIキーの生成、設定、セキュリティ対策について説明します。

---

## 🔍 APIキーの生成タイミングと場所

### 1. Firebase Consoleで自動生成されるAPIキー

**生成タイミング**: Firebaseプロジェクトを作成した時点で自動生成

**生成場所**: Firebase Console（内部的にGoogle Cloud Platformで生成）

**特徴**:
- FirebaseプロジェクトのデフォルトAPIキー
- `GoogleService-Info.plist`に含まれる（Firebase Consoleからダウンロードした場合）
- 通常、制限が設定されていない（セキュリティリスクあり）

**確認方法**:
1. Firebase Console > プロジェクト設定 > 全般
2. 「GoogleService-Info.plistをダウンロード」
3. ファイル内の`API_KEY`を確認

### 2. Google Cloud Consoleで手動で作成するAPIキー

**生成タイミング**: 開発者が手動で作成

**生成場所**: Google Cloud Console > APIとサービス > 認証情報

**特徴**:
- 制限を設定できる（推奨）
- アプリケーションの制限（Bundle IDなど）を設定可能
- APIの制限（使用可能なAPI）を設定可能

---

## ⚠️ セキュリティリスク

### 1. APIキーが抽出されるリスク

**iOSアプリは逆アセンブル可能**:
- `.ipa`ファイルはZIP形式のため、簡単に解凍可能
- `GoogleService-Info.plist`は読み取り可能
- ツール（`otool`、`class-dump`など）で抽出可能

**結論**: APIキーは確実に抽出可能です。

### 2. 制限が設定されていない場合のリスク

**重大なリスク**:
1. **💰 不正な課金**: 攻撃者がGemini APIやGoogle Maps APIを無断で使用
2. **📊 使用量の悪用**: APIキーが抽出され、大量のリクエストが送信される
3. **🔓 サービスへの不正アクセス**: 他のGoogle Cloudサービスへの不正アクセス

---

## ✅ 必須のセキュリティ対策

### 1. アプリケーションの制限を設定（最優先）

1. **Google Cloud ConsoleでAPIキーを開く**
   - https://console.cloud.google.com/
   - プロジェクト: `personastamp-studio` を選択
   - APIとサービス > 認証情報
   - APIキーを選択

2. **「アプリケーションの制限」セクション**
   - **「iOSアプリ」を選択**

3. **「+ アプリを追加」をクリック**
   - Bundle ID: `com.ken.PersonaStampStudio` を入力
   - 「完了」をクリック

4. **「保存」をクリック**

**効果**:
- ✅ 正規のiOSアプリ（Bundle ID: `com.ken.PersonaStampStudio`）からのリクエストのみ許可
- ❌ 不正なアプリやスクリプトからのリクエストはブロックされる

### 2. APIの制限を設定（必須）

1. **「APIの制限」セクション**
   - **「APIキーを制限」を選択**

2. **「APIを選択」をクリック**

3. **以下の3個のAPIのみを選択**:
   - ✅ **Identity Toolkit API**（Firebase Authentication用）
   - ✅ **Firebase Installations API**（Firebase SDK用）
   - ✅ **Token Service API**（認証トークンの取得に必須）

4. **「保存」をクリック**

**効果**:
- ✅ Firebase AuthenticationとFirebase SDKに必要なAPIのみアクセス可能
- ❌ 不要なAPI（Cloud SQL、Cloud Datastore、Cloud Loggingなど）へのアクセスをブロック
- ❌ Gemini APIやGoogle Maps APIへのアクセスをブロック

---

## 📋 必要なAPI一覧

### 必須のAPI（3個）

1. **Identity Toolkit API**
   - Firebase Authenticationに必須
   - ユーザー認証に使用
   - 使用箇所: `Auth.auth().signIn(with: credential)`

2. **Firebase Installations API**
   - Firebase SDKに必須
   - アプリのインストール情報を管理
   - 使用箇所: `FirebaseApp.configure()`

3. **Token Service API**
   - Firebase IDトークンの取得に必須
   - トークンの生成とリフレッシュ
   - 使用箇所: `user.getIDToken()`

---

## 🔍 確認方法

### 設定の確認

1. **Google Cloud Console > APIとサービス > 認証情報**
2. **APIキーを選択**
3. **設定を確認**:
   - 「アプリケーションの制限」: iOSアプリ、Bundle ID `com.ken.PersonaStampStudio`
   - 「APIの制限」: 3個のAPI（Identity Toolkit API、Firebase Installations API、Token Service API）

### アプリの動作確認

1. **Xcodeでアプリをビルド**
2. **アプリを実行**
3. **Firebase Authenticationが正常に動作するか確認**
4. **Apple Sign Inが正常に動作するか確認**

---

## 📊 リスク評価

### 対策実施前のリスクレベル: 🔴 高

- アプリケーションの制限が設定されていない
- 過剰なAPI権限が付与されている
- 不正な課金や使用量の悪用のリスクが高い

### 対策実施後のリスクレベル: 🟢 低

- アプリケーションの制限により、正規アプリからのリクエストのみ許可
- APIの制限により、必要なAPIのみアクセス可能
- 不正な課金や使用量の悪用のリスクが大幅に低減

---

## 📚 参考資料

- [APIキーの制限](https://cloud.google.com/docs/authentication/api-keys#api_key_restrictions)
- [Firebase Authentication](https://firebase.google.com/docs/auth)
- [Firebase ID Tokens](https://firebase.google.com/docs/auth/admin/verify-id-tokens)

---

**更新日**: 2025年1月  
**作成者**: AI Assistant

