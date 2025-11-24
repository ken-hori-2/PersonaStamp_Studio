# テスト仕様

## 🧪 テスト戦略

### テストレベル

1. **単体テスト**: 個別の関数・メソッドのテスト
2. **統合テスト**: APIエンドポイントのテスト
3. **エンドツーエンドテスト**: 実際のユーザーフローをテスト

---

## 📋 テストケース

### 認証テスト

#### TC-AUTH-001: Firebase認証成功

**前提条件**:
- 有効なFirebase IDトークンがある

**テスト手順**:
1. 有効なFirebase IDトークンでAPIリクエストを送信

**期待結果**:
- ステータスコード: 200 OK
- ユーザー情報が正しく取得される

#### TC-AUTH-002: Firebase認証失敗（無効なトークン）

**前提条件**:
- 無効なFirebase IDトークンがある

**テスト手順**:
1. 無効なFirebase IDトークンでAPIリクエストを送信

**期待結果**:
- ステータスコード: 401 Unauthorized
- エラーメッセージ: "無効なトークンです"

#### TC-AUTH-003: Firebase認証失敗（トークンなし）

**前提条件**:
- トークンなし

**テスト手順**:
1. AuthorizationヘッダーなしでAPIリクエストを送信

**期待結果**:
- ステータスコード: 401 Unauthorized
- エラーメッセージ: "Authorizationヘッダーが必要です"

---

### Voice Cloningテスト

#### TC-CLONE-001: Voice Cloning成功

**前提条件**:
- 有効なFirebase IDトークンがある
- 有効な音声サンプル（base64）がある
- 利用制限内である

**テスト手順**:
1. `/api/v2/clone`にリクエストを送信
2. 音声サンプルとreference_nameを送信

**期待結果**:
- ステータスコード: 200 OK
- モデルIDが返される
- データベースにモデルが保存される
- 利用履歴が記録される

#### TC-CLONE-002: Voice Cloning失敗（利用制限）

**前提条件**:
- 有効なFirebase IDトークンがある
- 日次Voice Cloning制限に達している

**テスト手順**:
1. `/api/v2/clone`にリクエストを送信

**期待結果**:
- ステータスコード: 429 Too Many Requests
- エラーメッセージ: "日次利用制限に達しました（2回/日）"

#### TC-CLONE-003: Voice Cloning失敗（無効な音声データ）

**前提条件**:
- 有効なFirebase IDトークンがある
- 無効な音声データ（base64）がある

**テスト手順**:
1. `/api/v2/clone`に無効な音声データでリクエストを送信

**期待結果**:
- ステータスコード: 400 Bad Request または 500 Internal Server Error
- エラーメッセージが返される

---

### TTS生成テスト

#### TC-TTS-001: TTS生成成功（モデルID指定）

**前提条件**:
- 有効なFirebase IDトークンがある
- ユーザーが所有するモデルIDがある
- 利用制限内である

**テスト手順**:
1. `/api/v2/tts/generate`にリクエストを送信
2. テキストとモデルIDを送信

**期待結果**:
- ステータスコード: 200 OK
- 音声ファイル（mp3）が返される
- 利用履歴が記録される

#### TC-TTS-002: TTS生成成功（モデルIDなし）

**前提条件**:
- 有効なFirebase IDトークンがある
- 利用制限内である

**テスト手順**:
1. `/api/v2/tts/generate`にリクエストを送信
2. テキストのみを送信（モデルIDなし）

**期待結果**:
- ステータスコード: 200 OK
- デフォルト音声で音声ファイルが返される

#### TC-TTS-003: TTS生成失敗（モデル所有権エラー）

**前提条件**:
- 有効なFirebase IDトークンがある
- 他のユーザーが所有するモデルIDがある

**テスト手順**:
1. `/api/v2/tts/generate`にリクエストを送信
2. 他のユーザーのモデルIDを送信

**期待結果**:
- ステータスコード: 403 Forbidden
- エラーメッセージ: "このモデルへのアクセス権限がありません"

#### TC-TTS-004: TTS生成失敗（利用制限）

**前提条件**:
- 有効なFirebase IDトークンがある
- 日次TTS制限に達している

**テスト手順**:
1. `/api/v2/tts/generate`にリクエストを送信

**期待結果**:
- ステータスコード: 429 Too Many Requests
- エラーメッセージ: "日次利用制限に達しました（20回/日）"

