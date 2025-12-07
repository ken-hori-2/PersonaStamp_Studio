# システム概要

## 🎯 プロジェクトの目的

iOSアプリ「PersonaStamp Studio」のバックエンドAPIサーバーです。ユーザーが自分の声をクローン（Voice Cloning）し、その声でテキストを音声合成（TTS）できる機能を提供します。

## 📋 要件

### 機能要件

1. **Voice Cloning**
   - ユーザーが音声サンプルをアップロード
   - Fish Audio APIを使用して声をクローン
   - クローンした声モデルのIDを保存

2. **Text-to-Speech (TTS)**
   - ユーザーがテキストを入力
   - クローンした声モデルを使用して音声合成
   - 音声ファイル（mp3/wav）を返す

3. **モデル管理**
   - ユーザーが所有する声モデルの一覧取得
   - 声モデルの削除

4. **認証・認可**
   - Firebase Authenticationを使用
   - ユーザーごとの利用制限
   - モデル所有権の検証

5. **利用制限**
   - 日次制限（TTS: 20回/日、Clone: 2回/日）
   - 月次コスト上限（5,000円/月）

### 非機能要件

1. **パフォーマンス**
   - TTS生成: 3秒以内
   - Voice Cloning: 30秒以内

2. **セキュリティ**
   - Fish Audio APIキーをサーバー側で秘匿
   - Firebase IDトークンによる認証
   - HTTPS必須

3. **可用性**
   - 99%以上の稼働率
   - エラーハンドリング

4. **コスト**
   - 小規模運用（~50ユーザー）で無料または低コスト

## 🛠️ 技術スタック

### バックエンド

- **フレームワーク**: FastAPI (Python 3.11+)
- **データベース**: SQLite（小規模運用）
- **認証**: Firebase Authentication
- **ホスティング**: Railway（推奨）またはAWS Lightsail

### 外部サービス

- **音声API**: Fish Audio API
  - Voice Cloning API
  - Text-to-Speech API

### iOSアプリ（クライアント）

- **言語**: Swift
- **認証**: Firebase Authentication SDK
- **UI**: SwiftUI（想定）

## 📊 システム構成図

```
┌─────────────────┐
│   iOSアプリ      │
│  (Swift/SwiftUI) │
└────────┬────────┘
         │
         │ HTTPS
         │ Firebase ID Token
         ▼
┌─────────────────┐
│  FastAPI Server │
│  (Railway/Lightsail) │
│                 │
│  ├─ Firebase    │
│  │  Auth検証    │
│  ├─ 利用制限    │
│  │  チェック    │
│  ├─ Voice Clone │
│  │  エンドポイント│
│  ├─ TTS         │
│  │  エンドポイント│
│  └─ モデル管理  │
└────────┬────────┘
         │
         │ HTTPS
         │ Bearer Token
         ▼
┌─────────────────┐
│  Fish Audio API │
│                 │
│  ├─ Voice Clone │
│  └─ TTS         │
└─────────────────┘
```

## 🎯 ユーザーストーリー

### ストーリー1: Voice Cloning

1. ユーザーがiOSアプリを開く
2. Firebase Authenticationでログイン（Apple Sign In）
3. 音声サンプルを録音またはアップロード
4. 「Voice Clone」ボタンをタップ
5. サーバーがFish Audio APIを呼び出してクローン
6. モデルIDが返される
7. アプリにモデルIDが保存される

### ストーリー2: TTS生成

1. ユーザーがテキストを入力
2. 使用する声モデルを選択
3. 「音声生成」ボタンをタップ
4. サーバーがモデル所有権を検証
5. Fish Audio APIを呼び出してTTS生成
6. 音声ファイル（mp3）が返される
7. アプリで音声を再生

## 📈 想定ユーザー数

- **初期**: ~50ユーザー
- **成長後**: 100-500ユーザー

## 💰 コスト見積もり

### 小規模運用（~50ユーザー）

| 項目 | コスト |
|------|--------|
| ホスティング（Railway） | $0（無料クレジット内） |
| データベース（SQLite） | $0 |
| Firebase Authentication | $0（無料枠内） |
| Fish Audio API | 従量課金 |
| **合計** | **$0 + Fish Audio API使用量** |

### 中規模運用（~500ユーザー）

| 項目 | コスト |
|------|--------|
| ホスティング（Railway） | $5-10/月 |
| データベース（SQLite） | $0 |
| Firebase Authentication | $0（無料枠内） |
| Fish Audio API | 従量課金 |
| **合計** | **$5-10/月 + Fish Audio API使用量** |

## 🔒 セキュリティ要件

1. **APIキー管理**
   - Fish Audio APIキーはサーバー側のみで管理
   - 環境変数で保存
   - Gitにコミットしない

2. **認証**
   - Firebase IDトークンによる認証
   - トークンの有効期限チェック
   - トークンの改ざん検知

3. **認可**
   - モデル所有権の検証
   - 利用制限のチェック

4. **通信**
   - HTTPS必須
   - CORS設定

## 📝 用語集

- **Voice Cloning**: 音声サンプルから声をクローンする技術
- **TTS**: Text-to-Speech（テキストを音声に変換）
- **モデルID**: Fish Audio APIが返す声モデルの識別子
- **Firebase UID**: Firebase Authenticationが発行するユーザーID
- **MAU**: Monthly Active Users（月間アクティブユーザー数）

---

## 🔗 関連ドキュメント

- [アーキテクチャ設計](./02_ARCHITECTURE.md)
- [API仕様](./03_API_SPECIFICATION.md)
- [データベース設計](./04_DATABASE_DESIGN.md)

