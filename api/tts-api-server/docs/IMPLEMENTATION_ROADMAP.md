# 実装ロードマップ：最適な実装方針

`refs_architectue.md`とこれまでの会話を統合し、最適な実装方針を提案します。

## 🎯 要件の整理

### 現在の実装状況

- ✅ FastAPI + SQLite（実装済み）
- ✅ TTS機能（実装済み）
- ✅ 多ユーザー対応（独自APIキー方式）
- ✅ 利用制限機能（実装済み）
- ❌ Voice Cloning機能（未実装）
- ❌ モデル管理（未実装）
- ❌ Firebase Authentication（未実装）

### `refs_architectue.md`の要件

- iOSアプリ連携
- Firebase Authentication（Firebase IDトークン）
- Voice Cloning機能
- モデル管理（VoiceModel）
- Firestore/PostgreSQL推奨

### これまでの会話から

- シンプルでコストを抑えたい
- Pythonベース（FastAPI）
- AWS知見がある
- 小規模スタートアップ（~50ユーザー）

---

## 🎯 推奨実装方針

### Phase 1: 現在の実装をベースに拡張（推奨）

**方針**: 現在のFastAPI + SQLite実装をベースに、Voice Cloning機能を追加

#### 理由

1. ✅ **既存コードを活用**: 現在の実装をそのまま使える
2. ✅ **シンプル**: 追加実装が最小限
3. ✅ **コスト**: SQLiteで無料
4. ✅ **開発速度**: すぐに実装可能

#### 実装内容

1. **Voice Cloning機能の追加**
   - `/api/v2/clone` エンドポイント
   - 音声サンプル（base64）を受け取り、Fish Audio APIを呼び出し
   - モデルIDをデータベースに保存

2. **モデル管理機能の追加**
   - `/api/v2/models` エンドポイント（モデル一覧取得）
   - `/api/v2/models/{model_id}` エンドポイント（モデル削除）
   - データベースに`voice_models`テーブルを追加

3. **認証方式の選択**
   - **オプションA**: 現在の独自APIキー方式を継続（推奨）
   - **オプションB**: Firebase Authenticationに移行（将来的に）

#### データベーススキーマ拡張

```sql
-- voice_models テーブルを追加
CREATE TABLE IF NOT EXISTS voice_models (
    model_id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    reference_name TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    metadata TEXT,  -- JSON形式で保存
    FOREIGN KEY (user_id) REFERENCES users(user_id)
);

-- インデックスの作成
CREATE INDEX IF NOT EXISTS idx_voice_models_user 
ON voice_models(user_id);
```

#### 実装時間

- Voice Cloning機能: 1-2日
- モデル管理機能: 0.5-1日
- **合計: 1.5-3日**

---

### Phase 2: 認証方式の選択

#### オプションA: 現在の独自APIキー方式を継続（推奨）

**メリット**:
- ✅ 既に実装済み
- ✅ シンプル
- ✅ 外部依存なし
- ✅ 無料

**デメリット**:
- ⚠️ iOSアプリ側でAPIキー管理が必要
- ⚠️ ユーザー体験がやや劣る（ログイン画面なし）

**実装**: 変更不要（既に実装済み）

#### オプションB: Firebase Authenticationに移行

**メリット**:
- ✅ ユーザー体験が良い（Apple Sign In等）
- ✅ セキュリティが高い
- ✅ 業界標準

**デメリット**:
- ⚠️ 実装が複雑（1-2週間）
- ⚠️ Firebase依存
- ⚠️ コスト（Firebase無料枠内なら無料）

**実装時間**: 1-2週間

**推奨**: Phase 1では独自APIキー方式を継続し、Phase 2でFirebase Authenticationを検討

---

## 🏗️ アーキテクチャ設計

### 推奨アーキテクチャ（Phase 1）

```
iOSアプリ
   │
   ▼
FastAPIサーバー（Railway/Lightsail）
   │
   ├── 認証（X-API-Key）
   ├── 利用制限チェック（SQLite）
   ├── Voice Cloning（Fish Audio API）
   ├── TTS（Fish Audio API）
   └── モデル管理（SQLite）
   ▼
Fish Audio API
```

### データフロー

1. **Voice Cloning**:
   ```
   iOSアプリ → FastAPI (/api/v2/clone) 
   → Fish Audio API (Voice Clone) 
   → モデルIDをDBに保存 
   → iOSアプリにモデルIDを返す
   ```

2. **TTS**:
   ```
   iOSアプリ → FastAPI (/api/v2/tts/generate) 
   → モデル所有チェック 
   → Fish Audio API (TTS with model_id) 
   → 音声ファイルを返す
   ```

---

## 📝 実装詳細

### 1. Voice Cloningエンドポイント

