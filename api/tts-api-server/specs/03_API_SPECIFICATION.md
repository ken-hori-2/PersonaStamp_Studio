# API仕様

## 📋 エンドポイント一覧

| メソッド | エンドポイント | 説明 | 認証 |
|---------|--------------|------|------|
| POST | `/api/v2/clone` | Voice Cloningを実行 | 必須 |
| POST | `/api/v2/tts/generate` | TTS音声を生成 | 必須 |
| POST | `/api/v2/audio/process` | 音声処理（音源分離、無音区間削除） | 必須 |
| GET | `/api/v2/models` | 声モデル一覧を取得 | 必須 |
| DELETE | `/api/v2/models/{model_id}` | 声モデルを削除 | 必須 |
| GET | `/api/v2/users/me/stats` | 利用統計を取得 | 必須 |
| GET | `/health` | ヘルスチェック | 不要 |

---

## 🔐 認証

すべてのAPIエンドポイント（`/health`を除く）は、Firebase IDトークンによる認証が必要です。

### リクエストヘッダー

```
Authorization: Bearer <Firebase ID Token>
Content-Type: application/json
```

### 認証エラー

```json
{
  "detail": "Authorizationヘッダーが必要です"
}
```

ステータスコード: `401 Unauthorized`

---

## 📝 エンドポイント詳細

### 1. POST /api/v2/clone

Voice Cloningを実行し、声モデルを作成します。

#### リクエスト

**ヘッダー**:
```
Authorization: Bearer <Firebase ID Token>
Content-Type: application/json
```

**ボディ**:
```json
{
  "audio_base64": "base64エンコードされた音声データ",
  "reference_name": "my_voice"
}
```

**パラメータ**:
- `audio_base64` (string, required): base64エンコードされた音声データ（WAV/MP3形式）
- `reference_name` (string, required): ユーザーがつける声モデルの名前

#### レスポンス

**成功時 (200 OK)**:
```json
{
  "model_id": "abc123def456",
  "reference_name": "my_voice",
  "message": "Voice Cloningが完了しました"
}
```

**エラー時**:

- **401 Unauthorized**: 認証エラー
```json
{
  "detail": "無効なトークンです"
}
```

- **429 Too Many Requests**: 利用制限エラー
```json
{
  "detail": "日次利用制限に達しました（2回/日）"
}
```

- **500 Internal Server Error**: サーバーエラー
```json
{
  "detail": "Fish Audio API呼び出しエラー: ..."
}
```

---

### 2. POST /api/v2/tts/generate

指定した声モデルを使用してTTS音声を生成します。

#### リクエスト

**ヘッダー**:
```
Authorization: Bearer <Firebase ID Token>
Content-Type: application/json
```

**ボディ**:
```json
{
  "text": "こんにちは。これはテストです。",
  "model_id": "abc123def456",
  "format": "mp3",
  "speed": 1.0,
  "volume": 0
}
```

**パラメータ**:
- `text` (string, required): 音声合成するテキスト
- `model_id` (string, optional): 使用する声モデルID（指定しない場合はデフォルト音声）
- `format` (string, optional): 音声フォーマット（`mp3` または `wav`、デフォルト: `mp3`）
- `speed` (float, optional): 話す速度（0.5-2.0、デフォルト: 1.0）
- `volume` (int, optional): 音量（-20-20、デフォルト: 0）

#### レスポンス

**成功時 (200 OK)**:
- Content-Type: `audio/mp3` または `audio/wav`
- ボディ: 音声ファイルのバイナリデータ

**エラー時**:

- **400 Bad Request**: バリデーションエラー
```json
{
  "detail": "textパラメータが必要です"
}
```

- **403 Forbidden**: モデル所有権エラー
```json
{
  "detail": "このモデルへのアクセス権限がありません"
}
```

- **429 Too Many Requests**: 利用制限エラー
```json
{
  "detail": "日次利用制限に達しました（20回/日）"
}
```

- **500 Internal Server Error**: サーバーエラー
```json
{
  "detail": "Fish Audio API呼び出しエラー: ..."
}
```

---

### 3. POST /api/v2/audio/process

音声ファイルを処理します。音源分離（ボーカル抽出）と無音区間削除を組み合わせて実行できます。

iOSアプリ側でファイルを読み込んでbase64エンコードして送信します。

#### リクエスト

**ヘッダー**:
```
Authorization: Bearer <Firebase ID Token>
Content-Type: application/json
```

