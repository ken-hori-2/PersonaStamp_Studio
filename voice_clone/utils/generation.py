"""
音声生成ユーティリティ
VALL-E-Xスタイルの音声生成機能を提供
"""
import os
import sys
from pathlib import Path

# VALL-E-Xのパス
vallex_path = Path(__file__).parent.parent / "vallex"
if not vallex_path.exists():
    raise ImportError(f"VALL-E-Xリポジトリが見つかりません: {vallex_path}")

# サンプリングレート（VALL-E-Xのデフォルト値）
SAMPLE_RATE = 24000

# モジュールをキャッシュ
_vallex_gen_module = None


def _get_vallex_gen_module():
    """VALL-E-Xのgenerationモジュールを取得（遅延インポート）"""
    global _vallex_gen_module
    
    if _vallex_gen_module is None:
        # 現在のutilsパスを一時的に削除（循環インポートを防ぐ）
        current_utils_paths = []
        paths_to_remove = []
        current_dir = Path(__file__).parent
        
        for i, path in enumerate(sys.path):
            path_str = str(path)
            path_obj = Path(path_str) if path_str else None
            # 現在のプロジェクトのutilsパスを削除
            if 'voice_clone/utils' in path_str or (path_obj and current_dir in path_obj.parents):
                current_utils_paths.append((i, path))
                paths_to_remove.append(i)
        
        # 後ろから削除（インデックスがずれないように）
        for i in reversed(paths_to_remove):
            sys.path.pop(i)
        
        # vallexパスを最初に追加（優先されるように）
        if str(vallex_path) not in sys.path:
            sys.path.insert(0, str(vallex_path))
        
        # 現在のプロジェクトのルートも削除
        project_root = Path(__file__).parent.parent
        if str(project_root) in sys.path:
            try:
                sys.path.remove(str(project_root))
            except ValueError:
                pass
        
        # 作業ディレクトリを変更
        original_cwd = os.getcwd()
        os.chdir(str(vallex_path))
        
        try:
            # モジュール名を変更してインポート（循環インポートを防ぐ）
            import importlib.util
            spec = importlib.util.spec_from_file_location(
                "vallex_generation",
                vallex_path / "utils" / "generation.py"
            )
            vallex_gen = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(vallex_gen)
            _vallex_gen_module = vallex_gen
        finally:
            os.chdir(original_cwd)
            # 元のutilsパスを復元
            for i, path in reversed(current_utils_paths):
                sys.path.insert(i, str(path))
    
    return _vallex_gen_module

# サンプリングレートを取得（モジュールロード時に）
try:
    _vallex_gen = _get_vallex_gen_module()
    VALLEX_SAMPLE_RATE = _vallex_gen.SAMPLE_RATE
except:
    VALLEX_SAMPLE_RATE = 24000  # デフォルト値


def preload_models():
    """すべてのモデルを事前ロード"""
    print("🔄 VALL-E-Xモデルをロード中...")
    vallex_gen = _get_vallex_gen_module()
    original_cwd = os.getcwd()
    os.chdir(str(vallex_path))
    try:
        vallex_gen.preload_models()
    finally:
        os.chdir(original_cwd)
    print("✓ モデルのロードが完了しました")


def generate_audio(
    text: str,
    prompt=None,
    language="auto",
    accent="no-accent",
    **kwargs
):
    """
    テキストから音声を生成
    
    Args:
        text: 生成するテキスト
        prompt: 音声プロンプト（プリセット名または.npzファイルパス）
        language: 言語（'auto', 'en', 'zh', 'ja', 'mix'）
        accent: アクセント制御（'no-accent' または 'English', '中文', '日本語'）
        **kwargs: その他のオプション
    
    Returns:
        生成された音声配列
    """
    vallex_gen = _get_vallex_gen_module()
    original_cwd = os.getcwd()
    os.chdir(str(vallex_path))
    try:
        return vallex_gen.generate_audio(
            text=text,
            prompt=prompt,
            language=language,
            accent=accent,
        )
    finally:
        os.chdir(original_cwd)


def generate_audio_from_long_text(
    text: str,
    prompt=None,
    language="auto",
    accent="no-accent",
    mode="sliding-window",
):
    """
    長文テキストから音声を生成
    
    Args:
        text: 生成するテキスト
        prompt: 音声プロンプト（プリセット名または.npzファイルパス）
        language: 言語（'auto', 'en', 'zh', 'ja', 'mix'）
        accent: アクセント制御
        mode: 生成モード（'fixed-prompt' または 'sliding-window'）
    
    Returns:
        生成された音声配列
    """
    vallex_gen = _get_vallex_gen_module()
    original_cwd = os.getcwd()
    os.chdir(str(vallex_path))
    try:
        return vallex_gen.generate_audio_from_long_text(
            text=text,
            prompt=prompt,
            language=language,
            accent=accent,
            mode=mode,
        )
    finally:
        os.chdir(original_cwd)