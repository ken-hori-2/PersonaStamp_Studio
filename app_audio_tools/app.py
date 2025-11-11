"""
Audio Tools - Streamlit Web UI

YouTube音声ダウンロードと音源分離のためのWebインターフェース
"""

import streamlit as st
import os
import subprocess
import tempfile
from pathlib import Path
from datetime import datetime
from typing import Dict, Optional, Tuple

# app_audio_toolsフォルダ内の関数をインポート
from youtube_downloader import download_youtube_as_wav
from audio_separation import separate_vocals, separate_vocals_full

# .envファイルがあれば読み込む
try:
    from dotenv import load_dotenv
    env_path = Path(__file__).parent.parent / '.env'
    load_dotenv(dotenv_path=env_path)
except ImportError:
    pass

# ページ設定
st.set_page_config(
    page_title="Audio Tools",
    page_icon="🎵",
    layout="wide"
)

# 定数
PART_NAMES = {
    'vocals': '📢 ボーカル',
    'no_vocals': '🎵 伴奏',
    'drums': '🥁 ドラム',
    'bass': '🎸 ベース',
    'other': '🎹 その他'
}

SUPPORTED_AUDIO_TYPES = ['wav', 'mp3', 'm4a', 'flac', 'ogg']


def init_session_state():
    """セッション状態の初期化"""
    defaults = {
        "youtube_output_file": None,
        "youtube_audio_bytes": None,
        "youtube_audio_mp3_bytes": None,  # プレビュー用MP3データ
        "separation_output_files": {},
        "separation_audio_bytes": {},
        "separation_audio_mp3_bytes": {},  # プレビュー用MP3データ
        "last_uploaded_file_name": None,
        "separation_input_source": "upload"  # "upload" or "youtube"
    }
    
    for key, default_value in defaults.items():
        if key not in st.session_state:
            st.session_state[key] = default_value


def check_tool_available(tool_name: str, version_flag: str = '--version') -> bool:
    """
    ツールが利用可能かチェック
    
    Args:
        tool_name: チェックするツール名
        version_flag: バージョン確認用のフラグ
    
    Returns:
        ツールが利用可能な場合True
    """
    import shutil
    import sys
    
    try:
        # demucsの場合は特別な処理
        if tool_name == 'demucs':
            # まず、Pythonモジュールとしてインポートできるか確認（Streamlit Cloud対応）
            try:
                import demucs
                # モジュールがインポートできれば利用可能
                return True
            except ImportError:
                pass
            
            # コマンドラインから実行できるか確認
            # 1. 直接コマンドを試す
            if shutil.which('demucs'):
                result = subprocess.run(
                    ['demucs', '--help'], 
                    capture_output=True, 
                    check=False,
                    timeout=5
                )
                if result.returncode in [0, 1]:
                    return True
            
            # 2. python -m demucs で試す
            result = subprocess.run(
                [sys.executable, '-m', 'demucs', '--help'], 
                capture_output=True, 
                check=False,
                timeout=5
            )
            # エラーコードが0または1（help表示は成功）なら利用可能
            return result.returncode in [0, 1]
            
        elif tool_name == 'ffmpeg':
            # ffmpegは-versionで動作確認（stderrに出力される）
            if not shutil.which('ffmpeg'):
                return False
            result = subprocess.run(
                ['ffmpeg', '-version'], 
                capture_output=True, 
                check=False,
                timeout=5
            )
            # ffmpegはバージョン情報をstderrに出力するが、エラーコードは0
            return result.returncode == 0
        else:
            # その他のツール
            if not shutil.which(tool_name):
                return False
            result = subprocess.run(
                [tool_name, version_flag], 
                capture_output=True, 
                check=False,
                timeout=5
            )
            return result.returncode == 0
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return False


def get_output_directory(subdir: str = "examples") -> Path:
    """
    出力ディレクトリを取得（存在しない場合は作成）
    
    Args:
        subdir: サブディレクトリ名
    
    Returns:
        出力ディレクトリのPath
    """
    output_dir = Path(__file__).parent.parent / subdir
    output_dir.mkdir(parents=True, exist_ok=True)
    return output_dir


def load_audio_file(file_path: str) -> bytes:
    """
    音声ファイルを読み込む
    
    Args:
        file_path: ファイルパス
    
    Returns:
        ファイルのバイトデータ
    
    Raises:
        FileNotFoundError: ファイルが見つからない場合
        IOError: ファイルの読み込みに失敗した場合
    """
    if not os.path.exists(file_path):
        raise FileNotFoundError(f"ファイルが見つかりません: {file_path}")
    
    with open(file_path, "rb") as f:
        data = f.read()
    
    if len(data) == 0:
        raise IOError(f"ファイルが空です: {file_path}")
    
    return data


