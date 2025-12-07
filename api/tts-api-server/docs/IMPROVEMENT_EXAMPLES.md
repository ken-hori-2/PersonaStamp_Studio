# セキュリティ改善の実装例

このドキュメントでは、`NOTION_COMPARISON.md`で提案した改善点の具体的な実装例を提供します。

## 📋 目次

1. [IPアドレスベースのレート制限](#1-ipアドレスベースのレート制限)
2. [異常アクセス検知](#2-異常アクセス検知)
3. [APIキーの暗号化保存](#3-apiキーの暗号化保存)
4. [トークンの有効期限](#4-トークンの有効期限)
5. [アクセスログ](#5-アクセスログ)

---

## 1. IPアドレスベースのレート制限

### 実装方法

`api_server.py`に以下のコードを追加：

```python
# api_server.py の先頭に追加
from fastapi import Request
from fastapi.responses import JSONResponse
from collections import defaultdict
import time

# IPアドレスごとのリクエストカウント
ip_request_counts = defaultdict(list)

# 環境変数から設定を取得（デフォルト値あり）
RATE_LIMIT_REQUESTS = int(os.environ.get("RATE_LIMIT_REQUESTS", "100"))  # 1分あたりの最大リクエスト数
RATE_LIMIT_WINDOW = int(os.environ.get("RATE_LIMIT_WINDOW", "60"))  # 秒

@app.middleware("http")
async def rate_limit_middleware(request: Request, call_next):
    """IPアドレスベースのレート制限ミドルウェア"""
    # ヘルスチェックエンドポイントは除外
    if request.url.path in ["/health", "/"]:
        return await call_next(request)
    
    client_ip = request.client.host if request.client else "unknown"
    
    # 1分以内のリクエストをカウント
    now = time.time()
    ip_request_counts[client_ip] = [
        timestamp for timestamp in ip_request_counts[client_ip]
        if now - timestamp < RATE_LIMIT_WINDOW
    ]
    
    # レート制限チェック
    if len(ip_request_counts[client_ip]) >= RATE_LIMIT_REQUESTS:
        return JSONResponse(
            status_code=429,
            content={
                "detail": f"レート制限に達しました。{RATE_LIMIT_WINDOW}秒以内に{RATE_LIMIT_REQUESTS}回以上のリクエストは許可されません。",
                "retry_after": RATE_LIMIT_WINDOW
            }
        )
    
    # リクエストを記録
    ip_request_counts[client_ip].append(now)
    
    response = await call_next(request)
    return response
```

### 使用方法

`.env`ファイルで設定をカスタマイズ：

```bash
# 1分あたりの最大リクエスト数（デフォルト: 100）
RATE_LIMIT_REQUESTS=100

# レート制限の時間窓（秒）（デフォルト: 60）
RATE_LIMIT_WINDOW=60
```

### 注意点

- メモリベースの実装のため、サーバー再起動でリセットされます
- 本番環境では、Redisなどの外部ストレージを使用することを推奨
- 複数サーバーで運用する場合は、共有ストレージが必要

---

## 2. 異常アクセス検知

### データベーススキーマの拡張

`database.py`に以下を追加：

```python
# database.py に追加

def init_database():
    """データベースを初期化（テーブル作成）"""
    conn = get_db_connection()
    cursor = conn.cursor()
    
    # ... 既存のテーブル作成コード ...
    
    # 失敗試行テーブル
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS failed_attempts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            ip_address TEXT NOT NULL,
            user_id TEXT,
            endpoint TEXT,
            attempted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    """)
    
    # インデックスの作成
    cursor.execute("""
        CREATE INDEX IF NOT EXISTS idx_failed_attempts_ip_time 
        ON failed_attempts(ip_address, attempted_at)
    """)
    
    conn.commit()
    conn.close()


def record_failed_attempt(ip_address: str, user_id: str = None, endpoint: str = None):
    """失敗した認証試行を記録"""
    conn = get_db_connection()
    cursor = conn.cursor()
    
    cursor.execute("""
        INSERT INTO failed_attempts (ip_address, user_id, endpoint)
        VALUES (?, ?, ?)
    """, (ip_address, user_id, endpoint))
    
    conn.commit()
    conn.close()


def check_suspicious_activity(ip_address: str, user_id: str = None) -> tuple[bool, str]:
    """
    不審なアクティビティをチェック
    
    Returns:
        (is_suspicious, reason)
    """
    conn = get_db_connection()
    cursor = conn.cursor()
    
    # 過去1時間の失敗試行をカウント
    cursor.execute("""
        SELECT COUNT(*) as count
        FROM failed_attempts
        WHERE ip_address = ? 
        AND attempted_at > datetime('now', '-1 hour')
    """, (ip_address,))
    
    result = cursor.fetchone()
    failed_count = result["count"] if result else 0
    
    # 10回以上失敗したら不審と判断
    if failed_count >= 10:
        conn.close()
        return True, f"過去1時間に{failed_count}回の失敗試行が検出されました"
    
    # 過去24時間の失敗試行をカウント
    cursor.execute("""
        SELECT COUNT(*) as count
        FROM failed_attempts
        WHERE ip_address = ? 
        AND attempted_at > datetime('now', '-24 hours')
    """, (ip_address,))
    
    result = cursor.fetchone()
    daily_failed_count = result["count"] if result else 0
    
    # 50回以上失敗したら不審と判断
    if daily_failed_count >= 50:
        conn.close()
        return True, f"過去24時間に{daily_failed_count}回の失敗試行が検出されました"
    
    conn.close()
    return False, ""


def clear_old_failed_attempts(days: int = 7):
    """古い失敗試行記録を削除"""
    conn = get_db_connection()
    cursor = conn.cursor()
    
    cursor.execute("""
        DELETE FROM failed_attempts
        WHERE attempted_at < datetime('now', '-{} days')
    """.format(days))
    
    conn.commit()
    conn.close()
```

### APIサーバーでの使用

`api_server.py`の`get_user_api_key`関数を修正：

```python
# api_server.py に追加
from database import record_failed_attempt, check_suspicious_activity

def get_user_api_key(x_api_key: str = Header(None, alias="X-API-Key"), 
                     request: Request = None) -> dict:
    """ユーザーAPIキーからユーザー情報を取得"""
    if not x_api_key:
        # 失敗試行を記録
        if request:
            client_ip = request.client.host if request.client else "unknown"
            record_failed_attempt(client_ip, endpoint=request.url.path)
        raise HTTPException(status_code=401, detail="X-API-Keyヘッダーが必要です")
    
    # IPアドレスを取得
    client_ip = request.client.host if request and request.client else "unknown"
    
    # 不審なアクティビティをチェック
    is_suspicious, reason = check_suspicious_activity(client_ip)
    if is_suspicious:
        record_failed_attempt(client_ip, endpoint=request.url.path if request else None)
        raise HTTPException(
            status_code=403,
            detail=f"アクセスがブロックされました: {reason}"
        )
    
    user = get_user_by_api_key(x_api_key)
    if not user:
        # 失敗試行を記録
        record_failed_attempt(client_ip, endpoint=request.url.path if request else None)
        raise HTTPException(status_code=401, detail="無効なAPIキーです")
    
    return user
```

### 定期クリーンアップ

`api_server.py`に定期タスクを追加：

```python
# api_server.py に追加
from apscheduler.schedulers.background import BackgroundScheduler
from database import clear_old_failed_attempts

# スケジューラーを初期化
scheduler = BackgroundScheduler()

@scheduler.scheduled_job('cron', hour=2, minute=0)  # 毎日午前2時
def cleanup_old_records():
    """古い失敗試行記録を削除"""
    clear_old_failed_attempts(days=7)
    print("古い失敗試行記録を削除しました")

# サーバー起動時にスケジューラーを開始
@app.on_event("startup")
async def startup_event():
    scheduler.start()

@app.on_event("shutdown")
async def shutdown_event():
    scheduler.shutdown()
```

### requirements.txtに追加

```txt
apscheduler==3.10.4
```

---

## 3. APIキーの暗号化保存

### 暗号化モジュールの作成

`database.py`に以下を追加：

```python
# database.py に追加
from cryptography.fernet import Fernet
import base64

def get_encryption_key() -> bytes:
    """暗号化キーを取得（環境変数から）"""
    key = os.environ.get("ENCRYPTION_KEY")
    if not key:
        # 開発環境用の警告
        print("⚠️ 警告: ENCRYPTION_KEYが設定されていません。APIキーは平文で保存されます。")
        return None
    
    # 32バイトのキーが必要（Fernetはbase64エンコードされた32バイトキーを使用）
    if len(key) < 32:
        # キーが短い場合はパディング
        key = key.ljust(32, '0')
    
    # base64エンコードされたキーに変換
    try:
        return base64.urlsafe_b64encode(key.encode()[:32])
    except:
        # 既にbase64エンコードされている場合
        return key.encode() if isinstance(key, str) else key

def encrypt_api_key(api_key: str) -> str:
    """APIキーを暗号化"""
    key = get_encryption_key()
    if not key:
        return api_key  # 暗号化キーが設定されていない場合は平文で返す
    
    try:
        f = Fernet(key)
        return f.encrypt(api_key.encode()).decode()
    except Exception as e:
        print(f"⚠️ 暗号化エラー: {e}")
        return api_key  # エラー時は平文で返す

def decrypt_api_key(encrypted_key: str) -> str:
    """APIキーを復号化"""
    key = get_encryption_key()
    if not key:
        return encrypted_key  # 暗号化キーが設定されていない場合はそのまま返す
    
    try:
        f = Fernet(key)
        return f.decrypt(encrypted_key.encode()).decode()
    except Exception as e:
        print(f"⚠️ 復号化エラー: {e}")
        return encrypted_key  # エラー時はそのまま返す
```

### データベーススキーマの変更

`database.py`の`create_user`関数を修正：

```python
def create_user(user_id: str, api_key: str, 
                daily_tts_limit: int = DEFAULT_DAILY_TTS_LIMIT,
                daily_clone_limit: int = DEFAULT_DAILY_CLONE_LIMIT) -> bool:
    """新しいユーザーを作成"""
    conn = get_db_connection()
    cursor = conn.cursor()
    
    # APIキーを暗号化
    encrypted_api_key = encrypt_api_key(api_key)
    
    try:
        cursor.execute("""
            INSERT INTO users (user_id, api_key, daily_tts_limit, daily_clone_limit)
            VALUES (?, ?, ?, ?)
        """, (user_id, encrypted_api_key, daily_tts_limit, daily_clone_limit))
        conn.commit()
        return True
    except sqlite3.IntegrityError:
        return False
    finally:
        conn.close()
```

### データベースからの取得時に復号化

`database.py`の`get_user_by_api_key`関数を修正：

```python
def get_user_by_api_key(api_key: str) -> Optional[Dict]:
    """APIキーからユーザー情報を取得"""
    conn = get_db_connection()
    cursor = conn.cursor()
    
    # データベース内のすべてのAPIキーを復号化して比較
    cursor.execute("""
        SELECT user_id, api_key, daily_tts_limit, daily_clone_limit, is_active
        FROM users
        WHERE is_active = 1
    """)
    
    rows = cursor.fetchall()
    conn.close()
    
    for row in rows:
        # 暗号化されたAPIキーを復号化
        decrypted_key = decrypt_api_key(row["api_key"])
        
        # 比較（タイミング攻撃対策のため、secrets.compare_digestを使用）
        if secrets.compare_digest(decrypted_key, api_key):
            return {
                "user_id": row["user_id"],
                "api_key": row["api_key"],  # 暗号化されたキーを返す（表示用）
                "daily_tts_limit": row["daily_tts_limit"],
                "daily_clone_limit": row["daily_clone_limit"],
                "is_active": bool(row["is_active"])
            }
    
    return None
```

### 環境変数の設定

`.env`ファイルに追加：

```bash
# 暗号化キー（32文字以上推奨、またはFernet.generate_key()で生成）
ENCRYPTION_KEY=your_32_character_encryption_key_here
```

### 暗号化キーの生成

```python
# 一時的なスクリプト: generate_key.py
from cryptography.fernet import Fernet

key = Fernet.generate_key()
print(f"ENCRYPTION_KEY={key.decode()}")
```

### requirements.txtに追加

```txt
cryptography>=41.0.0
```

---

## 4. トークンの有効期限

### データベーススキーマの拡張

`database.py`の`init_database`関数を修正：

```python
def init_database():
    """データベースを初期化（テーブル作成）"""
    conn = get_db_connection()
    cursor = conn.cursor()
    
    # ユーザーテーブル
    cursor.execute(f"""
        CREATE TABLE IF NOT EXISTS users (
            user_id TEXT PRIMARY KEY,
            api_key TEXT UNIQUE NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            api_key_expires_at TIMESTAMP,
            refresh_token TEXT,
            refresh_token_expires_at TIMESTAMP,
            daily_tts_limit INTEGER DEFAULT {DEFAULT_DAILY_TTS_LIMIT},
            daily_clone_limit INTEGER DEFAULT {DEFAULT_DAILY_CLONE_LIMIT},
            is_active BOOLEAN DEFAULT 1
        )
    """)
    
    # 既存のテーブルにカラムを追加（マイグレーション）
    try:
        cursor.execute("ALTER TABLE users ADD COLUMN api_key_expires_at TIMESTAMP")
    except sqlite3.OperationalError:
        pass  # カラムが既に存在する場合
    
    try:
        cursor.execute("ALTER TABLE users ADD COLUMN refresh_token TEXT")
    except sqlite3.OperationalError:
        pass
    
    try:
        cursor.execute("ALTER TABLE users ADD COLUMN refresh_token_expires_at TIMESTAMP")
    except sqlite3.OperationalError:
        pass
    
    conn.commit()
    conn.close()
```

### APIキー作成時の有効期限設定

`api_server.py`の`create_user_endpoint`関数を修正：

```python
from datetime import datetime, timedelta

@app.post("/api/v2/users", response_model=UserCreateResponse)
async def create_user_endpoint(request: UserCreateRequest):
    """新しいユーザーを作成"""
    try:
        # ユーザーIDが指定されていない場合は自動生成
        if not request.user_id:
            user_id = f"user_{secrets.token_urlsafe(8)}"
        else:
            user_id = request.user_id
        
        # APIキーを生成
        api_key = f"sk_{secrets.token_urlsafe(32)}"
        
        # 有効期限を設定（デフォルト: 90日）
        expires_days = int(os.environ.get("API_KEY_EXPIRES_DAYS", "90"))
        expires_at = datetime.now() + timedelta(days=expires_days)
        
        # リフレッシュトークンを生成
        refresh_token = f"rt_{secrets.token_urlsafe(32)}"
        refresh_expires_at = datetime.now() + timedelta(days=180)  # 6ヶ月
        
        # ユーザーを作成（database.pyのcreate_user関数を拡張する必要あり）
        success = create_user(
            user_id=user_id,
            api_key=api_key,
            daily_tts_limit=request.daily_tts_limit or DEFAULT_DAILY_TTS_LIMIT,
            daily_clone_limit=request.daily_clone_limit or DEFAULT_DAILY_CLONE_LIMIT,
            expires_at=expires_at,
            refresh_token=refresh_token,
            refresh_token_expires_at=refresh_expires_at
        )
        
        if not success:
            raise HTTPException(
                status_code=409,
                detail="ユーザーIDまたはAPIキーが既に存在します"
            )
        
        return UserCreateResponse(
            user_id=user_id,
            api_key=api_key,
            message=f"ユーザーが作成されました。APIキーの有効期限: {expires_at.strftime('%Y-%m-%d')}"
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
```

### 有効期限チェック

`api_server.py`の`get_user_api_key`関数を修正：

```python
from datetime import datetime

def get_user_api_key(x_api_key: str = Header(None, alias="X-API-Key")) -> dict:
    """ユーザーAPIキーからユーザー情報を取得"""
    if not x_api_key:
        raise HTTPException(status_code=401, detail="X-API-Keyヘッダーが必要です")
    
    user = get_user_by_api_key(x_api_key)
    if not user:
        raise HTTPException(status_code=401, detail="無効なAPIキーです")
    
    # 有効期限チェック
    if user.get("api_key_expires_at"):
        expires_at = datetime.fromisoformat(user["api_key_expires_at"])
        if datetime.now() > expires_at:
            raise HTTPException(
                status_code=401,
                detail=f"APIキーの有効期限が切れています。有効期限: {expires_at.strftime('%Y-%m-%d %H:%M:%S')}"
            )
    
    return user
```

---

## 5. アクセスログ

### ログ設定

`api_server.py`に追加：

```python
# api_server.py の先頭に追加
import logging
from logging.handlers import RotatingFileHandler
from pathlib import Path

# ログディレクトリを作成
log_dir = Path(__file__).parent / "logs"
log_dir.mkdir(exist_ok=True)

# ログ設定
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        RotatingFileHandler(
            log_dir / "api_access.log",
            maxBytes=10*1024*1024,  # 10MB
            backupCount=5
        ),
        logging.StreamHandler()
    ]
)

logger = logging.getLogger(__name__)
```

### リクエストログミドルウェア

`api_server.py`に追加：

```python
@app.middleware("http")
async def log_requests(request: Request, call_next):
    """リクエストとレスポンスをログに記録"""
    start_time = time.time()
    
    # リクエスト情報をログ
    client_ip = request.client.host if request.client else "unknown"
    user_agent = request.headers.get("user-agent", "unknown")
    
    logger.info(
        f"Request: {request.method} {request.url.path} - "
        f"IP: {client_ip} - "
        f"User-Agent: {user_agent}"
    )
    
    try:
        response = await call_next(request)
        process_time = time.time() - start_time
        
        logger.info(
            f"Response: {request.method} {request.url.path} - "
            f"Status: {response.status_code} - "
            f"Time: {process_time:.3f}s - "
            f"IP: {client_ip}"
        )
        
        return response
    except Exception as e:
        process_time = time.time() - start_time
        logger.error(
            f"Error: {request.method} {request.url.path} - "
            f"Exception: {str(e)} - "
            f"Time: {process_time:.3f}s - "
            f"IP: {client_ip}",
            exc_info=True
        )
        raise
```

### エラーログ

`api_server.py`の各エンドポイントでエラーログを追加：

```python
@app.post("/api/v2/tts/generate")
async def generate_tts_audio(
    request: TTSRequest,
    user: dict = Depends(get_user_api_key)
):
    """TTS音声を生成（多ユーザー対応版）"""
    try:
        # ... 既存のコード ...
    except HTTPException as e:
        logger.warning(
            f"HTTP Error: {e.status_code} - {e.detail} - "
            f"User: {user.get('user_id', 'unknown')}"
        )
        raise
    except Exception as e:
        logger.error(
            f"Unexpected Error in TTS generation - "
            f"User: {user.get('user_id', 'unknown')} - "
            f"Error: {str(e)}",
            exc_info=True
        )
        raise HTTPException(status_code=500, detail="内部サーバーエラーが発生しました")
```

---

## 📝 実装の順序

1. **Phase 1（最優先）**
   - IPアドレスベースのレート制限
   - 異常アクセス検知
   - アクセスログ

2. **Phase 2（中優先）**
   - APIキーの暗号化保存
   - トークンの有効期限

3. **Phase 3（低優先）**
   - リフレッシュトークン
   - ダッシュボード

---

## ⚠️ 注意事項

1. **暗号化キーの管理**
   - 本番環境では必ず環境変数で管理
   - キーをバージョン管理システムにコミットしない
   - キーを失くすと既存のAPIキーが復号化できなくなる

2. **パフォーマンス**
   - 暗号化/復号化はCPU負荷がかかる
   - 大量のユーザーがいる場合は、キャッシュを検討

3. **データベースマイグレーション**
   - 既存のデータがある場合、マイグレーションスクリプトが必要
   - バックアップを取ってから実行

---

## 🔗 関連ドキュメント

- [NOTION_COMPARISON.md](./NOTION_COMPARISON.md) - Notionとの比較と改善案
- [SECURITY.md](./SECURITY.md) - セキュリティに関する詳細
- [AUTHENTICATION_OPTIONS.md](./AUTHENTICATION_OPTIONS.md) - 認証方式の選択肢

