# TTS API Server の実装

## 📋 概要

思い出動画像 → 音声付きスタンプアプリ向けのTTS（Text-to-Speech）APIサーバーを実装しました。Fish Audio APIを統合し、多ユーザー対応と利用制限機能を備えた最小構成のバックエンドAPIです。

## ✨ 主な機能

### 1. 多ユーザー対応
- ユーザーごとのAPIキー管理（`sk_xxxxx`形式）
- ユーザー作成エンドポイント（`POST /api/v2/users`）
- ユーザーごとの利用制限設定

### 2. 利用制限機能
- **日次制限**: TTS生成回数の日次上限（デフォルト: 20回/日）
- **月次コスト制限**: 月間コスト上限（デフォルト: 5000円/月）
- リアルタイムでの利用統計取得（`GET /api/v2/users/me/stats`）

### 3. TTS生成機能
- Fish Audio API統合
- テキストから音声ファイル（MP3/WAV）を生成
- カスタマイズ可能なパラメータ（速度、音量、フォーマット）

### 4. コスト管理
- 利用履歴の記録
- 日次/月次コストの追跡
- コスト上限に達した場合の自動停止

## 🏗️ 技術スタック

- **フレームワーク**: FastAPI
- **データベース**: SQLite（無料で運用可能）
- **外部API**: Fish Audio API
- **依存関係**: 最小限（FastAPI, Uvicorn, Requests, Pydantic, python-dotenv）

## 📁 プロジェクト構造

```
tts-api-server/
├── tts_api_server/          # APIサーバーコード
│   ├── api_server.py        # FastAPIアプリケーション
│   ├── database.py          # SQLiteデータベース管理
│   ├── test_mock_ios.py     # iOSアプリ向けテスト
│   └── requirements.txt     # 依存関係
└── docs/                    # 詳細ドキュメント
    ├── README.md            # 概要とセットアップ
    ├── API_KEY_EXPLANATION.md
    ├── AUTHENTICATION_OPTIONS.md
    ├── SECURITY.md          # セキュリティガイド
    └── TEST_EXPLANATION.md
```

## 🔐 セキュリティ

- **Fish Audio APIキー**: サーバー側のみで管理（環境変数）
- **ユーザーAPIキー**: ユーザーごとに異なるトークンを生成
- **利用制限**: 日次/月次制限で悪用を防止
- 詳細は `docs/SECURITY.md` を参照

## 🚀 セットアップ

### 1. 依存関係のインストール

```bash
cd tts_api_server
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

### 2. 環境変数の設定

`.env`ファイルを作成し、Fish Audio APIキーを設定：

```bash
echo "FISH_AUDIO_API_KEY=your_api_key_here" > .env
```

### 3. サーバーの起動

```bash
python api_server.py
```

サーバーは `http://localhost:8000` で起動します。

## 📡 APIエンドポイント

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

## 📚 ドキュメント

詳細なドキュメントは `docs/` フォルダを参照してください：

- [README.md](docs/README.md) - 概要とセットアップ
- [API_KEY_EXPLANATION.md](docs/API_KEY_EXPLANATION.md) - APIキーの説明
- [AUTHENTICATION_OPTIONS.md](docs/AUTHENTICATION_OPTIONS.md) - 認証オプション
- [SECURITY.md](docs/SECURITY.md) - セキュリティガイド
- [TEST_EXPLANATION.md](docs/TEST_EXPLANATION.md) - テストの説明

## 🎯 設計思想

- **最小限の実装**: 依存関係を最小化し、シンプルな構成
- **無料で運用可能**: SQLiteを使用し、追加のインフラ不要
- **スケーラブル**: 小規模（~50ユーザー）向けに最適化
- **セキュア**: Fish Audio APIキーを保護し、利用制限で悪用を防止

## 🔄 今後の改善予定

- [ ] アクセストークンの有効期限機能
- [ ] IPアドレスベースのレート制限
- [ ] Voice Clone機能の実装
- [ ] 管理者用ダッシュボード

## 📝 参考資料

- `refs.md` - アーキテクチャ設計の参考資料
- Fish Audio API ドキュメント

