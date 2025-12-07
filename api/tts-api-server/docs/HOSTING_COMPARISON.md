# ホスティングサービス比較ガイド

3rdパーティAPI（Fish Audio API/ChatGPT API）をラッピングするバックエンドサーバーのホスティング先を比較します。

## 🎯 要件

- **シンプル**: 設定が簡単で、すぐに始められる
- **低コスト**: 無料または月額$5以下
- **FastAPI対応**: Python + FastAPIアプリケーション
- **SQLite対応**: ファイルベースのデータベース
- **常時起動**: スリープしない（または最小限）

---

## 📊 ホスティングサービス比較

### 🥇 推奨: Railway（最優先）

**評価**: ⭐⭐⭐⭐⭐

#### 特徴

- ✅ **無料クレジット**: $5/月の無料クレジット（500時間/月）
- ✅ **デプロイが超簡単**: Git pushで自動デプロイ
- ✅ **環境変数管理**: Web UIで簡単に設定
- ✅ **SQLite対応**: 永続ストレージあり
- ✅ **HTTPS自動**: 自動でSSL証明書発行
- ✅ **ログ確認**: Web UIでリアルタイムログ確認
- ✅ **スリープなし**: 無料クレジット内なら常時起動

#### コスト

- **無料プラン**: $5/月のクレジット（500時間/月）
- **有料プラン**: $5/月から（クレジット超過時）
- **小規模運用**: ほぼ無料で運用可能

#### デプロイ手順

```bash
# 1. Railway CLIをインストール
npm i -g @railway/cli

# 2. ログイン
railway login

# 3. プロジェクトを初期化
railway init

# 4. 環境変数を設定
railway variables set FISH_AUDIO_API_KEY=your_key_here

# 5. デプロイ
railway up
```

または、GitHubと連携して自動デプロイも可能。

#### メリット

- デプロイが最も簡単
- 無料クレジットが使いやすい
- ドキュメントが充実
- コミュニティが活発

#### デメリット

- 無料クレジットを超えると課金
- 日本からのアクセスがやや遅い場合あり

---

### 🥈 推奨: Render

**評価**: ⭐⭐⭐⭐

#### 特徴

- ✅ **無料プラン**: 750時間/月
- ✅ **デプロイが簡単**: GitHubと連携
- ✅ **環境変数管理**: Web UIで設定
- ✅ **SQLite対応**: 永続ストレージあり
- ✅ **HTTPS自動**: 自動でSSL証明書発行
- ⚠️ **スリープあり**: 15分無アクセスでスリープ（初回リクエストが遅い）

#### コスト

- **無料プラン**: 750時間/月
- **有料プラン**: $7/月から（スリープなし）

#### デプロイ手順

1. GitHubリポジトリを接続
2. Renderで「New Web Service」を選択
3. リポジトリを選択
4. 環境変数を設定
5. 「Create Web Service」でデプロイ

#### メリット

- 無料プランが充実
- デプロイが簡単
- ドキュメントが分かりやすい

#### デメリット

- スリープ機能（無料プラン）
- 初回リクエストが遅い（スリープからの復帰）

---

### 🥉 推奨: Fly.io

**評価**: ⭐⭐⭐⭐

#### 特徴

- ✅ **無料プラン**: 3つの共有CPU、256MB RAM
- ✅ **グローバルデプロイ**: 複数リージョン対応
- ✅ **SQLite対応**: 永続ストレージ（Volumes）
- ✅ **HTTPS自動**: 自動でSSL証明書発行
- ✅ **スリープなし**: 常時起動

#### コスト

- **無料プラン**: 3つの共有CPU、256MB RAM
- **有料プラン**: $1.94/月から（専用CPU）

#### デプロイ手順

```bash
# 1. Fly CLIをインストール
curl -L https://fly.io/install.sh | sh

# 2. ログイン
fly auth login

# 3. アプリを作成
fly launch

# 4. 環境変数を設定
fly secrets set FISH_AUDIO_API_KEY=your_key_here

# 5. デプロイ
fly deploy
```

#### メリット

- グローバルデプロイ
- スリープなし
- パフォーマンスが良い

#### デメリット

- 設定がやや複雑
- 無料プランのリソースが限定的

---

### その他の選択肢

#### Heroku（非推奨）

- ❌ **無料プラン終了**: 2022年11月に終了
- ⚠️ **有料プラン**: $7/月から
- ✅ デプロイが簡単（ただし有料）

**結論**: 無料プランがないため、他の選択肢を推奨

#### Vercel / Netlify（非推奨）

- ⚠️ **サーバーレス関数**: FastAPIの常時起動には不向き
- ⚠️ **SQLite制限**: サーバーレス環境ではSQLiteが難しい
- ✅ フロントエンド向け

**結論**: FastAPI + SQLiteの構成には不向き

#### AWS Lambda + API Gateway（非推奨）

- ⚠️ **複雑さ**: 設定が複雑
- ⚠️ **SQLite制限**: サーバーレス環境ではSQLiteが難しい
- ⚠️ **コスト**: 無料枠内でも管理が大変