**ボディ**:
```json
{
  "audio_base64": "base64エンコードされた音声データ",
  "separate_vocals": true,
  "remove_silence": true,
  "separation_model": "htdemucs",
  "silence_thresh": -40.0,
  "min_silence_len": 500,
  "keep_silence": 200
}
```

**パラメータ**:
- `audio_base64` (string, required): base64エンコードされた音声データ（WAV, MP3, M4A, FLAC, OGG形式）
- `separate_vocals` (boolean, optional): 音源分離を有効にする（デフォルト: false）
- `remove_silence` (boolean, optional): 無音区間削除を有効にする（デフォルト: false）
- `separation_model` (string, optional): 分離モデル（デフォルト: "spleeter:2stems"）
  - `spleeter:2stems`: ボーカルと伴奏の2-stem分離（軽量・推奨・Render無料プラン対応・デフォルト）
  - `spleeter:4stems`: ボーカル、ドラム、ベース、その他の4-stem分離
  - `spleeter:5stems`: ボーカル、ドラム、ベース、ピアノ、その他の5-stem分離
  - 注意: Demucsモデル（`htdemucs`など）はRender無料プランでは重すぎるため使用不可（コメントアウト済み）
- `silence_thresh` (float, optional): 無音とみなす音量閾値（dB、デフォルト: -40.0）
- `min_silence_len` (int, optional): 無音とみなす最小長さ（ミリ秒、デフォルト: 500）
- `keep_silence` (int, optional): 無音区間の前後に残す長さ（ミリ秒、デフォルト: 200）

#### レスポンス

**成功時 (200 OK)**:
```json
{
  "output_audio_base64": "処理後の音声データ（base64）",
  "vocals_audio_base64": "ボーカル音声データ（base64、音源分離した場合のみ）",
  "message": "音声処理が完了しました（音源分離済み）（無音区間削除済み）"
}
```

**パラメータ説明**:
- `output_audio_base64`: 処理後の音声データ（base64エンコード）
- `vocals_audio_base64`: ボーカル音声データ（base64エンコード、`separate_vocals`が`true`の場合のみ）
- `message`: 処理結果のメッセージ

**エラー時**:

- **400 Bad Request**: バリデーションエラー
```json
{
  "detail": "音声データのデコードに失敗しました"
}
```

- **401 Unauthorized**: 認証エラー
```json
{
  "detail": "無効なトークンです"
}
```

- **500 Internal Server Error**: サーバーエラー
```json
{
  "detail": "音源分離に失敗しました"
}
```

**使用例**:
- 音楽ファイルからボーカルを抽出: `separate_vocals: true, remove_silence: false`
- 録音音声から無音区間を削除: `separate_vocals: false, remove_silence: true`
- 両方を実行: `separate_vocals: true, remove_silence: true`

---

### 4. GET /api/v2/models

ユーザーが所有する声モデルの一覧を取得します。

#### リクエスト

**ヘッダー**:
```
Authorization: Bearer <Firebase ID Token>
```

#### レスポンス

**成功時 (200 OK)**:
```json
[
  {
    "model_id": "abc123def456",
    "reference_name": "my_voice",
    "created_at": "2024-01-15T10:30:00Z"
  },
  {
    "model_id": "xyz789ghi012",
    "reference_name": "work_voice",
    "created_at": "2024-01-14T15:20:00Z"
  }
]
```

**エラー時**:

- **401 Unauthorized**: 認証エラー
```json
{
  "detail": "無効なトークンです"
}
```

---

### 5. DELETE /api/v2/models/{model_id}

指定した声モデルを削除します。

#### リクエスト

**ヘッダー**:
```
Authorization: Bearer <Firebase ID Token>
```

**パスパラメータ**:
- `model_id` (string, required): 削除する声モデルID

#### レスポンス

**成功時 (200 OK)**:
```json
{
  "success": true,
  "message": "モデルが削除されました"
}
```

**エラー時**:

- **403 Forbidden**: モデル所有権エラー
```json
{
  "detail": "このモデルへのアクセス権限がありません"
}
```

- **404 Not Found**: モデルが見つからない
```json
{
  "detail": "モデルが見つかりません"
}
```

---

### 6. GET /api/v2/users/me/stats

ユーザーの利用統計を取得します。

#### リクエスト

**ヘッダー**:
```
Authorization: Bearer <Firebase ID Token>
```

#### レスポンス

