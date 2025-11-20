# テストの実行方法とAPIキーの仕組み

## 📋 テストの実行方法

### 1. サーバーの起動

```bash
cd tts_api_minimal
source venv/bin/activate
python api_server.py
```

サーバーは `http://localhost:8000` で起動します。

### 2. テストスクリプトの実行

別のターミナルで：

```bash
cd tts_api_minimal
source venv/bin/activate
python test_mock_ios.py
```

## 🔄 テストの流れ（詳細）

### ステップ1: ユーザー作成テスト

**エンドポイント**: `POST /api/v2/users`

**リクエスト**:
```json
{
  "user_id": null,  // 自動生成
  "daily_tts_limit": 20,
  "daily_clone_limit": 2
}
```

**レスポンス**:
```json
{
  "user_id": "user_xxxxx",
  "api_key": "sk_xxxxx...",
  "message": "ユーザーが作成されました"
}
```

**何が起こるか**:
1. サーバーがランダムなユーザーIDを生成（例: `user_JFGdFbA8nUo`）
2. ランダムなAPIキーを生成（例: `sk_6fQGg9_P2kuO4kB4-wid89y5yQ_Zn0OIdzzxncYk3_4`）
3. SQLiteデータベースに保存
4. ユーザーIDとAPIキーを返す

### ステップ2: TTS生成テスト

**エンドポイント**: `POST /api/v2/tts/generate`

**リクエストヘッダー**:
```
X-API-Key: sk_xxxxx...  (ステップ1で取得したAPIキー)
Content-Type: application/json
```

**リクエストボディ**:
```json
{
  "text": "こんにちは。これはテスト音声です。",
  "format": "mp3",
  "speed": 1.0,
  "volume": 0
}
```

**何が起こるか**:
1. APIキーからユーザー情報を取得
2. 利用制限をチェック（日次制限、月次コスト上限）
3. Fish Audio APIを呼び出して音声生成
4. 利用履歴をデータベースに記録（コスト: 0.1円）
5. 音声ファイル（MP3）を返す

### ステップ3: 利用統計取得テスト

**エンドポイント**: `GET /api/v2/users/me/stats`

**リクエストヘッダー**:
```
X-API-Key: sk_xxxxx...
```

**レスポンス**:
```json
{
  "daily_usage": 1,
  "daily_tts": 1,
  "daily_clone": 0,
  "daily_cost": 0.1,
  "monthly_cost": 0.1,
  "daily_tts_limit": 20,
  "daily_clone_limit": 2,
  "monthly_cost_limit": 5000.0
}
```

**何が起こるか**:
1. APIキーからユーザー情報を取得
2. データベースから利用履歴を集計
3. 統計情報を返す

### ステップ4: 管理者統計取得テスト

**エンドポイント**: `GET /api/v2/admin/stats`

**認証**: 不要（本番環境では認証を追加すべき）

**レスポンス**:
```json
{
  "daily_usage": 1,
  "daily_tts": 1,
  "daily_clone": 0,
  "daily_cost": 0.1,
  "monthly_cost": 0.1,
  "daily_tts_limit": 0,
  "daily_clone_limit": 0,
  "monthly_cost_limit": 5000.0
}
```

**何が起こるか**:
1. 全ユーザーの利用履歴を集計
2. 全体統計を返す

## 🔑 APIキーの仕組み

### 2種類のAPIキー

#### 1. **ユーザーAPIキー**（ユーザーごとに作成）

- **形式**: `sk_xxxxx...`（32文字のランダム文字列）
- **用途**: iOSアプリから送信される認証キー
- **保存場所**: SQLiteデータベース（`users`テーブル）
- **生成方法**: `secrets.token_urlsafe(32)`でランダム生成

**特徴**:
- ✅ ユーザーごとに異なるキー
- ✅ ユーザーIDと紐付けられている
- ✅ 利用制限（日次/月次）が個別に管理される

#### 2. **Fish Audio APIキー**（サーバー側のみ）

