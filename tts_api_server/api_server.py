"""
最小構成のTTS APIサーバー
refs.mdを参考に実装
- 多ユーザー対応
- 利用制限機能
- コスト管理
"""

from fastapi import FastAPI, HTTPException, Depends, Header
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from pydantic import BaseModel
from typing import Optional
import os
import secrets
import requests
from pathlib import Path
import tempfile

# データベースモジュールをインポート
from database import (
    init_database, create_user, get_user_by_api_key,
    check_usage_limit, record_usage, get_usage_stats,
    DEFAULT_DAILY_TTS_LIMIT, DEFAULT_DAILY_CLONE_LIMIT, DEFAULT_MONTHLY_COST_LIMIT
)

# .envファイルがあれば読み込む
try:
    from dotenv import load_dotenv
    load_dotenv()
except ImportError:
    pass

app = FastAPI(title="TTS API Minimal", version="1.0.0")

# CORS設定
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # 本番環境では適切に制限
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Pydanticモデル
class TTSRequest(BaseModel):
    text: str
    model_id: Optional[str] = None
    format: str = "mp3"
    speed: float = 1.0
    volume: int = 0

class UserCreateRequest(BaseModel):
    user_id: Optional[str] = None
    daily_tts_limit: Optional[int] = DEFAULT_DAILY_TTS_LIMIT
    daily_clone_limit: Optional[int] = DEFAULT_DAILY_CLONE_LIMIT

class UserCreateResponse(BaseModel):
    user_id: str
    api_key: str
    message: str

class UsageStatsResponse(BaseModel):
    daily_usage: int
    daily_tts: int
    daily_clone: int
    daily_cost: float
    monthly_cost: float
    daily_tts_limit: int
    daily_clone_limit: int
    monthly_cost_limit: float


def get_fish_api_key() -> str:
    """Fish Audio APIキーを環境変数から取得"""
    api_key = os.environ.get("FISH_AUDIO_API_KEY", "")
    if not api_key:
        raise HTTPException(
            status_code=500,
            detail="FISH_AUDIO_API_KEY環境変数が設定されていません"
        )
    return api_key


def get_user_api_key(x_api_key: str = Header(None, alias="X-API-Key")) -> dict:
    """ユーザーAPIキーからユーザー情報を取得"""
    if not x_api_key:
        raise HTTPException(status_code=401, detail="X-API-Keyヘッダーが必要です")
    
    user = get_user_by_api_key(x_api_key)
    if not user:
        raise HTTPException(status_code=401, detail="無効なAPIキーです")
    
    return user


def call_fish_audio_tts(text: str, model_id: Optional[str] = None, 
                        format: str = "mp3", speed: float = 1.0, volume: int = 0) -> bytes:
    """
    Fish Audio APIを呼び出してTTSを生成
    最小構成のため、直接HTTPリクエストで実装
    """
    api_key = get_fish_api_key()
    
    # Fish Audio APIのエンドポイント（実際のエンドポイントに合わせて調整）
    url = "https://api.fish.audio/v1/tts"
    
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json"
    }
    
    payload = {
        "text": text,
        "format": format,
        "prosody": {
            "speed": speed,
            "volume": volume
        },
        "normalize": True,
        "latency": "balanced"
    }
    
    if model_id:
        payload["reference_id"] = model_id
    
    if format == "mp3":
        payload["mp3_bitrate"] = 192
    elif format == "wav":
        payload["sample_rate"] = 44100
    
    try:
        response = requests.post(url, json=payload, headers=headers, timeout=30)
        response.raise_for_status()
        return response.content
    except requests.exceptions.RequestException as e:
        raise HTTPException(
            status_code=500,
            detail=f"Fish Audio API呼び出しエラー: {str(e)}"
        )


# データベース初期化
init_database()


@app.get("/")
async def root():
    """APIルート"""
    return {
        "message": "TTS API Minimal",
        "version": "1.0.0",
        "features": ["multi-user", "usage-limits", "cost-management"]
    }


@app.get("/health")
async def health_check():
    """ヘルスチェック"""
    return {"status": "ok"}


