# データベース設計

## 🗄️ データベース概要

- **DBMS**: SQLite 3
- **ファイル名**: `tts_app.db`
- **場所**: `tts_api_server/tts_app.db`

## 📊 テーブル一覧

1. `users` - ユーザー情報
2. `voice_models` - 声モデル情報
3. `usage_history` - 利用履歴
4. `monthly_costs` - 月次コスト

---

## 📋 テーブル設計

### 1. users テーブル

ユーザー情報を保存します。Firebase AuthenticationのUIDを主キーとして使用します。

#### スキーマ

```sql
CREATE TABLE IF NOT EXISTS users (
    user_id TEXT PRIMARY KEY,              -- Firebase UID
    email TEXT,                            -- メールアドレス（オプション）
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    daily_tts_limit INTEGER DEFAULT 20,   -- 日次TTS制限
    daily_clone_limit INTEGER DEFAULT 2,   -- 日次Voice Cloning制限
    is_active BOOLEAN DEFAULT 1            -- アクティブフラグ
);
```

#### カラム説明

| カラム名 | 型 | 説明 |
|---------|-----|------|
| `user_id` | TEXT | Firebase UID（主キー） |
| `email` | TEXT | メールアドレス（オプション） |
| `created_at` | TIMESTAMP | 作成日時 |
| `daily_tts_limit` | INTEGER | 日次TTS制限（デフォルト: 20） |
| `daily_clone_limit` | INTEGER | 日次Voice Cloning制限（デフォルト: 2） |
| `is_active` | BOOLEAN | アクティブフラグ（デフォルト: 1） |

#### インデックス

```sql
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
```

---

### 2. voice_models テーブル

ユーザーが作成した声モデルの情報を保存します。

#### スキーマ

```sql
CREATE TABLE IF NOT EXISTS voice_models (
    model_id TEXT PRIMARY KEY,             -- Fish Audio APIが返すモデルID
    user_id TEXT NOT NULL,                 -- ユーザーID（Firebase UID）
    reference_name TEXT NOT NULL,          -- ユーザーがつけた名前
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    metadata TEXT,                         -- JSON形式のメタデータ（オプション）
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
);
```

#### カラム説明

| カラム名 | 型 | 説明 |
|---------|-----|------|
| `model_id` | TEXT | Fish Audio APIが返すモデルID（主キー） |
| `user_id` | TEXT | ユーザーID（Firebase UID） |
| `reference_name` | TEXT | ユーザーがつけた声モデルの名前 |
| `created_at` | TIMESTAMP | 作成日時 |
| `metadata` | TEXT | JSON形式のメタデータ（オプション） |

#### インデックス

```sql
CREATE INDEX IF NOT EXISTS idx_voice_models_user 
ON voice_models(user_id);

CREATE INDEX IF NOT EXISTS idx_voice_models_user_created 
ON voice_models(user_id, created_at);
```

---

### 3. usage_history テーブル

ユーザーの利用履歴を記録します。

#### スキーマ

```sql
CREATE TABLE IF NOT EXISTS usage_history (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id TEXT NOT NULL,                 -- ユーザーID（Firebase UID）
    usage_type TEXT NOT NULL,              -- 'tts' または 'clone'
    cost REAL DEFAULT 0.0,                 -- コスト（円）
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
);
```

#### カラム説明

| カラム名 | 型 | 説明 |
|---------|-----|------|
| `id` | INTEGER | 主キー（自動増分） |
| `user_id` | TEXT | ユーザーID（Firebase UID） |
| `usage_type` | TEXT | 利用タイプ（'tts' または 'clone'） |
| `cost` | REAL | コスト（円、デフォルト: 0.0） |
| `created_at` | TIMESTAMP | 作成日時 |

#### インデックス

```sql
CREATE INDEX IF NOT EXISTS idx_usage_user_date 
ON usage_history(user_id, DATE(created_at));

CREATE INDEX IF NOT EXISTS idx_usage_type_date 
ON usage_history(usage_type, DATE(created_at));
```

---

### 4. monthly_costs テーブル

月次コストを集計して保存します。

#### スキーマ

```sql
CREATE TABLE IF NOT EXISTS monthly_costs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    year INTEGER NOT NULL,                 -- 年
    month INTEGER NOT NULL,                -- 月（1-12）
    total_cost REAL DEFAULT 0.0,          -- 月次総コスト（円）
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(year, month)
);
```

#### カラム説明

