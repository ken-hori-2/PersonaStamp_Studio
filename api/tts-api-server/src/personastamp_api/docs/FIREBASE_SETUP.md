# Firebase認証設定ガイド

## 📋 設定手順

### 1. Firebase Consoleで認証情報を取得

1. [Firebase Console](https://console.firebase.google.com/)にアクセス
2. プロジェクトを選択（または新規作成）
3. 左メニューから「⚙️ プロジェクトの設定」をクリック
4. 「サービスアカウント」タブを選択
5. 「新しい秘密鍵の生成」をクリック
6. JSONファイルがダウンロードされます

### 2. JSONファイルから環境変数を抽出

ダウンロードしたJSONファイル（例：`personastamp-studio-firebase-adminsdk-xxxxx.json`）を開いて、以下の情報を確認：

```json
{
  "type": "service_account",
  "project_id": "your-project-id",
  "private_key_id": "xxxxx",
  "private_key": "-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n",
  "client_email": "firebase-adminsdk-xxxxx@your-project.iam.gserviceaccount.com",
  "client_id": "xxxxx",
  ...
}
```

### 3. .envファイルに追加

`src/personastamp_api/.env`ファイルに以下を追加：

```bash
# Firebase Authentication
FIREBASE_PROJECT_ID=your-project-id
FIREBASE_PRIVATE_KEY_ID=xxxxx
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"
FIREBASE_CLIENT_EMAIL=firebase-adminsdk-xxxxx@your-project.iam.gserviceaccount.com
FIREBASE_CLIENT_ID=xxxxx
```

**重要**: `FIREBASE_PRIVATE_KEY`は**ダブルクォートで囲む**必要があります。

### 4. Authenticationの有効化

1. Firebase Consoleで「Authentication」を選択
2. 「始める」をクリック
3. サインイン方法を有効化:
   - **Apple**: iOSアプリの場合、必須
   - **Google**: オプション
   - **メール/パスワード**: オプション

### 5. 動作確認

サーバーを再起動して、Firebase認証が正常に動作するか確認：

```bash
cd src/personastamp_api
source venv/bin/activate
python main.py
```

---

## 🔧 自動設定スクリプト

JSONファイルがある場合、以下のコマンドで自動的に.envに追加できます：

```bash
# JSONファイルのパスを指定
python setup_firebase_env.py path/to/firebase-adminsdk-xxxxx.json
```

---

## ⚠️ 注意事項

1. **秘密鍵の改行文字**: `\n`はそのまま記述してください（エスケープ不要）
2. **ダブルクォート**: `FIREBASE_PRIVATE_KEY`は必ずダブルクォートで囲んでください
3. **セキュリティ**: `.env`ファイルは`.gitignore`に含まれていることを確認してください
4. **JSONファイル**: ダウンロードしたJSONファイルは安全に保管してください

---

## 🧪 テスト

Firebase認証が正しく設定されているかテスト：

```python
# test_firebase.py
from core.auth import initialize_firebase

try:
    initialize_firebase()
    print("✅ Firebase認証の初期化に成功しました")
except Exception as e:
    print(f"❌ エラー: {e}")
```

---

## 📝 トラブルシューティング

### エラー: "Firebase認証情報が環境変数に設定されていません"

→ `.env`ファイルにすべてのFirebase認証情報が設定されているか確認してください。

### エラー: "無効なトークンです"

→ Firebase IDトークンが正しく生成されているか確認してください。

### エラー: "トークンの有効期限が切れています"

→ 新しいFirebase IDトークンを取得してください。

