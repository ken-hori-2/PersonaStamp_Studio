# APIキーの役割と違い

## 🔑 2種類のAPIキー

### 1. **ユーザーアクセストークン**（`sk_xxxxx`）

**役割**: このサーバー（TTS API Minimal）にアクセスするための認証トークン

- **生成場所**: このサーバー（`api_server.py`）
- **生成方法**: `secrets.token_urlsafe(32)`でランダム生成
- **形式**: `sk_xxxxx...`（例: `sk_o9Q1PAk6meSKiljVY...`）
- **保存場所**: SQLiteデータベース（`users`テーブル）
- **用途**: 
  - iOSアプリがこのサーバーにリクエストを送る際の認証
  - ユーザー識別と利用制限の管理

**特徴**:
- ✅ Fish Audio APIとは**無関係**
- ✅ このサーバー独自の認証システム
- ✅ ユーザーごとに異なるトークン
- ✅ データベースで管理

### 2. **Fish Audio APIキー**

**役割**: 実際のFish Audio APIを呼び出すためのキー

- **取得場所**: Fish Audioの公式サイト
- **保存場所**: 環境変数（`.env`ファイル）
- **形式**: Fish Audioが発行する形式
- **用途**: 
  - サーバーがFish Audio APIを呼び出す際に使用
  - 音声生成の実際の処理

**特徴**:
- ✅ サーバー側のみで使用
- ✅ iOSアプリからは**絶対に見えない**
- ✅ すべてのユーザーが同じキーを共有（サーバー経由）

## 📊 認証フローの詳細

```
┌─────────────┐
│  iOSアプリ  │
└──────┬──────┘
       │
       │ 1. ユーザー作成リクエスト
       │    POST /api/v2/users
       │    （認証不要）
       ▼
┌─────────────────────────┐
│  TTS API Minimal サーバー │
│                         │
│  2. ユーザーID生成       │
│     user_xxxxx          │
│                         │
│  3. アクセストークン生成 │
│     sk_xxxxx...         │
│     （このサーバー用）   │
│                         │
│  4. データベースに保存   │
└──────┬──────────────────┘
       │
       │ レスポンス: {user_id, api_key}
       ▼
┌─────────────┐
│  iOSアプリ  │
│             │
│  api_keyを  │
│  保存       │
└──────┬──────┘
       │
       │ 5. TTS生成リクエスト
       │    POST /api/v2/tts/generate
       │    Header: X-API-Key: sk_xxxxx
       │    （アクセストークンで認証）
       ▼
┌─────────────────────────┐
│  TTS API Minimal サーバー │
│                         │
│  6. アクセストークン検証 │
│     sk_xxxxx → user_id  │
│                         │
│  7. 利用制限チェック     │
│     （日次/月次制限）    │
│                         │
│  8. Fish Audio API呼び出し
│     （環境変数のキー使用）│
│     FISH_AUDIO_API_KEY  │
│                         │
│  9. 音声ファイルを返す   │
│  10. 利用履歴を記録      │
└─────────────────────────┘
```

## 🔍 コードでの確認

### アクセストークンの生成（`api_server.py`）

```python
# 174行目: アクセストークンを生成
api_key = f"sk_{secrets.token_urlsafe(32)}"
# これはこのサーバー用のトークン
```

### アクセストークンでの認証（`api_server.py`）

```python
# 204行目: アクセストークンで認証
async def generate_tts_audio(
    request: TTSRequest,
    user: dict = Depends(get_user_api_key)  # ← アクセストークン検証
):
```

### Fish Audio APIキーの使用（`api_server.py`）

```python
# 221行目: Fish Audio APIを呼び出す
audio_bytes = call_fish_audio_tts(...)

# call_fish_audio_tts関数内（約130行目）:
def call_fish_audio_tts(...):
    api_key = get_fish_api_key()  # ← 環境変数から取得
    # Fish Audio APIを呼び出し
```

## 🎯 重要なポイント

### ✅ アクセストークン（`sk_xxxxx`）

- **このサーバーへの認証用**
- Fish Audio APIとは無関係
- ユーザーごとに異なる
- データベースで管理

### ✅ Fish Audio APIキー

- **Fish Audio API呼び出し用**
- サーバー側のみで使用
- iOSアプリからは見えない
- 環境変数で管理

## 🔒 セキュリティの利点

この設計により：

1. **Fish Audio APIキーが保護される**
   - iOSアプリからは絶対に見えない
   - サーバー側のみで使用

2. **ユーザー管理が可能**
   - ユーザーごとに利用制限を設定
   - 利用履歴を個別に管理

3. **コスト管理が可能**
   - 月次コスト上限で保護
   - 不正利用を防止

## 📝 まとめ

- **`sk_xxxxx`**: このサーバーへのアクセストークン（認証トークン）
- **Fish Audio APIキー**: Fish Audio API呼び出すためのキー（サーバー側のみ）

**アクセストークン ≠ Fish Audio APIキー**

アクセストークンは、このサーバーが独自に発行する認証トークンです。