def convert_wav_to_mp3(wav_bytes: bytes) -> bytes:
    """
    WAVファイルのバイトデータをMP3に変換
    
    Args:
        wav_bytes: WAVファイルのバイトデータ
    
    Returns:
        MP3ファイルのバイトデータ
    
    Raises:
        RuntimeError: 変換に失敗した場合
    """
    import tempfile
    
    # 一時ファイルにWAVを書き込み
    with tempfile.NamedTemporaryFile(delete=False, suffix=".wav") as tmp_wav:
        tmp_wav.write(wav_bytes)
        tmp_wav_path = tmp_wav.name
    
    try:
        # MP3に変換
        with tempfile.NamedTemporaryFile(delete=False, suffix=".mp3") as tmp_mp3:
            tmp_mp3_path = tmp_mp3.name
        
        cmd = [
            'ffmpeg', '-y', '-loglevel', 'error',
            '-i', tmp_wav_path,
            '-codec:a', 'libmp3lame',
            '-b:a', '192k',  # ビットレート 192kbps
            tmp_mp3_path
        ]
        
        result = subprocess.run(cmd, capture_output=True, text=True)
        
        if result.returncode != 0:
            raise RuntimeError(f"MP3変換に失敗しました: {result.stderr[:200]}")
        
        # MP3ファイルを読み込む
        with open(tmp_mp3_path, "rb") as f:
            mp3_bytes = f.read()
        
        return mp3_bytes
        
    finally:
        # 一時ファイルを削除
        for tmp_file in [tmp_wav_path, tmp_mp3_path]:
            if os.path.exists(tmp_file):
                try:
                    os.remove(tmp_file)
                except OSError:
                    pass


def display_audio_player(
    audio_bytes: bytes,
    file_name: str,
    file_path: Optional[str] = None,
    part_name: Optional[str] = None,
    mp3_bytes: Optional[bytes] = None
) -> None:
    """
    音声プレーヤーとダウンロードボタンを表示
    
    Args:
        audio_bytes: 音声データのバイト（元の形式、ダウンロード用）
        file_name: ファイル名
        file_path: ファイルパス（表示用）
        part_name: パート名（表示用）
        mp3_bytes: MP3形式のバイトデータ（プレビュー用、Noneの場合は自動変換）
    """
    file_size_mb = len(audio_bytes) / (1024 * 1024)
    
    # パート名がある場合は表示
    if part_name:
        st.markdown(f"### {part_name}")
    
    # プレビュー用のMP3データを準備
    preview_audio_bytes = mp3_bytes
    preview_format = "audio/mpeg"
    
    if preview_audio_bytes is None:
        # MP3データが提供されていない場合、WAVファイルの場合はMP3に変換
        file_ext = Path(file_name).suffix.lower()
        if file_ext == ".wav":
            try:
                preview_audio_bytes = convert_wav_to_mp3(audio_bytes)
            except Exception as e:
                # 変換に失敗した場合は元のWAVを使用
                preview_audio_bytes = audio_bytes
                preview_format = "audio/wav"
                st.warning(f"⚠️ MP3変換に失敗しました。WAV形式で再生します: {str(e)[:100]}")
        else:
            # WAV以外の場合はそのまま使用
            preview_audio_bytes = audio_bytes
            # ファイル拡張子に基づいてMIMEタイプを決定
            mime_map = {
                ".mp3": "audio/mpeg",
                ".wav": "audio/wav",
                ".m4a": "audio/mp4",
                ".ogg": "audio/ogg",
                ".flac": "audio/flac"
            }
            preview_format = mime_map.get(file_ext, "audio/wav")
    
    # 音声プレーヤー（MP3形式で再生、スマホ対応）
    try:
        st.audio(preview_audio_bytes, format=preview_format)
        st.caption("💡 再生できない場合は、ダウンロードボタンからファイルをダウンロードしてください。")
    except Exception as audio_error:
        st.warning(f"⚠️ 音声の再生に失敗しました。ダウンロードボタンからファイルをダウンロードして、デバイスのメディアプレーヤーで再生してください。")
        st.caption(f"エラー詳細: {str(audio_error)[:200]}")
    
    # ダウンロードボタン（元の形式でダウンロード）
    # MIMEタイプを決定
    file_ext = Path(file_name).suffix.lower()
    mime_map = {
        ".mp3": "audio/mpeg",
        ".wav": "audio/wav",
        ".m4a": "audio/mp4",
        ".ogg": "audio/ogg",
        ".flac": "audio/flac"
    }
    download_mime = mime_map.get(file_ext, "audio/wav")
    
    label = f"📥 {part_name or '音声ファイル'}をダウンロード ({file_size_mb:.1f}MB)"
    st.download_button(
        label=label,
        data=audio_bytes,
        file_name=file_name,
        mime=download_mime,
        use_container_width=True,
        key=f"download_{file_name}_{part_name or ''}"
    )
    
    # 保存先の表示
    if file_path:
        st.caption(f"💾 保存先: {file_path}")