@app.post("/api/v2/users", response_model=UserCreateResponse)
async def create_user_endpoint(request: UserCreateRequest):
    """新しいユーザーを作成"""
    try:
        # ユーザーIDが指定されていない場合は自動生成
        if not request.user_id:
            user_id = f"user_{secrets.token_urlsafe(8)}"
        else:
            user_id = request.user_id
        
        # APIキーを生成
        api_key = f"sk_{secrets.token_urlsafe(32)}"
        
        # ユーザーを作成
        success = create_user(
            user_id=user_id,
            api_key=api_key,
            daily_tts_limit=request.daily_tts_limit or DEFAULT_DAILY_TTS_LIMIT,
            daily_clone_limit=request.daily_clone_limit or DEFAULT_DAILY_CLONE_LIMIT
        )
        
        if not success:
            raise HTTPException(
                status_code=409,
                detail="ユーザーIDまたはAPIキーが既に存在します"
            )
        
        return UserCreateResponse(
            user_id=user_id,
            api_key=api_key,
            message="ユーザーが作成されました"
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/api/v2/tts/generate")
async def generate_tts_audio(
    request: TTSRequest,
    user: dict = Depends(get_user_api_key)
):
    """TTS音声を生成（多ユーザー対応版）"""
    try:
        user_id = user["user_id"]
        daily_tts_limit = user["daily_tts_limit"]
        monthly_cost_limit = float(
            os.environ.get("MONTHLY_COST_LIMIT", DEFAULT_MONTHLY_COST_LIMIT)
        )
        
        # 利用制限チェック
        is_allowed, error_message = check_usage_limit(
            user_id, "tts", daily_tts_limit, monthly_cost_limit
        )
        if not is_allowed:
            raise HTTPException(status_code=429, detail=error_message)
        
        # Fish Audio APIを呼び出してTTS生成
        audio_bytes = call_fish_audio_tts(
            text=request.text,
            model_id=request.model_id,
            format=request.format,
            speed=request.speed,
            volume=request.volume
        )
        
        # 利用履歴を記録（コストは仮で0.1円/回とする）
        estimated_cost = 0.1
        record_usage(user_id, "tts", estimated_cost)
        
        # 一時ファイルに保存して返す
        suffix = f".{request.format}"
        with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as tmp_file:
            tmp_file.write(audio_bytes)
            tmp_path = tmp_file.name
        
        return FileResponse(
            tmp_path,
            media_type=f"audio/{request.format}",
            filename=f"tts_output.{request.format}"
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/api/v2/users/me/stats", response_model=UsageStatsResponse)
async def get_user_stats(user: dict = Depends(get_user_api_key)):
    """ユーザーの利用統計を取得"""
    try:
        user_id = user["user_id"]
        stats = get_usage_stats(user_id)
        
        monthly_cost_limit = float(
            os.environ.get("MONTHLY_COST_LIMIT", DEFAULT_MONTHLY_COST_LIMIT)
        )
        
        return UsageStatsResponse(
            daily_usage=stats["daily_usage"],
            daily_tts=stats["daily_tts"],
            daily_clone=stats["daily_clone"],
            daily_cost=stats["daily_cost"],
            monthly_cost=stats["monthly_cost"],
            daily_tts_limit=user["daily_tts_limit"],
            daily_clone_limit=user["daily_clone_limit"],
            monthly_cost_limit=monthly_cost_limit
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/api/v2/admin/stats", response_model=UsageStatsResponse)
async def get_admin_stats():
    """管理者用の全体統計を取得（認証なし - 本番環境では認証を追加）"""
    try:
        stats = get_usage_stats()
        monthly_cost_limit = float(
            os.environ.get("MONTHLY_COST_LIMIT", DEFAULT_MONTHLY_COST_LIMIT)
        )
        
        return UsageStatsResponse(
            daily_usage=stats["daily_usage"],
            daily_tts=stats["daily_tts"],
            daily_clone=stats["daily_clone"],
            daily_cost=stats["daily_cost"],
            monthly_cost=stats["monthly_cost"],
            daily_tts_limit=0,
            daily_clone_limit=0,
            monthly_cost_limit=monthly_cost_limit
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


if __name__ == "__main__":
    import uvicorn
    port = int(os.environ.get("PORT", 8000))
    uvicorn.run(app, host="0.0.0.0", port=port)

