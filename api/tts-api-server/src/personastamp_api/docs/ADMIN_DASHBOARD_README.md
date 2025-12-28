# 管理者ダッシュボード 使い方ガイド

## 📋 概要

管理者向けのコスト管理ダッシュボードです。Streamlitを使用したWebインターフェースで、コスト情報やユーザー使用状況を確認できます。

---

## 🚀 起動方法

### 1. 必要なパッケージのインストール

```bash
pip install streamlit requests
```

### 2. 環境変数の設定

```bash
# 管理者のメールアドレス（カンマ区切りで複数指定可能）
export ADMIN_EMAILS="admin@example.com,manager@example.com"

# バックエンドAPIのベースURL
# デフォルト: https://personastamp-studio.onrender.com (Render本番環境)
# ローカル開発の場合は以下を設定:
export API_BASE_URL="http://localhost:8000"
```

### 3. ダッシュボードの起動

```bash
cd /path/to/personastamp_api
streamlit run admin_dashboard.py
```

ブラウザで `http://localhost:8501` にアクセスします。

---

## 🔐 認証方法

### Firebase IDトークンの取得

1. **iOSアプリから取得**:
   - RendVuアプリでログイン
   - 開発者ツールでIDトークンを確認

2. **Firebase Consoleから取得**:
   - Firebase Console > Authentication > Users
   - ユーザーのIDトークンを確認

3. **プログラムから取得**:
   ```python
   import firebase_admin
   from firebase_admin import auth
   
   # カスタムトークンを生成
   custom_token = auth.create_custom_token(uid)
   ```

### トークンの設定

ダッシュボードのサイドバーで、Firebase IDトークンを入力してください。

---

## 📊 機能説明

### タブ1: 全体統計

- **総ユーザー数**: 登録されている全ユーザー数
- **今日のアクティブユーザー**: 今日サービスを使用したユーザー数
- **今日のTTS生成**: 今日生成されたTTSの総数
- **今日のClone作成**: 今日作成されたVoice Cloneの総数
- **今日の総コスト**: 今日の全ユーザーのコスト合計
- **今月の総コスト**: 今月の全ユーザーのコスト合計と上限

### タブ2: ユーザー一覧

- **ユーザー検索**: EmailまたはUser IDで検索可能
- **ユーザー一覧テーブル**: 
  - User ID
  - Email
  - 今日のTTS使用状況
  - 今日のClone使用状況
  - 今日のコスト
  - 今月のコスト
- **ユーザー詳細**: 選択したユーザーの詳細情報を表示

### タブ3: コスト分析

- **コストサマリー**: 今日・今月の総コストと残り予算
- **ユーザー別コストランキング**: 今月のコストが高いユーザー順（トップ10）

---

## 🔒 セキュリティ

### 管理者権限の確認

管理者権限は、環境変数`ADMIN_EMAILS`に設定されたメールアドレスで判定されます。

```bash
export ADMIN_EMAILS="admin@example.com,manager@example.com"
```

### APIエンドポイントの保護

管理者向けAPIエンドポイント（`/api/admin/*`）は、以下のチェックを行います：

1. Firebase IDトークンの検証
2. 管理者メールアドレスの確認
3. 管理者でない場合は403エラーを返す

**重要**: iOSアプリ（エンドユーザー）から管理者APIにアクセスしようとした場合、管理者でないユーザーは自動的に403エラーが返されます。iOSアプリ側には管理者APIを呼び出すコードは含まれていませんが、万が一直接アクセスしようとしてもバックエンド側で保護されています。

---

## 📝 APIエンドポイント

### 1. `/api/admin/stats`

**説明**: 全体統計を取得

**レスポンス例**:
```json
{
  "total_users": 10,
  "active_users_today": 5,
  "daily_tts_count": 25,
  "daily_clone_count": 3,
  "daily_total_cost": 2.5,
  "monthly_total_cost": 45.0,
  "monthly_cost_limit": 5000.0
}
```

### 2. `/api/admin/users`

**説明**: 全ユーザーの一覧とコスト情報を取得

**レスポンス例**:
```json
{
  "users": [
    {
      "user_id": "user123",
      "email": "user@example.com",
      "daily_tts": 5,
      "daily_clone": 1,
      "daily_cost": 0.6,
      "monthly_cost": 12.5,
      "daily_tts_limit": 20,
      "daily_clone_limit": 2
    }
  ],
  "total_users": 10
}
```

### 3. `/api/admin/users/{user_id}/costs`

**説明**: 特定ユーザーのコスト情報を取得

**レスポンス例**:
```json
{
  "user_id": "user123",
  "email": "user@example.com",
  "daily_tts": 5,
  "daily_clone": 1,
  "daily_cost": 0.6,
  "monthly_cost": 12.5,
  "daily_tts_limit": 20,
  "daily_clone_limit": 2
}
```

---

## 🛠️ トラブルシューティング

### エラー: "管理者権限がありません"

**原因**: ログインしているユーザーのメールアドレスが`ADMIN_EMAILS`に含まれていない

**解決方法**:
1. 環境変数`ADMIN_EMAILS`を確認
2. 管理者のメールアドレスが正しく設定されているか確認
3. バックエンドサーバーを再起動

### エラー: "APIリクエストエラー"

**原因**: バックエンドAPIに接続できない

**解決方法**:
1. バックエンドAPIが起動しているか確認
2. `API_BASE_URL`が正しく設定されているか確認
3. ネットワーク接続を確認

### エラー: "無効なトークンです"

**原因**: Firebase IDトークンが無効または期限切れ

**解決方法**:
1. 新しいトークンを取得
2. トークンの有効期限を確認
3. Firebase Authenticationの設定を確認

---

## 📚 参考資料

- [Streamlit Documentation](https://docs.streamlit.io/)
- [FastAPI Documentation](https://fastapi.tiangolo.com/)
- [Firebase Authentication](https://firebase.google.com/docs/auth)

---

**更新日**: 2025年1月  
**作成者**: AI Assistant