def sidebar():
    """サイドバー"""
    st.sidebar.title("🎵 Audio Tools")
    st.sidebar.markdown("---")
    
    # ツールの可用性チェック
    st.sidebar.markdown("### 📋 ツールの状態")
    
    tools_status = {
        'yt-dlp': check_tool_available('yt-dlp'),
        'demucs': check_tool_available('demucs', '--help'),
        'ffmpeg': check_tool_available('ffmpeg')
    }
    
    tool_info = {
        'yt-dlp': {
            'name': 'yt-dlp',
            'install': 'pip install yt-dlp',
            'required_for': 'YouTubeダウンロード'
        },
        'demucs': {
            'name': 'demucs',
            'install': 'pip install demucs',
            'required_for': '音源分離'
        },
        'ffmpeg': {
            'name': 'ffmpeg',
            'install': 'システムにインストールが必要',
            'required_for': 'YouTubeダウンロード・音声変換'
        }
    }
    
    for tool_key, is_available in tools_status.items():
        info = tool_info[tool_key]
        if is_available:
            st.sidebar.success(f"✅ {info['name']}: 利用可能")
        else:
            if tool_key == 'ffmpeg':
                st.sidebar.error(f"❌ {info['name']}: 未インストール")
            else:
                st.sidebar.warning(f"⚠️ {info['name']}: 未インストール")
            st.sidebar.caption(f"  {info['install']}")
    
    st.sidebar.markdown("---")
    st.sidebar.markdown("### 📖 使い方")
    st.sidebar.markdown("""
    1. **YouTubeダウンロード**: YouTube URLから音声をダウンロード
    2. **音源分離**: 音楽ファイルからボーカルを抽出
    
    音声クローン作成の準備に最適です。
    """)


def page_youtube_download():
    """YouTubeダウンロードページ"""
    st.header("📺 YouTube音声ダウンロード")
    st.write("YouTubeから音声をダウンロードしてWAV形式に変換します。")
    
    # ツールの可用性チェック
    yt_dlp_ok = check_tool_available('yt-dlp')
    ffmpeg_ok = check_tool_available('ffmpeg')
    
    if not yt_dlp_ok or not ffmpeg_ok:
        st.error("⚠️ 必要なツールがインストールされていません。サイドバーを確認してください。")
        return
    
    with st.form("youtube_download_form"):
        youtube_url = st.text_input(
            "YouTube URL",
            placeholder="https://www.youtube.com/watch?v=xxxxx または https://youtu.be/xxxxx",
            help="ダウンロードしたいYouTube動画のURLを入力してください"
        )
        
        submitted = st.form_submit_button("📥 ダウンロード開始", use_container_width=True)
        
        if submitted:
            if not youtube_url or not youtube_url.strip():
                st.error("❌ YouTube URLを入力してください。")
                return
            
            try:
                with st.spinner("音声をダウンロード中..."):
                    # 出力ファイル名を生成
                    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
                    output_dir = get_output_directory("examples")
                    output_file = output_dir / f"downloaded_{timestamp}.wav"
                    
                    # ダウンロード実行
                    downloaded_path = download_youtube_as_wav(youtube_url, str(output_file))
                    
                    # ファイルを読み込んでセッション状態に保存
                    audio_bytes = load_audio_file(downloaded_path)
                    
                    # プレビュー用にMP3に変換
                    try:
                        mp3_bytes = convert_wav_to_mp3(audio_bytes)
                    except Exception as e:
                        # MP3変換に失敗した場合はNoneを設定（display_audio_playerで自動変換を試みる）
                        mp3_bytes = None
                        st.warning(f"⚠️ MP3変換に失敗しました。WAV形式で再生します: {str(e)[:100]}")
                    
                    st.session_state.youtube_output_file = downloaded_path
                    st.session_state.youtube_audio_bytes = audio_bytes
                    st.session_state.youtube_audio_mp3_bytes = mp3_bytes
                    
                    st.success("✅ ダウンロード完了！")
                    st.rerun()
                    
            except ValueError as e:
                st.error(f"❌ 入力エラー: {e}")
            except FileNotFoundError as e:
                st.error(f"❌ ツールが見つかりません: {e}")
            except RuntimeError as e:
                st.error(f"❌ ダウンロードに失敗しました: {e}")
            except Exception as e:
                st.error(f"❌ 予期しないエラーが発生しました: {e}")
                import traceback
                with st.expander("詳細なエラー情報"):
                    st.code(traceback.format_exc())
    
    # ダウンロード結果の表示
    if st.session_state.youtube_output_file and st.session_state.youtube_audio_bytes:
        st.markdown("---")
        st.subheader("🎵 ダウンロードされた音声")
        
        try:
            file_name = Path(st.session_state.youtube_output_file).name
            display_audio_player(
                st.session_state.youtube_audio_bytes,
                file_name,
                st.session_state.youtube_output_file,
                mp3_bytes=st.session_state.youtube_audio_mp3_bytes
            )
        except Exception as e:
            st.error(f"❌ 音声の表示に失敗しました: {e}")


