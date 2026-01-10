# PersonaStamp TTS + Voice Cloning API Server

iOSアプリ「PersonaStamp Studio」のバックエンドAPIサーバーです。Firebase Authenticationを使用した認証機能、Voice Cloning機能、Text-to-Speech (TTS)機能を提供します。

## 🎯 主な機能

- ✅ **Firebase Authentication** - セキュアなユーザー認証
- ✅ **Voice Cloning** - 音声サンプルから声モデルを生成
- ✅ **Text-to-Speech (TTS)** - テキストを音声に変換（カスタム声モデル対応）
- ✅ **モデル管理** - ユーザーごとの声モデル管理
- ✅ **利用制限機能** - 日次/月次制限、コスト上限管理
- ✅ **管理ダッシュボード** - 管理者向けAPIとダッシュボード
- ✅ **無料で運用可能** - SQLite使用、小規模運用に最適

## 📁 プロジェクト構造

```
tts-api-server/
├── src/
│   └── personastamp_api/          # メインのAPIサーバーコード
│       ├── main.py                # エントリーポイント（Render/本番用）
│       ├── requirements.txt       # Python依存関係
│       ├── core/                  # コアモジュール
│       │   ├── api_server.py      # FastAPIアプリケーション
│       │   ├── auth.py            # Firebase認証モジュール
│       │   ├── database.py        # データベースモジュール
│       │   └── fish_audio_client.py # Fish Audio APIクライアント
│       ├── admin/                 # 管理機能
│       │   └── admin_dashboard.py # 管理ダッシュボード
│       ├── utils/                 # ユーティリティ
│       ├── docs/                  # 実装関連ドキュメント
│       ├── storage/               # 生成音声ファイルの保存先
│       └── ios_app/               # iOSアプリ関連コード（参考用）
├── specs/                         # 仕様書
│   ├── 01_SYSTEM_OVERVIEW.md
│   ├── 02_ARCHITECTURE.md
│   ├── 03_API_SPECIFICATION.md
│   └── ...
├── docs/                          # 追加ドキュメント
│   ├── README.md
│   ├── SECURITY.md
│   └── ...
└── tts_api_server/                # レガシーコード（参考用）
```

## 🚀 クイックスタート

### 1. 依存関係のインストール

```bash
cd src/personastamp_api
python3.11 -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate
pip install -r requirements.txt
```

### 2. 環境変数の設定

`.env`ファイルを`src/personastamp_api/`ディレクトリに作成し、以下の環境変数を設定：

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

詳細は [Firebase設定ガイド](src/personastamp_api/docs/FIREBASE_SETUP.md) を参照してください。

### 3. サーバーの起動

```bash
cd src/personastamp_api
python main.py
```

サーバーは `http://localhost:8000` で起動します。

## 📚 APIエンドポイント

### Voice Cloning

```bash
POST /api/v2/clone
Authorization: Bearer <Firebase ID Token>
Content-Type: application/json

{
  "audio_base64": "base64エンコードされた音声データ",
  "reference_name": "my_voice",
  "transcription": "音声の文字起こし（推奨）"
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

### モデル一覧取得

```bash
GET /api/v2/models
Authorization: Bearer <Firebase ID Token>
```

### TTS履歴取得

```bash
GET /api/v2/tts/history
Authorization: Bearer <Firebase ID Token>
```

### 利用統計取得

```bash
GET /api/v2/users/me/stats
Authorization: Bearer <Firebase ID Token>
```

詳細なAPI仕様は [specs/03_API_SPECIFICATION.md](specs/03_API_SPECIFICATION.md) を参照してください。

## 🔐 認証

Firebase Authenticationを使用します。

1. iOSアプリでFirebase Authenticationでログイン
2. Firebase IDトークンを取得
3. APIリクエスト時に `Authorization: Bearer <Firebase ID Token>` ヘッダーを送信

詳細は [specs/05_AUTHENTICATION.md](specs/05_AUTHENTICATION.md) を参照してください。

## 💾 データベース

SQLiteを使用しており、`src/personastamp_api/storage/tts_app.db` ファイルが自動的に作成されます。

### 主なテーブル

- `users`: ユーザー情報（Firebase UIDを主キー）
- `voice_models`: 声モデル情報
- `usage_history`: 利用履歴
- `monthly_costs`: 月次コスト
- `tts_history`: TTS生成履歴（最新10件）

詳細は [specs/04_DATABASE_DESIGN.md](specs/04_DATABASE_DESIGN.md) を参照してください。

## 🎛️ 管理機能

管理者向けのAPIとダッシュボードが利用可能です。

詳細は [src/personastamp_api/docs/ADMIN_DASHBOARD_README.md](src/personastamp_api/docs/ADMIN_DASHBOARD_README.md) を参照してください。

## 🚢 デプロイ

### Render

1. GitHubリポジトリを接続
2. 環境変数を設定
3. Start Command: `cd src/personastamp_api && python main.py`

詳細は [src/personastamp_api/docs/RENDER_DEPLOYMENT.md](src/personastamp_api/docs/RENDER_DEPLOYMENT.md) を参照してください。

### Railway / AWS

詳細は [specs/07_DEPLOYMENT_GUIDE.md](specs/07_DEPLOYMENT_GUIDE.md) を参照してください。

## 🧪 テスト

```bash
# ヘルスチェック
curl http://localhost:8000/health

# APIテスト（Firebase IDトークンが必要）
curl -X POST "http://localhost:8000/api/v2/tts/generate" \
  -H "Authorization: Bearer <Firebase ID Token>" \
  -H "Content-Type: application/json" \
  -d '{"text": "テスト"}'
```

詳細は [specs/08_TEST_SPECIFICATION.md](specs/08_TEST_SPECIFICATION.md) を参照してください。

## 📖 ドキュメント

### 仕様書

すべての仕様書は `specs/` フォルダにあります：

- [システム概要](specs/01_SYSTEM_OVERVIEW.md)
- [アーキテクチャ設計](specs/02_ARCHITECTURE.md)
- [API仕様](specs/03_API_SPECIFICATION.md)
- [データベース設計](specs/04_DATABASE_DESIGN.md)
- [認証方式](specs/05_AUTHENTICATION.md)
- [実装手順](specs/06_IMPLEMENTATION_GUIDE.md)
- [デプロイ手順](specs/07_DEPLOYMENT_GUIDE.md)
- [テスト仕様](specs/08_TEST_SPECIFICATION.md)

### 追加ドキュメント

- [セキュリティガイド](docs/SECURITY.md)
- [Firebase設定ガイド](src/personastamp_api/docs/FIREBASE_SETUP.md)
- [iOS統合ガイド](src/personastamp_api/docs/IOS_INTEGRATION_GUIDE.md)
- [管理ダッシュボード](src/personastamp_api/docs/ADMIN_DASHBOARD_README.md)

## 🛠️ 技術スタック

- **フレームワーク**: FastAPI (Python 3.11+)
- **データベース**: SQLite
- **認証**: Firebase Authentication
- **音声API**: Fish Audio API
- **ホスティング**: Render（推奨）、Railway、AWS Lightsail

## 📝 ライセンス

このプロジェクトはMITライセンスの下で公開されています。