| カラム名 | 型 | 説明 |
|---------|-----|------|
| `id` | INTEGER | 主キー（自動増分） |
| `year` | INTEGER | 年 |
| `month` | INTEGER | 月（1-12） |
| `total_cost` | REAL | 月次総コスト（円） |
| `updated_at` | TIMESTAMP | 更新日時 |

#### インデックス

```sql
CREATE INDEX IF NOT EXISTS idx_monthly_costs_year_month 
ON monthly_costs(year, month);
```

---

## 🔗 テーブル間の関係

```
users (1) ──< (N) voice_models
users (1) ──< (N) usage_history
```

- 1人のユーザーは複数の声モデルを持つことができる
- 1人のユーザーは複数の利用履歴を持つことができる

---

## 📝 データ操作例

### ユーザー作成

```sql
INSERT INTO users (user_id, email, daily_tts_limit, daily_clone_limit)
VALUES ('firebase_uid_123', 'user@example.com', 20, 2);
```

### 声モデル保存

```sql
INSERT INTO voice_models (model_id, user_id, reference_name)
VALUES ('abc123def456', 'firebase_uid_123', 'my_voice');
```

### 利用履歴記録

```sql
INSERT INTO usage_history (user_id, usage_type, cost)
VALUES ('firebase_uid_123', 'tts', 0.1);
```

### 月次コスト更新

```sql
INSERT INTO monthly_costs (year, month, total_cost)
VALUES (2024, 1, 0.1)
ON CONFLICT(year, month) DO UPDATE SET
    total_cost = total_cost + 0.1,
    updated_at = CURRENT_TIMESTAMP;
```

---

## 🔍 よく使うクエリ

### ユーザーの声モデル一覧取得

```sql
SELECT model_id, reference_name, created_at
FROM voice_models
WHERE user_id = ?
ORDER BY created_at DESC;
```

### 今日の利用回数取得

```sql
SELECT 
    COUNT(*) as total_usage,
    SUM(CASE WHEN usage_type = 'tts' THEN 1 ELSE 0 END) as tts_count,
    SUM(CASE WHEN usage_type = 'clone' THEN 1 ELSE 0 END) as clone_count,
    SUM(cost) as total_cost
FROM usage_history
WHERE user_id = ? AND DATE(created_at) = DATE('now');
```

### 今月のコスト取得

```sql
SELECT total_cost
FROM monthly_costs
WHERE year = ? AND month = ?;
```

### モデル所有権チェック

```sql
SELECT COUNT(*) as count
FROM voice_models
WHERE user_id = ? AND model_id = ?;
```

---

## 🔄 マイグレーション

### 初期化

データベースは初回起動時に自動的に初期化されます。

```python
# database.py
def init_database():
    """データベースを初期化（テーブル作成）"""
    conn = get_db_connection()
    cursor = conn.cursor()
    
    # テーブル作成
    # ...
    
    conn.commit()
    conn.close()
```

### スキーマ変更

将来的にスキーマを変更する場合は、マイグレーションスクリプトを作成してください。

```python
# migrations/add_column_example.py
def migrate():
    conn = get_db_connection()
    cursor = conn.cursor()
    
    try:
        cursor.execute("ALTER TABLE users ADD COLUMN new_column TEXT")
        conn.commit()
    except sqlite3.OperationalError:
        # カラムが既に存在する場合
        pass
    finally:
        conn.close()
```

---

## 📊 データ量見積もり

### 小規模運用（~50ユーザー）

| テーブル | 想定レコード数 | データサイズ |
|---------|--------------|------------|
| users | 50 | ~5KB |
| voice_models | 100 | ~10KB |
| usage_history | 10,000 | ~500KB |
| monthly_costs | 12 | ~1KB |
| **合計** | - | **~516KB** |

### 中規模運用（~500ユーザー）

| テーブル | 想定レコード数 | データサイズ |
|---------|--------------|------------|
| users | 500 | ~50KB |
| voice_models | 1,000 | ~100KB |
| usage_history | 100,000 | ~5MB |
| monthly_costs | 12 | ~1KB |
| **合計** | - | **~5.15MB** |

---

## 🔒 セキュリティ考慮事項

### データ保護

- SQLiteファイルのパーミッションを適切に設定
- バックアップを定期的に取得
- 機密情報（APIキー等）は保存しない

### パフォーマンス

- インデックスを適切に設定
- 古い利用履歴は定期的にアーカイブ
- クエリの最適化

---

## 🔗 関連ドキュメント

- [システム概要](./01_SYSTEM_OVERVIEW.md)
- [アーキテクチャ設計](./02_ARCHITECTURE.md)
- [API仕様](./03_API_SPECIFICATION.md)