def page_audio_separation():
    """音源分離ページ"""
    st.header("🎤 音源分離（ボーカル抽出）")
    st.write("音楽ファイルからボーカル（人の声）を抽出します。音声クローン作成に最適です。")
    
    # ツールの可用性チェック
    demucs_ok = check_tool_available('demucs', '--help')
    
    if not demucs_ok:
        st.error("⚠️ demucsがインストールされていません。サイドバーを確認してください。")
        return
    
    # 入力ソースの選択
    has_youtube_file = (
        st.session_state.youtube_output_file and 
        os.path.exists(st.session_state.youtube_output_file)
    )
    
    if has_youtube_file:
        input_source = st.radio(
            "入力ソースを選択",
            ["upload", "youtube"],
            format_func=lambda x: "📁 ファイルをアップロード" if x == "upload" else "📺 YouTubeダウンロード済みファイル",
            horizontal=True,
            key="separation_input_source_radio"
        )
        st.session_state.separation_input_source = input_source
    else:
        st.session_state.separation_input_source = "upload"
        st.info("💡 YouTubeダウンロードタブでファイルをダウンロードすると、ここで選択できるようになります。")
    
    # 入力ファイルの取得
    input_file_path = None
    input_file_name = None
    uploaded_file = None
    
    if st.session_state.separation_input_source == "youtube" and has_youtube_file:
        # YouTubeダウンロード済みファイルを使用
        input_file_path = st.session_state.youtube_output_file
        input_file_name = Path(input_file_path).name
        st.success(f"✅ 使用するファイル: {input_file_name}")
        st.caption(f"📁 {input_file_path}")
        
        # ファイル情報を表示
        if os.path.exists(input_file_path):
            file_size_mb = os.path.getsize(input_file_path) / (1024 * 1024)
            st.caption(f"📊 ファイルサイズ: {file_size_mb:.2f}MB")
    else:
        # ファイルアップロード
        uploaded_file = st.file_uploader(
            "音声ファイルをアップロード",
            type=SUPPORTED_AUDIO_TYPES,
            help="分離したい音楽ファイルをアップロードしてください"
        )
        
        # 新しいファイルがアップロードされたら、以前の結果をクリア
        if uploaded_file:
            if st.session_state.last_uploaded_file_name != uploaded_file.name:
                st.session_state.last_uploaded_file_name = uploaded_file.name
                st.session_state.separation_output_files = {}
                st.session_state.separation_audio_bytes = {}
            input_file_name = uploaded_file.name
    
    # 入力ファイルが選択されている場合のみ処理を続行
    if not input_file_path and not uploaded_file:
        return
    
    if input_file_path or uploaded_file:
        st.markdown("---")
        
        with st.form("separation_form"):
            col1, col2 = st.columns(2)
            
            with col1:
                mode = st.radio(
                    "分離モード",
                    ["vocal", "full"],
                    format_func=lambda x: "ボーカルのみ（高速・推奨）" if x == "vocal" else "完全分離（4-stem）",
                    help="ボーカルのみ: vocalsとno_vocalsのみ出力（高速）\n完全分離: vocals, drums, bass, otherを出力"
                )
            
            with col2:
                model = st.selectbox(
                    "分離モデル",
                    ["htdemucs", "htdemucs_ft", "mdx_extra", "mdx_extra_q"],
                    help="htdemucs: 最高品質（推奨）\nhtdemucs_ft: fine-tuned版\nmdx_extra: 超高品質（処理時間長）"
                )
            
            st.caption("💡 初回実行時はモデルのダウンロードで数分かかります")
            
            submitted = st.form_submit_button("🎵 音源分離を開始", use_container_width=True)
            
            if submitted:
                try:
                    with st.spinner("音源分離中...（初回はモデルダウンロードで時間がかかります）"):
                        # 入力ファイルのパスを決定
                        if input_file_path:
                            # YouTubeダウンロード済みファイルを使用
                            tmp_path = input_file_path
                            need_cleanup = False
                        else:
                            # アップロードされたファイルを一時ファイルに保存
                            file_ext = uploaded_file.name.split('.')[-1] if '.' in uploaded_file.name else 'wav'
                            with tempfile.NamedTemporaryFile(delete=False, suffix=f".{file_ext}") as tmp_file:
                                tmp_file.write(uploaded_file.read())
                                tmp_path = tmp_file.name
                            need_cleanup = True
                        
                        try:
                            # 出力ディレクトリ
                            output_dir = get_output_directory("separated")
                            
                            # 音源分離実行
                            if mode == 'vocal':
                                vocals_path = separate_vocals(tmp_path, str(output_dir), model=model)
                                vocals_dir = Path(vocals_path).parent
                                output_files = {
                                    'vocals': vocals_path,
                                    'no_vocals': str(vocals_dir / 'no_vocals.wav')
                                }
                            else:
                                output_files = separate_vocals_full(tmp_path, str(output_dir), model=model)
                            
                            # 出力ファイルを読み込んでセッション状態に保存
                            separation_audio_bytes = {}
                            separation_audio_mp3_bytes = {}
                            for key, file_path in output_files.items():
                                if os.path.exists(file_path):
                                    audio_bytes = load_audio_file(file_path)
                                    separation_audio_bytes[key] = audio_bytes
                                    
                                    # プレビュー用にMP3に変換（WAVファイルの場合）
                                    file_ext = Path(file_path).suffix.lower()
                                    if file_ext == ".wav":
                                        try:
                                            mp3_bytes = convert_wav_to_mp3(audio_bytes)
                                            separation_audio_mp3_bytes[key] = mp3_bytes
                                        except Exception:
                                            # MP3変換に失敗した場合はNoneを設定
                                            separation_audio_mp3_bytes[key] = None
                                    else:
                                        # WAV以外の場合はそのまま使用
                                        separation_audio_mp3_bytes[key] = None
                            
                            st.session_state.separation_output_files = output_files
                            st.session_state.separation_audio_bytes = separation_audio_bytes
                            st.session_state.separation_audio_mp3_bytes = separation_audio_mp3_bytes
                            
                            st.success("✅ 音源分離完了！")
                            st.rerun()
                            
                        finally:
                            # 一時ファイルのクリーンアップ（アップロードファイルの場合のみ）
                            if need_cleanup and os.path.exists(tmp_path):
                                try:
                                    os.remove(tmp_path)
                                except OSError:
                                    pass
                        
                except ValueError as e:
                    st.error(f"❌ 入力エラー: {e}")
                except FileNotFoundError as e:
                    st.error(f"❌ ツールが見つかりません: {e}")
                except RuntimeError as e:
                    st.error(f"❌ 音源分離に失敗しました: {e}")
                except Exception as e:
                    st.error(f"❌ 予期しないエラーが発生しました: {e}")
                    import traceback
                    with st.expander("詳細なエラー情報"):
                        st.code(traceback.format_exc())
    
    # 分離結果の表示
    if st.session_state.separation_output_files and st.session_state.separation_audio_bytes:
        st.markdown("---")
        st.subheader("🎵 分離結果")
        
        for key, file_path in st.session_state.separation_output_files.items():
            if key in st.session_state.separation_audio_bytes:
                try:
                    audio_bytes = st.session_state.separation_audio_bytes[key]
                    mp3_bytes = st.session_state.separation_audio_mp3_bytes.get(key)
                    file_name = Path(file_path).name
                    part_name = PART_NAMES.get(key, key)
                    
                    display_audio_player(
                        audio_bytes,
                        file_name,
                        file_path,
                        part_name,
                        mp3_bytes=mp3_bytes
                    )
                    st.markdown("---")
                except Exception as e:
                    st.error(f"❌ {PART_NAMES.get(key, key)}の表示に失敗しました: {e}")


def main():
    """メイン関数"""
    init_session_state()
    sidebar()
    
    # タブで機能を分ける
    tab1, tab2 = st.tabs(["📺 YouTubeダウンロード", "🎤 音源分離"])
    
    with tab1:
        page_youtube_download()
    
    with tab2:
        page_audio_separation()


if __name__ == "__main__":
    main()