**成功時 (200 OK)**:
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

**パラメータ説明**:
- `daily_usage`: 今日の総利用回数
- `daily_tts`: 今日のTTS利用回数
- `daily_clone`: 今日のVoice Cloning利用回数
- `daily_cost`: 今日のコスト（円）
- `monthly_cost`: 今月のコスト（円）
- `daily_tts_limit`: 日次TTS制限
- `daily_clone_limit`: 日次Voice Cloning制限
- `monthly_cost_limit`: 月次コスト上限

---

### 7. GET /health

サーバーのヘルスチェックを行います。

#### リクエスト

認証不要

#### レスポンス

**成功時 (200 OK)**:
```json
{
  "status": "ok"
}
```

---

## 🔄 エラーハンドリング

### エラーレスポンス形式

すべてのエラーレスポンスは以下の形式です：

```json
{
  "detail": "エラーメッセージ"
}
```

### ステータスコード

| ステータスコード | 説明 | 例 |
|---------------|------|-----|
| 200 | 成功 | リクエストが正常に処理された |
| 400 | バリデーションエラー | 必須パラメータが不足している |
| 401 | 認証エラー | トークンが無効または期限切れ |
| 403 | 認可エラー | モデルへのアクセス権限がない |
| 404 | リソースが見つからない | モデルIDが存在しない |
| 429 | 利用制限エラー | 日次/月次制限に達した |
| 500 | サーバーエラー | 内部エラーが発生した |

---

## 📊 レート制限

### 日次制限

- **TTS**: 20回/日（デフォルト）
- **Voice Cloning**: 2回/日（デフォルト）

### 月次コスト上限

- **デフォルト**: 5,000円/月

### レート制限エラー

レート制限に達した場合、`429 Too Many Requests`が返されます：

```json
{
  "detail": "日次利用制限に達しました（20回/日）"
}
```

---

## 🔒 セキュリティ

### CORS設定

本番環境では、適切なオリジンを指定してください：

```python
app.add_middleware(
    CORSMiddleware,
    allow_origins=["https://your-ios-app.com"],  # 本番環境では適切に制限
    allow_credentials=True,
    allow_methods=["GET", "POST", "DELETE"],
    allow_headers=["Authorization", "Content-Type"],
)
```

### 入力検証

すべての入力パラメータは検証されます：

- 必須パラメータのチェック
- データ型の検証
- 文字列長の制限
- 不正な文字の検証

---

## 📝 使用例

### cURL例

#### Voice Cloning

```bash
curl -X POST "https://your-api.com/api/v2/clone" \
  -H "Authorization: Bearer <Firebase ID Token>" \
  -H "Content-Type: application/json" \
  -d '{
    "audio_base64": "base64_encoded_audio_data",
    "reference_name": "my_voice"
  }'
```

#### TTS生成

```bash
curl -X POST "https://your-api.com/api/v2/tts/generate" \
  -H "Authorization: Bearer <Firebase ID Token>" \
  -H "Content-Type: application/json" \
  -d '{
    "text": "こんにちは",
    "model_id": "abc123def456",
    "format": "mp3"
  }' \
  --output audio.mp3
```

#### モデル一覧取得

```bash
curl -X GET "https://your-api.com/api/v2/models" \
  -H "Authorization: Bearer <Firebase ID Token>"
```

#### 音声処理（無音区間削除のみ）

```bash
curl -X POST "https://your-api.com/api/v2/audio/process" \
  -H "Authorization: Bearer <Firebase ID Token>" \
  -H "Content-Type: application/json" \
  -d '{
    "audio_base64": "base64_encoded_audio_data",
    "separate_vocals": false,
    "remove_silence": true
  }'
```

**注意**: 
- 音源分離機能（`separate_vocals: true`）は現在利用できませんが、コードはコメントアウトで残されています
- **Spleeter**: 依存関係の競合により現在は使用不可（将来的に使用可能）
- **Demucs**: Render無料プランでは重すぎるため現在は使用不可（将来的に使用可能）
- 詳細は `docs/AUDIO_PROCESSING_API.md` を参照してください

---

## 🔗 関連ドキュメント

- [システム概要](./01_SYSTEM_OVERVIEW.md)
- [アーキテクチャ設計](./02_ARCHITECTURE.md)
- [データベース設計](./04_DATABASE_DESIGN.md)
- [音声処理API詳細](../src/personastamp_api/docs/AUDIO_PROCESSING_API.md)