**結論**: シンプルさを重視する場合は不向き

---

## 📊 詳細比較表

| サービス | 無料プラン | 有料プラン | デプロイ | スリープ | SQLite | HTTPS | 評価 |
|---------|-----------|-----------|---------|---------|--------|-------|------|
| **Railway** | $5/月クレジット | $5/月から | ⭐⭐⭐⭐⭐ | なし | ✅ | ✅ | ⭐⭐⭐⭐⭐ |
| **Render** | 750時間/月 | $7/月から | ⭐⭐⭐⭐ | あり | ✅ | ✅ | ⭐⭐⭐⭐ |
| **Fly.io** | 3CPU共有 | $1.94/月から | ⭐⭐⭐ | なし | ✅ | ✅ | ⭐⭐⭐⭐ |
| Heroku | なし | $7/月から | ⭐⭐⭐⭐ | なし | ✅ | ✅ | ⭐⭐ |
| Vercel | あり | $20/月から | ⭐⭐⭐ | - | ❌ | ✅ | ⭐⭐ |

---

## 🎯 推奨順位

### 1位: Railway（最推奨）

**理由**:
- ✅ デプロイが最も簡単
- ✅ 無料クレジットが使いやすい
- ✅ スリープなし
- ✅ ドキュメントが充実

**適している人**:
- 初めてのデプロイ
- シンプルさを最優先
- すぐに始めたい

### 2位: Render

**理由**:
- ✅ 無料プランが充実
- ✅ デプロイが簡単
- ⚠️ スリープ機能あり（無料プラン）

**適している人**:
- スリープを許容できる
- 無料で運用したい
- シンプルなデプロイを希望

### 3位: Fly.io

**理由**:
- ✅ グローバルデプロイ
- ✅ スリープなし
- ⚠️ 設定がやや複雑

**適している人**:
- グローバル展開を検討
- パフォーマンスを重視
- 設定に慣れている

---

## 🚀 Railwayでのデプロイ手順（詳細）

### 方法1: Railway CLIを使用

```bash
# 1. Railway CLIをインストール
npm i -g @railway/cli

# 2. ログイン
railway login

# 3. プロジェクトディレクトリに移動
cd tts-api-server/tts_api_server

# 4. Railwayプロジェクトを初期化
railway init

# 5. 環境変数を設定
railway variables set FISH_AUDIO_API_KEY=your_api_key_here
railway variables set PORT=8000

# 6. デプロイ
railway up
```

### 方法2: GitHubと連携（推奨）

1. **GitHubリポジトリを作成**
   ```bash
   git init
   git add .
   git commit -m "Initial commit"
   git remote add origin https://github.com/yourusername/tts-api-server.git
   git push -u origin main
   ```

