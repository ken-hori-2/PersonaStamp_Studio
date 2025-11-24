"""
TTS + Voice Cloning API Server
仕様書に基づいた実装
- Firebase Authentication
- Voice Cloning機能
- TTS機能
- モデル管理機能
"""

from fastapi import FastAPI, HTTPException, Depends
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from pydantic import BaseModel
from typing import Optional, List, Tuple
import os
import base64
from pathlib import Path
from uuid import uuid4
from datetime import datetime

# データベースモジュールをインポート
from database import (
    init_database,
    create_user,
    get_user_by_id,
    check_usage_limit,
    record_usage,
    get_usage_stats,
    save_voice_model,
    get_voice_models_by_user,
    check_model_belongs_to_user,
    delete_voice_model_from_db,
    get_voice_model_by_id,
    save_tts_history_entry,
    get_recent_tts_history,
    get_tts_history_entry,
    cleanup_old_tts_history,
    DEFAULT_DAILY_TTS_LIMIT,
    DEFAULT_DAILY_CLONE_LIMIT,
    DEFAULT_MONTHLY_COST_LIMIT
)

# 認証モジュールをインポート
from auth import verify_firebase_token, get_current_user

# Fish Audio APIクライアントをインポート
from fish_audio_client import call_fish_audio_tts, call_fish_audio_clone

# .envファイルがあれば読み込む
try:
    from dotenv import load_dotenv
    load_dotenv()
except ImportError:
    pass

app = FastAPI(
    title="TTS + Voice Cloning API",
    version="2.0.0",
    description="Firebase Authentication対応のTTS + Voice Cloning APIサーバー"
)

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


class CloneRequest(BaseModel):
    audio_base64: str
    reference_name: str


class CloneResponse(BaseModel):
    model_id: str
    reference_name: str
    message: str


class VoiceModelResponse(BaseModel):
    model_id: str
    reference_name: str
    created_at: str


class UsageStatsResponse(BaseModel):
    daily_usage: int
    daily_tts: int
    daily_clone: int
    daily_cost: float
    monthly_cost: float
    daily_tts_limit: int
    daily_clone_limit: int
    monthly_cost_limit: float


class TTSHistoryResponse(BaseModel):
    id: int
    text: str
    model_id: Optional[str]
    format: str
    file_name: str
    size_bytes: Optional[int]
    created_at: str


# データベース初期化
init_database()

# 生成音声の保存先
AUDIO_STORAGE_DIR = Path(__file__).parent / "generated_audio"
AUDIO_STORAGE_DIR.mkdir(parents=True, exist_ok=True)
MAX_TTS_HISTORY_ITEMS = int(os.environ.get("TTS_HISTORY_LIMIT", "10"))


def _persist_tts_result(
    user_id: str,
    request: TTSRequest,
    audio_bytes: bytes
) -> Tuple[Path, str, int]:
    """
    音声ファイルを保存し、履歴に記録する
    Returns: (file_path, media_type, history_id)
    """
    user_dir = AUDIO_STORAGE_DIR / user_id
    user_dir.mkdir(parents=True, exist_ok=True)

    timestamp = datetime.utcnow().strftime("%Y%m%d-%H%M%S")
    file_name = f"{timestamp}_{uuid4().hex[:8]}.{request.format}"
    file_path = user_dir / file_name
    file_path.write_bytes(audio_bytes)

    media_type = {
        "mp3": "audio/mpeg",
        "wav": "audio/wav",
        "opus": "audio/ogg",
        "pcm": "audio/wav"
    }.get(request.format.lower(), f"audio/{request.format}")

    history_id = save_tts_history_entry(
        user_id=user_id,
        model_id=request.model_id,
        text=request.text[:1000],
        audio_format=request.format,
        file_name=file_name,
        file_path=str(file_path),
        size_bytes=len(audio_bytes)
    )

    old_paths = cleanup_old_tts_history(user_id, keep=MAX_TTS_HISTORY_ITEMS)
    for old_path in old_paths:
        try:
            Path(old_path).unlink(missing_ok=True)
        except OSError:
            pass

    return file_path, media_type, history_id


@app.get("/")
async def root():
    """APIルート"""
    return {
        "message": "TTS + Voice Cloning API",
        "version": "2.0.0",
        "features": [
            "firebase-authentication",
            "voice-cloning",
            "tts",
            "model-management",
            "usage-limits",
            "cost-management"
        ]
    }


@app.get("/health")
async def health_check():
    """ヘルスチェック"""
    return {"status": "ok"}


@app.post("/api/v2/clone", response_model=CloneResponse)
async def clone_voice(
    request: CloneRequest,
    user: dict = Depends(get_current_user)
):
    """
    Voice Cloningを実行
    
    仕様書: specs/03_API_SPECIFICATION.md
    """
    try:
        user_id = user["user_id"]
        
        # ユーザー情報を取得
        user_info = get_user_by_id(user_id)
        if not user_info:
            raise HTTPException(status_code=404, detail="ユーザーが見つかりません")
        
        daily_clone_limit = user_info["daily_clone_limit"]
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
        try:
            audio_bytes = base64.b64decode(request.audio_base64)
        except Exception as e:
            raise HTTPException(
                status_code=400,
                detail=f"音声データのデコードに失敗しました: {str(e)}"
            )
        
        # Fish Audio APIを呼び出してVoice Cloning
        model_id = call_fish_audio_clone(
            audio_bytes=audio_bytes,
            reference_name=request.reference_name
        )
        
        # モデルをデータベースに保存
        try:
            save_voice_model(
                user_id=user_id,
                model_id=model_id,
                reference_name=request.reference_name
            )
        except ValueError as e:
            # モデルIDが既に存在する場合
            raise HTTPException(status_code=409, detail=str(e))
        
        # 利用履歴を記録（コストは仮で1.0円/回とする）
        estimated_cost = 1.0
        record_usage(user_id, "clone", estimated_cost)
        
        return CloneResponse(
            model_id=model_id,
            reference_name=request.reference_name,
            message="Voice Cloningが完了しました"
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"内部サーバーエラー: {str(e)}")


