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
from datetime import datetime, date
import tempfile
import shutil

# データベースモジュールをインポート（相対インポート）
from .database import (
    init_database,
    create_user,
    get_user_by_id,
    get_all_users,
    check_usage_limit,
    record_usage,
    get_usage_stats,
    get_monthly_cost,
    get_user_monthly_cost,
    get_db_connection,
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

# 認証モジュールをインポート（相対インポート）
from .auth import verify_firebase_token, get_current_user

# Fish Audio APIクライアントをインポート（相対インポート）
from .fish_audio_client import call_fish_audio_tts, call_fish_audio_clone

# 音声処理モジュールをインポート（相対インポート、オプショナル）
try:
    from .audio_processing import separate_vocals, remove_silence, process_audio_file
    AUDIO_PROCESSING_AVAILABLE = True
except ImportError as e:
    AUDIO_PROCESSING_AVAILABLE = False
    # デフォルトのダミー関数を定義（エラー時に使用）
    def separate_vocals(*args, **kwargs):
        raise HTTPException(status_code=503, detail="音源分離機能は利用できません。demucsがインストールされていません。")
    def remove_silence(*args, **kwargs):
        raise HTTPException(status_code=503, detail="無音区間削除機能は利用できません。pydubがインストールされていません。")
    def process_audio_file(*args, **kwargs):
        raise HTTPException(status_code=503, detail="音声処理機能は利用できません。必要なライブラリがインストールされていません。")

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
    transcription: Optional[str] = None  # 文字起こし（オプション、推奨）


class CloneResponse(BaseModel):
    model_id: str
    reference_name: str
    message: str


class VoiceModelResponse(BaseModel):
    model_id: str
    reference_name: str
    created_at: str


class UsageStatsResponse(BaseModel):
    """エンドユーザー向けの利用統計（コスト情報は含まない）"""
    daily_usage: int
    daily_tts: int
    daily_clone: int
    daily_tts_limit: int
    daily_clone_limit: int


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

# 生成音声の保存先（storageディレクトリに配置）
AUDIO_STORAGE_DIR = Path(__file__).parent.parent / "storage" / "generated_audio"
AUDIO_STORAGE_DIR.mkdir(parents=True, exist_ok=True)
MAX_TTS_HISTORY_ITEMS = int(os.environ.get("TTS_HISTORY_LIMIT", "10"))

# 管理者のメールアドレス（環境変数から取得、カンマ区切りで複数指定可能）
ADMIN_EMAILS = set(
    email.strip().lower() 
    for email in os.environ.get("ADMIN_EMAILS", "").split(",") 
    if email.strip()
)


def is_admin_user(user: dict) -> bool:
    """ユーザーが管理者かどうかを判定"""
    email = user.get("email", "").lower()
    return email in ADMIN_EMAILS


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
            reference_name=request.reference_name,
            transcription=request.transcription
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
        
        # エンドユーザーには使用回数のみを返す（コスト情報は含まない）
        return UsageStatsResponse(
            daily_usage=stats["daily_usage"],
            daily_tts=stats["daily_tts"],
            daily_clone=stats["daily_clone"],
            daily_tts_limit=user_info["daily_tts_limit"],
            daily_clone_limit=user_info["daily_clone_limit"]
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"内部サーバーエラー: {str(e)}")


# ============================================================================
# 管理者向けAPIエンドポイント
# ============================================================================

class AdminStatsResponse(BaseModel):
    """管理者向けの全体統計"""
    total_users: int
    active_users_today: int
    daily_tts_count: int
    daily_clone_count: int
    daily_total_cost: float
    monthly_total_cost: float
    monthly_cost_limit: float


class AdminUserCostResponse(BaseModel):
    """管理者向けのユーザー別コスト情報"""
    user_id: str
    email: Optional[str]
    daily_tts: int
    daily_clone: int
    daily_cost: float
    monthly_cost: float
    daily_tts_limit: int
    daily_clone_limit: int


class AdminUserListResponse(BaseModel):
    """管理者向けのユーザー一覧"""
    users: List[AdminUserCostResponse]
    total_users: int


def verify_admin_user(user: dict = Depends(get_current_user)) -> dict:
    """管理者かどうかを確認し、管理者でない場合はエラーを返す"""
    if not is_admin_user(user):
        raise HTTPException(
            status_code=403,
            detail="このエンドポイントにアクセスするには管理者権限が必要です"
        )
    return user


@app.get("/api/admin/stats", response_model=AdminStatsResponse)
async def get_admin_stats(admin_user: dict = Depends(verify_admin_user)):
    """
    管理者向けの全体統計を取得
    
    コスト情報を含む詳細な統計情報を返します。
    """
    try:
        # 全体統計を取得
        all_stats = get_usage_stats(user_id=None)
        
        # ユーザー数を取得
        all_users = get_all_users()
        total_users = len(all_users)
        
        # 今日アクティブなユーザー数（今日使用したユーザー数）
        today = date.today()
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("""
            SELECT COUNT(DISTINCT user_id) as active_users
            FROM usage_history
            WHERE DATE(created_at) = ?
        """, (today.isoformat(),))
        result = cursor.fetchone()
        active_users_today = result["active_users"] if result else 0
        conn.close()
        
        # 月次コストを取得
        monthly_cost = get_monthly_cost()
        monthly_cost_limit = float(
            os.environ.get("MONTHLY_COST_LIMIT", DEFAULT_MONTHLY_COST_LIMIT)
        )
        
        return AdminStatsResponse(
            total_users=total_users,
            active_users_today=active_users_today,
            daily_tts_count=all_stats["daily_tts"],
            daily_clone_count=all_stats["daily_clone"],
            daily_total_cost=all_stats["daily_cost"],
            monthly_total_cost=monthly_cost,
            monthly_cost_limit=monthly_cost_limit
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"内部サーバーエラー: {str(e)}")


@app.get("/api/admin/users", response_model=AdminUserListResponse)
async def get_admin_users(admin_user: dict = Depends(verify_admin_user)):
    """
    管理者向けのユーザー一覧とコスト情報を取得
    
    全ユーザーの使用状況とコスト情報を返します。
    """
    try:
        all_users = get_all_users()
        user_costs = []
        
        for user in all_users:
            user_id = user["user_id"]
            stats = get_usage_stats(user_id)
            
            # ユーザー別の月次コストを取得
            monthly_cost = get_user_monthly_cost(user_id)
            
            user_costs.append(AdminUserCostResponse(
                user_id=user_id,
                email=user.get("email"),
                daily_tts=stats["daily_tts"],
                daily_clone=stats["daily_clone"],
                daily_cost=stats["daily_cost"],
                monthly_cost=monthly_cost,
                daily_tts_limit=user["daily_tts_limit"],
                daily_clone_limit=user["daily_clone_limit"]
            ))
        
        return AdminUserListResponse(
            users=user_costs,
            total_users=len(user_costs)
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"内部サーバーエラー: {str(e)}")


@app.get("/api/admin/users/{user_id}/costs", response_model=AdminUserCostResponse)
async def get_admin_user_costs(
    user_id: str,
    admin_user: dict = Depends(verify_admin_user)
):
    """
    管理者向けの特定ユーザーのコスト情報を取得
    
    指定されたユーザーの詳細な使用状況とコスト情報を返します。
    """
    try:
        user_info = get_user_by_id(user_id)
        if not user_info:
            raise HTTPException(status_code=404, detail="ユーザーが見つかりません")
        
        stats = get_usage_stats(user_id)
        
        # ユーザー別の月次コストを取得
        monthly_cost = get_user_monthly_cost(user_id)
        
        return AdminUserCostResponse(
            user_id=user_id,
            email=user_info.get("email"),
            daily_tts=stats["daily_tts"],
            daily_clone=stats["daily_clone"],
            daily_cost=stats["daily_cost"],
            monthly_cost=monthly_cost,
            daily_tts_limit=user_info["daily_tts_limit"],
            daily_clone_limit=user_info["daily_clone_limit"]
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"内部サーバーエラー: {str(e)}")


# 音声処理関連のPydanticモデル
class AudioProcessRequest(BaseModel):
    """音声処理リクエスト（base64形式）"""
    audio_base64: str
    separate_vocals: bool = False
    remove_silence: bool = False
    separation_model: str = "htdemucs"
    silence_thresh: float = -40.0
    min_silence_len: int = 500
    keep_silence: int = 200


class AudioProcessResponse(BaseModel):
    """音声処理レスポンス"""
    output_audio_base64: str
    vocals_audio_base64: Optional[str] = None
    message: str


@app.post("/api/v2/audio/process", response_model=AudioProcessResponse)
async def process_audio(
    request: AudioProcessRequest,
    user: dict = Depends(get_current_user)
):
    """
    音声ファイルを処理（音源分離、無音区間削除）
    
    iOSアプリからbase64エンコードされた音声データを受け取り、処理して返します。
    
    - 音源分離: 音楽ファイルからボーカルを抽出
    - 無音区間削除: 音声から無音区間を削除
    
    仕様書: specs/03_API_SPECIFICATION.md
    """
    if not AUDIO_PROCESSING_AVAILABLE:
        raise HTTPException(
            status_code=503,
            detail="音声処理機能は現在利用できません。必要なライブラリ（demucs, pydub）がインストールされていません。"
        )
    
    try:
        user_id = user["user_id"]
        
        # base64デコード
        try:
            audio_bytes = base64.b64decode(request.audio_base64)
        except Exception as e:
            raise HTTPException(
                status_code=400,
                detail=f"音声データのデコードに失敗しました: {str(e)}"
            )
        
        # 一時ファイルに保存
        with tempfile.NamedTemporaryFile(delete=False, suffix=".wav") as tmp_input:
            tmp_input.write(audio_bytes)
            tmp_input_path = tmp_input.name
        
        try:
            # 出力ディレクトリ
            output_dir = tempfile.mkdtemp(prefix=f"audio_processing_{user_id}_")
            
            # 音声処理を実行
            result = process_audio_file(
                input_path=tmp_input_path,
                output_dir=output_dir,
                separate_vocals_enabled=request.separate_vocals,
                remove_silence_enabled=request.remove_silence,
                separation_model=request.separation_model,
                silence_thresh=request.silence_thresh,
                min_silence_len=request.min_silence_len,
                keep_silence=request.keep_silence
            )
            
            # 出力ファイルを読み込む
            with open(result['output'], 'rb') as f:
                output_audio_bytes = f.read()
            
            output_audio_base64 = base64.b64encode(output_audio_bytes).decode('utf-8')
            
            # ボーカルファイルがある場合は読み込む
            vocals_audio_base64 = None
            if 'vocals' in result and os.path.exists(result['vocals']):
                with open(result['vocals'], 'rb') as f:
                    vocals_audio_bytes = f.read()
                vocals_audio_base64 = base64.b64encode(vocals_audio_bytes).decode('utf-8')
            
            # クリーンアップ
            shutil.rmtree(output_dir, ignore_errors=True)
            
            message = "音声処理が完了しました"
            if request.separate_vocals:
                message += "（音源分離済み）"
            if request.remove_silence:
                message += "（無音区間削除済み）"
            
            return AudioProcessResponse(
                output_audio_base64=output_audio_base64,
                vocals_audio_base64=vocals_audio_base64,
                message=message
            )
            
        finally:
            # 一時ファイルを削除
            if os.path.exists(tmp_input_path):
                os.remove(tmp_input_path)
                
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"内部サーバーエラー: {str(e)}")




if __name__ == "__main__":
    import uvicorn
    port = int(os.environ.get("PORT", 8000))
    uvicorn.run(app, host="0.0.0.0", port=port)

