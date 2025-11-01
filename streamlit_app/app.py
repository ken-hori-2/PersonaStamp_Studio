"""
Fish Audio Studio - Streamlit Web UI

音声クローン作成とTTS生成のためのWebインターフェース
"""

import streamlit as st
import os
from pathlib import Path
import tempfile
from datetime import datetime
import json

# Whisper用のインポート
try:
    import whisper
    WHISPER_AVAILABLE = True
except ImportError:
    WHISPER_AVAILABLE = False

# 既存のモジュールをインポート（streamlit_appフォルダ内のカスタマイズ版を使用）
from create_voice_clone import create_voice_clone_model, list_existing_models
from generate_tts import generate_tts, load_model_id_from_file, check_api_credit

# .envファイルがあれば読み込む
try:
    from dotenv import load_dotenv
    env_path = Path(__file__).parent.parent / '.env'
    load_dotenv(dotenv_path=env_path)
except ImportError:
    pass

# ページ設定
st.set_page_config(
    page_title="Fish Audio Studio",
    page_icon="🎤",
    layout="wide"
)

def init_session_state():
    """セッション状態の初期化"""
    if "fish_audio_api_key" not in st.session_state:
        try:
            st.session_state.fish_audio_api_key = os.environ.get("FISH_AUDIO_API_KEY", "")
        except:
            st.session_state.fish_audio_api_key = ""
    
    if "models" not in st.session_state:
        st.session_state.models = []
    
    # モデル辞書: {モデル名: モデルID} のマッピング
    if "models_dict" not in st.session_state:
        st.session_state.models_dict = {}
        # JSONファイルから読み込む
        json_data = load_models_from_json()
        for model_entry in json_data.get("models", []):
            name = model_entry.get("name", "")
            model_id = model_entry.get("id", "")
            if name and model_id:
                st.session_state.models_dict[name] = model_id
    
    if "show_model_management" not in st.session_state:
        st.session_state.show_model_management = False
    
    if "last_model_id" not in st.session_state:
        json_data = load_models_from_json()
        last_used = json_data.get("last_used", {})
        st.session_state.last_model_id = last_used.get("id", "")
    
    if "last_model_name" not in st.session_state:
        json_data = load_models_from_json()
        last_used = json_data.get("last_used", {})
        st.session_state.last_model_name = last_used.get("name", "")
    
    if "tts_output_file" not in st.session_state:
        st.session_state.tts_output_file = None
    
    if "tts_audio_bytes" not in st.session_state:
        st.session_state.tts_audio_bytes = None
    
    if "tts_format" not in st.session_state:
        st.session_state.tts_format = "wav"

def get_models_json_path() -> Path:
    """models.jsonファイルのパスを取得"""
    return Path(__file__).parent / "models.json"

def load_models_from_json() -> dict:
    """JSONファイルからモデル情報を読み込む"""
    json_path = get_models_json_path()
    
    if not json_path.exists():
        return {"models": [], "last_used": {"name": "", "id": ""}}
    
    try:
        with open(json_path, "r", encoding="utf-8") as f:
            data = json.load(f)
            # 旧形式の互換性
            if "models" not in data:
                data = {"models": [], "last_used": {"name": "", "id": ""}}
            return data
    except Exception:
        return {"models": [], "last_used": {"name": "", "id": ""}}

