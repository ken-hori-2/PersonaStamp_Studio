# 管理者向けAPI使い方ガイド

## 📋 概要

管理者向けAPIエンドポイントの使い方を説明します。管理者APIは、Firebase IDトークンを使用して認証し、管理者メールアドレスで権限を確認します。

---

## 🔐 認証方法

### Firebase IDトークンの取得

管理者APIを使用するには、Firebase IDトークンが必要です。

#### 方法1: iOSアプリから取得

1. **RendVuアプリでログイン**
   - 管理者のメールアドレスでログイン

2. **開発者ツールでIDトークンを確認**
   - Xcodeのデバッグコンソールで確認
   - または、アプリ内でトークンを表示する機能を追加

#### 方法2: Firebase Consoleから確認

1. **Firebase Console > Authentication > Users**
2. ユーザーを選択
3. ユーザー情報を確認（IDトークンは直接表示されません）

#### 方法3: プログラムから取得

```python
import firebase_admin
from firebase_admin import auth

# カスタムトークンを生成
custom_token = auth.create_custom_token(uid)
```

---

## 📝 APIエンドポイント

### 1. GET `/api/admin/stats`

**説明**: 全体統計を取得

**認証**: 管理者権限が必要

**リクエスト例**:

```bash
curl -X GET "http://localhost:8000/api/admin/stats" \
  -H "Authorization: Bearer YOUR_FIREBASE_ID_TOKEN"
```

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

---

### 2. GET `/api/admin/users`

**説明**: 全ユーザーの一覧とコスト情報を取得

**認証**: 管理者権限が必要

**リクエスト例**:

```bash
curl -X GET "http://localhost:8000/api/admin/users" \
  -H "Authorization: Bearer YOUR_FIREBASE_ID_TOKEN"
```

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

---

### 3. GET `/api/admin/users/{user_id}/costs`

**説明**: 特定ユーザーのコスト情報を取得

**認証**: 管理者権限が必要

**パラメータ**:
- `user_id` (path): ユーザーID

**リクエスト例**:

```bash
curl -X GET "http://localhost:8000/api/admin/users/user123/costs" \
  -H "Authorization: Bearer YOUR_FIREBASE_ID_TOKEN"
```

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

## 🚀 使い方

### curlでの使用例

```bash
# 1. Firebase IDトークンを取得（環境変数に設定）
export FIREBASE_ID_TOKEN="your_firebase_id_token_here"

# 2. 全体統計を取得
curl -X GET "http://localhost:8000/api/admin/stats" \
  -H "Authorization: Bearer $FIREBASE_ID_TOKEN"

# 3. ユーザー一覧を取得
curl -X GET "http://localhost:8000/api/admin/users" \
  -H "Authorization: Bearer $FIREBASE_ID_TOKEN"

# 4. 特定ユーザーのコスト情報を取得
curl -X GET "http://localhost:8000/api/admin/users/user123/costs" \
  -H "Authorization: Bearer $FIREBASE_ID_TOKEN"
```

### Postmanでの使用例

1. **新しいリクエストを作成**
   - Method: `GET`
   - URL: `http://localhost:8000/api/admin/stats`

2. **認証ヘッダーを設定**
   - Headersタブを開く
   - Key: `Authorization`
   - Value: `Bearer YOUR_FIREBASE_ID_TOKEN`

3. **リクエストを送信**

### Pythonでの使用例

```python
import requests

# Firebase IDトークン
id_token = "your_firebase_id_token_here"

# ベースURL
base_url = "http://localhost:8000"

# ヘッダー
headers = {
    "Authorization": f"Bearer {id_token}"
}

# 全体統計を取得
response = requests.get(
    f"{base_url}/api/admin/stats",
    headers=headers
)
stats = response.json()
print(stats)

# ユーザー一覧を取得
response = requests.get(
    f"{base_url}/api/admin/users",
    headers=headers
)
users = response.json()
print(users)
```

---

## ⚙️ 管理者設定

### 環境変数の設定

管理者メールアドレスを環境変数`ADMIN_EMAILS`に設定します。

**ローカル開発環境**:

```bash
export ADMIN_EMAILS="admin@example.com,manager@example.com"
```

**`.env`ファイル**:

```env
ADMIN_EMAILS=admin@example.com,manager@example.com
```

**重要**: 
- 複数の管理者を設定する場合は、カンマ（`,`）で区切ります
- メールアドレスは、Firebase Authenticationで登録されているメールアドレスと**完全に一致**する必要があります
- 大文字・小文字は区別されません（自動的に小文字に変換されます）

---

## 🔒 セキュリティ

### 管理者権限の確認

管理者APIは、以下のチェックを行います：

1. **Firebase IDトークンの検証**
   - トークンが有効か確認
   - トークンが期限切れでないか確認

2. **管理者メールアドレスの確認**
   - トークンに含まれるメールアドレスが`ADMIN_EMAILS`に含まれているか確認

3. **エラーレスポンス**
   - 管理者でない場合は403エラーを返す

### エラーレスポンス

**403 Forbidden**:
```json
{
  "detail": "このエンドポイントにアクセスするには管理者権限が必要です"
}
```

**401 Unauthorized**:
```json
{
  "detail": "認証が必要です"
}
```

---

## 🛠️ トラブルシューティング

### エラー: "管理者権限がありません"

**原因**: ログインしているユーザーのメールアドレスが`ADMIN_EMAILS`に含まれていない

**解決方法**:
1. 環境変数`ADMIN_EMAILS`を確認
2. 管理者のメールアドレスが正しく設定されているか確認
3. メールアドレスがFirebase Authenticationで登録されているか確認
4. バックエンドサーバーを再起動

### エラー: "認証が必要です"

**原因**: Firebase IDトークンが無効または期限切れ

**解決方法**:
1. 新しいトークンを取得
2. トークンの有効期限を確認
3. Firebase Authenticationの設定を確認

### エラー: "APIリクエストエラー"

**原因**: バックエンドAPIに接続できない

**解決方法**:
1. バックエンドAPIが起動しているか確認
2. URLが正しいか確認（`http://localhost:8000`）
3. ネットワーク接続を確認

---

## 📚 参考資料

- [ADMIN_SETUP.md](./ADMIN_SETUP.md) - 管理者設定ガイド
- [ADMIN_DASHBOARD_README.md](./ADMIN_DASHBOARD_README.md) - 管理者ダッシュボードの使い方
- [FastAPI Documentation](https://fastapi.tiangolo.com/)
- [Firebase Authentication](https://firebase.google.com/docs/auth)

---

**更新日**: 2025年1月  
**作成者**: AI Assistant