```python
# api_server.py に追加

class CloneRequest(BaseModel):
    audio_base64: str
    reference_name: str

class CloneResponse(BaseModel):
    model_id: str
    message: str

@app.post("/api/v2/clone", response_model=CloneResponse)
async def clone_voice(
    request: CloneRequest,
    user: dict = Depends(get_user_api_key)
):
    """Voice Cloningエンドポイント"""
    try:
        user_id = user["user_id"]
        daily_clone_limit = user["daily_clone_limit"]
        monthly_cost_limit = float(
            os.environ.get("MONTHLY_COST_LIMIT", DEFAULT_MONTHLY_COST_LIMIT)
        )
        
        # 利用制限チェック
        is_allowed, error_message = check_usage_limit(
            user_id, "clone", daily_clone_limit, monthly_cost_limit
        )
        if not is_allowed:
            raise HTTPException(status_code=429, detail=error_message)
        
        # base64デコード
        audio_bytes = base64.b64decode(request.audio_base64)
        
        # Fish Audio APIを呼び出してVoice Cloning
        model_id = call_fish_audio_clone(
            audio_bytes=audio_bytes,
            reference_name=request.reference_name
        )
        
        # モデルをデータベースに保存
        save_voice_model(
            user_id=user_id,
            model_id=model_id,
            reference_name=request.reference_name
        )
        
        # 利用履歴を記録（コストは仮で1.0円/回とする）
        estimated_cost = 1.0
        record_usage(user_id, "clone", estimated_cost)
        
        return CloneResponse(
            model_id=model_id,
            message="Voice Cloningが完了しました"
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

def call_fish_audio_clone(audio_bytes: bytes, reference_name: str) -> str:
    """Fish Audio APIを呼び出してVoice Cloning"""
    api_key = get_fish_api_key()
    
    # Fish Audio APIのエンドポイント（実際のエンドポイントに合わせて調整）
    url = "https://api.fish.audio/v1/voice-clone"  # 実際のエンドポイントを確認
    
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json"
    }
    
    # base64エンコード
    audio_base64 = base64.b64encode(audio_bytes).decode('utf-8')
    
    payload = {
        "reference_audio": audio_base64,
        "reference_name": reference_name
    }
    
    try:
        response = requests.post(url, json=payload, headers=headers, timeout=60)
        response.raise_for_status()
        result = response.json()
        # Fish Audio APIのレスポンス形式に合わせて調整
        model_id = result.get("model_id") or result.get("reference_id")
        return model_id
    except requests.exceptions.RequestException as e:
        raise HTTPException(
            status_code=500,
            detail=f"Fish Audio API呼び出しエラー: {str(e)}"
        )
```

### 2. モデル管理エンドポイント

```python
# api_server.py に追加

class VoiceModelResponse(BaseModel):
    model_id: str
    reference_name: str
    created_at: str

@app.get("/api/v2/models", response_model=List[VoiceModelResponse])
async def get_voice_models(user: dict = Depends(get_user_api_key)):
    """ユーザーのVoice Model一覧を取得"""
    try:
        user_id = user["user_id"]
        models = get_voice_models_by_user(user_id)
        return [
            VoiceModelResponse(
                model_id=model["model_id"],
                reference_name=model["reference_name"],
                created_at=model["created_at"]
            )
            for model in models
        ]
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.delete("/api/v2/models/{model_id}")
async def delete_voice_model(
    model_id: str,
    user: dict = Depends(get_user_api_key)
):
    """Voice Modelを削除"""
    try:
        user_id = user["user_id"]
        
        # モデル所有チェック
        if not check_model_belongs_to_user(user_id, model_id):
            raise HTTPException(
                status_code=403,
                detail="このモデルへのアクセス権限がありません"
            )
        
        # モデルを削除
        delete_voice_model_from_db(user_id, model_id)
        
        return {"success": True, "message": "モデルが削除されました"}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
```

### 3. データベース関数の追加

```python
# database.py に追加

def save_voice_model(user_id: str, model_id: str, reference_name: str):
    """Voice Modelをデータベースに保存"""
    conn = get_db_connection()
    cursor = conn.cursor()
    
    try:
        cursor.execute("""
            INSERT INTO voice_models (model_id, user_id, reference_name)
            VALUES (?, ?, ?)
        """, (model_id, user_id, reference_name))
        conn.commit()
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
    """モデルがユーザーに属しているかチェック"""
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
    finally:
        conn.close()
```

### 4. データベース初期化の更新

```python
# database.py の init_database() に追加

def init_database():
    """データベースを初期化（テーブル作成）"""
    conn = get_db_connection()
    cursor = conn.cursor()
    
    # ... 既存のテーブル作成コード ...
    
    # Voice Modelsテーブル
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS voice_models (
            model_id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL,
            reference_name TEXT NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            metadata TEXT,
            FOREIGN KEY (user_id) REFERENCES users(user_id)
        )
    """)
    
    # インデックスの作成
    cursor.execute("""
        CREATE INDEX IF NOT EXISTS idx_voice_models_user 
        ON voice_models(user_id)
    """)
    
    conn.commit()
    conn.close()
```

