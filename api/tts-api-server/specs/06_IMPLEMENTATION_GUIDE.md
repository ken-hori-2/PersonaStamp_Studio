# 実装手順

## 📋 実装の優先順位

### Phase 1: 基本機能（最優先）

1. ✅ Firebase Authenticationの実装
2. ✅ Voice Cloning機能の追加
3. ✅ モデル管理機能の追加
4. ✅ TTS機能の拡張（model_id対応）

### Phase 2: 改善機能

1. ⚠️ エラーハンドリング強化
2. ⚠️ ログ機能追加
3. ⚠️ セキュリティ改善

### Phase 3: 最適化

1. 🔄 パフォーマンス最適化
2. 🔄 監視機能追加
3. 🔄 ダッシュボード実装

---

## 🛠️ 開発環境セットアップ

### 1. 必要なツール

- Python 3.11以上
- pip（Pythonパッケージマネージャー）
- Git
- テキストエディタ（VS Code推奨）

### 2. プロジェクトのクローン

```bash
git clone <repository-url>
cd tts-api-server
```

### 3. 仮想環境の作成

```bash
cd tts_api_server
python3 -m venv venv
source venv/bin/activate  # macOS/Linux
# または
venv\Scripts\activate  # Windows
```

### 4. 依存関係のインストール

```bash
pip install -r requirements.txt
```

### 5. 環境変数の設定

`.env`ファイルを作成：

```bash
# .env
FISH_AUDIO_API_KEY=your_fish_audio_api_key_here
FIREBASE_PROJECT_ID=your-firebase-project-id
FIREBASE_PRIVATE_KEY_ID=your-private-key-id
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"
FIREBASE_CLIENT_EMAIL=your-client-email@your-project.iam.gserviceaccount.com
FIREBASE_CLIENT_ID=your-client-id
MONTHLY_COST_LIMIT=5000.0
PORT=8000
```

---

## 📝 実装ステップ

### Step 1: Firebase Authenticationの実装

#### 1.1 Firebase Admin SDKの追加

```bash
pip install firebase-admin
```

`requirements.txt`に追加：

```txt
firebase-admin>=6.0.0
```

#### 1.2 認証関数の実装

`api_server.py`に以下を追加：

```python
import firebase_admin
from firebase_admin import credentials, auth
import os

# Firebase Admin SDKの初期化
if not firebase_admin._apps:
    cred = credentials.Certificate({
        "type": "service_account",
        "project_id": os.environ.get("FIREBASE_PROJECT_ID"),
        "private_key_id": os.environ.get("FIREBASE_PRIVATE_KEY_ID"),
        "private_key": os.environ.get("FIREBASE_PRIVATE_KEY").replace('\\n', '\n'),
        "client_email": os.environ.get("FIREBASE_CLIENT_EMAIL"),
        "client_id": os.environ.get("FIREBASE_CLIENT_ID"),
        "auth_uri": "https://accounts.google.com/o/oauth2/auth",
        "token_uri": "https://oauth2.googleapis.com/token",
    })
    firebase_admin.initialize_app(cred)

def verify_firebase_token(authorization: str = Header(None, alias="Authorization")) -> dict:
    """Firebase IDトークンを検証"""
    # 実装は05_AUTHENTICATION.mdを参照
    pass
```

#### 1.3 データベース関数の追加

`database.py`に以下を追加：

```python
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

def create_user(user_id: str, email: str = None) -> bool:
    """新しいユーザーを作成（Firebase UID使用）"""
    conn = get_db_connection()
    cursor = conn.cursor()
    
    try:
        cursor.execute("""
            INSERT INTO users (user_id, email, daily_tts_limit, daily_clone_limit)
            VALUES (?, ?, ?, ?)
        """, (user_id, email, DEFAULT_DAILY_TTS_LIMIT, DEFAULT_DAILY_CLONE_LIMIT))
        conn.commit()
        return True
    except sqlite3.IntegrityError:
        return False
    finally:
        conn.close()
```

---

### Step 2: Voice Cloning機能の追加

#### 2.1 データベーススキーマの拡張

`database.py`の`init_database()`関数に以下を追加：

```python
def init_database():
    # ... 既存のコード ...
    
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
    
    cursor.execute("""
        CREATE INDEX IF NOT EXISTS idx_voice_models_user 
        ON voice_models(user_id)
    """)
```

#### 2.2 Voice Cloningエンドポイントの実装

`api_server.py`に以下を追加：

