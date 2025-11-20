"""
音声クローンのメインスクリプト
VALL-E-Xスタイルの音声クローン機能を提供
"""
import argparse
import numpy as np
from pathlib import Path
from scipy.io.wavfile import write as write_wav
from utils.generation import SAMPLE_RATE, generate_audio, generate_audio_from_long_text, preload_models
from utils.prompt_making import make_prompt, list_prompts


def main():
    parser = argparse.ArgumentParser(description="VALL-E-Xスタイルの音声クローン")
    parser.add_argument(
        "mode",
        choices=["generate", "create_prompt", "list_prompts"],
        help="実行モード: generate (音声生成), create_prompt (プロンプト作成), list_prompts (プロンプト一覧)",
    )
    
    # 音声生成モードの引数
    parser.add_argument("--text", type=str, help="生成するテキスト")
    parser.add_argument("--prompt", type=str, help="音声プロンプト名またはファイルパス")
    parser.add_argument("--language", type=str, default="auto", choices=["auto", "en", "zh", "ja", "mix"], help="言語")
    parser.add_argument("--accent", type=str, default="no-accent", help="アクセント制御")
    parser.add_argument("--output", type=str, default="output.wav", help="出力ファイル名")
    parser.add_argument("--long-text", action="store_true", help="長文生成モードを使用")
    parser.add_argument("--mode", type=str, default="sliding-window", choices=["fixed-prompt", "sliding-window"], help="長文生成モード")
    
    # プロンプト作成モードの引数
    parser.add_argument("--name", type=str, help="プロンプト名")
    parser.add_argument("--audio", type=str, help="音声ファイルのパス")
    parser.add_argument("--transcript", type=str, help="転写テキスト（省略可）")
    
    args = parser.parse_args()
    
    if args.mode == "generate":
        # 音声生成
        if not args.text:
            print("❌ --text オプションが必要です")
            return
        
        print("🔄 モデルをロード中...")
        preload_models()
        
        print(f"📝 テキスト: {args.text}")
        if args.prompt:
            print(f"🎤 プロンプト: {args.prompt}")
        
        if args.long_text:
            audio_array = generate_audio_from_long_text(
                text=args.text,
                prompt=args.prompt,
                language=args.language,
                accent=args.accent,
                mode=args.mode,
            )
        else:
            audio_array = generate_audio(
                text=args.text,
                prompt=args.prompt,
                language=args.language,
                accent=args.accent,
            )
        
        write_wav(args.output, SAMPLE_RATE, audio_array)
        print(f"✓ 音声を保存しました: {args.output}")
    
    elif args.mode == "create_prompt":
        # プロンプト作成
        if not args.name or not args.audio:
            print("❌ --name と --audio オプションが必要です")
            return
        
        make_prompt(
            name=args.name,
            audio_prompt_path=args.audio,
            transcript=args.transcript,
        )
    
    elif args.mode == "list_prompts":
        # プロンプト一覧
        prompts = list_prompts()
        if prompts:
            print("📋 利用可能なプロンプト:")
            for prompt in prompts:
                print(f"  - {prompt}")
        else:
            print("プロンプトがありません")


if __name__ == "__main__":
    main()
