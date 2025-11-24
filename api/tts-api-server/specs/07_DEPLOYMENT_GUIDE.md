# デプロイ手順

## 🎯 ホスティング選択

### 推奨: Railway

**理由**:
- ✅ デプロイが最も簡単
- ✅ 無料クレジット（$5/月）
- ✅ SQLite対応
- ✅ スリープなし

### 代替: AWS Lightsail

**理由**:
- ✅ 固定料金（$5/月）
- ✅ 現在のコードをそのまま使える
- ✅ AWS知識を活用

---

## 🚀 Railwayでのデプロイ

### 1. Railwayアカウント作成

1. [Railway](https://railway.app)にアクセス
2. GitHubアカウントでサインアップ

### 2. プロジェクト作成

1. 「New Project」をクリック
2. 「Deploy from GitHub repo」を選択
3. リポジトリを選択

### 3. 環境変数の設定

Railwayダッシュボードで環境変数を設定：

```
FISH_AUDIO_API_KEY=your_fish_audio_api_key
FIREBASE_PROJECT_ID=your-firebase-project-id
FIREBASE_PRIVATE_KEY_ID=your-private-key-id
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"
FIREBASE_CLIENT_EMAIL=your-client-email@your-project.iam.gserviceaccount.com
FIREBASE_CLIENT_ID=your-client-id
MONTHLY_COST_LIMIT=5000.0
PORT=8000
```

### 4. デプロイ設定

**Start Command**を設定：

```bash
cd tts_api_server && python api_server.py
```

または、`Procfile`を作成：

```
web: cd tts_api_server && python api_server.py
```

### 5. デプロイ

GitHubにpushすると自動でデプロイされます。

---

## 🚀 AWS Lightsailでのデプロイ

### 1. Lightsailインスタンス作成

1. AWSコンソールでLightsailにアクセス
2. 「Create instance」をクリック
3. 設定:
   - **Platform**: Linux/Unix
   - **Blueprint**: Ubuntu 22.04 LTS
   - **Instance plan**: $5/月（1GB RAM、1 vCPU、40GB SSD）

### 2. SSH接続

```bash
ssh -i ~/.ssh/lightsail-key.pem ubuntu@your-instance-ip
```

### 3. 環境セットアップ

```bash
# システム更新
sudo apt update && sudo apt upgrade -y

# Python 3.11をインストール
sudo apt install python3.11 python3.11-venv python3-pip -y

# Nginxをインストール
sudo apt install nginx -y

# Gitをインストール
sudo apt install git -y
```

### 4. アプリケーションのデプロイ

```bash
# アプリケーションディレクトリを作成
mkdir -p /var/www/tts-api
cd /var/www/tts-api

# リポジトリをクローン
git clone https://github.com/yourusername/tts-api-server.git .

# 仮想環境を作成
cd tts_api_server
python3.11 -m venv venv
source venv/bin/activate

# 依存関係をインストール
pip install -r requirements.txt

# 環境変数を設定
echo "FISH_AUDIO_API_KEY=your_api_key_here" > .env
echo "FIREBASE_PROJECT_ID=your-project-id" >> .env
# ... 他の環境変数も追加
```

### 5. systemdサービスを作成

```bash
sudo nano /etc/systemd/system/tts-api.service
```

```ini
[Unit]
Description=TTS API Server
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/var/www/tts-api/tts_api_server
Environment="PATH=/var/www/tts-api/venv/bin"
ExecStart=/var/www/tts-api/venv/bin/python api_server.py
Restart=always

[Install]
WantedBy=multi-user.target
```

```bash
# サービスを有効化
sudo systemctl enable tts-api
sudo systemctl start tts-api
sudo systemctl status tts-api
```

### 6. Nginx設定

```bash
sudo nano /etc/nginx/sites-available/tts-api
```

```nginx
server {
    listen 80;
    server_name your-domain.com;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

```bash
# シンボリックリンクを作成
sudo ln -s /etc/nginx/sites-available/tts-api /etc/nginx/sites-enabled/

# Nginxを再起動
sudo nginx -t
sudo systemctl restart nginx
```

### 7. SSL証明書（Let's Encrypt）

```bash
# Certbotをインストール
sudo apt install certbot python3-certbot-nginx -y

# SSL証明書を取得
sudo certbot --nginx -d your-domain.com
```

---

## 🔧 環境変数設定

### 必須環境変数

| 変数名 | 説明 | 例 |
|--------|------|-----|
| `FISH_AUDIO_API_KEY` | Fish Audio APIキー | `sk_xxxxx` |
| `FIREBASE_PROJECT_ID` | FirebaseプロジェクトID | `your-project-id` |
| `FIREBASE_PRIVATE_KEY_ID` | Firebase秘密鍵ID | `xxxxx` |
| `FIREBASE_PRIVATE_KEY` | Firebase秘密鍵 | `-----BEGIN PRIVATE KEY-----\n...` |
| `FIREBASE_CLIENT_EMAIL` | Firebaseクライアントメール | `xxx@xxx.iam.gserviceaccount.com` |
| `FIREBASE_CLIENT_ID` | FirebaseクライアントID | `xxxxx` |

### オプション環境変数

| 変数名 | 説明 | デフォルト |
|--------|------|-----------|
| `MONTHLY_COST_LIMIT` | 月次コスト上限（円） | `5000.0` |
| `PORT` | サーバーポート | `8000` |

---

## ✅ デプロイチェックリスト

### デプロイ前

- [ ] 環境変数がすべて設定されている
- [ ] ローカル環境で動作確認が完了している
- [ ] テストがすべて通過している
- [ ] `.env`ファイルが`.gitignore`に含まれている

### デプロイ後

- [ ] サーバーが起動している
- [ ] ヘルスチェックが成功している（`/health`）
- [ ] APIエンドポイントが動作している
- [ ] Firebase認証が動作している
- [ ] ログが正常に出力されている

---

## 🔍 トラブルシューティング

### サーバーが起動しない

1. ログを確認
   - Railway: ダッシュボードの「Logs」タブ
   - Lightsail: `sudo journalctl -u tts-api -f`

2. 環境変数を確認
   - すべての必須環境変数が設定されているか

3. ポート番号を確認
   - 環境変数`PORT`が正しく設定されているか

### Firebase認証エラー

1. Firebase認証情報を確認
   - 環境変数が正しく設定されているか
   - 秘密鍵の改行文字（`\n`）が正しくエスケープされているか

2. Firebaseプロジェクト設定を確認
   - Authenticationが有効化されているか
   - Apple Sign Inが設定されているか

### Fish Audio APIエラー

1. APIキーを確認
   - 環境変数`FISH_AUDIO_API_KEY`が正しく設定されているか
   - APIキーが有効か

2. APIエンドポイントを確認
   - Fish Audio APIのエンドポイントが正しいか

---

## 📊 監視

### ログ確認

- Railway: ダッシュボードの「Logs」タブ
- Lightsail: `sudo journalctl -u tts-api -f`

### メトリクス

- リクエスト数
- エラー率
- レスポンス時間
- 利用制限の状況

---

## 🔗 関連ドキュメント

- [ホスティング比較](../docs/HOSTING_COMPARISON.md)
- [AWS実装ガイド](../docs/AWS_HOSTING_GUIDE.md)
- [実装手順](./06_IMPLEMENTATION_GUIDE.md)

