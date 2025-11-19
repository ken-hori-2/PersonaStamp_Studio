# TTS API Server

他ユーザー向けのTTS（Text-to-Speech）APIサーバーです。

## プロジェクト構造

```
tts-api-server/
├── tts_api_server/    # APIサーバーコード
│   ├── api_server.py
│   ├── database.py
│   ├── test_mock_ios.py
│   └── requirements.txt
└── docs/              # ドキュメント
    ├── README.md
    ├── API_KEY_EXPLANATION.md
    ├── AUTHENTICATION_OPTIONS.md
    ├── SECURITY.md
    ├── TEST_EXPLANATION.md
    └── memo.md
```

## 特徴

- ✅ 多ユーザー対応（ユーザーごとのAPIキー管理）
- ✅ 利用制限機能（日次/月次制限、コスト上限）
- ✅ 無料で運用可能（SQLite使用）
- ✅ 最小限の実装（依存関係を最小化）

## クイックスタート

### 1. 依存関係のインストール

```bash
cd tts_api_server
python3 -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate
pip install -r requirements.txt
```

### 2. 環境変数の設定

`.env`ファイルを作成し、Fish Audio APIキーを設定：

```bash
cd tts_api_server
echo "FISH_AUDIO_API_KEY=your_api_key_here" > .env
```

### 3. サーバーの起動

```bash
cd tts_api_server
python api_server.py
```

サーバーは `http://localhost:8000` で起動します。

## 詳細ドキュメント

詳細なドキュメントは `docs/` フォルダを参照してください：

- [README.md](docs/README.md) - 概要とセットアップ
- [API_KEY_EXPLANATION.md](docs/API_KEY_EXPLANATION.md) - APIキーの説明
- [AUTHENTICATION_OPTIONS.md](docs/AUTHENTICATION_OPTIONS.md) - 認証オプション
- [SECURITY.md](docs/SECURITY.md) - セキュリティガイド
- [TEST_EXPLANATION.md](docs/TEST_EXPLANATION.md) - テストの説明

## APIエンドポイント

### ユーザー作成

```bash
POST /api/v2/users
Content-Type: application/json

{
  "user_id": "optional_user_id",
  "daily_tts_limit": 20,
  "daily_clone_limit": 2
}
```

### TTS生成

```bash
POST /api/v2/tts/generate
X-API-Key: sk_xxxxx
Content-Type: application/json

{
  "text": "こんにちは。これはテストです。",
  "format": "mp3",
  "speed": 1.0,
  "volume": 0
}
```

### 利用統計取得

```bash
GET /api/v2/users/me/stats
X-API-Key: sk_xxxxx
```

詳細は `docs/README.md` を参照してください。

## ライセンス

このプロジェクトはMITライセンスの下で公開されています。