---

## 🚀 ホスティング選択

### 推奨: Railway（最優先）

**理由**:
1. ✅ デプロイが最も簡単
2. ✅ 無料クレジット（$5/月）
3. ✅ SQLite対応
4. ✅ スリープなし

**実装時間**: 30分-1時間

### 代替: AWS Lightsail（AWS知見がある場合）

**理由**:
1. ✅ 固定料金（$5/月）
2. ✅ 現在のコードをそのまま使える
3. ✅ AWS知識を活用

**実装時間**: 1-2日

---

## 📊 実装スケジュール

### Week 1: Voice Cloning機能の実装

- [ ] データベーススキーマ拡張（voice_modelsテーブル）
- [ ] Voice Cloningエンドポイント実装（`/api/v2/clone`）
- [ ] モデル管理エンドポイント実装（`/api/v2/models`）
- [ ] Fish Audio API統合（Voice Cloning）
- [ ] テスト（単体・統合）

### Week 2: デプロイとiOSアプリ連携

- [ ] Railway/Lightsailにデプロイ
- [ ] 環境変数設定
- [ ] iOSアプリ側実装（Voice Cloning）
- [ ] iOSアプリ側実装（TTS with model_id）
- [ ] エンドツーエンドテスト

### Week 3: 改善と最適化（オプション）

- [ ] エラーハンドリング強化
- [ ] ログ機能追加
- [ ] パフォーマンス最適化
- [ ] セキュリティ改善

---

## 🔄 将来の拡張（Phase 2以降）

### Firebase Authenticationへの移行

**タイミング**: ユーザー数が50人を超えた、またはユーザー体験を向上させたい場合

**実装内容**:
1. Firebase Admin SDKの統合
2. Firebase IDトークン検証機能
3. 既存ユーザーの移行（オプション）
4. iOSアプリ側のFirebase Authentication実装

**実装時間**: 1-2週間

### データベースの移行（オプション）

**タイミング**: ユーザー数が100人を超えた、またはスケーラビリティが必要になった場合

**選択肢**:
- **Firestore**: Firebase Authenticationと統合しやすい
- **PostgreSQL**: より柔軟なクエリが必要な場合
- **DynamoDB**: AWS環境の場合

---

## 💰 コスト見積もり

### Phase 1（小規模運用、~50ユーザー）

| 項目 | コスト |
|------|--------|
| ホスティング（Railway） | $0（無料クレジット内） |
| データベース（SQLite） | $0 |
| Fish Audio API | 従量課金（使用量による） |
| **合計** | **$0 + Fish Audio API使用量** |

### Phase 2（中規模運用、~500ユーザー）

| 項目 | コスト |
|------|--------|
| ホスティング（Railway） | $5-10/月 |
| データベース（SQLite/Firestore） | $0-5/月 |
| Fish Audio API | 従量課金 |
| **合計** | **$5-15/月 + Fish Audio API使用量** |

---

## 🎯 最終推奨

### 実装方針

1. **Phase 1（推奨）**: 現在の実装をベースにVoice Cloning機能を追加
   - 実装時間: 1.5-3日
   - コスト: $0（無料枠内）
   - ホスティング: Railway

2. **認証方式**: 現在の独自APIキー方式を継続（Phase 2でFirebase Authenticationを検討）

3. **データベース**: SQLiteを継続（小規模なら十分）

4. **ホスティング**: Railway（シンプル）またはAWS Lightsail（AWS知見活用）

### 実装の優先順位

1. ✅ **最優先**: Voice Cloning機能（`/api/v2/clone`）
2. ✅ **高**: モデル管理機能（`/api/v2/models`）
3. ⚠️ **中**: エラーハンドリング強化
4. 🔄 **低**: Firebase Authentication（将来）

---

## 📚 参考リソース

### Fish Audio API

- [Fish Audio Developers](https://fish.audio/ja/developers/)
- [Voice Cloning API](https://fish.audio/ja/voice-clone/)
- [TTS API Documentation](https://fish.audio/ja/developers/)

### 実装ガイド

- [HOSTING_COMPARISON.md](./HOSTING_COMPARISON.md) - ホスティングサービス比較
- [AWS_HOSTING_GUIDE.md](./AWS_HOSTING_GUIDE.md) - AWS実装ガイド
- [IMPROVEMENT_EXAMPLES.md](./IMPROVEMENT_EXAMPLES.md) - セキュリティ改善例

---

## 🔗 関連ドキュメント

- [refs_architectue.md](../refs_architectue.md) - アーキテクチャ設計書
- [refs.md](../refs.md) - 初期設計参考資料
- [README.md](../README.md) - プロジェクト概要