---

### モデル管理テスト

#### TC-MODEL-001: モデル一覧取得成功

**前提条件**:
- 有効なFirebase IDトークンがある
- ユーザーが複数のモデルを持っている

**テスト手順**:
1. `/api/v2/models`にリクエストを送信

**期待結果**:
- ステータスコード: 200 OK
- ユーザーのモデル一覧が返される
- 作成日時の降順でソートされている

#### TC-MODEL-002: モデル削除成功

**前提条件**:
- 有効なFirebase IDトークンがある
- ユーザーが所有するモデルIDがある

**テスト手順**:
1. `/api/v2/models/{model_id}`にDELETEリクエストを送信

**期待結果**:
- ステータスコード: 200 OK
- モデルがデータベースから削除される

#### TC-MODEL-003: モデル削除失敗（所有権エラー）

**前提条件**:
- 有効なFirebase IDトークンがある
- 他のユーザーが所有するモデルIDがある

**テスト手順**:
1. `/api/v2/models/{model_id}`にDELETEリクエストを送信
2. 他のユーザーのモデルIDを指定

**期待結果**:
- ステータスコード: 403 Forbidden
- エラーメッセージ: "このモデルへのアクセス権限がありません"

---

## 🧪 テスト実装

### 単体テスト

```python
# test_auth.py
import pytest
from api_server import verify_firebase_token
from fastapi import HTTPException

def test_verify_firebase_token_valid():
    """有効なトークンの検証テスト"""
    # モックトークンを使用
    token = "valid_firebase_id_token"
    result = verify_firebase_token(f"Bearer {token}")
    assert result["user_id"] is not None

def test_verify_firebase_token_invalid():
    """無効なトークンの検証テスト"""
    with pytest.raises(HTTPException) as exc_info:
        verify_firebase_token("Bearer invalid_token")
    assert exc_info.value.status_code == 401
```

### 統合テスト

```python
# test_api.py
import pytest
from fastapi.testclient import TestClient
from api_server import app

client = TestClient(app)

def test_health_check():
    """ヘルスチェックテスト"""
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}

def test_clone_voice_without_auth():
    """認証なしのVoice Cloningテスト"""
    response = client.post("/api/v2/clone", json={
        "audio_base64": "test",
        "reference_name": "test"
    })
    assert response.status_code == 401
```

### エンドツーエンドテスト

```python
# test_e2e.py
import pytest
import requests

BASE_URL = "https://your-api.com"

def test_e2e_voice_cloning_and_tts():
    """Voice CloningからTTS生成までのエンドツーエンドテスト"""
    # 1. Firebase IDトークンを取得（実際のFirebase認証を使用）
    token = get_firebase_id_token()
    
    # 2. Voice Cloning
    response = requests.post(
        f"{BASE_URL}/api/v2/clone",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "audio_base64": "base64_encoded_audio",
            "reference_name": "test_voice"
        }
    )
    assert response.status_code == 200
    model_id = response.json()["model_id"]
    
    # 3. TTS生成
    response = requests.post(
        f"{BASE_URL}/api/v2/tts/generate",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "text": "テスト",
            "model_id": model_id
        }
    )
    assert response.status_code == 200
    assert response.headers["Content-Type"] == "audio/mp3"
```

---

## 📊 テストカバレッジ

### 目標カバレッジ

- **単体テスト**: 80%以上
- **統合テスト**: 主要なエンドポイントをカバー
- **エンドツーエンドテスト**: 主要なユーザーフローをカバー

---

## 🔍 テスト実行

### ローカル環境

```bash
# すべてのテストを実行
pytest

# 特定のテストファイルを実行
pytest test_auth.py

# カバレッジレポートを生成
pytest --cov=tts_api_server --cov-report=html
```

### CI/CD

GitHub Actions等で自動テストを実行：

```yaml
# .github/workflows/test.yml
name: Test

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: actions/setup-python@v2
        with:
          python-version: '3.11'
      - run: pip install -r requirements.txt
      - run: pip install pytest pytest-cov
      - run: pytest --cov=tts_api_server
```

---

## 🔗 関連ドキュメント

- [API仕様](./03_API_SPECIFICATION.md)
- [実装手順](./06_IMPLEMENTATION_GUIDE.md)
- [デプロイ手順](./07_DEPLOYMENT_GUIDE.md)

