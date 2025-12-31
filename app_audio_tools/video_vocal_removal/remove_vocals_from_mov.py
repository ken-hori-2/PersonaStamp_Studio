"""
MOVファイルから人の声を削除して、人の声以外の音源を抽出し、元のMOVファイルの音声を差し替える

使用方法:
    python remove_vocals_from_mov.py <MOVファイルパス>

必要なツール:
    - ffmpeg: 動画・音声処理
    - demucs: 音源分離
"""

import subprocess
import sys
import os
from pathlib import Path
from typing import Optional


def extract_audio_from_video(video_path: str, output_audio_path: str) -> str:
    """
    MOVファイルから音声を抽出
    
    Args:
        video_path: 入力動画ファイルパス
        output_audio_path: 出力音声ファイルパス（WAV形式）
    
    Returns:
        出力音声ファイルのパス
    
    Raises:
        FileNotFoundError: ffmpegが見つからない場合
        RuntimeError: 音声抽出に失敗した場合
    """
    if not os.path.exists(video_path):
        raise ValueError(f"動画ファイルが見つかりません: {video_path}")
    
    print(f"📹 動画から音声を抽出中...")
    print(f"   入力: {video_path}")
    print(f"   出力: {output_audio_path}")
    
    cmd = [
        'ffmpeg', '-y', '-loglevel', 'error',
        '-i', video_path,
        '-ar', '44100',  # サンプリングレート 44.1kHz
        '-ac', '2',      # ステレオ
        '-vn',           # 動画なし
        output_audio_path
    ]
    
    result = subprocess.run(cmd, capture_output=True, text=True)
    
    if result.returncode != 0:
        error_msg = "音声抽出に失敗しました"
        if result.stderr:
            error_msg += f": {result.stderr.strip()}"
        raise RuntimeError(error_msg)
    
    if not os.path.exists(output_audio_path) or os.path.getsize(output_audio_path) == 0:
        raise RuntimeError(f"出力音声ファイルが正常に生成されませんでした: {output_audio_path}")
    
    print(f"✅ 音声抽出完了")
    return output_audio_path


def separate_vocals(input_path: str, output_dir: Optional[str] = None, model: str = 'htdemucs') -> dict:
    """
    Demucsによる音源分離（vocalsとno_vocalsを取得）
    
    Args:
        input_path: 入力音声ファイルパス
        output_dir: 出力ディレクトリ（Noneの場合は自動生成）
        model: 分離モデル
    
    Returns:
        各パートの音声ファイルパスの辞書（vocals, no_vocals）
    
    Raises:
        FileNotFoundError: demucsが見つからない場合
        RuntimeError: 音源分離に失敗した場合
    """
    if not os.path.exists(input_path):
        raise ValueError(f"入力ファイルが見つかりません: {input_path}")
    
    if output_dir is None:
        output_dir = str(Path(input_path).parent / "separated_temp")
    else:
        output_dir = str(output_dir)
    
    os.makedirs(output_dir, exist_ok=True)
    
    print(f"🎵 音源分離中...")
    print(f"   使用モデル: {model}")
    print(f"   入力: {input_path}")
    print(f"   出力先: {output_dir}")
    print(f"   ※初回実行時はモデルのダウンロードで数分かかります")
    
    cmd = [
        'demucs',
        '-n', model,
        '-o', output_dir,
        '--two-stems=vocals',  # vocalsとno_vocalsのみ出力（高速）
        input_path
    ]
    
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, check=False)
        
        if result.returncode != 0:
            error_msg = "音源分離に失敗しました"
            if result.stderr:
                stderr_lines = result.stderr.split('\n')
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
            raise RuntimeError(error_msg)
    except FileNotFoundError:
        raise FileNotFoundError(
            "demucsが見つかりません。`pip install demucs`でインストールしてください。"
        )
    
    # 出力ファイルのパスを返す
    input_name = Path(input_path).stem
    output_path = Path(output_dir) / model / input_name
    vocals_path = output_path / "vocals.wav"
    no_vocals_path = output_path / "no_vocals.wav"
    
    if not vocals_path.exists():
        raise RuntimeError(f"ボーカルファイルが生成されませんでした: {vocals_path}")
    if not no_vocals_path.exists():
        raise RuntimeError(f"伴奏ファイルが生成されませんでした: {no_vocals_path}")
    
    print(f"✅ 音源分離完了")
    print(f"   ボーカル: {vocals_path}")
    print(f"   伴奏: {no_vocals_path}")
    
    return {
        'vocals': str(vocals_path),
        'no_vocals': str(no_vocals_path)
    }


