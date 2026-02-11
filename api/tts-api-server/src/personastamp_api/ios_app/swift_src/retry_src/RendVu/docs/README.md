# PersonaStamp Studio iOS アプリ ドキュメント

## 📚 ドキュメント構成

このディレクトリには、PersonaStamp Studio iOSアプリの開発・運用に関するドキュメントが整理されています。

### ディレクトリ構成

```
docs/
├── 01_setup/              # 初期セットアップ
├── 02_api_key/            # APIキー管理
├── 03_authentication/     # 認証関連
├── 04_troubleshooting/    # トラブルシューティング
├── 05_development/        # 開発環境
└── 06_reference/         # 参考資料
```

---

## 📖 カテゴリ別ドキュメント

### 01_setup/ - 初期セットアップ

プロジェクトの初期セットアップに関するドキュメント

- `project_setup.md` - Firebaseプロジェクトの作成と初期設定

### 02_api_key/ - APIキー管理

Firebase APIキーの設定、制限、セキュリティ対策

- `api_key_guide.md` - APIキーの完全ガイド（生成、設定、セキュリティ）
- `api_key_restrictions.md` - APIキーの制限設定手順

### 03_authentication/ - 認証関連

Firebase Authentication、Apple Sign Inの設定とトラブルシューティング

- `firebase_authentication.md` - Firebase Authenticationの設定と使用方法

### 04_troubleshooting/ - トラブルシューティング

よくあるエラーとその解決方法

- `authentication_errors.md` - 認証関連のエラーと解決方法
- `FIX_BUNDLE_ID_ERROR.md` - Bundle IDエラーの解決方法
- `FIX_BLACK_SCREEN.md` - 画面が黒い問題の解決方法
- `FIX_MICROPHONE_PERMISSION.md` - マイク権限の問題の解決方法

### 05_development/ - 開発環境

Xcode、Apple Developer、開発ツールの設定、機能仕様

- `XCODE_SIGNING_SETUP.md` - Xcodeの署名設定
- `APPLE_DEVELOPER_PROGRAM_SETUP.md` - Apple Developer Programの設定
- `BACKEND_SERVER_SETUP.md` - バックエンドサーバーの設定
- `VOICE_CLONE_AND_TTS_SPECIFICATION.md` - 音声クローン・TTS機能の設計仕様書
- `RENDER_FREE_PLAN_LIMITATIONS.md` - Render.com無料プランの制限と音源分離処理

### 06_reference/ - 参考資料

技術的な参考資料、アーキテクチャ図など

- `refs/FISH_AUDIO_SDK_RESEARCH.md` - Fish Audio SDKの調査資料

---

## 🚀 クイックスタート

### 新規プロジェクトのセットアップ

1. `01_setup/project_setup.md` を参照
2. `02_api_key/api_key_guide.md` でAPIキーを設定
3. `03_authentication/firebase_authentication.md` で認証を設定

### エラーが発生した場合

1. `04_troubleshooting/authentication_errors.md` を確認
2. 該当するエラーの解決方法を参照

---

## 📝 ドキュメント更新履歴

- 2025年1月: ドキュメント構造を整理・階層化

---

## 🔗 外部リンク

- [Firebase Console](https://console.firebase.google.com/)
- [Google Cloud Console](https://console.cloud.google.com/)
- [Apple Developer](https://developer.apple.com/)

