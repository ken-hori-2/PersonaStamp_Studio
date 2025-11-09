"""
Demucsによる高精度音源分離（ボーカル抽出）

Streamlitアプリ用に最適化されたバージョン
"""

import subprocess
import os
from pathlib import Path
from typing import Dict, Optional


def separate_vocals(
    input_path: str, 
    output_dir: Optional[str] = None, 
    model: str = 'htdemucs'
) -> str:
    """
    Demucsによる高精度音声分離（ボーカルのみ）
    
    Args:
        input_path: 入力音声ファイルパス
        output_dir: 出力ディレクトリ（Noneの場合は自動生成）
        model: 分離モデル
            - 'htdemucs': 最高品質（推奨・デフォルト）
            - 'htdemucs_ft': 最高品質・fine-tuned版
            - 'mdx_extra': 超高品質（処理時間長）
            - 'mdx_extra_q': 超高品質・量子化版
    
    Returns:
        ボーカル音声ファイルのパス
    
    Raises:
        FileNotFoundError: demucsが見つからない場合
        subprocess.CalledProcessError: 音源分離に失敗した場合
        ValueError: 入力ファイルが存在しない場合
    """
    input_path = str(input_path)
    if not os.path.exists(input_path):
        raise ValueError(f"入力ファイルが見つかりません: {input_path}")
    
    if output_dir is None:
        output_dir = str(Path(__file__).parent.parent / "separated")
    else:
        output_dir = str(output_dir)
    
    os.makedirs(output_dir, exist_ok=True)
    
    # Demucsコマンドを実行
    cmd = [
        'demucs',
        '-n', model,
        '-o', output_dir,
        '--two-stems=vocals',  # vocalsとno_vocalsのみ出力（高速）
        input_path
    ]
    
    try:
        # demucsは進捗情報をstderrに出力するため、check=Falseで実行してリターンコードを確認
        result = subprocess.run(cmd, capture_output=True, text=True, check=False)
        
        # リターンコードが0以外の場合はエラー
        if result.returncode != 0:
            error_msg = "音源分離に失敗しました"
            # stderrから実際のエラーメッセージを抽出（進捗情報を除外）
            if result.stderr:
                stderr_lines = result.stderr.split('\n')
                # 進捗バー（%や|を含む行、seconds/sを含む行）を除外
                error_lines = [
                    line for line in stderr_lines 
                    if line.strip() and 
                    '%' not in line and 
                    '|' not in line and
                    'seconds/s' not in line and
                    not line.strip().startswith('[') and
                    ('Error' in line or 'error' in line.lower() or 'failed' in line.lower() or 'exception' in line.lower() or 'ModuleNotFoundError' in line or 'ImportError' in line)
                ]
                if error_lines:
                    error_msg += f": {' '.join(error_lines[:3])}"
                    
                    # 特定のモジュールエラーの場合、解決方法を追加
                    stderr_text = ' '.join(error_lines)
                    if 'torchcodec' in stderr_text or 'ModuleNotFoundError' in stderr_text:
                        error_msg += "\n\n💡 解決方法: 以下のコマンドで必要なモジュールをインストールしてください:\n"
                        error_msg += "   pip install torchcodec\n"
                        error_msg += "   または、demucsを再インストール:\n"
                        error_msg += "   pip install --upgrade --force-reinstall demucs"
                elif result.stderr.strip():
                    # エラー行が見つからない場合、進捗情報以外の最後の数行を表示
                    non_progress_lines = [
                        line for line in stderr_lines[-10:]
                        if line.strip() and '%' not in line and '|' not in line and 'seconds/s' not in line
                    ]
                    if non_progress_lines:
                        error_msg += f": {non_progress_lines[-1][:200]}"
            
            raise RuntimeError(error_msg)
    except FileNotFoundError:
        raise FileNotFoundError(
            "demucsが見つかりません。`pip install demucs`でインストールしてください。"
        )
    
    # 出力ファイルのパスを返す
    input_name = Path(input_path).stem
    output_path = Path(output_dir) / model / input_name
    vocals_path = output_path / "vocals.wav"
    
    if not vocals_path.exists():
        raise RuntimeError(f"ボーカルファイルが生成されませんでした: {vocals_path}")
    
    return str(vocals_path)


