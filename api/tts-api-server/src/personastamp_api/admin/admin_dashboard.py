"""
管理者向けコスト管理ダッシュボード
Streamlitを使用したWebインターフェース

使用方法:
    streamlit run admin_dashboard.py

環境変数:
    ADMIN_EMAILS: 管理者のメールアドレス（カンマ区切り）
    API_BASE_URL: バックエンドAPIのベースURL（デフォルト: http://localhost:8000）
"""

import streamlit as st
import requests
import os
from datetime import datetime, date
from typing import Optional

# 設定
# デフォルトはRenderの本番環境URL
# ローカル開発の場合は環境変数で上書き可能
API_BASE_URL = os.environ.get(
    "API_BASE_URL", 
    "https://personastamp-studio.onrender.com"
)
ADMIN_EMAILS = os.environ.get("ADMIN_EMAILS", "").split(",")

# ページ設定
st.set_page_config(
    page_title="管理者ダッシュボード - PersonaStamp Studio",
    page_icon="📊",
    layout="wide"
)

# セッション状態の初期化
if "id_token" not in st.session_state:
    st.session_state.id_token = None


def get_firebase_token() -> Optional[str]:
    """Firebase IDトークンを取得（手動入力または環境変数から）"""
    if st.session_state.id_token:
        return st.session_state.id_token
    
    # 環境変数から取得を試みる
    token = os.environ.get("FIREBASE_ID_TOKEN")
    if token:
        return token
    
    return None


def make_admin_request(endpoint: str) -> Optional[dict]:
    """管理者向けAPIリクエストを送信"""
    token = get_firebase_token()
    if not token:
        return None
    
    url = f"{API_BASE_URL}{endpoint}"
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    }
    
    try:
        response = requests.get(url, headers=headers, timeout=10)
        if response.status_code == 200:
            return response.json()
        elif response.status_code == 403:
            st.error("❌ 管理者権限がありません。管理者のメールアドレスでログインしてください。")
            return None
        else:
            st.error(f"❌ エラー: {response.status_code} - {response.text}")
            return None
    except requests.exceptions.RequestException as e:
        st.error(f"❌ APIリクエストエラー: {str(e)}")
        return None


