"""
ユーザー管理と利用制限のためのデータベースモジュール
SQLiteを使用して無料で運用可能
仕様書: specs/04_DATABASE_DESIGN.md
"""

import sqlite3
from datetime import date, datetime
from pathlib import Path
from typing import Optional, Dict, List, Tuple

# データベースファイルのパス（storageディレクトリに配置）
DB_PATH = Path(__file__).parent.parent / "storage" / "tts_app.db"

# デフォルトの利用制限設定
DEFAULT_DAILY_TTS_LIMIT = 20
DEFAULT_DAILY_CLONE_LIMIT = 2
DEFAULT_MONTHLY_COST_LIMIT = 5000.0


def get_db_connection():
    """データベース接続を取得"""
    conn = sqlite3.connect(str(DB_PATH), timeout=10.0)
    conn.row_factory = sqlite3.Row
    # WALモードを有効にして同時アクセスを改善
    conn.execute("PRAGMA journal_mode=WAL")
    return conn


def init_database():
    """データベースを初期化（テーブル作成）"""
    conn = get_db_connection()
    cursor = conn.cursor()
    
    # ユーザーテーブル（Firebase UIDを主キーとして使用）
    cursor.execute(f"""
        CREATE TABLE IF NOT EXISTS users (
            user_id TEXT PRIMARY KEY,
            email TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            daily_tts_limit INTEGER DEFAULT {DEFAULT_DAILY_TTS_LIMIT},
            daily_clone_limit INTEGER DEFAULT {DEFAULT_DAILY_CLONE_LIMIT},
            is_active BOOLEAN DEFAULT 1
        )
    """)
    
    # Voice Modelsテーブル
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS voice_models (
            model_id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL,
            reference_name TEXT NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            metadata TEXT,
            FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
        )
    """)
    
    # 利用履歴テーブル
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS usage_history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id TEXT NOT NULL,
            usage_type TEXT NOT NULL,
            cost REAL DEFAULT 0.0,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
        )
    """)
    
    # コスト管理テーブル（月次）
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS monthly_costs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            year INTEGER NOT NULL,
            month INTEGER NOT NULL,
            total_cost REAL DEFAULT 0.0,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            UNIQUE(year, month)
        )
    """)
    
    # インデックスの作成
    cursor.execute("""
        CREATE INDEX IF NOT EXISTS idx_users_email 
        ON users(email)
    """)
    
    cursor.execute("""
        CREATE INDEX IF NOT EXISTS idx_voice_models_user 
        ON voice_models(user_id)
    """)
    
    cursor.execute("""
        CREATE INDEX IF NOT EXISTS idx_voice_models_user_created 
        ON voice_models(user_id, created_at)
    """)
    
    cursor.execute("""
        CREATE INDEX IF NOT EXISTS idx_usage_user_date 
        ON usage_history(user_id, DATE(created_at))
    """)
    
    cursor.execute("""
        CREATE INDEX IF NOT EXISTS idx_usage_type_date 
        ON usage_history(usage_type, DATE(created_at))
    """)
    
    cursor.execute("""
        CREATE INDEX IF NOT EXISTS idx_monthly_costs_year_month 
        ON monthly_costs(year, month)
    """)

    # TTS履歴テーブル
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS tts_history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id TEXT NOT NULL,
            model_id TEXT,
            text TEXT NOT NULL,
            format TEXT NOT NULL,
            file_name TEXT NOT NULL,
            file_path TEXT NOT NULL,
            size_bytes INTEGER,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
        )
    """)

    cursor.execute("""
        CREATE INDEX IF NOT EXISTS idx_tts_history_user_created
        ON tts_history(user_id, created_at DESC)
    """)
    
    conn.commit()
    conn.close()


def create_user(user_id: str, email: str = None,
                daily_tts_limit: int = DEFAULT_DAILY_TTS_LIMIT,
                daily_clone_limit: int = DEFAULT_DAILY_CLONE_LIMIT) -> bool:
    """新しいユーザーを作成（Firebase UID使用）"""
    conn = get_db_connection()
    cursor = conn.cursor()
    
    try:
        cursor.execute("""
            INSERT INTO users (user_id, email, daily_tts_limit, daily_clone_limit)
            VALUES (?, ?, ?, ?)
        """, (user_id, email, daily_tts_limit, daily_clone_limit))
        conn.commit()
        return True
    except sqlite3.IntegrityError:
        return False
    finally:
        conn.close()


