# バックエンドAPIサーバーの起動ガイド

## 🔴 エラー内容

```
Connection refused
Could not connect to the server.
http://localhost:8000/api/v2/...
```

iOSアプリがバックエンドAPIサーバーに接続できていません。バックエンドサーバーが起動していないことが原因です。

## ✅ 解決方法

### ステップ1: バックエンドサーバーを起動

1. **ターミナルを開く**

2. **バックエンドディレクトリに移動**
   ```bash
   cd /Users/ken/workdir/startup/portfolio_ws/PersonaStamp_Studio/api/tts-api-server/src/personastamp_api
   ```

3. **仮想環境をアクティベート**
   ```bash
   source venv/bin/activate
   ```
   （Windowsの場合: `venv\Scripts\activate`）

4. **環境変数を確認**
   `.env`ファイルが存在し、必要な環境変数が設定されているか確認：
   ```bash
   cat .env
   ```
   
   必要な環境変数：
   - `FISH_AUDIO_API_KEY`
   - `FIREBASE_PROJECT_ID`
   - `FIREBASE_PRIVATE_KEY_ID`
   - `FIREBASE_PRIVATE_KEY`
   - `FIREBASE_CLIENT_EMAIL`
   - `FIREBASE_CLIENT_ID`

5. **サーバーを起動**
   ```bash
   python api_server.py
   ```
   
   または：
   ```bash
   uvicorn api_server:app --host 0.0.0.0 --port 8000 --reload
   ```

6. **サーバーが起動したことを確認**
   ターミナルに以下のようなメッセージが表示されます：
   ```
   INFO:     Started server process [xxxxx]
   INFO:     Waiting for application startup.
   INFO:     Application startup complete.
   INFO:     Uvicorn running on http://0.0.0.0:8000 (Press CTRL+C to quit)
   ```

7. **サーバーが動作しているか確認**
   ブラウザで `http://localhost:8000/docs` にアクセス
   - FastAPIの自動生成ドキュメントが表示されればOK

### ステップ2: iOSアプリで接続を確認

1. **Xcodeでアプリを実行**
   - シミュレーターまたは実機で実行

2. **接続を確認**
   - エラーが解消され、APIリクエストが成功することを確認

## 🔍 シミュレーター vs 実機

### シミュレーターでテストする場合

- ✅ `localhost:8000` で接続可能
- ✅ Mac上でバックエンドサーバーを起動すればOK

### 実機でテストする場合

- ❌ `localhost:8000` では接続できない（実機の`localhost`を指すため）
- ✅ MacのIPアドレスを使用する必要がある

#### 実機での設定方法

1. **MacのIPアドレスを確認**
   ```bash
   ifconfig | grep "inet " | grep -v 127.0.0.1
   ```
   または：
   ```bash
   ipconfig getifaddr en0
   ```
   
   例: `192.168.1.100`

2. **APIClient.swiftを修正**
   ```swift
   #if DEBUG
   // シミュレーター用
   // let baseURL = "http://localhost:8000"
   
   // 実機用（MacのIPアドレスに変更）
   let baseURL = "http://192.168.1.100:8000"
   #else
   let baseURL = "https://your-api-domain.com"
   #endif
   ```

3. **バックエンドサーバーを起動**
   ```bash
   uvicorn api_server:app --host 0.0.0.0 --port 8000 --reload
   ```
   （`--host 0.0.0.0`を指定することで、外部からの接続を許可）

4. **ファイアウォールの設定**
   - システム環境設定 → セキュリティとプライバシー → ファイアウォール
   - 必要に応じて、Pythonまたはuvicornの接続を許可

## 🚨 トラブルシューティング

### ポート8000が既に使用されている場合

```bash
lsof -i :8000
```

別のポートを使用する場合：

1. **環境変数を設定**
   ```bash
   export PORT=8001
   ```

2. **サーバーを起動**
   ```bash
   python api_server.py
   ```

3. **APIClient.swiftを修正**
   ```swift
   let baseURL = "http://localhost:8001"
   ```

### 仮想環境がアクティベートされていない場合

```bash
# 仮想環境を作成（まだの場合）
python3.11 -m venv venv

# アクティベート
source venv/bin/activate

# 依存関係をインストール
pip install -r requirements.txt
```

### 環境変数が設定されていない場合

`.env`ファイルを作成：

```bash
cd /Users/ken/workdir/startup/portfolio_ws/PersonaStamp_Studio/api/tts-api-server/src/personastamp_api
nano .env
```

以下の内容を追加：

```env
FISH_AUDIO_API_KEY=your_fish_audio_api_key_here
FIREBASE_PROJECT_ID=personastamp-studio
FIREBASE_PRIVATE_KEY_ID=your-private-key-id
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"
FIREBASE_CLIENT_EMAIL=your-client-email@personastamp-studio.iam.gserviceaccount.com
FIREBASE_CLIENT_ID=your-client-id
PORT=8000
```

### CORSエラーが発生する場合

`api_server.py`のCORS設定を確認：

```python
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # 本番環境では適切に制限
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
```

## 📝 まとめ

1. ✅ バックエンドサーバーを起動
2. ✅ シミュレーター: `localhost:8000` で接続
3. ✅ 実機: MacのIPアドレスを使用（例: `192.168.1.100:8000`）
4. ✅ サーバーは `--host 0.0.0.0` で起動

これで、iOSアプリからバックエンドAPIサーバーに接続できるようになります。