def save_models_to_json(data: dict):
    """JSONファイルにモデル情報を保存"""
    json_path = get_models_json_path()
    with open(json_path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

def add_model_to_json(name: str, model_id: str, description: str = ""):
    """JSONファイルにモデルを追加"""
    data = load_models_from_json()
    
    # 既存のモデルを確認（同じIDがあれば上書き、同じ名前があれば削除）
    data["models"] = [m for m in data["models"] if m["id"] != model_id and m["name"] != name]
    
    # 新しいモデルを追加
    model_entry = {
        "name": name,
        "id": model_id,
        "description": description,
        "created_at": datetime.now().isoformat()
    }
    data["models"].append(model_entry)
    
    # 最後に使用したモデルを更新
    data["last_used"] = {"name": name, "id": model_id}
    
    save_models_to_json(data)

def delete_model_from_json(model_id: str = None, model_name: str = None):
    """JSONファイルからモデルを削除"""
    data = load_models_from_json()
    
    if model_id:
        data["models"] = [m for m in data["models"] if m["id"] != model_id]
    elif model_name:
        data["models"] = [m for m in data["models"] if m["name"] != model_name]
    
    # 最後に使用したモデルが削除された場合、リセット
    last_used = data.get("last_used", {})
    if (last_used.get("id") == model_id or last_used.get("name") == model_name):
        data["last_used"] = {"name": "", "id": ""}
    
    save_models_to_json(data)
    return True

def get_session():
    """Fish Audioセッションを取得"""
    from fish_audio_sdk import Session
    return Session(st.session_state.fish_audio_api_key)

def update_models_dict():
    """モデルリストからモデル辞書を更新（JSONファイルは更新しない）"""
    # APIから取得したモデルで辞書を更新（表示用）
    api_models_dict = {}
    for model in st.session_state.models:
        api_models_dict[model.title] = model.id
    
    # JSONファイルから読み込んだモデルを優先（ユーザーが管理しているモデル）
    json_data = load_models_from_json()
    json_models_dict = {}
    for model_entry in json_data.get("models", []):
        name = model_entry.get("name", "")
        model_id = model_entry.get("id", "")
        if name and model_id:
            json_models_dict[name] = model_id
    
    # JSONに保存されているモデルを優先して辞書を構築
    # これにより、削除したモデルはJSONから削除されていれば表示されない
    st.session_state.models_dict = json_models_dict

def transcribe_audio_with_whisper(audio_file_path: str, language: str = "ja") -> str:
    """Whisperを使用して音声ファイルを文字起こし"""
    if not WHISPER_AVAILABLE:
        return ""
    
    try:
        # Whisperモデルの読み込み（初回のみ、セッション状態にキャッシュ）
        if "whisper_model" not in st.session_state:
            with st.spinner("Whisperモデルを読み込んでいます（初回のみ）..."):
                st.session_state.whisper_model = whisper.load_model("base")
        
        model = st.session_state.whisper_model
        
        # 音声認識を実行
        result = model.transcribe(
            audio_file_path,
            language=language,
            task="transcribe",
            fp16=False
        )
        
        text = result["text"].strip()
        return text
    except Exception as e:
        st.warning(f"文字起こしに失敗しました: {e}")
        return ""

def get_model_id_from_name_or_id(model_input: str) -> str:
    """モデル名またはIDからモデルIDを取得"""
    if not model_input or not model_input.strip():
        return None
    
    model_input = model_input.strip()
    
    # モデル名で検索（セッション状態の辞書）
    if model_input in st.session_state.models_dict:
        return st.session_state.models_dict[model_input]
    
    # JSONファイルからも検索
    json_data = load_models_from_json()
    for model_entry in json_data.get("models", []):
        if model_entry.get("name") == model_input:
            return model_entry.get("id")
        if model_entry.get("id") == model_input:
            return model_entry.get("id")
    
    # APIから取得したモデルリストで検索
    for model in st.session_state.models:
        if model.id == model_input:
            return model.id
    
    # そのまま返す（API側で検証される）
    return model_input

def sidebar():
    """サイドバーの設定"""
    with st.sidebar:
        st.title("⚙️ 設定")
        
        # APIキー入力
        api_key = st.text_input(
            "Fish Audio API Key",
            type="password",
            value=st.session_state.fish_audio_api_key,
            help="Fish AudioのAPIキーを入力してください"
        )
        
        if api_key:
            st.session_state.fish_audio_api_key = api_key
        
        st.markdown("---")
        st.markdown("**ローカル実行時:**\n環境変数 `FISH_AUDIO_API_KEY` が設定されていれば、入力不要です。")
        
        # APIキーが設定されている場合、クレジット残高を表示
        if st.session_state.fish_audio_api_key:
            st.markdown("---")
            if st.button("📊 クレジット残高を確認"):
                try:
                    session = get_session()
                    credit = session.get_api_credit()
                    st.success(f"クレジット残高: {credit.credit}")
                except Exception as e:
                    st.error(f"エラー: {e}")

def page_create_voice_clone():
    """音声クローンモデル作成ページ"""
    st.markdown("## 🎤 音声クローンモデル作成")
    st.markdown("音声ファイルから音声クローンモデルを作成します。")
    st.markdown("---")
    
    if not st.session_state.fish_audio_api_key:
        st.warning("⚠️ サイドバーでAPIキーを設定してください。")
        return
    
    # フォーム外でファイルアップロード（自動文字起こしを先に実行するため）
    with st.container():
        st.markdown("### 📁 音声ファイルのアップロード")
        uploaded_file = st.file_uploader(
            "音声ファイルをドラッグ&ドロップ、またはクリックして選択",
            type=["wav", "mp3", "m4a", "flac", "ogg"],
            help="音声サンプルをアップロードしてください（WAV、MP3、M4A形式対応）",
            key="voice_file_uploader",
            label_visibility="collapsed"
        )
    
    # 新しいファイルがアップロードされたら、以前の文字起こし結果をクリア
    if uploaded_file:
        if "last_uploaded_file_name" not in st.session_state:
            st.session_state.last_uploaded_file_name = None
        
        if st.session_state.last_uploaded_file_name != uploaded_file.name:
            # 新しいファイルがアップロードされた
            st.session_state.last_uploaded_file_name = uploaded_file.name
            if "transcription_auto_text" in st.session_state:
                del st.session_state.transcription_auto_text
            # テキストエリアの入力もクリア
            if "transcription_input" in st.session_state:
                st.session_state.transcription_input = ""
            # ユーザー編集フラグをリセット
            if "transcription_edited_by_user" in st.session_state:
                del st.session_state.transcription_edited_by_user
            # 処理済みファイルをリセットして再処理可能にする
            if "last_processed_file" in st.session_state:
                del st.session_state.last_processed_file
            # 自動適用フラグもクリア（既存のファイル名のフラグをすべてクリア）
            keys_to_delete = [key for key in st.session_state.keys() if key.startswith("transcription_auto_applied_")]
            for key in keys_to_delete:
                del st.session_state[key]
    
    # 自動文字起こしの実行（音声ファイルアップロード後、フォーム表示前に実行）
    current_file_name = None
    if uploaded_file is not None:
        # 自動文字起こしが有効で、新しいファイルがアップロードされた場合
        if "auto_transcribe_enabled" not in st.session_state:
            st.session_state.auto_transcribe_enabled = True  # デフォルトで有効
        
        if "last_processed_file" not in st.session_state:
            st.session_state.last_processed_file = None
        
        current_file_name = uploaded_file.name if hasattr(uploaded_file, 'name') else None
        
        auto_transcribe_enabled = st.session_state.get("auto_transcribe_enabled", True)
        
        # 文字起こし実行条件のチェック
        should_transcribe = (
            auto_transcribe_enabled and 
            current_file_name and 
            current_file_name != st.session_state.last_processed_file and
            WHISPER_AVAILABLE
        )
        
        if should_transcribe:
            # 自動文字起こしを実行
            try:
                with st.spinner("🎤 音声を自動文字起こし中（音声クローン作成の精度向上のため）..."):
                    # アップロードされたファイルを読み込む
                    file_bytes = uploaded_file.getvalue()
                    file_ext = current_file_name.split('.')[-1] if current_file_name else "wav"
                    
                    # 一時ファイルに保存してWhisperで処理
                    with tempfile.NamedTemporaryFile(delete=False, suffix=f".{file_ext}") as tmp_audio:
                        tmp_audio.write(file_bytes)
                        tmp_audio_path = tmp_audio.name
                    
                    try:
                        transcribed_text = transcribe_audio_with_whisper(tmp_audio_path)
                        if transcribed_text:
                            st.session_state.transcription_auto_text = transcribed_text
                            # ユーザーが編集していない場合のみ、テキストエリアに反映
                            if not st.session_state.get("transcription_edited_by_user", False):
                                st.session_state.transcription_input = transcribed_text
                            st.session_state.last_processed_file = current_file_name
                            # 自動適用フラグをリセット（新しい文字起こし結果なので）
                            auto_applied_key = f"transcription_auto_applied_{current_file_name}"
                            st.session_state[auto_applied_key] = False
                            st.success("✅ 自動文字起こしが完了しました。文字起こし欄に結果が表示されます。")
                            st.rerun()  # 結果を表示するために再レンダリング
                        else:
                            st.warning("⚠️ 文字起こし結果が空でした。手動で入力してください。")
                    except Exception as e:
                        st.error(f"❌ 文字起こしエラー: {e}")
                        import traceback
                        with st.expander("詳細なエラー情報"):
                            st.code(traceback.format_exc())
                    finally:
                        if os.path.exists(tmp_audio_path):
                            os.unlink(tmp_audio_path)
            except Exception as e:
                st.error(f"❌ ファイル読み込みエラー: {e}")
                import traceback
                with st.expander("詳細なエラー情報"):
                    st.code(traceback.format_exc())
        
        # 文字起こし処理中の表示
        if should_transcribe:
            pass  # 上でspinnerが表示される
        elif auto_transcribe_enabled and not WHISPER_AVAILABLE:
            st.warning("⚠️ Whisperがインストールされていません。自動文字起こしを使用するには `pip install openai-whisper` を実行してください。")
    
    # モデル設定フォーム
    st.markdown("---")
    st.markdown("### ⚙️ モデル設定")
    
    with st.form("create_voice_clone_form"):
        # 自動文字起こしの設定と公開設定
        col_settings1, col_settings2 = st.columns([1, 1])
        with col_settings1:
            if "auto_transcribe_enabled" not in st.session_state:
                st.session_state.auto_transcribe_enabled = True  # デフォルトで有効
            
            auto_transcribe = st.checkbox(
                "🎤 Whisperで自動文字起こし",
                value=st.session_state.auto_transcribe_enabled,
                help="音声ファイルをアップロード時に自動で文字起こしを実行します（推奨）",
                key="auto_transcribe_checkbox"
            )
            st.session_state.auto_transcribe_enabled = auto_transcribe
        
        with col_settings2:
            visibility = st.selectbox(
                "公開設定",
                ["private", "public", "unlist"],
                index=0,
                help="モデルの公開設定",
                key="visibility_select"
            )
        
        # 文字起こしエリア（フォーム内）- 自動文字起こし結果をここに表示
        st.markdown("#### 📝 文字起こし（推奨）")
        st.caption("💡 音声クローンの精度向上のため、文字起こしの入力をおすすめします。自動文字起こしが有効な場合は自動で入力されます。")
        
        # 現在のファイル名をセッション状態から取得
        current_file_from_session = st.session_state.get("voice_file_uploader", None)
        current_file_name_in_form = current_file_from_session.name if current_file_from_session and hasattr(current_file_from_session, 'name') else None
        
        # 音声プレーヤーを表示（編集しながら音声を聴けるように）
        if current_file_from_session:
            st.markdown("##### 🎵 音声プレーヤー")
            st.caption("音声を再生しながら、文字起こしを編集できます。")
            try:
                # 音声ファイルのフォーマットを判定
                file_ext = current_file_name_in_form.split('.')[-1].lower() if current_file_name_in_form else "wav"
                audio_format = f"audio/{file_ext}" if file_ext in ["wav", "mp3", "m4a", "ogg"] else "audio/wav"
                
                # ファイルを読み込んで再生（ファイルポインタをリセット）
                current_file_from_session.seek(0)
                audio_bytes = current_file_from_session.read()
                st.audio(audio_bytes, format=audio_format)
            except Exception as e:
                st.warning(f"音声ファイルの読み込みに失敗しました: {e}")
            st.markdown("---")
        
        # 自動文字起こし結果をセッション状態と同期（ウィジェット作成前に実行）
        if "transcription_input" not in st.session_state:
            st.session_state.transcription_input = ""
        if "transcription_edited_by_user" not in st.session_state:
            st.session_state.transcription_edited_by_user = False
        
        # 新しい自動文字起こし結果がある場合のみ、テキストエリアを更新
        # ただし、ユーザーが既に編集している場合は上書きしない
        # ウィジェット作成前に適用する必要がある
        if "transcription_auto_text" in st.session_state and st.session_state.transcription_auto_text:
            # 新しいファイルがアップロードされて自動文字起こしが実行された直後のみ更新
            # かつ、まだ適用されていない場合（transcription_auto_appliedフラグで管理）
            # かつ、ユーザーが編集していない場合
            if ("last_processed_file" in st.session_state and 
                current_file_name_in_form and 
                current_file_name_in_form == st.session_state.last_processed_file):
                # 自動適用フラグをチェック
                auto_applied_key = f"transcription_auto_applied_{current_file_name_in_form}"
                if (not st.session_state.get(auto_applied_key, False) and 
                    not st.session_state.transcription_edited_by_user):
                    # ユーザーが編集していない場合のみ、自動文字起こし結果を適用
                    # ウィジェット作成前に適用する
                    st.session_state.transcription_input = st.session_state.transcription_auto_text
                    st.session_state.transcription_edited_by_user = False  # 自動入力なので編集フラグはFalse
                    st.session_state[auto_applied_key] = True  # 適用済みフラグを設定
        
        # valueパラメータを使わず、keyのみでセッション状態から値を取得
        # この時点で、自動文字起こし結果が適用されている場合は、その値が表示される
        transcription = st.text_area(
            "文字起こし",
            height=120,
            help="音声ファイルの文字起こし。自動文字起こしが有効な場合は自動で入力されます。必要に応じて編集できます。",
            key="transcription_input",
            label_visibility="collapsed",
            placeholder="自動文字起こしが有効な場合、ここに結果が表示されます。手動で入力することもできます。"
        )
        
        # ユーザーが編集したかどうかをチェック（ウィジェット作成後はセッション状態を直接変更できないため、
        # ここでは確認のみ行い、実際の変更は次回レンダリング時に行う）
        # フォーム送信時に編集状態を確認する
        
        # モデル情報
        st.markdown("#### 🏷️ モデル情報")
        
        col_info1, col_info2 = st.columns([1, 1])
        with col_info1:
            model_title = st.text_input(
                "モデル名",
                value="My Custom Voice",
                help="作成するモデルの名前",
                key="model_title_input"
            )
        
        with col_info2:
            model_description = st.text_area(
                "モデルの説明",
                value="Voice cloned from sample audio",
                height=80,
                help="モデルの説明を入力してください",
                key="model_description_input"
            )
        
        submitted = st.form_submit_button("🚀 モデルを作成", use_container_width=True)
        
        if submitted:
            # フォーム送信時には、テキストエリアから直接値を取得して使用
            # （ウィジェットが作成された後はセッション状態を直接変更できないため）
            
            # フォーム外で定義したuploaded_fileを取得
            submitted_file = st.session_state.get("voice_file_uploader", None)
            
            if not submitted_file:
                st.error("⚠️ 音声ファイルをアップロードしてください。")
                st.stop()
            
            # 文字起こしの取得（テキストエリアから直接取得した値を使用）
            final_transcription = transcription.strip() if transcription else ""
            
            # ユーザーが編集したと判断し、編集フラグを設定（次回のレンダリング時に反映）
            # ただし、ウィジェットが作成された後なので、セッション状態は直接変更できない
            # 代わりに、別のキーを使用して編集状態を記録
            if final_transcription:
                # 自動適用フラグを設定して、以降の上書きを防ぐ
                if current_file_name_in_form:
                    auto_applied_key = f"transcription_auto_applied_{current_file_name_in_form}"
                    st.session_state[auto_applied_key] = True
                # 編集済みフラグも設定（次回レンダリング時に反映される）
                if ("transcription_auto_text" in st.session_state and 
                    st.session_state.transcription_auto_text and
                    final_transcription != st.session_state.transcription_auto_text):
                    st.session_state.transcription_edited_by_user = True
            
            if not final_transcription:
                st.warning("⚠️ 文字起こしが入力されていません。音声クローンの精度向上のため、文字起こしの入力をおすすめします。")
                # 続行するか確認
                if not st.checkbox("文字起こしなしで続行する", key="continue_without_transcription"):
                    st.stop()
                final_transcription = ""
            
            # 一時ファイルに保存
            file_ext = submitted_file.name.split('.')[-1] if hasattr(submitted_file, 'name') else "wav"
            with tempfile.NamedTemporaryFile(delete=False, suffix=f".{file_ext}") as tmp_file:
                submitted_file.seek(0)  # ファイルポインタをリセット
                tmp_file.write(submitted_file.read())
                tmp_path = tmp_file.name
            
            try:
                with st.spinner("音声クローンモデルを作成中... この処理には時間がかかる場合があります。"):
                    model_id = create_voice_clone_model(
                        api_key=st.session_state.fish_audio_api_key,
                        audio_file_path=tmp_path,
                        model_title=model_title,
                        model_description=model_description,
                        transcription=final_transcription,
                        visibility=visibility
                    )
                
                st.success("✅ モデルの作成が完了しました！")
                
                col1, col2 = st.columns(2)
                with col1:
                    st.info(f"**モデルID:**\n`{model_id}`")
                with col2:
                    st.info(f"**モデル名:**\n{model_title}")
                
                # モデルIDと名前をセッション状態に保存
                st.session_state.last_model_id = model_id
                st.session_state.last_model_name = model_title
                
                # JSONファイルに保存（名前とIDをセットで保存）
                add_model_to_json(model_title, model_id, model_description)
                
                # モデル辞書に追加（JSONから再読み込みして更新）
                json_data = load_models_from_json()
                st.session_state.models_dict = {}
                for model_entry in json_data.get("models", []):
                    name = model_entry.get("name", "")
                    mid = model_entry.get("id", "")
                    if name and mid:
                        st.session_state.models_dict[name] = mid
                
                st.balloons()
                
                # モデル作成後にTTSタブが自動的に表示されるように
                st.info("💡 TTS生成タブで、作成したモデルを選択して使用できます。")
                
            except Exception as e:
                st.error(f"❌ エラーが発生しました: {e}")
                import traceback
                with st.expander("詳細なエラー情報"):
                    st.code(traceback.format_exc())
            finally:
                # 一時ファイルを削除
                if os.path.exists(tmp_path):
                    os.unlink(tmp_path)

def page_generate_tts():
    """TTS生成ページ"""
    st.header("🗣️ テキスト読み上げ生成")
    st.write("作成した音声モデルまたはデフォルト音声を使用してテキストを音声に変換します。")
    
    if not st.session_state.fish_audio_api_key:
        st.warning("⚠️ サイドバーでAPIキーを設定してください。")
        return
    
    # JSONファイルからモデルリストを読み込む（確実に取得）
    json_data = load_models_from_json()
    json_models = json_data.get("models", [])
    
    # models_dictを更新（JSONから読み込んだモデルで更新）
    models_dict_from_json = {}
    for model_entry in json_models:
        name = model_entry.get("name", "")
        model_id = model_entry.get("id", "")
        if name and model_id:
            models_dict_from_json[name] = model_id
    
    # セッション状態のmodels_dictも更新
    st.session_state.models_dict = models_dict_from_json
    
    # モデル一覧と管理機能
    st.markdown("### 📋 モデル一覧と管理")
    
    # モデルオプションの準備
    if models_dict_from_json:
        model_options = ["デフォルト音声（モデルID未指定）"] + list(models_dict_from_json.keys())
        default_index = 0
        if st.session_state.last_model_name and st.session_state.last_model_name in models_dict_from_json:
            try:
                default_index = model_options.index(st.session_state.last_model_name)
            except ValueError:
                default_index = 0
    else:
        model_options = ["デフォルト音声（モデルID未指定）"]
        default_index = 0
    
    # モデル一覧の表示と管理ボタン
    col_refresh, col_manage = st.columns([1, 1])
    with col_refresh:
        if st.button("🔄 モデル一覧を更新", use_container_width=True):
            try:
                session = get_session()
                models_response = session.list_models(self_only=True, page_size=20)
                if models_response.items:
                    st.session_state.models = models_response.items
                    # update_models_dict()は呼ばない（JSONを更新しない）
                    # JSONからモデルリストを再読み込み
                    json_data = load_models_from_json()
                    json_models = json_data.get("models", [])
                    models_dict_from_json = {}
                    for model_entry in json_models:
                        name = model_entry.get("name", "")
                        model_id = model_entry.get("id", "")
                        if name and model_id:
                            models_dict_from_json[name] = model_id
                    st.session_state.models_dict = models_dict_from_json
                    st.success(f"✅ APIから {len(models_response.items)}個のモデルを取得しました（JSONに保存されているモデルのみ表示されます）")
                    st.rerun()
            except Exception as e:
                st.error(f"エラー: {e}")
    
    with col_manage:
        if st.button("📋 モデル管理・一覧", use_container_width=True):
            st.session_state.show_model_management = not st.session_state.get("show_model_management", False)
            st.rerun()
    
    # 統合されたモデル管理・一覧セクション
    if st.session_state.get("show_model_management", False):
        st.markdown("---")
        st.markdown("#### 📋 モデル管理・一覧")
        
        if json_models:
            # シンプルなモデル一覧表示
            for i, model_entry in enumerate(json_models):
                model_name = model_entry.get("name", "")
                model_id = model_entry.get("id", "")
                
                # 詳細表示の状態を取得
                detail_key = f"show_detail_{model_id}"
                is_detail_visible = st.session_state.get(detail_key, False)
                
                col1, col2, col3, col4 = st.columns([3, 1, 1, 1])
                with col1:
                    st.write(f"**{model_name}** (ID: `{model_id[:8]}...`)")
                with col2:
                    # 詳細ボタン（トグル表示）
                    button_label = "🔽 非表示" if is_detail_visible else "📝 詳細"
                    if st.button(button_label, key=f"detail_model_{i}", use_container_width=True):
                        # 詳細表示のトグル
                        st.session_state[detail_key] = not is_detail_visible
                        st.rerun()
                with col3:
                    # 選択ボタン
                    if st.button("✅ 選択", key=f"select_model_{i}", use_container_width=True):
                        st.session_state.last_model_id = model_id
                        st.session_state.last_model_name = model_name
                        # JSONファイルの最後に使用したモデルを更新
                        json_data = load_models_from_json()
                        json_data["last_used"] = {"name": model_name, "id": model_id}
                        save_models_to_json(json_data)
                        st.success(f"モデル '{model_name}' を選択しました！")
                        st.rerun()
                with col4:
                    # 削除ボタン
                    if st.button("🗑️ 削除", key=f"delete_model_{i}", use_container_width=True, type="secondary"):
                        try:
                            # APIからも削除を試みる
                            try:
                                session = get_session()
                                session.delete_model(model_id)
                            except Exception:
                                pass  # APIからの削除に失敗しても続行
                            
                            # JSONから削除
                            delete_model_from_json(model_id=model_id)
                            st.success(f"モデル '{model_name}' を削除しました。")
                            
                            # セッション状態を更新
                            if st.session_state.last_model_id == model_id:
                                st.session_state.last_model_id = ""
                                st.session_state.last_model_name = ""
                            
                            st.rerun()
                        except Exception as e:
                            st.error(f"削除エラー: {e}")
            
            # 詳細表示セクション（詳細ボタンを押したモデルの詳細情報をまとめて表示）
            detail_models = []
            for model_entry in json_models:
                model_id = model_entry.get("id", "")
                detail_key = f"show_detail_{model_id}"
                if st.session_state.get(detail_key, False):
                    detail_models.append(model_entry)
            
            if detail_models:
                st.markdown("---")
                st.markdown("#### 📋 詳細情報")
                for model_entry in detail_models:
                    model_name = model_entry.get("name", "")
                    model_id = model_entry.get("id", "")
                    model_desc = model_entry.get("description", "")
                    
                    with st.expander(f"📝 {model_name}", expanded=True):
                        col_detail1, col_detail2 = st.columns([1, 1])
                        with col_detail1:
                            st.write(f"**モデル名:** {model_name}")
                            st.write(f"**モデルID:** `{model_id}`")
                        with col_detail2:
                            if model_desc:
                                st.write(f"**説明:** {model_desc}")
                            else:
                                st.write("**説明:** （説明なし）")
        else:
            st.info("登録されているモデルがありません。「🎤 音声クローン作成」タブでモデルを作成してください。")
    
    if not models_dict_from_json:
        st.info("📝 モデルを作成するには、「🎤 音声クローン作成」タブでモデルを作成してください。")
    
    with st.form("generate_tts_form"):
        col1, col2 = st.columns([2, 1])
        
        with col1:
            text = st.text_area(
                "読み上げるテキスト",
                value="こんにちは。Fish Audioを使用した音声合成のテストです。感情表現も可能で、明るい声や悲しい声など、様々な表現が可能です。",
                height=150,
                help="読み上げたいテキストを入力してください。感情表現を使う場合は (happy) や (sad) 、(excited) などのタグを使用できます。"
            )
            
            # モデル選択（JSONから読み込んだモデルリストを使用）
            if models_dict_from_json:
                selected_model_name = st.selectbox(
                    "使用するモデル",
                    options=model_options,
                    index=default_index,
                    help="使用する音声モデルを選択してください。デフォルト音声を使用する場合は「デフォルト音声」を選択してください。"
                )
                
                if selected_model_name == "デフォルト音声（モデルID未指定）":
                    selected_model_id = None
                    selected_model_display = "デフォルト音声"
                else:
                    selected_model_id = models_dict_from_json.get(selected_model_name)
                    selected_model_display = f"{selected_model_name} (ID: {selected_model_id})"
            else:
                # モデル一覧がない場合は手動入力
                model_input = st.text_input(
                    "モデル名またはID（オプション）",
                    value=st.session_state.last_model_name if st.session_state.last_model_name else st.session_state.last_model_id,
                    help="モデル名またはモデルIDを入力。空欄の場合はデフォルト音声を使用します。"
                )
                selected_model_id = get_model_id_from_name_or_id(model_input) if model_input else None
                selected_model_display = model_input if model_input else "デフォルト音声"
            
            # 選択されたモデルの情報を表示
            if selected_model_id:
                st.info(f"選択中: {selected_model_display}")
        
        with col2:
            format = st.selectbox(
                "出力形式",
                ["wav", "mp3", "opus", "pcm"],
                help="出力音声ファイルの形式"
            )
            
            speed = st.slider(
                "話速",
                min_value=0.5,
                max_value=2.0,
                value=1.0,
                step=0.1,
                help="話速を調整します（0.5-2.0）"
            )
            
            volume = st.slider(
                "音量",
                min_value=-20,
                max_value=20,
                value=0,
                step=1,
                help="音量を調整します（-20〜20）"
            )
        
        submitted = st.form_submit_button("🎵 音声を生成", use_container_width=True)
        
        if submitted:
            if not text.strip():
                st.error("⚠️ テキストを入力してください。")
                st.session_state.tts_output_file = None
                st.session_state.tts_audio_bytes = None
                return
            
            try:
                with st.spinner("音声を生成中..."):
                    output_file = generate_tts(
                        api_key=st.session_state.fish_audio_api_key,
                        text=text,
                        model_id=selected_model_id,
                        output_file=None,  # 自動生成
                        format=format,
                        speed=speed,
                        volume=volume
                    )
                
                # 音声ファイルを読み込んでセッション状態に保存
                with open(output_file, "rb") as f:
                    audio_bytes = f.read()
                
                st.session_state.tts_output_file = output_file
                st.session_state.tts_audio_bytes = audio_bytes
                st.session_state.tts_format = format
                
                # 選択されたモデル情報を保存
                if selected_model_id:
                    st.session_state.last_model_id = selected_model_id
                    # モデル名から検索（JSONから読み込んだリストを使用）
                    selected_name = None
                    for name, mid in models_dict_from_json.items():
                        if mid == selected_model_id:
                            selected_name = name
                            break
                    if selected_name:
                        st.session_state.last_model_name = selected_name
                        # JSONファイルの最後に使用したモデルを更新
                        json_data = load_models_from_json()
                        json_data["last_used"] = {"name": selected_name, "id": selected_model_id}
                        save_models_to_json(json_data)
                    elif selected_model_name and selected_model_name != "デフォルト音声（モデルID未指定）":
                        st.session_state.last_model_name = selected_model_name
                        json_data = load_models_from_json()
                        json_data["last_used"] = {"name": selected_model_name, "id": selected_model_id}
                        save_models_to_json(json_data)
                
                st.success("✅ 音声の生成が完了しました！")
                st.rerun()
                
            except Exception as e:
                st.error(f"❌ エラーが発生しました: {e}")
                st.session_state.tts_output_file = None
                st.session_state.tts_audio_bytes = None
                import traceback
                with st.expander("詳細なエラー情報"):
                    st.code(traceback.format_exc())
    
    # フォームの外で結果を表示（ダウンロードボタンを含む）
    if st.session_state.tts_output_file and st.session_state.tts_audio_bytes:
        st.markdown("---")
        st.subheader("🎵 生成された音声")
        
        st.audio(st.session_state.tts_audio_bytes, format=f"audio/{st.session_state.tts_format}")
        
        # ダウンロードボタン（フォームの外なので使用可能）
        st.download_button(
            label="📥 音声ファイルをダウンロード",
            data=st.session_state.tts_audio_bytes,
            file_name=Path(st.session_state.tts_output_file).name,
            mime=f"audio/{st.session_state.tts_format}",
            use_container_width=True
        )

def main():
    """メイン関数"""
    init_session_state()
    sidebar()
    
    # タブで機能を分割
    tab1, tab2 = st.tabs(["🎤 音声クローン作成", "🗣️ TTS生成"])
    
    with tab1:
        page_create_voice_clone()
    
    with tab2:
        page_generate_tts()

if __name__ == "__main__":
    main()