def separate_vocals_full(
    input_path: str, 
    output_dir: Optional[str] = None, 
    model: str = 'htdemucs'
) -> Dict[str, str]:
    """
    完全分離（vocals, drums, bass, other）
    
    Args:
        input_path: 入力音声ファイルパス
        output_dir: 出力ディレクトリ（Noneの場合は自動生成）
        model: 分離モデル
    
    Returns:
        各パートの音声ファイルパスの辞書
    
    Raises:
        FileNotFoundError: demucsが見つからない場合
        subprocess.CalledProcessError: 音源分離に失敗した場合
        ValueError: 入力ファイルが存在しない場合
    """
    input_path = str(input_path)
    if not os.path.exists(input_path):
        raise ValueError(f"入力ファイルが見つかりません: {input_path}")
    
    if output_dir is None:
        output_dir = str(Path(__file__).parent.parent / "separated")
    else:
        output_dir = str(output_dir)
    
    os.makedirs(output_dir, exist_ok=True)
    
    cmd = [
        'demucs',
        '-n', model,
        '-o', output_dir,
        input_path
    ]
    
    try:
        # demucsは進捗情報をstderrに出力するため、check=Falseで実行してリターンコードを確認
        result = subprocess.run(cmd, capture_output=True, text=True, check=False)
        
        # リターンコードが0以外の場合はエラー
        if result.returncode != 0:
            error_msg = "音源分離に失敗しました"
            # stderrから実際のエラーメッセージを抽出（進捗情報を除外）
            if result.stderr:
                stderr_lines = result.stderr.split('\n')
                # 進捗バー（%や|を含む行、seconds/sを含む行）を除外
                error_lines = [
                    line for line in stderr_lines 
                    if line.strip() and 
                    '%' not in line and 
                    '|' not in line and
                    'seconds/s' not in line and
                    not line.strip().startswith('[') and
                    ('Error' in line or 'error' in line.lower() or 'failed' in line.lower() or 'exception' in line.lower() or 'ModuleNotFoundError' in line or 'ImportError' in line)
                ]
                if error_lines:
                    error_msg += f": {' '.join(error_lines[:3])}"
                    
                    # 特定のモジュールエラーの場合、解決方法を追加
                    stderr_text = ' '.join(error_lines)
                    if 'torchcodec' in stderr_text or 'ModuleNotFoundError' in stderr_text:
                        error_msg += "\n\n💡 解決方法: 以下のコマンドで必要なモジュールをインストールしてください:\n"
                        error_msg += "   pip install torchcodec\n"
                        error_msg += "   または、demucsを再インストール:\n"
                        error_msg += "   pip install --upgrade --force-reinstall demucs"
                elif result.stderr.strip():
                    # エラー行が見つからない場合、進捗情報以外の最後の数行を表示
                    non_progress_lines = [
                        line for line in stderr_lines[-10:]
                        if line.strip() and '%' not in line and '|' not in line and 'seconds/s' not in line
                    ]
                    if non_progress_lines:
                        error_msg += f": {non_progress_lines[-1][:200]}"
            
            raise RuntimeError(error_msg)
    except FileNotFoundError:
        raise FileNotFoundError(
            "demucsが見つかりません。`pip install demucs`でインストールしてください。"
        )
    
    # 出力ファイルのパスを返す
    input_name = Path(input_path).stem
    output_path = Path(output_dir) / model / input_name
    
    result = {
        'vocals': str(output_path / 'vocals.wav'),
        'drums': str(output_path / 'drums.wav'),
        'bass': str(output_path / 'bass.wav'),
        'other': str(output_path / 'other.wav')
    }
    
    # ファイルの存在確認
    for key, file_path in result.items():
        if not os.path.exists(file_path):
            raise RuntimeError(f"{key}ファイルが生成されませんでした: {file_path}")
    
    return result
