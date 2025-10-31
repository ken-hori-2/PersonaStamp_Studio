"""
Fish Audio TTS - 音声クローン作成の完全ワークフロー

このスクリプトは以下のステップを案内します:
1. YouTubeから音声をダウンロード（オプション）
2. 音源分離でボーカルを抽出（オプション）
3. 音声クローンモデルを作成
4. TTSで音声を生成

使い方:
    python workflow.py
"""

import os
import sys
from pathlib import Path

def print_header(text):
    print("\n" + "=" * 70)
    print(f"  {text}")
    print("=" * 70 + "\n")

def print_step(step, text):
    print(f"\n【ステップ {step}】 {text}")
    print("-" * 70)

def get_choice(prompt, valid_choices):
    while True:
        choice = input(prompt).strip().lower()
        if choice in valid_choices:
            return choice
        print(f"無効な入力です。{valid_choices} から選択してください。")

def main():
    print_header("🎤 Fish Audio - 音声クローン作成ワークフロー")
    
    print("このツールは音声クローンモデルの作成を段階的にサポートします。\n")
    
    # ステップ1: 音声ソースの選択
    print_step(1, "音声ソースの選択")
    print("1. 既存の音声ファイルを使用")
    print("2. YouTubeから音声をダウンロード")
    
    source_choice = get_choice("\n選択してください (1/2): ", ['1', '2'])
    
    audio_file = None
    
    if source_choice == '2':
        # YouTubeダウンロード
        url = input("\nYouTubeのURLを入力: ").strip()
        if url:
            print("\nダウンロード中...")
            try:
                from src.utils.youtube_downloader import download_youtube_as_wav
                audio_file = download_youtube_as_wav(url)
                print(f"✓ ダウンロード完了: {audio_file}")
            except Exception as e:
                print(f"エラー: {e}")
                print("yt-dlpとffmpegがインストールされているか確認してください。")
                sys.exit(1)
    else:
        # 既存ファイル
        default_path = "examples"
        print(f"\n'{default_path}' フォルダ内のファイル:")
        examples_dir = Path(default_path)
        if examples_dir.exists():
            audio_files = list(examples_dir.glob("*.wav")) + list(examples_dir.glob("*.mp3"))
            for i, f in enumerate(audio_files, 1):
                print(f"  {i}. {f.name}")
        
        audio_file = input("\n音声ファイルのパスを入力: ").strip()
    
    if not audio_file or not os.path.exists(audio_file):
        print(f"エラー: ファイルが見つかりません: {audio_file}")
        sys.exit(1)
    
    # ステップ2: 音源分離の確認
    print_step(2, "音源分離（ボーカル抽出）")
    print("音楽ファイルの場合、ボーカル（人の声）のみを抽出することを推奨します。")
    
    separate = get_choice("\n音源分離を実行しますか？ (y/n): ", ['y', 'n', 'yes', 'no'])
    
    vocal_file = audio_file
    
    if separate in ['y', 'yes']:
        print("\n音源分離モデル:")
        print("1. htdemucs - 最高品質（推奨）")
        print("2. htdemucs_ft - 最高品質・fine-tuned版")
        print("3. mdx_extra - 超高品質（処理時間長）")
        
        model_choice = get_choice("\n選択してください (1/2/3, Enter=1): ", ['1', '2', '3', '']) or '1'
        
        models = {
            '1': 'htdemucs',
            '2': 'htdemucs_ft',
            '3': 'mdx_extra'
        }
        model = models[model_choice]
        
        print(f"\n音源分離を実行中（モデル: {model}）...")
        print("※初回実行時はモデルのダウンロードで数分かかります\n")
        
        try:
            from src.utils.audio_separation import separate_vocals
            vocal_file = separate_vocals(audio_file, model=model)
            print(f"✓ ボーカル抽出完了: {vocal_file}")
        except Exception as e:
            print(f"エラー: {e}")
            print("demucsがインストールされているか確認してください: pip install demucs")
            use_original = get_choice("\n元のファイルを使用しますか？ (y/n): ", ['y', 'n'])
            if use_original != 'y':
                sys.exit(1)
            vocal_file = audio_file
    
    # ステップ3: 音声クローンモデルの作成
    print_step(3, "音声クローンモデルの作成")
    
    print(f"使用する音声ファイル: {vocal_file}")
    
    model_title = input("\nモデル名を入力（Enter=デフォルト）: ").strip() or "My Voice Clone"
    model_desc = input("モデルの説明（Enter=スキップ）: ").strip() or f"Created from {Path(vocal_file).name}"
    
    print("\n音声クローンモデルを作成中...")
    print("※APIクレジットを消費します\n")
    
    # APIキーの確認
    api_key = os.getenv("FISH_AUDIO_API_KEY")
    if not api_key:
        print("エラー: FISH_AUDIO_API_KEY が設定されていません")
        print(".envファイルを作成するか、環境変数を設定してください")
        sys.exit(1)
    
    try:
        from src.create_voice_clone import create_voice_clone_model
        model_id = create_voice_clone_model(
            api_key=api_key,
            audio_file_path=vocal_file,
            model_title=model_title,
            model_description=model_desc
        )
        print(f"\n✓ モデル作成完了!")
        print(f"モデルID: {model_id}")
    except Exception as e:
        print(f"エラー: {e}")
        sys.exit(1)
    
    # ステップ4: TTS生成
    print_step(4, "TTS音声生成（オプション）")
    
    test_tts = get_choice("\nすぐにTTSをテストしますか？ (y/n): ", ['y', 'n'])
    
    if test_tts == 'y':
        text = input("\n生成するテキストを入力: ").strip()
        if text:
            print("\nTTS生成中...")
            try:
                from src.generate_tts import generate_tts
                output = generate_tts(
                    api_key=api_key,
                    text=text,
                    model_id=model_id,
                    output_file="test_output.wav"
                )
                print(f"\n✓ TTS生成完了: {output}")
            except Exception as e:
                print(f"エラー: {e}")
    
    # 完了
    print_header("✅ ワークフロー完了!")
    print("次のステップ:")
    print(f"  - モデルID: {model_id}")
    print("  - TTSの実行: python src/generate_tts.py")
    print("  - モデルIDは model_id.txt に保存されています")
    print("=" * 70 + "\n")

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n\n中断されました。")
        sys.exit(0)
