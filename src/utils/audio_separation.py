"""
Demucsによる高精度音源分離（ボーカル抽出）

このスクリプトは音楽ファイルからボーカル（人の声）を抽出します。
Fish Audio の音声クローンに最適な音声を準備できます。

必要なインストール:
    pip install demucs
"""

import subprocess
import sys
import os
from pathlib import Path

def separate_vocals(input_path, output_dir=None, model='htdemucs'):
    """
    Demucsによる高精度音声分離
    
    Args:
        input_path (str): 入力音声ファイルパス
        output_dir (str): 出力ディレクトリ（デフォルト: ../separated）
        model (str): 分離モデル
            - 'htdemucs': 最高品質（推奨・デフォルト）
            - 'htdemucs_ft': 最高品質・fine-tuned版
            - 'mdx_extra': 超高品質（処理時間長）
            - 'mdx_extra_q': 超高品質・量子化版
    
    Returns:
        str: ボーカル音声ファイルのパス
    """
    if output_dir is None:
        output_dir = os.path.join(os.path.dirname(__file__), "..", "..", "separated")
    
    print(f"=" * 60)
    print(f"Demucs 音源分離")
    print(f"=" * 60)
    print(f"使用モデル: {model}")
    print(f"入力ファイル: {input_path}")
    print(f"出力先: {output_dir}")
    print(f"\n※初回実行時はモデルのダウンロードで数分かかります")
    print(f"=" * 60 + "\n")
    
    # Demucsコマンドを実行
    # -n: モデル名
    # -o: 出力ディレクトリ
    # --two-stems=vocals: ボーカルとその他の2つに分離（高速化）
    cmd = [
        'demucs',
        '-n', model,
        '-o', output_dir,
        '--two-stems=vocals',  # vocalsとno_vocalsのみ出力（高速）
        input_path
    ]
    
    try:
        result = subprocess.run(cmd, check=True, capture_output=True, text=True)
        print(result.stdout)
    except subprocess.CalledProcessError as e:
        print(f"エラー: {e}")
        print(f"標準エラー: {e.stderr}")
        sys.exit(1)
    except FileNotFoundError:
        print("エラー: demucs が見つかりません")
        print("以下のコマンドでインストールしてください:")
        print("  pip install demucs")
        sys.exit(1)
    
    # 出力ファイルの場所を表示
    input_name = Path(input_path).stem
    output_path = Path(output_dir) / model / input_name
    vocals_path = output_path / "vocals.wav"
    
    print(f"\n" + "=" * 60)
    print(f"✓ 分離完了!")
    print(f"=" * 60)
    print(f"出力先: {output_path}")
    print(f"  📢 vocals.wav: ボーカルのみ（人の声）")
    print(f"  🎵 no_vocals.wav: 伴奏のみ（BGM・楽器）")
    print(f"\n次のステップ:")
    print(f"  1. vocals.wav を確認")
    print(f"  2. create_voice_clone.py で音声クローンを作成")
    print(f"=" * 60)
    
    return str(vocals_path)


def separate_vocals_full(input_path, output_dir=None, model='htdemucs'):
    """
    完全分離（vocals, drums, bass, other）
    
    Args:
        input_path (str): 入力音声ファイルパス
        output_dir (str): 出力ディレクトリ
        model (str): 分離モデル
    
    Returns:
        dict: 各パートの音声ファイルパス
    """
    if output_dir is None:
        output_dir = os.path.join(os.path.dirname(__file__), "..", "..", "separated")
    
    print(f"=" * 60)
    print(f"Demucs 完全音源分離 (4-stem)")
    print(f"=" * 60)
    print(f"使用モデル: {model}")
    print(f"入力ファイル: {input_path}")
    print(f"※4stem分離（vocals/drums/bass/other）実行中...")
    print(f"=" * 60 + "\n")
    
    cmd = [
        'demucs',
        '-n', model,
        '-o', output_dir,
        input_path
    ]
    
    try:
        result = subprocess.run(cmd, check=True, capture_output=True, text=True)
        print(result.stdout)
    except subprocess.CalledProcessError as e:
        print(f"エラー: {e}")
        print(f"標準エラー: {e.stderr}")
        sys.exit(1)
    except FileNotFoundError:
        print("エラー: demucs が見つかりません")
        print("インストール: pip install demucs")
        sys.exit(1)
    
    input_name = Path(input_path).stem
    output_path = Path(output_dir) / model / input_name
    
    print(f"\n" + "=" * 60)
    print(f"✓ 分離完了!")
    print(f"=" * 60)
    print(f"出力先: {output_path}")
    print(f"  📢 vocals.wav: ボーカル")
    print(f"  🥁 drums.wav: ドラム")
    print(f"  🎸 bass.wav: ベース")
    print(f"  🎹 other.wav: その他の楽器")
    print(f"=" * 60)
    
    return {
        'vocals': str(output_path / 'vocals.wav'),
        'drums': str(output_path / 'drums.wav'),
        'bass': str(output_path / 'bass.wav'),
        'other': str(output_path / 'other.wav'),
    }


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("=" * 60)
        print("Demucs 音源分離ツール")
        print("=" * 60)
        print("\n使い方:")
        print("  python audio_separation.py <入力ファイル> [モード] [モデル]")
        print("\nモード:")
        print("  vocal (デフォルト): ボーカルのみ分離（高速・推奨）")
        print("  full: 4-stem完全分離（vocals/drums/bass/other）")
        print("\nモデル:")
        print("  htdemucs (デフォルト): 最高品質（推奨）")
        print("  htdemucs_ft: 最高品質・fine-tuned版")
        print("  mdx_extra: 超高品質（処理時間長）")
        print("\n例:")
        print("  python audio_separation.py song.mp3")
        print("  python audio_separation.py song.mp3 full")
        print("  python audio_separation.py song.mp3 vocal htdemucs_ft")
        print("=" * 60)
        sys.exit(1)
    
    input_file = sys.argv[1]
    mode = sys.argv[2] if len(sys.argv) > 2 else 'vocal'
    model = sys.argv[3] if len(sys.argv) > 3 else 'htdemucs'
    
    if not os.path.exists(input_file):
        print(f"エラー: ファイルが見つかりません: {input_file}")
        sys.exit(1)
    
    if mode.lower() == 'full':
        separate_vocals_full(input_file, model=model)
    else:
        separate_vocals(input_file, model=model)