def replace_audio_in_video(video_path: str, audio_path: str, output_video_path: str) -> str:
    """
    動画ファイルの音声トラックを差し替える
    
    Args:
        video_path: 元の動画ファイルパス
        audio_path: 新しい音声ファイルパス
        output_video_path: 出力動画ファイルパス
    
    Returns:
        出力動画ファイルのパス
    
    Raises:
        FileNotFoundError: ffmpegが見つからない場合
        RuntimeError: 音声差し替えに失敗した場合
    """
    if not os.path.exists(video_path):
        raise ValueError(f"動画ファイルが見つかりません: {video_path}")
    if not os.path.exists(audio_path):
        raise ValueError(f"音声ファイルが見つかりません: {audio_path}")
    
    print(f"🔄 動画の音声を差し替え中...")
    print(f"   元の動画: {video_path}")
    print(f"   新しい音声: {audio_path}")
    print(f"   出力: {output_video_path}")
    
    # ffmpegで音声を差し替え
    # -i video: 動画ファイル
    # -i audio: 音声ファイル
    # -c:v copy: 動画コーデックをコピー（再エンコードしない）
    # -c:a aac: 音声コーデックをAACに設定（MOV形式に適したコーデック）
    # -map 0:v:0: 最初の入力（動画）の動画ストリームを使用
    # -map 1:a:0: 2番目の入力（音声）の音声ストリームを使用
    # -shortest: 最短のストリームに合わせる
    cmd = [
        'ffmpeg', '-y', '-loglevel', 'error',
        '-i', video_path,
        '-i', audio_path,
        '-c:v', 'copy',  # 動画はコピー（再エンコードしない）
        '-c:a', 'aac',   # 音声はAACにエンコード（MOV形式に適したコーデック）
        '-b:a', '192k',  # 音声ビットレート 192kbps
        '-map', '0:v:0',  # 動画ストリーム
        '-map', '1:a:0',  # 音声ストリーム
        '-shortest',      # 最短のストリームに合わせる
        output_video_path
    ]
    
    result = subprocess.run(cmd, capture_output=True, text=True)
    
    if result.returncode != 0:
        error_msg = "音声差し替えに失敗しました"
        if result.stderr:
            error_msg += f": {result.stderr.strip()}"
        raise RuntimeError(error_msg)
    
    if not os.path.exists(output_video_path) or os.path.getsize(output_video_path) == 0:
        raise RuntimeError(f"出力動画ファイルが正常に生成されませんでした: {output_video_path}")
    
    print(f"✅ 音声差し替え完了")
    return output_video_path


def check_tools_available() -> bool:
    """
    必要なツールが利用可能かチェック
    
    Returns:
        すべてのツールが利用可能な場合True
    """
    import shutil
    
    tools = {
        'ffmpeg': shutil.which('ffmpeg'),
        'demucs': shutil.which('demucs')
    }
    
    all_available = True
    for tool_name, tool_path in tools.items():
        if tool_path is None:
            print(f"❌ {tool_name}が見つかりません")
            if tool_name == 'ffmpeg':
                print("   macOS: brew install ffmpeg")
                print("   Ubuntu/Debian: sudo apt install ffmpeg")
            elif tool_name == 'demucs':
                print("   pip install demucs")
            all_available = False
        else:
            print(f"✅ {tool_name}: 利用可能 ({tool_path})")
    
    return all_available


def main():
    """メイン処理"""
    if len(sys.argv) < 2:
        print("使用方法: python remove_vocals_from_mov.py <MOVファイルパス>")
        print("\n例:")
        print("  python remove_vocals_from_mov.py wefunk_2025.MOV")
        sys.exit(1)
    
    mov_path = sys.argv[1]
    
    # ファイルの存在確認
    if not os.path.exists(mov_path):
        print(f"❌ エラー: ファイルが見つかりません: {mov_path}")
        sys.exit(1)
    
    # ツールの確認
    print("=" * 60)
    print("🔧 必要なツールの確認")
    print("=" * 60)
    if not check_tools_available():
        print("\n❌ 必要なツールがインストールされていません。")
        sys.exit(1)
    print()
    
    # 作業ディレクトリを設定
    mov_file = Path(mov_path)
    work_dir = mov_file.parent
    mov_stem = mov_file.stem
    
    # 一時ファイルと出力ファイルのパス
    temp_audio = work_dir / f"{mov_stem}_temp_audio.wav"
    separated_dir = work_dir / "separated_temp"
    output_mov = work_dir / f"{mov_stem}_no_vocals.MOV"
    
    try:
        print("=" * 60)
        print("🎬 MOVファイルから人の声を削除")
        print("=" * 60)
        print(f"入力ファイル: {mov_path}")
        print(f"出力ファイル: {output_mov}")
        print()
        
        # ステップ1: 動画から音声を抽出
        print("=" * 60)
        print("ステップ 1/3: 動画から音声を抽出")
        print("=" * 60)
        extract_audio_from_video(mov_path, str(temp_audio))
        print()
        
        # ステップ2: 音源分離（人の声を削除）
        print("=" * 60)
        print("ステップ 2/3: 音源分離（人の声を削除）")
        print("=" * 60)
        separated = separate_vocals(str(temp_audio), str(separated_dir))
        no_vocals_path = separated['no_vocals']
        print()
        
        # ステップ3: 動画の音声を差し替え
        print("=" * 60)
        print("ステップ 3/3: 動画の音声を差し替え")
        print("=" * 60)
        replace_audio_in_video(mov_path, no_vocals_path, str(output_mov))
        print()
        
        # 完了メッセージ
        print("=" * 60)
        print("✅ 処理完了！")
        print("=" * 60)
        print(f"出力ファイル: {output_mov}")
        file_size_mb = os.path.getsize(output_mov) / (1024 * 1024)
        print(f"ファイルサイズ: {file_size_mb:.2f} MB")
        print()
        print("💡 元のファイルは保持されています。")
        print("   人の声が削除された動画が出力されました。")
        print("=" * 60)
        
    except Exception as e:
        print()
        print("=" * 60)
        print("❌ エラーが発生しました")
        print("=" * 60)
        print(f"{e}")
        import traceback
        print("\n詳細:")
        traceback.print_exc()
        sys.exit(1)
    
    finally:
        # 一時ファイルのクリーンアップ
        print()
        print("🧹 一時ファイルをクリーンアップ中...")
        cleanup_files = [
            temp_audio,
        ]
        
        for file_path in cleanup_files:
            if file_path.exists():
                try:
                    file_path.unlink()
                    print(f"   削除: {file_path.name}")
                except OSError as e:
                    print(f"   ⚠️ 削除失敗: {file_path.name} ({e})")
        
        # 分離結果のディレクトリは残しておく（デバッグ用）
        if separated_dir.exists():
            print(f"   💾 分離結果は保持されています: {separated_dir}")
        
        print("✅ クリーンアップ完了")


if __name__ == "__main__":
    main()

