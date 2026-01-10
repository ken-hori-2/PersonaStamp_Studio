"""
音声処理モジュール
- 音源分離（ボーカル抽出）- Spleeterを使用（Render無料プラン対応）
- 無音区間の削除
"""

import subprocess
import os
import tempfile
from pathlib import Path
from typing import Optional, Dict

# ============================================================================
# Demucs実装（コメントアウト - Render無料プランでは重すぎるため）
# ============================================================================
# def separate_vocals_demucs(
#     input_path: str,
#     output_dir: Optional[str] = None,
#     model: str = 'htdemucs'
# ) -> str:
#     """
#     Demucsによる高精度音声分離（ボーカルのみ）
#     
#     Args:
#         input_path: 入力音声ファイルパス
#         output_dir: 出力ディレクトリ（Noneの場合は自動生成）
#         model: 分離モデル
#             - 'htdemucs': 最高品質（推奨・デフォルト）
#             - 'htdemucs_ft': 最高品質・fine-tuned版
#             - 'mdx_extra': 超高品質（処理時間長）
#             - 'mdx_extra_q': 超高品質・量子化版
#     
#     Returns:
#         ボーカル音声ファイルのパス
#     
#     Raises:
#         FileNotFoundError: demucsが見つからない場合
#         RuntimeError: 音源分離に失敗した場合
#         ValueError: 入力ファイルが存在しない場合
#     """
#     input_path = str(input_path)
#     if not os.path.exists(input_path):
#         raise ValueError(f"入力ファイルが見つかりません: {input_path}")
#     
#     if output_dir is None:
#         # 一時ディレクトリを使用
#         output_dir = tempfile.mkdtemp(prefix="audio_separation_")
#     else:
#         output_dir = str(output_dir)
#         os.makedirs(output_dir, exist_ok=True)
#     
#     # Demucsコマンドを実行
#     cmd = [
#         'demucs',
#         '-n', model,
#         '-o', output_dir,
#         '--two-stems=vocals',  # vocalsとno_vocalsのみ出力（高速）
#         input_path
#     ]
#     
#     try:
#         # demucsは進捗情報をstderrに出力するため、check=Falseで実行してリターンコードを確認
#         result = subprocess.run(cmd, capture_output=True, text=True, check=False)
#         
#         # リターンコードが0以外の場合はエラー
#         if result.returncode != 0:
#             error_msg = "音源分離に失敗しました"
#             # stderrから実際のエラーメッセージを抽出（進捗情報を除外）
#             if result.stderr:
#                 stderr_lines = result.stderr.split('\n')
#                 # 進捗バー（%や|を含む行、seconds/sを含む行）を除外
#                 error_lines = [
#                     line for line in stderr_lines
#                     if line.strip() and
#                     '%' not in line and
#                     '|' not in line and
#                     'seconds/s' not in line and
#                     not line.strip().startswith('[') and
#                     ('Error' in line or 'error' in line.lower() or 'failed' in line.lower() or 'exception' in line.lower() or 'ModuleNotFoundError' in line or 'ImportError' in line)
#                 ]
#                 if error_lines:
#                     error_msg += f": {' '.join(error_lines[:3])}"
#             
#             raise RuntimeError(error_msg)
#     except FileNotFoundError:
#         raise FileNotFoundError(
#             "demucsが見つかりません。`pip install demucs`でインストールしてください。"
#         )
#     
#     # 出力ファイルのパスを返す
#     input_name = Path(input_path).stem
#     output_path = Path(output_dir) / model / input_name
#     vocals_path = output_path / "vocals.wav"
#     
#     if not vocals_path.exists():
#         raise RuntimeError(f"ボーカルファイルが生成されませんでした: {vocals_path}")
#     
#     return str(vocals_path)
# ============================================================================


