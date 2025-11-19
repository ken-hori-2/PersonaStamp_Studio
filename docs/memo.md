その通りです。生成しているAPIキー（`sk_xxxxx`）は、このサーバーへのアクセストークン（認証トークン）です。Fish AudioのAPIキーではありません。


[2 tools called]


その理解で正しいです。整理して説明します。


[2 tools called]


## 理解の確認

**生成しているAPIキー（`sk_xxxxx`）は、このサーバーへのアクセストークン（認証トークン）です。**

### 2種類のキーの違い

#### 1. **アクセストークン**（`sk_xxxxx`）
- 役割: このサーバー（TTS API Minimal）への認証
- 生成: このサーバーが生成（`secrets.token_urlsafe(32)`）
- 保存: SQLiteデータベース
- 用途: iOSアプリがこのサーバーにリクエストする際の認証
- Fish Audio APIとは無関係

#### 2. **Fish Audio APIキー**
- 役割: Fish Audio APIを呼び出すためのキー
- 取得: Fish Audioの公式サイト
- 保存: 環境変数（`.env`ファイル）
- 用途: サーバーがFish Audio APIを呼び出す際に使用
- iOSアプリからは見えない

### 認証フロー

```
iOSアプリ
  ↓
  POST /api/v2/users
  （アクセストークン生成リクエスト）
  ↓
サーバー
  ↓
  アクセストークン生成: sk_xxxxx
  （このサーバー用の認証トークン）
  ↓
iOSアプリ
  ↓
  POST /api/v2/tts/generate
  Header: X-API-Key: sk_xxxxx
  （アクセストークンで認証）
  ↓
サーバー
  ↓
  アクセストークン検証
  ↓
  Fish Audio API呼び出し
  （環境変数のFISH_AUDIO_API_KEYを使用）
  ↓
  音声ファイルを返す
```

### コードでの確認

```python
# アクセストークンの生成（174行目）
api_key = f"sk_{secrets.token_urlsafe(32)}"
# ↑ これはこのサーバー用のトークン

# Fish Audio APIキーの使用（103行目）
api_key = get_fish_api_key()  # 環境変数から取得
# ↑ これはFish Audio API用のキー
```

## まとめ

- `sk_xxxxx` = このサーバーへのアクセストークン（認証トークン）
- Fish Audio APIキー = Fish Audio API呼び出し用（サーバー側のみ）

アクセストークンは、このサーバーが独自に発行する認証トークンです。Fish Audio APIキーとは別物です。

詳細は `API_KEY_EXPLANATION.md` に記載しています。