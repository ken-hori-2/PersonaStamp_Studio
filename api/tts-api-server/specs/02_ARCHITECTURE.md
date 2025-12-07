# アーキテクチャ設計

## 🏗️ 全体アーキテクチャ

### システム構成

```
┌─────────────────────────────────────────────────────────┐
│                    iOSアプリ（クライアント）              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │
│  │ 認証画面     │  │ Voice Clone  │  │ TTS生成画面  │ │
│  │ (Firebase)   │  │ 画面         │  │              │ │
│  └──────────────┘  └──────────────┘  └──────────────┘ │
└───────────────────────┬─────────────────────────────────┘
                        │
                        │ HTTPS
                        │ Authorization: Bearer <Firebase ID Token>
                        ▼
┌─────────────────────────────────────────────────────────┐
│              FastAPI バックエンドサーバー                 │
│  ┌──────────────────────────────────────────────────┐   │
│  │          認証ミドルウェア                        │   │
│  │  - Firebase IDトークン検証                      │   │
│  │  - ユーザー情報取得                              │   │
│  └──────────────────────────────────────────────────┘   │
│  ┌──────────────────────────────────────────────────┐   │
│  │          利用制限チェック                        │   │
│  │  - 日次制限チェック                              │   │
│  │  - 月次コスト上限チェック                        │   │
│  └──────────────────────────────────────────────────┘   │
│  ┌──────────────────────────────────────────────────┐   │
│  │          APIエンドポイント                        │   │
│  │  - POST /api/v2/clone                            │   │
│  │  - POST /api/v2/tts/generate                      │   │
│  │  - GET  /api/v2/models                           │   │
│  │  - DELETE /api/v2/models/{model_id}              │   │
│  └──────────────────────────────────────────────────┘   │
│  ┌──────────────────────────────────────────────────┐   │
│  │          データベース層（SQLite）                  │   │
│  │  - users（ユーザー情報）                          │   │
│  │  - voice_models（声モデル）                       │   │
│  │  - usage_history（利用履歴）                      │   │
│  │  - monthly_costs（月次コスト）                     │   │
│  └──────────────────────────────────────────────────┘   │
└───────────────────────┬─────────────────────────────────┘
                        │
                        │ HTTPS
                        │ Authorization: Bearer <Fish Audio API Key>
                        ▼
┌─────────────────────────────────────────────────────────┐
│                  Fish Audio API                         │
│  ┌──────────────┐  ┌──────────────┐                    │
│  │ Voice Clone  │  │ TTS API      │                    │
│  │ API          │  │              │                    │
│  └──────────────┘  └──────────────┘                    │
└─────────────────────────────────────────────────────────┘
```

## 🔄 データフロー

### Voice Cloningフロー

```
1. iOSアプリ
   │
   ├─ 音声サンプルをbase64エンコード
   ├─ Firebase IDトークンを取得
   │
   ▼
2. POST /api/v2/clone
   │
   ├─ Firebase IDトークン検証
   ├─ 利用制限チェック（日次Clone制限）
   │
   ▼
3. Fish Audio API (Voice Clone)
   │
   ├─ 音声サンプルを送信
   ├─ モデルIDを受け取る
   │
   ▼
4. データベース
   │
   ├─ voice_modelsテーブルに保存
   ├─ usage_historyテーブルに記録
   │
   ▼
5. レスポンス
   │
   └─ モデルIDを返す
```

### TTS生成フロー

```
1. iOSアプリ
   │
   ├─ テキストを入力
   ├─ モデルIDを選択
   ├─ Firebase IDトークンを取得
   │
   ▼
2. POST /api/v2/tts/generate
   │
   ├─ Firebase IDトークン検証
   ├─ モデル所有権チェック
   ├─ 利用制限チェック（日次TTS制限）
   │
   ▼
3. Fish Audio API (TTS)
   │
   ├─ テキストとモデルIDを送信
   ├─ 音声ファイル（mp3）を受け取る
   │
   ▼
4. データベース
   │
   ├─ usage_historyテーブルに記録
   │
   ▼
5. レスポンス
   │
   └─ 音声ファイル（mp3）を返す
```

## 🧩 コンポーネント設計

### 認証コンポーネント

```python
# auth.py
class FirebaseAuth:
    def verify_token(token: str) -> dict:
        """Firebase IDトークンを検証してユーザー情報を返す"""
        pass
```

### 利用制限コンポーネント

```python
# rate_limiter.py
class RateLimiter:
    def check_daily_limit(user_id: str, usage_type: str) -> bool:
        """日次制限をチェック"""
        pass
    
    def check_monthly_cost(user_id: str) -> bool:
        """月次コスト上限をチェック"""
        pass
```

### Fish Audio APIクライアント

