"""
ユーザー管理と利用制限のためのデータベースモジュール
SQLiteを使用して無料で運用可能
"""

import sqlite3
from datetime import date
from pathlib import Path
from typing import Optional, Dict, Tuple

# データベースファイルのパス
DB_PATH = Path(__file__).parent / "tts_app.db"

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
    
    # ユーザーテーブル
    cursor.execute(f"""
        CREATE TABLE IF NOT EXISTS users (
            user_id TEXT PRIMARY KEY,
            api_key TEXT UNIQUE NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            daily_tts_limit INTEGER DEFAULT {DEFAULT_DAILY_TTS_LIMIT},
            daily_clone_limit INTEGER DEFAULT {DEFAULT_DAILY_CLONE_LIMIT},
            is_active BOOLEAN DEFAULT 1
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
            FOREIGN KEY (user_id) REFERENCES users(user_id)
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
        CREATE INDEX IF NOT EXISTS idx_usage_user_date 
        ON usage_history(user_id, DATE(created_at))
    """)
    
    conn.commit()
    conn.close()


def create_user(user_id: str, api_key: str, 
                daily_tts_limit: int = DEFAULT_DAILY_TTS_LIMIT,
                daily_clone_limit: int = DEFAULT_DAILY_CLONE_LIMIT) -> bool:
    """新しいユーザーを作成"""
    conn = get_db_connection()
    cursor = conn.cursor()
    
    try:
        cursor.execute("""
            INSERT INTO users (user_id, api_key, daily_tts_limit, daily_clone_limit)
            VALUES (?, ?, ?, ?)
        """, (user_id, api_key, daily_tts_limit, daily_clone_limit))
        conn.commit()
        return True
    except sqlite3.IntegrityError:
        return False
    finally:
        conn.close()


def get_user_by_api_key(api_key: str) -> Optional[Dict]:
    """APIキーからユーザー情報を取得"""
    conn = get_db_connection()
    cursor = conn.cursor()
    
    cursor.execute("""
        SELECT user_id, api_key, daily_tts_limit, daily_clone_limit, is_active
        FROM users
        WHERE api_key = ? AND is_active = 1
    """, (api_key,))
    
    row = cursor.fetchone()
    conn.close()
    
    if row:
        return {
            "user_id": row["user_id"],
            "api_key": row["api_key"],
            "daily_tts_limit": row["daily_tts_limit"],
            "daily_clone_limit": row["daily_clone_limit"],
            "is_active": bool(row["is_active"])
        }
    return None


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
    """月次コストを取得"""
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


# データベース初期化（モジュール読み込み時）
if not DB_PATH.exists():
    init_database()

