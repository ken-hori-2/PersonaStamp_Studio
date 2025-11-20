"""
長い音声ファイル（60秒など）からプロンプトを作成するスクリプト
"""
import argparse
import os
from pathlib import Path
import sys

# プロジェクトルートをパスに追加
project_root = Path(__file__).parent
sys.path.insert(0, str(project_root))

from utils.long_audio_prompt import (
    create_prompt_from_long_audio,
    create_multiple_prompts_from_long_audio,
)


def main():
    parser = argparse.ArgumentParser(
        description="長い音声ファイルからプロンプトを作成"
    )
    parser.add_argument(
        "audio_path",
        type=str,
        help="音声ファイルのパス（60秒など長いファイルも可）"
    )
    parser.add_argument(
        "--name",
        type=str,
        default="vocals",
        help="プロンプト名（デフォルト: vocals）"
    )
    parser.add_argument(
        "--segment-length",
        type=float,
        default=10.0,
        help="セグメントの長さ（秒、最大15秒、デフォルト: 10.0）"
    )
    parser.add_argument(
        "--method",
        type=str,
        default="energy",
        choices=["energy", "middle", "first", "last"],
        help="セグメント選択方法（デフォルト: energy）"
    )
    parser.add_argument(
        "--transcript",
        type=str,
        default=None,
        help="転写テキスト（省略可、Whisperで自動生成）"
    )
    parser.add_argument(
        "--multiple",
        action="store_true",
        help="複数のプロンプトを作成（各セグメントから）"
    )
    parser.add_argument(
        "--max-prompts",
        type=int,
        default=None,
        help="作成するプロンプトの最大数（--multiple使用時）"
    )
    
    args = parser.parse_args()
    
    if not os.path.exists(args.audio_path):
        print(f"❌ 音声ファイルが見つかりません: {args.audio_path}")
        return
    
    if args.segment_length > 15:
        print(f"⚠️  セグメント長さが15秒を超えています。15秒に制限します。")
        args.segment_length = 15.0
    
    if args.multiple:
        # 複数のプロンプトを作成
        print(f"🎯 複数のプロンプトを作成モード")
        prompt_paths = create_multiple_prompts_from_long_audio(
            base_name=args.name,
            audio_path=args.audio_path,
            segment_length=args.segment_length,
            max_prompts=args.max_prompts,
        )
        print(f"\n✅ 作成されたプロンプト:")
        for path in prompt_paths:
            print(f"   - {path}")
    else:
        # 単一のプロンプトを作成（最適なセグメントを選択）
        prompt_path = create_prompt_from_long_audio(
            name=args.name,
            audio_path=args.audio_path,
            segment_length=args.segment_length,
            selection_method=args.method,
            transcript=args.transcript,
        )
        print(f"\n📌 使用方法:")
        print(f"   python voice_clone.py generate \\")
        print(f"       --text 'テキスト' \\")
        print(f"       --prompt {args.name} \\")
        print(f"       --language ja \\")
        print(f"       --output output.wav")


if __name__ == "__main__":
    main()