def separate_vocals(
    input_path: str,
    output_dir: Optional[str] = None,
        model: str = 'spleeter:2stems'  # Spleeterのデフォルトモデル（軽量）
) -> str:
    """
    Spleeterによる音声分離（ボーカルのみ）
    
    Render無料プラン（512MB RAM、0.1 CPU）でも動作する軽量な実装。
    Demucsよりも軽量で、メモリ使用量が少ない。
    
    Args:
        input_path: 入力音声ファイルパス
        output_dir: 出力ディレクトリ（Noneの場合は自動生成）
        model: 分離モデル（Spleeter形式）
            - 'spleeter:2stems': ボーカルと伴奏の2-stem分離（軽量・推奨・デフォルト）
            - 'spleeter:4stems': ボーカル、ドラム、ベース、その他の4-stem分離
            - 'spleeter:5stems': ボーカル、ドラム、ベース、ピアノ、その他の5-stem分離
    
    Returns:
        ボーカル音声ファイルのパス
    
    Raises:
        ImportError: spleeterがインストールされていない場合
        RuntimeError: 音源分離に失敗した場合
        ValueError: 入力ファイルが存在しない場合
    """
    try:
        from spleeter.separator import Separator
        from spleeter.audio.adapter import AudioAdapter
    except ImportError:
        raise ImportError(
            "spleeterがインストールされていません。`pip install spleeter`でインストールしてください。"
        )
    
    input_path = str(input_path)
    if not os.path.exists(input_path):
        raise ValueError(f"入力ファイルが見つかりません: {input_path}")
    
    if output_dir is None:
        # 一時ディレクトリを使用
        output_dir = tempfile.mkdtemp(prefix="audio_separation_")
    else:
        output_dir = str(output_dir)
        os.makedirs(output_dir, exist_ok=True)
    
    try:
        # Spleeterのセパレーターを初期化
        separator = Separator(model)
        audio_adapter = AudioAdapter.default()
        
        # 音声ファイルを読み込む
        waveform, sample_rate = audio_adapter.load(input_path)
        
        # 音源分離を実行
        prediction = separator.separate(waveform)
        
        # ボーカル音声を取得（2-stemモデルの場合）
        if 'vocals' in prediction:
            vocals_waveform = prediction['vocals']
        else:
            # 4-stemまたは5-stemモデルの場合もvocalsキーがあるはず
            raise RuntimeError("ボーカル音声が見つかりませんでした")
        
        # 出力ファイルパス
        input_name = Path(input_path).stem
        vocals_path = os.path.join(output_dir, f"{input_name}_vocals.wav")
        
        # ボーカル音声を保存
        audio_adapter.save(vocals_path, vocals_waveform, sample_rate)
        
        if not os.path.exists(vocals_path):
            raise RuntimeError(f"ボーカルファイルが生成されませんでした: {vocals_path}")
        
        return vocals_path
        
    except ImportError as e:
        # ImportErrorの場合は、より詳細なメッセージを返す
        raise ImportError(
            f"spleeterがインストールされていません。`pip install spleeter`でインストールしてください。"
            f" 詳細エラー: {str(e)}"
        )
    except Exception as e:
        # その他のエラーの場合
        error_msg = f"音源分離に失敗しました: {str(e)}"
        # ImportErrorが含まれている場合は、より詳細なメッセージを追加
        if "ImportError" in str(e) or "No module named" in str(e):
            error_msg += "\n\nspleeterがインストールされていない可能性があります。`pip install spleeter`でインストールしてください。"
        raise RuntimeError(error_msg)