```python
# fish_audio_client.py
class FishAudioClient:
    def clone_voice(audio_bytes: bytes, reference_name: str) -> str:
        """Voice Cloningを実行してモデルIDを返す"""
        pass
    
    def generate_tts(text: str, model_id: str) -> bytes:
        """TTSを生成して音声ファイルを返す"""
        pass
```

### データベースコンポーネント

```python
# database.py
class Database:
    def save_voice_model(user_id: str, model_id: str, name: str):
        """声モデルを保存"""
        pass
    
    def get_voice_models(user_id: str) -> List[dict]:
        """ユーザーの声モデル一覧を取得"""
        pass
    
    def check_model_ownership(user_id: str, model_id: str) -> bool:
        """モデル所有権をチェック"""
        pass
```

## 🔐 セキュリティアーキテクチャ

### 認証フロー

```
1. iOSアプリ
   │
   ├─ Firebase Authenticationでログイン
   ├─ Firebase IDトークンを取得
   │
   ▼
2. APIリクエスト
   │
   ├─ Authorization: Bearer <Firebase ID Token>
   │
   ▼
3. バックエンド
   │
   ├─ Firebase Admin SDKでトークン検証
   ├─ ユーザーID（Firebase UID）を取得
   │
   ▼
4. 認証完了
```

### 認可フロー

```
1. リクエスト受信
   │
   ├─ ユーザーIDを取得（認証済み）
   │
   ▼
2. リソースアクセス
   │
   ├─ モデル所有権チェック
   │  └─ user_idとmodel_idの紐付けを確認
   │
   ├─ 利用制限チェック
   │  └─ 日次/月次制限を確認
   │
   ▼
3. アクセス許可/拒否
```

## 📊 データフロー図（詳細）

### Voice Cloning詳細フロー

```
iOS App                    Backend                    Fish Audio API
   │                          │                            │
   │ 1. 音声サンプル準備        │                            │
   │─────────────────────────>│                            │
   │                          │                            │
   │                          │ 2. トークン検証            │
   │                          │───────────────────────────>│
   │                          │                            │
   │                          │ 3. 利用制限チェック        │
   │                          │ (DB確認)                   │
   │                          │                            │
   │                          │ 4. Voice Clone API呼び出し │
   │                          │───────────────────────────>│
   │                          │                            │
   │                          │ 5. モデルID受信            │
   │                          │<───────────────────────────│
   │                          │                            │
   │                          │ 6. DBに保存                │
   │                          │ (voice_models, usage_history)│
   │                          │                            │
   │ 7. モデルID受信           │                            │
   │<─────────────────────────│                            │
```

### TTS生成詳細フロー

```
iOS App                    Backend                    Fish Audio API
   │                          │                            │
   │ 1. テキスト + モデルID    │                            │
   │─────────────────────────>│                            │
   │                          │                            │
   │                          │ 2. トークン検証            │
   │                          │───────────────────────────>│
   │                          │                            │
   │                          │ 3. モデル所有権チェック    │
   │                          │ (DB確認)                   │
   │                          │                            │
   │                          │ 4. 利用制限チェック        │
   │                          │ (DB確認)                   │
   │                          │                            │
   │                          │ 5. TTS API呼び出し         │
   │                          │───────────────────────────>│
   │                          │                            │
   │                          │ 6. 音声ファイル受信        │
   │                          │<───────────────────────────│
   │                          │                            │
   │                          │ 7. DBに記録                │
   │                          │ (usage_history)            │
   │                          │                            │
   │ 8. 音声ファイル受信       │                            │
   │<─────────────────────────│                            │
```

## 🗄️ データストレージ設計

### データ保存場所

1. **SQLiteデータベース**
   - ユーザー情報
   - 声モデル情報
   - 利用履歴
   - 月次コスト

2. **Fish Audio API**
   - 実際の声モデル（サーバー側には保存しない）

3. **一時ストレージ**
   - 音声ファイルは一時的にメモリに保持
   - レスポンス後は削除

## 🔄 エラーハンドリング

### エラー処理フロー

```
1. リクエスト受信
   │
   ├─ 認証エラー → 401 Unauthorized
   ├─ 認可エラー → 403 Forbidden
   ├─ 利用制限エラー → 429 Too Many Requests
   ├─ バリデーションエラー → 400 Bad Request
   ├─ サーバーエラー → 500 Internal Server Error
   │
   ▼
2. エラーレスポンス
   │
   └─ エラーメッセージを返す
```

## 📈 スケーラビリティ考慮

### 現在の設計（小規模）

- SQLite（単一サーバー）
- ファイルベースのデータベース
- シンプルな構成

### 将来の拡張（中規模以上）

- PostgreSQLへの移行
- 複数サーバー対応
- キャッシュ層の追加（Redis等）

---

## 🔗 関連ドキュメント

- [システム概要](./01_SYSTEM_OVERVIEW.md)
- [API仕様](./03_API_SPECIFICATION.md)
- [データベース設計](./04_DATABASE_DESIGN.md)