def get_user_by_id(user_id: str) -> Optional[Dict]:
    """ユーザーIDからユーザー情報を取得"""
    conn = get_db_connection()
    cursor = conn.cursor()
    
    cursor.execute("""
        SELECT user_id, email, daily_tts_limit, daily_clone_limit, is_active
        FROM users
        WHERE user_id = ? AND is_active = 1
    """, (user_id,))
    
    row = cursor.fetchone()
    conn.close()
    
    if row:
        return {
            "user_id": row["user_id"],
            "email": row["email"],
            "daily_tts_limit": row["daily_tts_limit"],
            "daily_clone_limit": row["daily_clone_limit"],
            "is_active": bool(row["is_active"])
        }
    return None


def get_all_users() -> List[Dict]:
    """全ユーザー情報を取得"""
    conn = get_db_connection()
    cursor = conn.cursor()
    
    cursor.execute("""
        SELECT user_id, email, daily_tts_limit, daily_clone_limit, is_active
        FROM users
        ORDER BY created_at DESC
    """)
    
    rows = cursor.fetchall()
    conn.close()
    
    return [
        {
            "user_id": row["user_id"],
            "email": row["email"],
            "daily_tts_limit": row["daily_tts_limit"],
            "daily_clone_limit": row["daily_clone_limit"],
            "is_active": bool(row["is_active"])
        }
        for row in rows
    ]


def get_daily_usage_count(user_id: str, usage_type: str, target_date: date = None) -> int:
    """指定日の利用回数を取得"""
    if target_date is None:
        target_date = date.today()
    
    conn = get_db_connection()
    cursor = conn.cursor()
    
    cursor.execute("""
        SELECT COUNT(*) as count
        FROM usage_history
        WHERE user_id = ? AND usage_type = ? AND DATE(created_at) = ?
    """, (user_id, usage_type, target_date.isoformat()))
    
    result = cursor.fetchone()
    conn.close()
    
    return result["count"] if result else 0


def get_monthly_cost(year: int = None, month: int = None) -> float:
    """月次コストを取得（全体）"""
    if year is None or month is None:
        today = date.today()
        year = today.year
        month = today.month
    
    conn = get_db_connection()
    cursor = conn.cursor()
    
    cursor.execute("""
        SELECT total_cost
        FROM monthly_costs
        WHERE year = ? AND month = ?
    """, (year, month))
    
    row = cursor.fetchone()
    conn.close()
    
    return row["total_cost"] if row else 0.0


def get_user_monthly_cost(user_id: str, year: int = None, month: int = None) -> float:
    """特定ユーザーの月次コストを取得"""
    if year is None or month is None:
        today = date.today()
        year = today.year
        month = today.month
    
    conn = get_db_connection()
    cursor = conn.cursor()
    
    cursor.execute("""
        SELECT SUM(cost) as total_cost
        FROM usage_history
        WHERE user_id = ? AND strftime('%Y', created_at) = ? AND strftime('%m', created_at) = ?
    """, (user_id, str(year).zfill(4), str(month).zfill(2)))
    
    row = cursor.fetchone()
    conn.close()
    
    return row["total_cost"] if row and row["total_cost"] is not None else 0.0


def update_monthly_cost(year: int, month: int, additional_cost: float):
    """月次コストを更新"""
    conn = get_db_connection()
    cursor = conn.cursor()
    
    cursor.execute("""
        INSERT INTO monthly_costs (year, month, total_cost, updated_at)
        VALUES (?, ?, ?, CURRENT_TIMESTAMP)
        ON CONFLICT(year, month) DO UPDATE SET
            total_cost = total_cost + ?,
            updated_at = CURRENT_TIMESTAMP
    """, (year, month, additional_cost, additional_cost))
    
    conn.commit()
    conn.close()


def record_usage(user_id: str, usage_type: str, cost: float = 0.0):
    """利用履歴を記録"""
    conn = get_db_connection()
    cursor = conn.cursor()
    
    try:
        cursor.execute("""
            INSERT INTO usage_history (user_id, usage_type, cost)
            VALUES (?, ?, ?)
        """, (user_id, usage_type, cost))
        
        # 月次コストも同じ接続で更新
        today = date.today()
        cursor.execute("""
            INSERT INTO monthly_costs (year, month, total_cost, updated_at)
            VALUES (?, ?, ?, CURRENT_TIMESTAMP)
            ON CONFLICT(year, month) DO UPDATE SET
                total_cost = total_cost + ?,
                updated_at = CURRENT_TIMESTAMP
        """, (today.year, today.month, cost, cost))
        
        conn.commit()
    finally:
        conn.close()


