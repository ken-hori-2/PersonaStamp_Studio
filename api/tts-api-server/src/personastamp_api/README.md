# TTS + Voice Cloning API Server

仕様書に基づいた実装版のTTS + Voice Cloning APIサーバーです。

## 特徴

- ✅ Firebase Authentication対応
- ✅ Voice Cloning機能
- ✅ TTS機能（モデルID対応）
- ✅ モデル管理機能
- ✅ 利用制限機能（日次/月次制限、コスト上限）
- ✅ 無料で運用可能（SQLite使用）

## プロジェクト構造

```
src/personastamp_api/
├── __init__.py
├── api_server.py          # FastAPIアプリケーション
├── database.py            # データベースモジュール
├── auth.py                # Firebase認証モジュール
├── fish_audio_client.py   # Fish Audio APIクライアント
├── requirements.txt       # 依存関係
└── README.md             # このファイル
```

## セットアップ

### 1. 依存関係のインストール

```bash
cd src/personastamp_api
python3.11 -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate
pip install -r requirements.txt
```

### 2. 環境変数の設定

`.env`ファイルを作成し、以下の環境変数を設定：

```bash
# Fish Audio API
FISH_AUDIO_API_KEY=your_fish_audio_api_key_here

# Firebase Authentication
FIREBASE_PROJECT_ID=your-firebase-project-id
FIREBASE_PRIVATE_KEY_ID=your-private-key-id
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"
FIREBASE_CLIENT_EMAIL=your-client-email@your-project.iam.gserviceaccount.com
FIREBASE_CLIENT_ID=your-client-id

# その他
MONTHLY_COST_LIMIT=5000.0
PORT=8000
```

### 3. サーバーの起動

```bash
python main.py
```

サーバーは `http://localhost:8000` で起動します。

## APIエンドポイント

### Voice Cloning

```bash
POST /api/v2/clone
Authorization: Bearer <Firebase ID Token>
Content-Type: application/json

{
  "audio_base64": "base64エンコードされた音声データ",
  "reference_name": "my_voice"
}
```

### TTS生成

```bash
POST /api/v2/tts/generate
Authorization: Bearer <Firebase ID Token>
Content-Type: application/json

{
  "text": "こんにちは。これはテストです。",
  "model_id": "optional_model_id",
  "format": "mp3",
  "speed": 1.0,
  "volume": 0
}
```

### TTS履歴取得

```bash
GET /api/v2/tts/history
Authorization: Bearer <Firebase ID Token>
```

### TTS履歴ダウンロード

```bash
GET /api/v2/tts/history/{history_id}/download
Authorization: Bearer <Firebase ID Token>
```

### モデル一覧取得

```bash
GET /api/v2/models
Authorization: Bearer <Firebase ID Token>
```

### モデル削除

```bash
DELETE /api/v2/models/{model_id}
Authorization: Bearer <Firebase ID Token>
```

### 利用統計取得

```bash
GET /api/v2/users/me/stats
Authorization: Bearer <Firebase ID Token>
```

詳細は `../../specs/03_API_SPECIFICATION.md` を参照してください。

## データベース

SQLiteを使用しており、`tts_app.db` ファイルが自動的に作成されます。

### テーブル

- `users`: ユーザー情報（Firebase UIDを主キー）
- `voice_models`: 声モデル情報
- `usage_history`: 利用履歴
- `monthly_costs`: 月次コスト
- `tts_history`: 最新10件までのTTS生成履歴（音声ファイルのパスを保存）

詳細は `../../specs/04_DATABASE_DESIGN.md` を参照してください。

### 生成音声の保存場所

`src/personastamp_api/generated_audio/<Firebase UID>/` に最新10件分の音声ファイルを保存します。
API経由で古い履歴が自動削除されるため、ストレージを圧迫しません。

## 認証

Firebase Authenticationを使用します。

1. iOSアプリでFirebase Authenticationでログイン
2. Firebase IDトークンを取得
3. APIリクエスト時に `Authorization: Bearer <Firebase ID Token>` ヘッダーを送信

詳細は `../../specs/05_AUTHENTICATION.md` を参照してください。

## デプロイ

### Railway

1. GitHubリポジトリを接続
2. 環境変数を設定
3. Start Command: `cd src/personastamp_api && python main.py`

詳細は `../../specs/07_DEPLOYMENT_GUIDE.md` を参照してください。

## テスト

```bash
# ヘルスチェック
curl http://localhost:8000/health

# APIテスト（Firebase IDトークンが必要）
curl -X POST "http://localhost:8000/api/v2/tts/generate" \
  -H "Authorization: Bearer <Firebase ID Token>" \
  -H "Content-Type: application/json" \
  -d '{"text": "テスト"}'
```

詳細は `../../specs/08_TEST_SPECIFICATION.md` を参照してください。

## 仕様書

すべての仕様書は `../../specs/` フォルダにあります：

- [システム概要](../../specs/01_SYSTEM_OVERVIEW.md)
- [アーキテクチャ設計](../../specs/02_ARCHITECTURE.md)
- [API仕様](../../specs/03_API_SPECIFICATION.md)
- [データベース設計](../../specs/04_DATABASE_DESIGN.md)
- [認証方式](../../specs/05_AUTHENTICATION.md)
- [実装手順](../../specs/06_IMPLEMENTATION_GUIDE.md)
- [デプロイ手順](../../specs/07_DEPLOYMENT_GUIDE.md)
- [テスト仕様](../../specs/08_TEST_SPECIFICATION.md)

## ライセンス

このプロジェクトはMITライセンスの下で公開されています。