def remove_silence(
    input_path: str,
    output_path: Optional[str] = None,
    silence_thresh: float = -40.0,
    min_silence_len: int = 500,
    keep_silence: int = 200
) -> str:
    """
    無音区間を削除
    
    Args:
        input_path: 入力音声ファイルパス
        output_path: 出力ファイルパス（Noneの場合は自動生成）
        silence_thresh: 無音とみなす音量閾値（dB、デフォルト: -40.0）
        min_silence_len: 無音とみなす最小長さ（ミリ秒、デフォルト: 500）
        keep_silence: 無音区間の前後に残す長さ（ミリ秒、デフォルト: 200）
    
    Returns:
        出力ファイルのパス
    
    Raises:
        ImportError: pydubがインストールされていない場合
        ValueError: 入力ファイルが存在しない場合
    """
    try:
        from pydub import AudioSegment
        from pydub.silence import detect_nonsilent
    except ImportError:
        raise ImportError(
            "pydubがインストールされていません。`pip install pydub`でインストールしてください。"
        )
    
    input_path = str(input_path)
    if not os.path.exists(input_path):
        raise ValueError(f"入力ファイルが見つかりません: {input_path}")
    
    if output_path is None:
        # 一時ファイルを使用
        output_path = tempfile.mktemp(suffix=".wav", prefix="audio_no_silence_")
    else:
        output_path = str(output_path)
        os.makedirs(os.path.dirname(output_path) if os.path.dirname(output_path) else '.', exist_ok=True)
    
    # 音声ファイルを読み込む
    audio = AudioSegment.from_file(input_path)
    
    # 無音区間を検出
    nonsilent_ranges = detect_nonsilent(
        audio,
        min_silence_len=min_silence_len,
        silence_thresh=silence_thresh
    )
    
    if not nonsilent_ranges:
        # 無音区間が見つからない場合は、元のファイルをコピー
        audio.export(output_path, format="wav")
        return output_path
    
    # 無音区間を削除して結合
    # 各無音区間の前後に少し余白を残す
    chunks = []
    for start, end in nonsilent_ranges:
        # 前後に余白を追加
        chunk_start = max(0, start - keep_silence)
        chunk_end = min(len(audio), end + keep_silence)
        chunks.append(audio[chunk_start:chunk_end])
    
    # チャンクを結合
    if chunks:
        output_audio = sum(chunks)
    else:
        output_audio = audio
    
    # 出力
    output_audio.export(output_path, format="wav")
    
    return output_path


def process_audio_file(
    input_path: str,
    output_dir: Optional[str] = None,
    separate_vocals_enabled: bool = False,
    remove_silence_enabled: bool = False,
    separation_model: str = 'spleeter:2stems',  # Spleeterの軽量モデル（Render無料プラン対応）
    silence_thresh: float = -40.0,
    min_silence_len: int = 500,
    keep_silence: int = 200
) -> Dict[str, str]:
    """
    音声ファイルを処理（音源分離と無音区間削除を組み合わせ）
    
    Args:
        input_path: 入力音声ファイルパス
        output_dir: 出力ディレクトリ
        separate_vocals_enabled: 音源分離を有効にする
        remove_silence_enabled: 無音区間削除を有効にする
        separation_model: 分離モデル
        silence_thresh: 無音とみなす音量閾値（dB）
        min_silence_len: 無音とみなす最小長さ（ミリ秒）
        keep_silence: 無音区間の前後に残す長さ（ミリ秒）
    
    Returns:
        処理されたファイルのパスの辞書
        - 'output': 最終的な出力ファイルパス
        - 'vocals': 音源分離した場合のボーカルファイルパス（オプション）
    """
    if output_dir is None:
        output_dir = tempfile.mkdtemp(prefix="audio_processing_")
    else:
        os.makedirs(output_dir, exist_ok=True)
    
    current_file = input_path
    result = {}
    
    # 1. 音源分離（必要に応じて）
    if separate_vocals_enabled:
        try:
            vocals_path = separate_vocals(current_file, output_dir, separation_model)
            current_file = vocals_path
            result['vocals'] = vocals_path
        except ImportError as e:
            # ImportErrorの場合は、より詳細なエラーメッセージを返す
            raise ImportError(
                f"音源分離に必要なライブラリ（spleeter）がインストールされていません。"
                f" `pip install spleeter`でインストールしてください。"
                f" 詳細エラー: {str(e)}"
            )
        except Exception as e:
            # その他のエラーの場合
            error_msg = f"音源分離処理中にエラーが発生しました: {str(e)}"
            if "ImportError" in str(e) or "No module named" in str(e):
                error_msg += "\n\nspleeterがインストールされていない可能性があります。`pip install spleeter`でインストールしてください。"
            raise RuntimeError(error_msg)
    
    # 2. 無音区間削除（必要に応じて）
    if remove_silence_enabled:
        output_path = os.path.join(output_dir, f"processed_{Path(current_file).name}")
        processed_path = remove_silence(
            current_file,
            output_path,
            silence_thresh,
            min_silence_len,
            keep_silence
        )
        current_file = processed_path
    
    result['output'] = current_file
    return result