```python
import base64

class CloneRequest(BaseModel):
    audio_base64: str
    reference_name: str

class CloneResponse(BaseModel):
    model_id: str
    reference_name: str
    message: str

@app.post("/api/v2/clone", response_model=CloneResponse)
async def clone_voice(
    request: CloneRequest,
    user: dict = Depends(verify_firebase_token)
):
    """Voice Cloningエンドポイント"""
    # 実装は03_API_SPECIFICATION.mdを参照
    pass

def call_fish_audio_clone(audio_bytes: bytes, reference_name: str) -> str:
    """Fish Audio APIを呼び出してVoice Cloning"""
    # 実装は03_API_SPECIFICATION.mdを参照
    pass
```

#### 2.3 データベース関数の追加

`database.py`に以下を追加：

```python
def save_voice_model(user_id: str, model_id: str, reference_name: str):
    """Voice Modelをデータベースに保存"""
    # 実装は04_DATABASE_DESIGN.mdを参照
    pass

def get_voice_models_by_user(user_id: str) -> List[Dict]:
    """ユーザーのVoice Model一覧を取得"""
    # 実装は04_DATABASE_DESIGN.mdを参照
    pass

def check_model_belongs_to_user(user_id: str, model_id: str) -> bool:
    """モデル所有権をチェック"""
    # 実装は04_DATABASE_DESIGN.mdを参照
    pass
```

---

### Step 3: モデル管理機能の追加

#### 3.1 モデル一覧取得エンドポイント

`api_server.py`に以下を追加：

```python
class VoiceModelResponse(BaseModel):
    model_id: str
    reference_name: str
    created_at: str

@app.get("/api/v2/models", response_model=List[VoiceModelResponse])
async def get_voice_models(user: dict = Depends(verify_firebase_token)):
    """ユーザーのVoice Model一覧を取得"""
    # 実装は03_API_SPECIFICATION.mdを参照
    pass
```

#### 3.2 モデル削除エンドポイント

`api_server.py`に以下を追加：

```python
@app.delete("/api/v2/models/{model_id}")
async def delete_voice_model(
    model_id: str,
    user: dict = Depends(verify_firebase_token)
):
    """Voice Modelを削除"""
    # 実装は03_API_SPECIFICATION.mdを参照
    pass
```

---

### Step 4: TTS機能の拡張

#### 4.1 TTSエンドポイントの更新

既存の`/api/v2/tts/generate`エンドポイントを更新：

```python
@app.post("/api/v2/tts/generate")
async def generate_tts_audio(
    request: TTSRequest,
    user: dict = Depends(verify_firebase_token)  # Firebase認証を使用
):
    """TTS音声を生成（Firebase認証版）"""
    user_id = user["user_id"]
    
    # モデル所有権チェック（model_idが指定されている場合）
    if request.model_id:
        if not check_model_belongs_to_user(user_id, request.model_id):
            raise HTTPException(
                status_code=403,
                detail="このモデルへのアクセス権限がありません"
            )
    
    # ... 既存の実装 ...
```

---

## ✅ 実装チェックリスト

### Firebase Authentication

- [ ] Firebase Admin SDKがインストールされている
- [ ] Firebase Admin SDKが初期化されている
- [ ] トークン検証関数が実装されている
- [ ] ユーザー作成関数が実装されている
- [ ] エンドポイントでFirebase認証が使用されている

### Voice Cloning

- [ ] データベーススキーマが拡張されている
- [ ] Voice Cloningエンドポイントが実装されている
- [ ] Fish Audio API統合が実装されている
- [ ] モデル保存関数が実装されている
- [ ] 利用制限チェックが実装されている

### モデル管理

- [ ] モデル一覧取得エンドポイントが実装されている
- [ ] モデル削除エンドポイントが実装されている
- [ ] モデル所有権チェックが実装されている

### TTS機能

- [ ] TTSエンドポイントがFirebase認証に対応している
- [ ] モデルID対応が実装されている
- [ ] モデル所有権チェックが実装されている

### テスト

- [ ] 単体テストが実装されている
- [ ] 統合テストが実装されている
- [ ] エンドツーエンドテストが実装されている

---

## 🧪 ローカルテスト

### 1. サーバーの起動

```bash
cd tts_api_server
python api_server.py
```

サーバーは `http://localhost:8000` で起動します。

### 2. ヘルスチェック

```bash
curl http://localhost:8000/health
```

### 3. APIテスト

Firebase IDトークンを取得して、APIをテスト：

```bash
# Voice Cloning
curl -X POST "http://localhost:8000/api/v2/clone" \
  -H "Authorization: Bearer <Firebase ID Token>" \
  -H "Content-Type: application/json" \
  -d '{
    "audio_base64": "base64_encoded_audio",
    "reference_name": "test_voice"
  }'
```

---

## 🔗 関連ドキュメント

- [API仕様](./03_API_SPECIFICATION.md)
- [データベース設計](./04_DATABASE_DESIGN.md)
- [認証方式](./05_AUTHENTICATION.md)
- [デプロイ手順](./07_DEPLOYMENT_GUIDE.md)

