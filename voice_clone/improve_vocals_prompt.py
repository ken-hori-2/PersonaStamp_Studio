"""
vocalsプロンプトの精度を向上させるスクリプト
"""
import os
import sys
from pathlib import Path

# プロジェクトルートをパスに追加
project_root = Path(__file__).parent
sys.path.insert(0, str(project_root))

from utils.quality_improvement import preprocess_audio, create_high_quality_prompt

def main():
    print("=" * 60)
    print("🎯 vocalsプロンプトの精度向上")
    print("=" * 60)
    
    # 音声ファイルのパス
    audio_path = "vocals_10sec.wav"
    
    if not os.path.exists(audio_path):
        print(f"❌ 音声ファイルが見つかりません: {audio_path}")
        print("   利用可能なファイル:")
        for f in os.listdir("."):
            if f.endswith((".wav", ".mp3", ".ogg")):
                print(f"   - {f}")
        return
    
    print(f"\n📁 音声ファイル: {audio_path}")
    
    # ステップ1: 音声前処理
    print("\n🔧 ステップ1: 音声前処理を実行中...")
    processed_path = "vocals_processed.wav"
    
    try:
        wav, sr = preprocess_audio(
            audio_path,
            output_path=processed_path,
            normalize=True,
            remove_noise=False,  # noisereduceが必要な場合はTrueに変更
        )
        print(f"✅ 音声前処理が完了しました")
        print(f"   サンプリングレート: {sr} Hz")
        print(f"   長さ: {wav.size(-1) / sr:.2f} 秒")
    except Exception as e:
        print(f"⚠️  前処理でエラーが発生しました: {e}")
        processed_path = audio_path
    
    # ステップ2: 転写テキストの入力
    print("\n📝 ステップ2: 転写テキストの入力")
    print("   Whisperで自動生成する場合はEnterキーを押してください")
    print("   手動で入力する場合は転写テキストを入力してください（推奨）")
    
    transcript = input("   転写テキスト: ").strip()
    if not transcript:
        transcript = None
        print("   Whisperで自動生成します...")
    else:
        print(f"   転写テキスト: {transcript}")
    
    # ステップ3: 高品質プロンプトの作成
    print("\n🎤 ステップ3: 高品質プロンプトを作成中...")
    
    try:
        prompt_path = create_high_quality_prompt(
            name="vocals_improved",
            audio_path=processed_path,
            transcript=transcript,
            preprocess=False,  # 既に前処理済み
            whisper_model_size="medium",
        )
        print(f"✅ プロンプトが作成されました: {prompt_path}")
    except Exception as e:
        print(f"❌ プロンプト作成でエラーが発生しました: {e}")
        import traceback
        traceback.print_exc()
        return
    
    # クリーンアップ
    if os.path.exists(processed_path) and processed_path != audio_path:
        os.remove(processed_path)
        print(f"\n🧹 一時ファイルを削除しました: {processed_path}")
    
    print("\n" + "=" * 60)
    print("✅ 完了！")
    print("=" * 60)
    print("\n📌 使用方法:")
    print("   改善されたプロンプトを使用するには:")
    print("   python -c \"")
    print("   from utils.quality_improvement import generate_with_custom_params")
    print("   generate_with_custom_params(")
    print("       text='テストテキスト',")
    print("       prompt='vocals_improved',")
    print("       language='ja',")
    print("       temperature=0.8,")
    print("       top_k=50")
    print("   )")
    print("   \"")

if __name__ == "__main__":
    main()




