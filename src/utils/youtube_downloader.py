"""
YouTubeから音声をダウンロードしてWAV形式に変換

必要なインストール:
    pip install yt-dlp
    ffmpegもシステムにインストール必要
"""

import sys
import subprocess
import os
from pathlib import Path

def download_youtube_as_wav(youtube_url, output_path=None):
    """
    YouTubeから音声をダウンロードしてWAV形式で保存
    
    Args:
        youtube_url (str): YouTubeのURL
        output_path (str): 出力ファイルパス（デフォルト: ../examples/downloaded.wav）
    
    Returns:
        str: 保存されたWAVファイルのパス
    """
    if output_path is None:
        output_dir = os.path.join(os.path.dirname(__file__), "..", "..", "examples")
        os.makedirs(output_dir, exist_ok=True)
        output_path = os.path.join(output_dir, "downloaded.wav")
    
    print("=" * 60)
    print("YouTube 音声ダウンロード")
    print("=" * 60)
    print(f"URL: {youtube_url}")
    print(f"出力先: {output_path}")
    print("=" * 60 + "\n")
    
    # 一時ファイル
    temp_file = "temp_audio.m4a"
    
    try:
        # yt-dlpで音声のみダウンロード
        print("音声をダウンロード中...")
        cmd1 = ['yt-dlp', '-f', 'bestaudio', '-o', temp_file, youtube_url]
        subprocess.run(cmd1, check=True)
        
        # ffmpegでwav変換
        print("\nWAV形式に変換中...")
        cmd2 = [
            'ffmpeg', '-y', '-i', temp_file,
            '-ar', '44100',  # サンプリングレート 44.1kHz
            '-ac', '2',      # ステレオ
            '-vn',           # 動画なし
            output_path
        ]
        subprocess.run(cmd2, check=True, capture_output=True)
        
        # 一時ファイル削除
        if os.path.exists(temp_file):
            os.remove(temp_file)
        
        print("\n" + "=" * 60)
        print("✓ ダウンロード完了!")
        print("=" * 60)
        print(f"保存先: {output_path}")
        print("\n次のステップ:")
        print("  1. audio_separation.py でボーカル抽出")
        print("  2. create_voice_clone.py で音声クローン作成")
        print("=" * 60)
        
        return output_path
        
    except subprocess.CalledProcessError as e:
        print(f"\nエラー: {e}")
        if os.path.exists(temp_file):
            os.remove(temp_file)
        sys.exit(1)
    except FileNotFoundError as e:
        print(f"\nエラー: 必要なツールが見つかりません")
        print("以下をインストールしてください:")
        print("  pip install yt-dlp")
        print("  ffmpeg (システムにインストール)")
        sys.exit(1)


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("=" * 60)
        print("YouTube 音声ダウンローダー")
        print("=" * 60)
        print("\n使い方:")
        print('  python youtube_downloader.py "<YouTubeのURL>" [出力ファイル名]')
        print("\n例:")
        print('  python youtube_downloader.py "https://www.youtube.com/watch?v=xxxxx"')
        print('  python youtube_downloader.py "https://youtu.be/xxxxx" my_song.wav')
        print("\n必要なツール:")
        print("  - yt-dlp: pip install yt-dlp")
        print("  - ffmpeg: システムにインストール")
        print("=" * 60)
        sys.exit(1)
    
    url = sys.argv[1]
    output = sys.argv[2] if len(sys.argv) > 2 else None
    
    download_youtube_as_wav(url, output)