- **形式**: Fish Audioから発行された実際のAPIキー
- **用途**: Fish Audio APIを呼び出すため
- **保存場所**: 環境変数（`.env`ファイル）
- **アクセス**: サーバー側のみ（iOSアプリからは見えない）

**特徴**:
- ✅ サーバー側で秘匿管理
- ✅ iOSアプリからは絶対に見えない
- ✅ すべてのユーザーが同じキーを共有（サーバー経由）

### 認証フロー

```
iOSアプリ
  │
  │ 1. ユーザー作成リクエスト
  │    POST /api/v2/users
  ▼
サーバー
  │
  │ 2. ユーザーID + APIキーを生成
  │    データベースに保存
  │
  │ 3. ユーザーID + APIキーを返す
  ▼
iOSアプリ
  │
  │ 4. APIキーを保存（ローカルストレージ）
  │
  │ 5. TTS生成リクエスト
  │    POST /api/v2/tts/generate
  │    Header: X-API-Key: sk_xxxxx
  ▼
サーバー
  │
  │ 6. APIキーからユーザー情報を取得
  │    利用制限をチェック
  │
  │ 7. Fish Audio APIを呼び出し
  │    （環境変数のFISH_AUDIO_API_KEYを使用）
  │
  │ 8. 音声ファイルを返す
  │    利用履歴を記録
  ▼
iOSアプリ
```

## 🔒 セキュリティについて

### ✅ 安全な点

1. **Fish Audio APIキーは秘匿されている**
   - 環境変数（`.env`）で管理
   - iOSアプリからは絶対に見えない
   - サーバー側のみで使用

2. **ユーザーAPIキーは認証に使用**
   - 各ユーザーが独自のキーを持つ
   - データベースで管理
   - キーが漏洩しても、そのユーザーのみ影響

3. **利用制限でコストを保護**
   - 日次制限（デフォルト: 20回/日）
   - 月次コスト上限（デフォルト: 5000円/月）

### ⚠️ 本番環境で改善すべき点

1. **HTTPSの使用**
   - 現在はHTTP（localhost）
   - 本番環境ではHTTPS必須

2. **APIキーの暗号化**
   - 現在は平文でデータベースに保存
   - 本番環境では暗号化を推奨

3. **レート制限**
   - 現在は利用制限のみ
   - IPアドレスベースのレート制限を追加推奨

4. **管理者エンドポイントの認証**
   - 現在は認証なし
   - 本番環境では認証必須

5. **APIキーの有効期限**
   - 現在は無期限
   - 本番環境では有効期限を設定推奨

### 🧪 テスト環境で作成したキーについて

**現在の状態**:
- テスト用のダミーFish Audio APIキー（`test_key_for_demo`）
- 実際のFish Audio APIは呼び出せない（402エラー）

**安全か？**:
- ✅ **テスト環境では安全**: localhostのみ、外部からアクセス不可
- ⚠️ **本番環境では改善必要**: 上記の改善点を実装

**推奨事項**:
1. テスト用のキーは本番環境では使用しない
2. 実際のFish Audio APIキーは環境変数で管理
3. データベースファイル（`tts_app.db`）は`.gitignore`に含まれている

## 📊 データベース構造

### usersテーブル
```
user_id (PRIMARY KEY)
api_key (UNIQUE)
daily_tts_limit
daily_clone_limit
is_active
created_at
```

### usage_historyテーブル
```
id (PRIMARY KEY)
user_id (FOREIGN KEY)
usage_type ('tts' or 'clone')
cost
created_at
```

### monthly_costsテーブル
```
id (PRIMARY KEY)
year
month
total_cost
updated_at
```

## 🎯 まとめ

- **ユーザーAPIキー**: ユーザーごとに作成、認証に使用
- **Fish Audio APIキー**: サーバー側のみ、環境変数で管理
- **テスト環境**: localhostのみ、安全
- **本番環境**: HTTPS、暗号化、認証などの改善が必要

