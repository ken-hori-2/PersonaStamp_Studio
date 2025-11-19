# TTS API Minimal

refs.mdを参考に実装した、最小構成のTTSアプリです。

## 特徴

- ✅ 多ユーザー対応（ユーザーごとのAPIキー管理）
- ✅ 利用制限機能（日次/月次制限、コスト上限）
- ✅ 無料で運用可能（SQLite使用）
- ✅ 最小限の実装（依存関係を最小化）

## セットアップ

### 1. 依存関係のインストール

```bash
cd tts_api_minimal
python3 -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate
pip install -r requirements.txt
```

### 2. 環境変数の設定

`.env.example`をコピーして`.env`を作成し、Fish Audio APIキーを設定：

```bash
cp .env.example .env
# .envファイルを編集してFISH_AUDIO_API_KEYを設定
```

### 3. サーバーの起動

```bash
python api_server.py
```

サーバーは `http://localhost:8000` で起動します。

## APIエンドポイント

### ユーザー作成

```bash
POST /api/v2/users
Content-Type: application/json

{
  "user_id": "optional_user_id",  // 省略可（自動生成）
  "daily_tts_limit": 20,          // デフォルト: 20
  "daily_clone_limit": 2           // デフォルト: 2
}
```

レスポンス:
```json
{
  "user_id": "user_xxxxx",
  "api_key": "sk_xxxxx",
  "message": "ユーザーが作成されました"
}
```

### TTS生成

```bash
POST /api/v2/tts/generate
X-API-Key: sk_xxxxx
Content-Type: application/json

{
  "text": "こんにちは。これはテストです。",
  "model_id": "optional_model_id",
  "format": "mp3",
  "speed": 1.0,
  "volume": 0
}
```

レスポンス: 音声ファイル（audio/mp3）

### 利用統計取得

```bash
GET /api/v2/users/me/stats
X-API-Key: sk_xxxxx
```

レスポンス:
```json
{
  "daily_usage": 5,
  "daily_tts": 5,
  "daily_clone": 0,
  "daily_cost": 0.5,
  "monthly_cost": 15.2,
  "daily_tts_limit": 20,
  "daily_clone_limit": 2,
  "monthly_cost_limit": 5000.0
}
```

### 管理者統計取得

```bash
GET /api/v2/admin/stats
```

## テスト

テストスクリプトを実行：

```bash
python test_mock_ios.py
```

## データベース

SQLiteを使用しており、`tts_app.db` ファイルが自動的に作成されます。

### デフォルト設定

- 日次TTS制限: 20回/日
- 日次Voice Clone制限: 2回/日
- 月次コスト上限: 5000円（環境変数で変更可能）
- TTS 1回あたりのコスト: 0.1円（仮設定）

## アーキテクチャ

```
iOSアプリ（モック）
   │
   ▼
TTS API Minimal (FastAPI)
   │
   ├── ユーザー認証（X-API-Key）
   ├── 利用制限チェック
   ├── コスト管理
   │
   ▼
Fish Audio API
   │
   ▼
音声ファイル（mp3/wav）
```

## セキュリティ

- Fish Audio APIキーは環境変数で管理（サーバー側のみ）
- ユーザーAPIキーは `X-API-Key` ヘッダーで送信
- 本番環境では、管理者エンドポイントに認証を追加することを推奨

## トラブルシューティング

### Fish Audio APIキーが設定されていない

`.env`ファイルに`FISH_AUDIO_API_KEY`を設定してください。

### ポートが既に使用されている

環境変数`PORT`で別のポートを指定：

```bash
PORT=8001 python api_server.py
```

