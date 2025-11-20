"""
YouTubeから音声をダウンロードしてWAV形式に変換

Streamlitアプリ用に最適化されたバージョン
"""

import subprocess
import os
import tempfile
import glob
import time
from pathlib import Path
from typing import Optional


def download_youtube_as_wav(youtube_url: str, output_path: Optional[str] = None) -> str:
    """
    YouTubeから音声をダウンロードしてWAV形式で保存
    
    Args:
        youtube_url: YouTubeのURL
        output_path: 出力ファイルパス（Noneの場合は自動生成）
    
    Returns:
        保存されたWAVファイルのパス
    
    Raises:
        FileNotFoundError: 必要なツール（yt-dlp, ffmpeg）が見つからない場合
        subprocess.CalledProcessError: ダウンロードまたは変換に失敗した場合
        ValueError: URLが無効な場合
    """
    if not youtube_url or not youtube_url.strip():
        raise ValueError("YouTube URLが空です")
    
    # 出力パスの設定
    if output_path is None:
        output_dir = Path(__file__).parent.parent / "examples"
        output_dir.mkdir(exist_ok=True)
        output_path = str(output_dir / "downloaded.wav")
    else:
        output_path = str(output_path)
        output_dir = Path(output_path).parent
        output_dir.mkdir(parents=True, exist_ok=True)
    
    # 一時ファイルの管理（tempfileを使用）
    temp_file = None
    try:
        # 一時ファイルを作成（拡張子なしで作成し、yt-dlpに形式を選択させる）
        with tempfile.NamedTemporaryFile(delete=False, suffix=".%(ext)s") as tmp:
            temp_file_template = tmp.name
        
        # yt-dlpで音声のみダウンロード
        # -x: 音声のみ抽出（ffmpegを使用して変換）
        # --audio-format opus: opus形式で出力（高品質で互換性が高い）
        # --audio-quality 0: 最高品質
        # -o: 出力ファイル名（%(ext)sで拡張子を自動決定）
        temp_dir = os.path.dirname(temp_file_template)
        temp_base = os.path.basename(temp_file_template)
        
        cmd1 = [
            'yt-dlp',
            '-x',  # 音声のみ抽出
            '--audio-format', 'opus',  # opus形式（高品質で互換性が高い）
            '--audio-quality', '0',  # 最高品質
            '--no-playlist',  # プレイリストではなく単一動画のみ
            '-o', temp_file_template,
            youtube_url
        ]
        result1 = subprocess.run(cmd1, check=True, capture_output=True, text=True)
        
        # yt-dlpが実際に作成したファイル名を取得
        # yt-dlpは%(ext)sを実際の拡張子（この場合はopus）に置き換える
        # 一時ディレクトリ内のファイルを検索
        pattern = os.path.join(temp_dir, temp_base.replace('%(ext)s', '*'))
        matching_files = glob.glob(pattern)
        
        if not matching_files:
            # パターンが見つからない場合、一時ディレクトリ内の最新の音声ファイルを探す
            audio_extensions = ['.opus', '.m4a', '.webm', '.ogg', '.mp3']
            all_files = []
            for ext in audio_extensions:
                all_files.extend(glob.glob(os.path.join(temp_dir, f'*{ext}')))
            
            if not all_files:
                # stderrからエラー情報を取得
                error_info = result1.stderr if result1.stderr else "詳細不明"
                raise RuntimeError(f"yt-dlpでダウンロードしたファイルが見つかりません。yt-dlp出力: {error_info[:200]}")
            
            matching_files = all_files
        
        # 最新のファイル（最も最近変更されたファイル）を選択
        temp_file = max(matching_files, key=os.path.getmtime)
        
        # ダウンロードされたファイルの存在とサイズを確認
        if not os.path.exists(temp_file):
            raise RuntimeError(f"ダウンロードされたファイルが見つかりません: {temp_file}")
        
        # ファイルサイズが安定するまで待つ（書き込み完了を確認）
        max_wait = 10  # 最大10秒待つ
        wait_interval = 0.1
        waited = 0
        last_size = 0
        
        while waited < max_wait:
            current_size = os.path.getsize(temp_file)
            if current_size > 0 and current_size == last_size:
                # サイズが安定した（書き込み完了）
                break
            last_size = current_size
            time.sleep(wait_interval)
            waited += wait_interval
        
        file_size = os.path.getsize(temp_file)
        if file_size == 0:
            raise RuntimeError(f"ダウンロードされたファイルが空です: {temp_file}")
        
        # ffmpegでwav変換
        # -loglevel error: エラーメッセージのみを出力（進捗情報を抑制）
        cmd2 = [
            'ffmpeg', '-y', '-loglevel', 'error', '-i', temp_file,
            '-ar', '44100',  # サンプリングレート 44.1kHz
            '-ac', '2',      # ステレオ
            '-vn',           # 動画なし
            output_path
        ]
        result = subprocess.run(cmd2, capture_output=True, text=True)
        
        # エラーチェック（リターンコードとstderrを確認）
        if result.returncode != 0:
            error_msg = "ffmpeg変換に失敗しました"
            if result.stderr:
                error_msg += f": {result.stderr.strip()}"
            raise subprocess.CalledProcessError(result.returncode, cmd2, result.stdout, result.stderr)
        
        # 出力ファイルが正常に生成されたか確認
        if not os.path.exists(output_path) or os.path.getsize(output_path) == 0:
            raise RuntimeError(f"出力ファイルが正常に生成されませんでした: {output_path}")
        
        return output_path
        
    except subprocess.CalledProcessError as e:
        error_msg = "ダウンロードまたは変換に失敗しました"
        # stderrから実際のエラーメッセージを抽出
        if e.stderr:
            stderr_text = e.stderr.strip()
            # ffmpegのバージョン情報が含まれている場合は除外
            if "ffmpeg version" not in stderr_text:
                error_msg += f": {stderr_text[:500]}"
            else:
                # バージョン情報の後に実際のエラーがある場合
                lines = stderr_text.split('\n')
                error_lines = [line for line in lines if 'ffmpeg version' not in line and line.strip()]
                if error_lines:
                    error_msg += f": {' '.join(error_lines[:5])}"
        raise RuntimeError(error_msg) from e
    except FileNotFoundError as e:
        if 'yt-dlp' in str(e) or 'yt-dlp' in str(e.cmd) if hasattr(e, 'cmd') else False:
            raise FileNotFoundError("yt-dlpが見つかりません。`pip install yt-dlp`でインストールしてください。") from e
        elif 'ffmpeg' in str(e) or 'ffmpeg' in str(e.cmd) if hasattr(e, 'cmd') else False:
            raise FileNotFoundError("ffmpegが見つかりません。システムにインストールしてください。") from e
        raise
    finally:
        # 一時ファイルのクリーンアップ
        if temp_file and os.path.exists(temp_file):
            try:
                os.remove(temp_file)
            except OSError:
                pass  # 削除に失敗しても続行