2. **Railwayでプロジェクトを作成**
   - [Railway](https://railway.app)にアクセス
   - 「New Project」をクリック
   - 「Deploy from GitHub repo」を選択
   - リポジトリを選択

3. **環境変数を設定**
   - Railwayのダッシュボードで「Variables」タブを開く
   - `FISH_AUDIO_API_KEY`を追加
   - `PORT=8000`を追加（Railwayが自動設定する場合もある）

4. **デプロイ設定**
   - 「Settings」タブで「Start Command」を設定:
     ```bash
     python api_server.py
     ```
   - または、`Procfile`を作成:
     ```
     web: python api_server.py
     ```

5. **自動デプロイ**
   - GitHubにpushすると自動でデプロイされる

### Railway用の設定ファイル

#### `railway.json`（オプション）

```json
{
  "$schema": "https://railway.app/railway.schema.json",
  "build": {
    "builder": "NIXPACKS"
  },
  "deploy": {
    "startCommand": "python api_server.py",
    "restartPolicyType": "ON_FAILURE",
    "restartPolicyMaxRetries": 10
  }
}
```

#### `Procfile`（オプション）

```
web: python api_server.py
```

---

## 🔧 Renderでのデプロイ手順

### 1. GitHubリポジトリを作成

```bash
git init
git add .
git commit -m "Initial commit"
git remote add origin https://github.com/yourusername/tts-api-server.git
git push -u origin main
```

### 2. RenderでWeb Serviceを作成

1. [Render](https://render.com)にアクセス
2. 「New +」→「Web Service」を選択
3. GitHubリポジトリを接続
4. リポジトリを選択

### 3. 設定

- **Name**: `tts-api-server`
- **Environment**: `Python 3`
- **Build Command**: `pip install -r requirements.txt`
- **Start Command**: `python api_server.py`
- **Plan**: `Free`

### 4. 環境変数を設定

- `FISH_AUDIO_API_KEY`: あなたのFish Audio APIキー
- `PORT`: `8000`（Renderが自動設定）

### 5. デプロイ

「Create Web Service」をクリックしてデプロイ開始

### 注意点

- **スリープ機能**: 15分無アクセスでスリープ
- **初回リクエスト**: スリープからの復帰に10-30秒かかる場合あり
- **解決策**: 有料プラン（$7/月）でスリープなし

---

## 🔧 Fly.ioでのデプロイ手順

### 1. Fly CLIをインストール

```bash
# macOS
curl -L https://fly.io/install.sh | sh

# Windows
powershell -Command "iwr https://fly.io/install.ps1 -useb | iex"
```

### 2. ログイン

```bash
fly auth login
```

### 3. アプリを作成

```bash
cd tts-api-server/tts_api_server
fly launch
```

### 4. `fly.toml`を編集

```toml
app = "your-app-name"
primary_region = "nrt"  # 東京リージョン

[build]

[env]
  PORT = "8000"

[[services]]
  internal_port = 8000
  protocol = "tcp"

  [[services.ports]]
    handlers = ["http"]
    port = 80

  [[services.ports]]
    handlers = ["tls", "http"]
    port = 443

  [[services.http_checks]]
    interval = "10s"
    timeout = "2s"
    grace_period = "5s"
    method = "GET"
    path = "/health"
```

### 5. 環境変数を設定

```bash
fly secrets set FISH_AUDIO_API_KEY=your_api_key_here
```

### 6. デプロイ

```bash
fly deploy
```

### 7. SQLite用のVolumeを作成（オプション）

```bash
fly volumes create tts_db --size 1 --region nrt
```

---

## 💰 コスト試算

### 小規模運用（~50ユーザー、月間10,000リクエスト）

| サービス | 月額コスト | 備考 |
|---------|-----------|------|
| **Railway** | **$0** | 無料クレジット内 |
| **Render** | **$0** | 無料プラン（スリープあり） |
| **Fly.io** | **$0** | 無料プラン |
| Heroku | $7 | 有料プラン必要 |

### 中規模運用（~500ユーザー、月間100,000リクエスト）

| サービス | 月額コスト | 備考 |
|---------|-----------|------|
| **Railway** | **$5-10** | クレジット超過時 |
| **Render** | **$7** | スリープなしプラン |
| **Fly.io** | **$2-5** | 専用CPU使用時 |
| Heroku | $7-25 | プランによる |

---

## 🎯 最終推奨

### シンプルでコストを抑えたい場合

**推奨: Railway**

理由:
1. ✅ デプロイが最も簡単（Git pushで自動デプロイ）
2. ✅ 無料クレジットが使いやすい
3. ✅ スリープなし
4. ✅ ドキュメントが充実
5. ✅ コミュニティが活発

### 完全無料で運用したい場合

**推奨: Render（無料プラン）**

理由:
1. ✅ 750時間/月の無料プラン
2. ✅ デプロイが簡単
3. ⚠️ スリープ機能あり（許容できる場合）

### グローバル展開を検討している場合

**推奨: Fly.io**

理由:
1. ✅ グローバルデプロイ
2. ✅ スリープなし
3. ✅ パフォーマンスが良い

---

## 📝 デプロイ前のチェックリスト

### 必須項目

- [ ] `requirements.txt`が正しく設定されている
- [ ] 環境変数（`FISH_AUDIO_API_KEY`）を設定する準備ができている
- [ ] `api_server.py`が正しく動作する（ローカルでテスト済み）
- [ ] ポート番号が環境変数`PORT`から取得できる

### 推奨項目

- [ ] `.gitignore`に`.env`が含まれている
- [ ] `README.md`にデプロイ手順が記載されている
- [ ] ヘルスチェックエンドポイント（`/health`）が実装されている
- [ ] ログ出力が適切に設定されている

---

## 🔗 参考リンク

### Railway

- [公式サイト](https://railway.app)
- [ドキュメント](https://docs.railway.app)
- [Pricing](https://railway.app/pricing)

### Render

- [公式サイト](https://render.com)
- [ドキュメント](https://render.com/docs)
- [Pricing](https://render.com/pricing)

### Fly.io

- [公式サイト](https://fly.io)
- [ドキュメント](https://fly.io/docs)
- [Pricing](https://fly.io/docs/about/pricing)

---

## 🆘 トラブルシューティング

### Railway

**問題**: デプロイが失敗する
- **解決**: ログを確認（`railway logs`）
- **解決**: `requirements.txt`を確認

**問題**: 環境変数が設定されない
- **解決**: Railwayダッシュボードで確認
- **解決**: 再デプロイを実行

### Render

**問題**: スリープからの復帰が遅い
- **解決**: 有料プラン（$7/月）にアップグレード
- **解決**: 定期的にpingを送る（外部サービス使用）

**問題**: デプロイが失敗する
- **解決**: Build Logを確認
- **解決**: Pythonバージョンを指定（`runtime.txt`）

### Fly.io

**問題**: デプロイが失敗する
- **解決**: `fly logs`でログを確認
- **解決**: `fly.toml`の設定を確認

**問題**: SQLiteファイルが消える
- **解決**: Volumeを作成してマウント
- **解決**: 永続ストレージを使用

---

## 📚 関連ドキュメント

- [AWS_COMPARISON.md](./AWS_COMPARISON.md) - AWS実装との比較
- [NOTION_COMPARISON.md](./NOTION_COMPARISON.md) - Notionとの比較
- [README.md](../README.md) - プロジェクトの概要