def check_usage_limit(user_id: str, usage_type: str, 
                     daily_limit: int, monthly_cost_limit: float = DEFAULT_MONTHLY_COST_LIMIT) -> Tuple[bool, str]:
    """
    利用制限をチェック
    
    Returns:
        (is_allowed, error_message)
    """
    # 日次制限チェック
    daily_count = get_daily_usage_count(user_id, usage_type)
    if daily_count >= daily_limit:
        return False, f"日次利用制限に達しました（{daily_limit}回/日）"
    
    # 月次コスト制限チェック
    monthly_cost = get_monthly_cost()
    if monthly_cost >= monthly_cost_limit:
        return False, f"月次コスト上限に達しました（{monthly_cost_limit}円/月）"
    
    return True, ""


def get_usage_stats(user_id: str = None) -> Dict:
    """利用統計を取得"""
    conn = get_db_connection()
    cursor = conn.cursor()
    
    today = date.today()
    
    if user_id:
        # 特定ユーザーの統計
        cursor.execute("""
            SELECT 
                COUNT(*) as total_usage,
                SUM(CASE WHEN usage_type = 'tts' THEN 1 ELSE 0 END) as tts_count,
                SUM(CASE WHEN usage_type = 'clone' THEN 1 ELSE 0 END) as clone_count,
                SUM(cost) as total_cost
            FROM usage_history
            WHERE user_id = ? AND DATE(created_at) = ?
        """, (user_id, today.isoformat()))
    else:
        # 全体の統計
        cursor.execute("""
            SELECT 
                COUNT(*) as total_usage,
                SUM(CASE WHEN usage_type = 'tts' THEN 1 ELSE 0 END) as tts_count,
                SUM(CASE WHEN usage_type = 'clone' THEN 1 ELSE 0 END) as clone_count,
                SUM(cost) as total_cost
            FROM usage_history
            WHERE DATE(created_at) = ?
        """, (today.isoformat(),))
    
    row = cursor.fetchone()
    
    # 月次コスト
    monthly_cost = get_monthly_cost()
    
    conn.close()
    
    # SQLiteのSUMは行がない場合にNoneを返すため、0に変換
    if row:
        daily_usage = row["total_usage"] or 0
        daily_tts = row["tts_count"] if row["tts_count"] is not None else 0
        daily_clone = row["clone_count"] if row["clone_count"] is not None else 0
        daily_cost = row["total_cost"] if row["total_cost"] is not None else 0.0
    else:
        daily_usage = 0
        daily_tts = 0
        daily_clone = 0
        daily_cost = 0.0
    
    return {
        "daily_usage": daily_usage,
        "daily_tts": daily_tts,
        "daily_clone": daily_clone,
        "daily_cost": daily_cost,
        "monthly_cost": monthly_cost
    }


# Voice Models関連の関数

def save_voice_model(user_id: str, model_id: str, reference_name: str, metadata: str = None):
    """Voice Modelをデータベースに保存"""
    conn = get_db_connection()
    cursor = conn.cursor()
    
    try:
        cursor.execute("""
            INSERT INTO voice_models (model_id, user_id, reference_name, metadata)
            VALUES (?, ?, ?, ?)
        """, (model_id, user_id, reference_name, metadata))
        conn.commit()
    except sqlite3.IntegrityError:
        # モデルIDが既に存在する場合
        raise ValueError(f"モデルID {model_id} は既に存在します")
    finally:
        conn.close()


def get_voice_models_by_user(user_id: str) -> List[Dict]:
    """ユーザーのVoice Model一覧を取得"""
    conn = get_db_connection()
    cursor = conn.cursor()
    
    cursor.execute("""
        SELECT model_id, reference_name, created_at
        FROM voice_models
        WHERE user_id = ?
        ORDER BY created_at DESC
    """, (user_id,))
    
    rows = cursor.fetchall()
    conn.close()
    
    return [
        {
            "model_id": row["model_id"],
            "reference_name": row["reference_name"],
            "created_at": row["created_at"]
        }
        for row in rows
    ]


def check_model_belongs_to_user(user_id: str, model_id: str) -> bool:
    """モデル所有権をチェック"""
    conn = get_db_connection()
    cursor = conn.cursor()
    
    cursor.execute("""
        SELECT COUNT(*) as count
        FROM voice_models
        WHERE user_id = ? AND model_id = ?
    """, (user_id, model_id))
    
    result = cursor.fetchone()
    conn.close()
    
    return result["count"] > 0 if result else False


