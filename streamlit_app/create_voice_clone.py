"""
Fish Audio 音声クローンモデル作成スクリプト（Streamlit用カスタマイズ版）

このスクリプトは、sample_voice.wavから音声クローンモデルを作成します。
Streamlitアプリケーション用にカスタマイズされています。
model_id.txtへの保存処理は削除され、models.jsonでの管理に統一されています。
"""

from fish_audio_sdk import Session
import os
from pathlib import Path

# .envファイルがあれば読み込む
try:
    from dotenv import load_dotenv
    env_path = Path(__file__).parent.parent / '.env'
    load_dotenv(dotenv_path=env_path)
except ImportError:
    pass  # python-dotenvがインストールされていない場合はスキップ

def create_voice_clone_model(
    api_key: str,
    audio_file_path: str,
    model_title: str = "My Custom Voice",
    model_description: str = "Voice cloned from sample audio",
    transcription: str = "",
    visibility: str = "private"
):
    """
    音声ファイルから音声クローンモデルを作成します。
    
    Parameters:
    -----------
    api_key : str
        Fish AudioのAPIキー
    audio_file_path : str
        音声ファイルのパス
    model_title : str
        作成するモデルのタイトル
    model_description : str
        モデルの説明
    transcription : str
        音声ファイルの文字起こし（推奨）
    visibility : str
        モデルの公開設定 ("private", "public", "unlist")
    
    Returns:
    --------
    model_id : str
        作成されたモデルのID
    """
    
    # セッションの作成
    session = Session(api_key)
    
    # 音声ファイルの存在確認
    if not os.path.exists(audio_file_path):
        raise FileNotFoundError(f"音声ファイルが見つかりません: {audio_file_path}")
    
    print(f"音声ファイルを読み込んでいます: {audio_file_path}")
    
    # 音声データの読み込み
    with open(audio_file_path, "rb") as f:
        audio_data = f.read()
    
    print("音声クローンモデルを作成中...")
    
    # モデルの作成
    model = session.create_model(
        title=model_title,
        description=model_description,
        voices=[audio_data],  # 複数のサンプルを指定可能
        texts=[transcription] if transcription else [""],
        visibility=visibility,
        enhance_audio_quality=True  # 音質向上オプション
    )
    
    print(f"\n✓ モデルの作成が完了しました！")
    print(f"モデルID: {model.id}")
    print(f"モデル名: {model.title}")
    print(f"\nこのモデルIDを使用してTTSを実行できます。")
    
    # model_id.txtへの保存処理は削除（models.jsonで管理）
    
    return model.id


def list_existing_models(api_key: str):
    """
    既存の音声モデルをリスト表示します。
    
    Parameters:
    -----------
    api_key : str
        Fish AudioのAPIキー
    """
    session = Session(api_key)
    
    print("\n=== 既存のモデル一覧 ===")
    models = session.list_models(self_only=True, page_size=20)
    
    if not models.items:
        print("モデルが見つかりませんでした。")
        return
    
    for i, model in enumerate(models.items, 1):
        print(f"{i}. {model.title} (ID: {model.id})")
        if model.description:
            print(f"   説明: {model.description}")
    
    print(f"\n合計: {len(models.items)} モデル")


if __name__ == "__main__":
    # APIキーを環境変数から取得
    API_KEY = os.getenv("FISH_AUDIO_API_KEY")
    
    if not API_KEY:
        print("エラー: APIキーが設定されていません！")
        print("環境変数 FISH_AUDIO_API_KEY を設定してください。")
        print("\nPowerShellの場合:")
        print('  $env:FISH_AUDIO_API_KEY = "your_api_key_here"')
        print("\nまたは .env ファイルを作成して読み込んでください。")
        exit(1)
    
    # 使用例
    print("=== Fish Audio 音声クローンモデル作成 ===\n")
    
    # 音声ファイルのパス
    AUDIO_FILE = os.path.join(os.path.dirname(__file__), "..", "examples", "sample_voice_aya.m4a")
    
    # モデルの設定
    MODEL_TITLE = "Sample Voice Clone"
    MODEL_DESCRIPTION = "sample_voice.wavから作成した音声クローン"
    TRANSCRIPTION = ""  # 可能であれば音声の文字起こしを入力
    
    try:
        # 既存モデルの確認
        list_existing_models(API_KEY)
        
        print("\n" + "="*50 + "\n")
        
        # 新しいモデルの作成
        model_id = create_voice_clone_model(
            api_key=API_KEY,
            audio_file_path=AUDIO_FILE,
            model_title=MODEL_TITLE,
            model_description=MODEL_DESCRIPTION,
            transcription=TRANSCRIPTION,
            visibility="private"
        )
        
        print("\n" + "="*50)
        print("次のステップ:")
        print("1. models.json に保存されたモデル情報を確認")
        print("2. generate_tts.py を実行してTTSを試す")
        print("="*50)
        
    except FileNotFoundError as e:
        print(f"\nエラー: {e}")
        print(f"\n'{AUDIO_FILE}' ファイルを用意してください。")
    except Exception as e:
        print(f"\nエラーが発生しました: {e}")
        import traceback
        traceback.print_exc()

