"""
Fish Audio API クライアント
仕様書: specs/03_API_SPECIFICATION.md
"""

import os
from typing import Optional
from datetime import datetime

from fastapi import HTTPException
from fish_audio_sdk import Session, TTSRequest, Prosody
from fish_audio_sdk.exceptions import HttpCodeErr


_cached_session: Optional[Session] = None
_cached_api_key: Optional[str] = None


def get_fish_api_key() -> str:
    """Fish Audio APIキーを環境変数から取得"""
    api_key = os.environ.get("FISH_AUDIO_API_KEY", "")
    if not api_key:
        raise HTTPException(
            status_code=500,
            detail="FISH_AUDIO_API_KEY環境変数が設定されていません"
        )
    return api_key


def _get_fish_session() -> Session:
    """
    Fish Audio SDK の Session をキャッシュして再利用する。
    APIキーが変更された場合は再作成する。
    """
    global _cached_session, _cached_api_key
    api_key = get_fish_api_key()

    if _cached_session is None or _cached_api_key != api_key:
        _cached_session = Session(api_key)
        _cached_api_key = api_key

    return _cached_session


def call_fish_audio_tts(
    text: str,
    model_id: Optional[str] = None,
    format: str = "mp3",
    speed: float = 1.0,
    volume: int = 0
) -> bytes:
    """
    Fish Audio SDK を用いて TTS を生成する。
    
    Args:
        text: 音声合成するテキスト
        model_id: 使用する声モデルID（オプション）
        format: 音声フォーマット（mp3 / wav / opus / pcm）
        speed: 話す速度（0.5-2.0）
        volume: 音量（-20-20）
    
    Returns:
        音声ファイルのバイナリデータ
    """
    session = _get_fish_session()

    request_params = {
        "text": text,
        "format": format,
        "prosody": Prosody(speed=speed, volume=volume),
        "normalize": True,
        "latency": "balanced",
    }

    if model_id:
        request_params["reference_id"] = model_id

    if format == "mp3":
        request_params["mp3_bitrate"] = 192
    elif format == "wav":
        request_params["sample_rate"] = 44100
    elif format == "opus":
        request_params["opus_bitrate"] = 48
    elif format == "pcm":
        request_params["sample_rate"] = 44100

    request = TTSRequest(**request_params)

    try:
        audio_chunks = session.tts(request)
        audio_bytes = b"".join(chunk for chunk in audio_chunks)
        return audio_bytes
    except HttpCodeErr as e:
        raise HTTPException(
            status_code=e.status_code or 500,
            detail=f"Fish Audio TTSエラー ({e.status_code}): {e}"
        )
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Fish Audio TTS呼び出しエラー: {str(e)}"
        )


def call_fish_audio_clone(
    audio_bytes: bytes, 
    reference_name: str,
    transcription: Optional[str] = None
) -> str:
    """
    Fish Audio SDK を用いて Voice Model を作成する。
    
    Args:
        audio_bytes: 音声サンプルのバイナリデータ
        reference_name: ユーザーがつけた声モデルの名前
        transcription: 音声の文字起こし（オプション、推奨）
    
    Returns:
        作成されたモデルID
    """
    session = _get_fish_session()

    # Fish Audio では複数の音声・テキストを渡せるが、現状は1件のみ
    title = reference_name or "PersonaStamp Voice"
    description = f"Uploaded from PersonaStamp Studio ({datetime.utcnow().isoformat()}Z)"
    
    # 文字起こしが提供されている場合は使用、なければ空文字列
    texts = [transcription] if transcription and transcription.strip() else [""]

    try:
        model = session.create_model(
            title=title,
            description=description,
            voices=[audio_bytes],
            texts=texts,
            visibility="private",
            enhance_audio_quality=True,
        )
        if not getattr(model, "id", None):
            raise HTTPException(
                status_code=500,
                detail="Fish Audio SDKからモデルIDが取得できませんでした"
            )
        return model.id
    except HttpCodeErr as e:
        raise HTTPException(
            status_code=e.status_code or 500,
            detail=f"Fish Audio Voice Cloneエラー ({e.status_code}): {e}"
        )
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Fish Audio Voice Clone呼び出しエラー: {str(e)}"
        )