def main():
    st.title("📊 管理者ダッシュボード")
    st.markdown("---")
    
    # 認証セクション
    with st.sidebar:
        st.header("🔐 認証")
        
        # Firebase IDトークンの入力
        token_input = st.text_input(
            "Firebase IDトークン",
            type="password",
            help="Firebase AuthenticationのIDトークンを入力してください"
        )
        
        if token_input:
            st.session_state.id_token = token_input
            st.success("✅ トークンが設定されました")
        
        if st.button("トークンをクリア"):
            st.session_state.id_token = None
            st.rerun()
        
        st.markdown("---")
        st.markdown("### 設定")
        st.text(f"API URL: {API_BASE_URL}")
        st.text(f"管理者数: {len([e for e in ADMIN_EMAILS if e.strip()])}")
    
    # メインコンテンツ
    token = get_firebase_token()
    if not token:
        st.warning("⚠️ Firebase IDトークンを入力してください（サイドバー）")
        st.info("💡 トークンは、Firebase Authenticationでログインした際に取得できます。")
        return
    
    # タブを作成
    tab1, tab2, tab3 = st.tabs(["📈 全体統計", "👥 ユーザー一覧", "💰 コスト分析"])
    
    # タブ1: 全体統計
    with tab1:
        st.header("📈 全体統計")
        
        if st.button("🔄 更新", key="refresh_stats"):
            st.rerun()
        
        stats = make_admin_request("/api/admin/stats")
        
        if stats:
            col1, col2, col3, col4 = st.columns(4)
            
            with col1:
                st.metric("総ユーザー数", stats["total_users"])
            
            with col2:
                st.metric("今日のアクティブユーザー", stats["active_users_today"])
            
            with col3:
                st.metric("今日のTTS生成", stats["daily_tts_count"])
            
            with col4:
                st.metric("今日のClone作成", stats["daily_clone_count"])
            
            st.markdown("---")
            
            col1, col2 = st.columns(2)
            
            with col1:
                st.metric(
                    "今日の総コスト",
                    f"¥{stats['daily_total_cost']:,.2f}",
                    delta=None
                )
            
            with col2:
                monthly_usage = stats["monthly_total_cost"] / stats["monthly_cost_limit"] * 100
                st.metric(
                    "今月の総コスト",
                    f"¥{stats['monthly_total_cost']:,.2f}",
                    delta=f"上限: ¥{stats['monthly_cost_limit']:,.0f} ({monthly_usage:.1f}%)"
                )
    
    # タブ2: ユーザー一覧
    with tab2:
        st.header("👥 ユーザー一覧とコスト")
        
        if st.button("🔄 更新", key="refresh_users"):
            st.rerun()
        
        users_data = make_admin_request("/api/admin/users")
        
        if users_data:
            st.metric("総ユーザー数", users_data["total_users"])
            
            # 検索機能
            search_term = st.text_input("🔍 ユーザー検索（EmailまたはUser ID）", "")
            
            users = users_data["users"]
            if search_term:
                users = [
                    u for u in users
                    if search_term.lower() in (u.get("email", "") or "").lower()
                    or search_term.lower() in u["user_id"].lower()
                ]
            
            # テーブル表示
            if users:
                st.markdown(f"### 表示中: {len(users)}ユーザー")
                
                # データをテーブル形式で表示
                table_data = []
                for user in users:
                    table_data.append({
                        "User ID": user["user_id"][:20] + "..." if len(user["user_id"]) > 20 else user["user_id"],
                        "Email": user.get("email") or "未設定",
                        "今日のTTS": f"{user['daily_tts']} / {user['daily_tts_limit']}",
                        "今日のClone": f"{user['daily_clone']} / {user['daily_clone_limit']}",
                        "今日のコスト": f"¥{user['daily_cost']:,.2f}",
                        "今月のコスト": f"¥{user['monthly_cost']:,.2f}"
                    })
                
                st.dataframe(
                    table_data,
                    use_container_width=True,
                    hide_index=True
                )
                
                # 詳細表示
                st.markdown("### ユーザー詳細")
                selected_user_id = st.selectbox(
                    "ユーザーを選択",
                    [u["user_id"] for u in users],
                    format_func=lambda x: next(
                        (u.get("email") or u["user_id"] for u in users if u["user_id"] == x),
                        x
                    )
                )
                
                if selected_user_id:
                    user_detail = make_admin_request(f"/api/admin/users/{selected_user_id}/costs")
                    if user_detail:
                        col1, col2 = st.columns(2)
                        
                        with col1:
                            st.markdown("#### 使用状況")
                            st.json({
                                "User ID": user_detail["user_id"],
                                "Email": user_detail.get("email") or "未設定",
                                "今日のTTS": f"{user_detail['daily_tts']} / {user_detail['daily_tts_limit']}",
                                "今日のClone": f"{user_detail['daily_clone']} / {user_detail['daily_clone_limit']}"
                            })
                        
                        with col2:
                            st.markdown("#### コスト情報")
                            st.json({
                                "今日のコスト": f"¥{user_detail['daily_cost']:,.2f}",
                                "今月のコスト": f"¥{user_detail['monthly_cost']:,.2f}"
                            })
            else:
                st.info("ユーザーが見つかりませんでした。")
    
    # タブ3: コスト分析
    with tab3:
        st.header("💰 コスト分析")
        
        if st.button("🔄 更新", key="refresh_costs"):
            st.rerun()
        
        users_data = make_admin_request("/api/admin/users")
        stats = make_admin_request("/api/admin/stats")
        
        if users_data and stats:
            # コストサマリー
            col1, col2, col3 = st.columns(3)
            
            with col1:
                st.metric("今日の総コスト", f"¥{stats['daily_total_cost']:,.2f}")
            
            with col2:
                st.metric("今月の総コスト", f"¥{stats['monthly_total_cost']:,.2f}")
            
            with col3:
                remaining = stats["monthly_cost_limit"] - stats["monthly_total_cost"]
                st.metric("残り予算", f"¥{remaining:,.2f}")
            
            st.markdown("---")
            
            # ユーザー別コストランキング
            st.markdown("### ユーザー別コストランキング（今月）")
            
            users = sorted(
                users_data["users"],
                key=lambda x: x["monthly_cost"],
                reverse=True
            )
            
            if users:
                cost_data = []
                for i, user in enumerate(users[:10], 1):  # トップ10
                    cost_data.append({
                        "順位": i,
                        "Email": user.get("email") or "未設定",
                        "User ID": user["user_id"][:15] + "...",
                        "今月のコスト": f"¥{user['monthly_cost']:,.2f}",
                        "今日のコスト": f"¥{user['daily_cost']:,.2f}"
                    })
                
                st.dataframe(
                    cost_data,
                    use_container_width=True,
                    hide_index=True
                )
            
            # コストの内訳
            st.markdown("### コスト内訳（今日）")
            
            total_daily_cost = stats["daily_total_cost"]
            if total_daily_cost > 0:
                # TTSとCloneのコストを推定（仮の値を使用）
                # 実際のコストはusage_historyテーブルから取得可能
                st.info("💡 詳細なコスト内訳は、usage_historyテーブルから取得できます。")


if __name__ == "__main__":
    main()

