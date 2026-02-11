# RendVu — Fish Audio SDK 音声クローン・TTS iOS アプリ

**RendVu** は、[Fish Audio SDK](https://fish.audio) を活用した**音声クローン（Voice Cloning）**と**テキスト読み上げ（TTS）**の iOS アプリです。  
[PersonaStamp Studio](https://github.com/your-org/PersonaStamp_Studio) リポジトリの Web 版（Streamlit / CLI）に対応する **iOS 版**として開発されています。

| 項目 | 内容 |
|------|------|
| プラットフォーム | iOS 15.0+ |
| UI | SwiftUI |
| 認証 | Firebase Authentication（Apple Sign In 対応） |
| バックエンド | PersonaStamp TTS API サーバー（ローカル／リモート） |

---

## 主な機能

| タブ | 機能 |
|------|------|
| **Voice Clone** | 音声サンプルから声を複製し、Fish Audio 経由で音声クローンモデルを作成 |
| **音声処理** | 音源分離（ボーカル抽出）、無音区間削除。処理済み音声を Voice Clone で再利用可能 |
| **TTS** | 作成したモデルでテキストを音声化。感情タグ・文字数制限・フォーマット選択対応 |
| **Models** | 作成済み音声クローンモデルの一覧・管理 |
| **Profile** | ログイン／ログアウト、アカウント情報 |

- 感情タグ: `(happy)`, `(sad)`, `(excited)` などで TTS の感情を制御
- TTS 文字数制限: クレジット抑制のため最大 30 文字（仕様: [VOICE_CLONE_AND_TTS_SPECIFICATION.md](docs/05_development/VOICE_CLONE_AND_TTS_SPECIFICATION.md)）
- 無料プラン制限: [RENDER_FREE_PLAN_LIMITATIONS.md](docs/05_development/RENDER_FREE_PLAN_LIMITATIONS.md) を参照

---

## ポートフォリオ用素材

`portfolio/` に、画面プレビュー画像を置いています。

| 素材 | ファイル |
|------|----------|
| 画面プレビュー | [IMG_3497.PNG](portfolio/IMG_3497.PNG) ～ [IMG_3501.PNG](portfolio/IMG_3501.PNG) |

### プレビュー画像

<img src="portfolio/IMG_3497.PNG" width="200" alt="RendVu 画面プレビュー 1"> <img src="portfolio/IMG_3498.PNG" width="200" alt="RendVu 画面プレビュー 2"> <img src="portfolio/IMG_3499.PNG" width="200" alt="RendVu 画面プレビュー 3">

<img src="portfolio/IMG_3500.PNG" width="200" alt="RendVu 画面プレビュー 4"> <img src="portfolio/IMG_3501.PNG" width="200" alt="RendVu 画面プレビュー 5">

---

## プロジェクト構成

```
RendVu/
├── RendVu/                 # アプリ本体（エントリポイント・リソース）
│   ├── RendVuApp.swift
│   ├── Info.plist
│   ├── Assets.xcassets/
│   └── GoogleService-Info.plist.example
├── Views/                  # SwiftUI 画面
│   ├── ContentView.swift, MainTabView.swift, SplashView.swift
│   ├── LoginView.swift, ProfileView.swift
│   ├── VoiceCloneView.swift, TTSView.swift, AudioProcessingView.swift
│   ├── ModelsView.swift, EmotionPickerView.swift
├── ViewModels/             # 画面用 ViewModel
│   ├── VoiceCloneViewModel.swift, TTSViewModel.swift
│   ├── AudioProcessingViewModel.swift, ModelsViewModel.swift
│   └── ProfileViewModel.swift
├── Services/               # API・認証
│   ├── APIClient.swift     # TTS API 通信
│   └── AuthManager.swift   # Firebase Auth
├── Models/                 # データモデル
│   ├── VoiceModel.swift, TTSHistoryItem.swift, EmotionTag.swift
├── docs/                   # ドキュメント（セットアップ・APIキー・認証・トラブルシュート等）
├── portfolio/              # 画面プレビュー画像（README・紹介用）
├── Podfile / Podfile.lock  # CocoaPods（FirebaseAuth, FirebaseCore）
└── RendVu.xcodeproj / RendVu.xcworkspace
```

---

## セットアップ

### 1. 前提条件

- Xcode 15 以上（推奨）
- CocoaPods (`pod --version`)
- Firebase プロジェクト（Apple Sign In 有効化）
- Fish Audio API キー（バックエンド側で利用）
- PersonaStamp TTS API サーバー（[BACKEND_SERVER_SETUP.md](docs/05_development/BACKEND_SERVER_SETUP.md) 参照）

### 2. インストール

```bash
cd api/tts-api-server/src/personastamp_api/ios_app/swift_src/retry_src/RendVu
pod install
```

### 3. Xcode で開く

```bash
open RendVu.xcworkspace
```

※ プロジェクトは **RendVu.xcworkspace** から開いてください（Pod 利用のため）。

### 4. 設定

- **GoogleService-Info.plist**: Firebase コンソールから取得し、`RendVu/` に配置（例: `GoogleService-Info.plist.example` を参考にリネーム・編集）
- **API ベース URL**: アプリ内で TTS API サーバーの URL を設定（`APIClient` 等）
- **署名**: [XCODE_SIGNING_SETUP.md](docs/05_development/XCODE_SIGNING_SETUP.md) を参照

詳細は [docs/README.md](docs/README.md) および各カテゴリ（01_setup, 02_api_key, 03_authentication, 04_troubleshooting, 05_development）を参照してください。

---

## ドキュメント

| カテゴリ | 内容 |
|----------|------|
| [01_setup](docs/01_setup/) | プロジェクト・Firebase 初期設定 |
| [02_api_key](docs/02_api_key/) | API キー管理・制限・セキュリティ |
| [03_authentication](docs/03_authentication/) | Firebase Authentication |
| [04_troubleshooting](docs/04_troubleshooting/) | 認証エラー・黒画面・Bundle ID・マイク権限など |
| [05_development](docs/05_development/) | 署名・Apple Developer・バックエンド・仕様・無料プラン制限 |
| [06_reference](docs/06_reference/) | Fish Audio SDK 調査・参考資料 |

---

## コミット履歴（RendVu 関連）

このディレクトリに関連する主なコミットは以下のとおりです。

| コミット | 概要 |
|----------|------|
| `03ac647` | docs: ドキュメント構造の整理とセキュリティ対策 |
| `17079b8` | feat: 感情タグ・文字起こし・フォーマット選択・UI 改善 |
| `e9ec431` | feat: 字幕テキストを1行で最小スケール表示 |
| `9818646` | feat: Netflix 風アニメーションとダークテーマのスプラッシュ |
| `01f065e` | feat: スプラッシュのモダン化と順次テキスト表示 |
| `b2615a3` | chore: アプリ表示名を Re:ndVu に変更、不要な AppDelegate 削除 |
| `fbfcde0` | feat: RendVu アプリ追加（スプラッシュ・認証修正） |

---

## 親リポジトリとの関係

- **PersonaStamp Studio**: Fish Audio SDK を用いた音声クローン・TTS の Web UI / CLI / API を提供
- **RendVu**: その **iOS 版クライアント**。TTS API サーバー（`api/tts-api-server`）に接続して音声クローン・TTS を利用します。
- **AXiV**: 同じリポジトリ内の別アプリ（しゃべるスタンプ）。RendVu とは別の Xcode プロジェクトです。

---

## ライセンス

親リポジトリ [PersonaStamp Studio](https://github.com/your-org/PersonaStamp_Studio) のライセンスに従います。
