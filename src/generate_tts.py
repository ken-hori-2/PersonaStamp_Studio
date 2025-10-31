"""
Fish Audio TTS生成スクリプト

このスクリプトは、作成した音声クローンモデルを使用してTTSを実行します。
"""

from fish_audio_sdk import Session, TTSRequest, Prosody
from fish_audio_sdk.exceptions import HttpCodeErr
import os
from datetime import datetime
from pathlib import Path

# .envファイルがあれば読み込む
try:
    from dotenv import load_dotenv
    env_path = Path(__file__).parent.parent / '.env'
    load_dotenv(dotenv_path=env_path)
except ImportError:
    pass  # python-dotenvがインストールされていない場合はスキップ

def generate_tts(
    api_key: str,
    text: str,
    model_id: str = None,
    output_file: str = None,
    format: str = "wav",
    speed: float = 1.0,
    volume: int = 0
):
    """
    テキストから音声を生成します。
    
    Parameters:
    -----------
    api_key : str
        Fish AudioのAPIキー
    text : str
        音声に変換するテキスト
    model_id : str
        使用する音声モデルのID（Noneの場合はデフォルト音声）
    output_file : str
        出力ファイル名（Noneの場合は自動生成）
    format : str
        出力フォーマット ("mp3", "wav", "opus", "pcm")
    speed : float
        話速（0.5-2.0、デフォルト1.0）
    volume : int
        音量調整（-20~20、デフォルト0）
    
    Returns:
    --------
    output_file : str
        生成された音声ファイルのパス
    """
    
    # セッションの作成
    session = Session(api_key)
    
    # 出力ファイル名の生成
    if output_file is None:
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        output_dir = os.path.join(os.path.dirname(__file__), "..", "output")
        os.makedirs(output_dir, exist_ok=True)
        output_file = os.path.join(output_dir, f"tts_output_{timestamp}.{format}")
    else:
        output_dir = os.path.join(os.path.dirname(__file__), "..", "output")
        os.makedirs(output_dir, exist_ok=True)
        output_file = os.path.join(output_dir, output_file)
    
    # TTSリクエストの作成
    request_params = {
        "text": text,
        "format": format,
        "prosody": Prosody(speed=speed, volume=volume),
        "normalize": True,
        "latency": "balanced"
    }
    
    # モデルIDが指定されている場合
    if model_id:
        request_params["reference_id"] = model_id
    
    # フォーマット別の設定
    if format == "mp3":
        request_params["mp3_bitrate"] = 192
    elif format == "wav":
        request_params["sample_rate"] = 44100
    elif format == "opus":
        request_params["opus_bitrate"] = 48
    elif format == "pcm":
        request_params["sample_rate"] = 44100
    
    request = TTSRequest(**request_params)
    
    # 音声の生成と保存
    try:
        with open(output_file, "wb") as f:
            for chunk in session.tts(request):
                f.write(chunk)
        
        return output_file
        
    except HttpCodeErr as e:
        if e.status_code == 402:
            print(f"\nエラー: APIクレジットが不足しています。")
            print(f"Fish Audio (https://fish.audio) でクレジットを購入するか、")
            print(f"無料プランの制限を確認してください。")
        elif e.status_code == 401:
            print(f"\nエラー: APIキーが無効です。")
        else:
            print(f"\nエラー ({e.status_code}): {e}")
        raise
    except Exception as e:
        print(f"\nエラーが発生しました: {e}")
        raise


def load_model_id_from_file(file_path: str = "../model_id.txt") -> str:
    """
    ファイルからモデルIDを読み込みます。
    
    Parameters:
    -----------
    file_path : str
        モデルIDが保存されているファイルのパス
    
    Returns:
    --------
    model_id : str
        モデルID
    """
    if os.path.exists(file_path):
        with open(file_path, "r", encoding="utf-8") as f:
            return f.read().strip()
    return None


def check_api_credit(api_key: str):
    """
    APIクレジット残高を確認します。
    
    Parameters:
    -----------
    api_key : str
        Fish AudioのAPIキー
    """
    try:
        session = Session(api_key)
        credit = session.get_api_credit()
        print(f"APIクレジット残高: {credit.credit}")
    except Exception as e:
        print(f"クレジット確認エラー: {e}")


if __name__ == "__main__":
    # APIキーを環境変数から取得
    API_KEY = os.getenv("FISH_AUDIO_API_KEY")
    
    if not API_KEY:
        print("エラー: APIキーが設定されていません！")
        print("環境変数 FISH_AUDIO_API_KEY を設定してください。")
        print("\nPowerShellの場合:")
        print('  $env:FISH_AUDIO_API_KEY = "your_api_key_here"')
        print("\nまたは .env ファイルを作成して読み込んでください。")
        exit(1)
    
    # APIクレジット残高確認
    check_api_credit(API_KEY)
    print()
    
    # モデルIDの読み込み
    model_id_path = os.path.join(os.path.dirname(__file__), "..", "model_id.txt")
    model_id = load_model_id_from_file(model_id_path)
    
    if not model_id:
        model_id = input("モデルIDを入力（デフォルト音声: Enter）: ").strip() or None
    
    # テキスト入力
    TEXT = input("生成するテキスト: ").strip() or "こんにちは！(happy)JJ足りてる？？"
    
    try:
        # 音声生成
        output_file = generate_tts(
            api_key=API_KEY,
            text=TEXT,
            model_id=model_id,
            output_file="tts_output.wav",
            format="wav",
            speed=1.0,
            volume=0
        )
        
        print(f"\n完了: {output_file}")
        
    except Exception as e:
        print(f"\n失敗しました")
        exit(1)