@app.post("/api/v2/tts/generate")
async def generate_tts_audio(
    request: TTSRequest,
    user: dict = Depends(get_current_user)
):
    """
    TTS音声を生成（Firebase認証版）
    
    仕様書: specs/03_API_SPECIFICATION.md
    """
    try:
        user_id = user["user_id"]
        
        # ユーザー情報を取得
        user_info = get_user_by_id(user_id)
        if not user_info:
            raise HTTPException(status_code=404, detail="ユーザーが見つかりません")
        
        daily_tts_limit = user_info["daily_tts_limit"]
        monthly_cost_limit = float(
            os.environ.get("MONTHLY_COST_LIMIT", DEFAULT_MONTHLY_COST_LIMIT)
        )
        
        # モデル所有権チェック（model_idが指定されている場合）
        if request.model_id:
            if not check_model_belongs_to_user(user_id, request.model_id):
                raise HTTPException(
                    status_code=403,
                    detail="このモデルへのアクセス権限がありません"
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
        
        # 履歴保存とファイル出力
        file_path, media_type, history_id = _persist_tts_result(
            user_id=user_id,
            request=request,
            audio_bytes=audio_bytes
        )
        
        # 利用履歴を記録（コストは仮で0.1円/回とする）
        estimated_cost = 0.1
        record_usage(user_id, "tts", estimated_cost)
        
        response = FileResponse(
            str(file_path),
            media_type=media_type,
            filename=file_path.name
        )
        response.headers["X-TTS-History-Id"] = str(history_id)
        return response
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"内部サーバーエラー: {str(e)}")


@app.get("/api/v2/tts/history", response_model=List[TTSHistoryResponse])
async def get_tts_history_endpoint(
    user: dict = Depends(get_current_user)
):
    """TTS履歴（最新10件）を取得"""
    try:
        history = get_recent_tts_history(
            user_id=user["user_id"],
            limit=MAX_TTS_HISTORY_ITEMS
        )
        return history
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"内部サーバーエラー: {str(e)}")


@app.get("/api/v2/tts/history/{history_id}/download")
async def download_tts_history(
    history_id: int,
    user: dict = Depends(get_current_user)
):
    """特定のTTS履歴ファイルをダウンロード"""
    entry = get_tts_history_entry(user["user_id"], history_id)
    if not entry:
        raise HTTPException(status_code=404, detail="履歴が見つかりません")

    file_path = Path(entry["file_path"])
    if not file_path.exists():
        raise HTTPException(status_code=404, detail="音声ファイルが見つかりません")

    media_type = {
        "mp3": "audio/mpeg",
        "wav": "audio/wav",
        "opus": "audio/ogg",
        "pcm": "audio/wav"
    }.get(entry["format"].lower(), f"audio/{entry['format']}")

    return FileResponse(
        str(file_path),
        media_type=media_type,
        filename=entry["file_name"]
    )


@app.get("/api/v2/models", response_model=List[VoiceModelResponse])
async def get_voice_models(user: dict = Depends(get_current_user)):
    """
    ユーザーのVoice Model一覧を取得
    
    仕様書: specs/03_API_SPECIFICATION.md
    """
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
        raise HTTPException(status_code=500, detail=f"内部サーバーエラー: {str(e)}")


@app.delete("/api/v2/models/{model_id}")
async def delete_voice_model(
    model_id: str,
    user: dict = Depends(get_current_user)
):
    """
    Voice Modelを削除
    
    仕様書: specs/03_API_SPECIFICATION.md
    """
    try:
        user_id = user["user_id"]
        
        # モデル所有権チェック
        if not check_model_belongs_to_user(user_id, model_id):
            raise HTTPException(
                status_code=403,
                detail="このモデルへのアクセス権限がありません"
            )
        
        # モデルを削除
        try:
            delete_voice_model_from_db(user_id, model_id)
        except ValueError as e:
            raise HTTPException(status_code=404, detail=str(e))
        
        return {"success": True, "message": "モデルが削除されました"}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"内部サーバーエラー: {str(e)}")


@app.get("/api/v2/users/me/stats", response_model=UsageStatsResponse)
async def get_user_stats(user: dict = Depends(get_current_user)):
    """
    ユーザーの利用統計を取得
    
    仕様書: specs/03_API_SPECIFICATION.md
    """
    try:
        user_id = user["user_id"]
        
        # ユーザー情報を取得
        user_info = get_user_by_id(user_id)
        if not user_info:
            raise HTTPException(status_code=404, detail="ユーザーが見つかりません")
        
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
            daily_tts_limit=user_info["daily_tts_limit"],
            daily_clone_limit=user_info["daily_clone_limit"],
            monthly_cost_limit=monthly_cost_limit
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"内部サーバーエラー: {str(e)}")


if __name__ == "__main__":
    import uvicorn
    port = int(os.environ.get("PORT", 8000))
    uvicorn.run(app, host="0.0.0.0", port=port)