def delete_voice_model_from_db(user_id: str, model_id: str):
    """Voice Modelをデータベースから削除"""
    conn = get_db_connection()
    cursor = conn.cursor()
    
    try:
        cursor.execute("""
            DELETE FROM voice_models
            WHERE user_id = ? AND model_id = ?
        """, (user_id, model_id))
        conn.commit()
        
        # 削除された行数を確認
        if cursor.rowcount == 0:
            raise ValueError("モデルが見つかりません")
    finally:
        conn.close()


# --- TTS履歴管理 ---

def save_tts_history_entry(
    user_id: str,
    model_id: Optional[str],
    text: str,
    audio_format: str,
    file_name: str,
    file_path: str,
    size_bytes: int
) -> int:
    """TTS履歴を保存し、レコードIDを返す"""
    conn = get_db_connection()
    cursor = conn.cursor()

    try:
        cursor.execute("""
            INSERT INTO tts_history (user_id, model_id, text, format, file_name, file_path, size_bytes)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        """, (user_id, model_id, text, audio_format, file_name, file_path, size_bytes))
        conn.commit()
        return cursor.lastrowid
    finally:
        conn.close()


def get_recent_tts_history(user_id: str, limit: int = 10) -> List[Dict]:
    """最新のTTS履歴を取得"""
    conn = get_db_connection()
    cursor = conn.cursor()

    cursor.execute("""
        SELECT id, user_id, model_id, text, format, file_name, file_path, size_bytes, created_at
        FROM tts_history
        WHERE user_id = ?
        ORDER BY created_at DESC
        LIMIT ?
    """, (user_id, limit))

    rows = cursor.fetchall()
    conn.close()

    return [
        {
            "id": row["id"],
            "user_id": row["user_id"],
            "model_id": row["model_id"],
            "text": row["text"],
            "format": row["format"],
            "file_name": row["file_name"],
            "file_path": row["file_path"],
            "size_bytes": row["size_bytes"],
            "created_at": row["created_at"]
        }
        for row in rows
    ]


def get_tts_history_entry(user_id: str, history_id: int) -> Optional[Dict]:
    """特定のTTS履歴を取得"""
    conn = get_db_connection()
    cursor = conn.cursor()

    cursor.execute("""
        SELECT id, user_id, model_id, text, format, file_name, file_path, size_bytes, created_at
        FROM tts_history
        WHERE user_id = ? AND id = ?
    """, (user_id, history_id))

    row = cursor.fetchone()
    conn.close()

    if row:
        return {
            "id": row["id"],
            "user_id": row["user_id"],
            "model_id": row["model_id"],
            "text": row["text"],
            "format": row["format"],
            "file_name": row["file_name"],
            "file_path": row["file_path"],
            "size_bytes": row["size_bytes"],
            "created_at": row["created_at"]
        }
    return None


def cleanup_old_tts_history(user_id: str, keep: int = 10) -> List[str]:
    """
    古いTTS履歴を削除し、削除したファイルパスの一覧を返す
    """
    if keep <= 0:
        keep = 1

    conn = get_db_connection()
    cursor = conn.cursor()

    cursor.execute("""
        SELECT id, file_path
        FROM tts_history
        WHERE user_id = ?
        ORDER BY created_at DESC
        LIMIT -1 OFFSET ?
    """, (user_id, keep))

    to_delete = cursor.fetchall()

    if to_delete:
        ids = [(row["id"],) for row in to_delete]
        cursor.executemany("DELETE FROM tts_history WHERE id = ?", ids)
        conn.commit()
        deleted_paths = [row["file_path"] for row in to_delete]
    else:
        deleted_paths = []

    conn.close()
    return deleted_paths


def get_voice_model_by_id(model_id: str) -> Optional[Dict]:
    """モデルIDからVoice Model情報を取得"""
    conn = get_db_connection()
    cursor = conn.cursor()
    
    cursor.execute("""
        SELECT model_id, user_id, reference_name, created_at, metadata
        FROM voice_models
        WHERE model_id = ?
    """, (model_id,))
    
    row = cursor.fetchone()
    conn.close()
    
    if row:
        return {
            "model_id": row["model_id"],
            "user_id": row["user_id"],
            "reference_name": row["reference_name"],
            "created_at": row["created_at"],
            "metadata": row["metadata"]
        }
    return None


# データベース初期化（モジュール読み込み時）
if not DB_PATH.exists():
    init_database()

