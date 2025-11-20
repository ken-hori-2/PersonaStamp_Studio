"""
音声プロンプト作成ユーティリティ
音声クローン用のプロンプトを作成
"""
import os
import sys
from pathlib import Path

# VALL-E-Xのパス
vallex_path = Path(__file__).parent.parent / "vallex"
if not vallex_path.exists():
    raise ImportError(f"VALL-E-Xリポジトリが見つかりません: {vallex_path}")

# customsディレクトリを作成
CUSTOMS_DIR = Path("./customs")
CUSTOMS_DIR.mkdir(exist_ok=True)

# モジュールをキャッシュ
_vallex_prompt_module = None


def _get_vallex_prompt_module():
    """VALL-E-Xのprompt_makingモジュールを取得（遅延インポート）"""
    global _vallex_prompt_module
    
    if _vallex_prompt_module is None:
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
        
        # 現在のプロジェクトのルートも削除（vallexのutilsが優先されるように）
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
                "vallex_prompt_making",
                vallex_path / "utils" / "prompt_making.py"
            )
            vallex_prompt = importlib.util.module_from_spec(spec)
            # 作業ディレクトリをvallexに設定してから実行
            spec.loader.exec_module(vallex_prompt)
            _vallex_prompt_module = vallex_prompt
        finally:
            os.chdir(original_cwd)
            # 元のutilsパスを復元
            for i, path in reversed(current_utils_paths):
                sys.path.insert(i, str(path))
    
    return _vallex_prompt_module


def make_prompt(name: str, audio_prompt_path: str, transcript=None):
    """
    音声プロンプトを作成
    
    Args:
        name: プロンプト名
        audio_prompt_path: 音声ファイルのパス（3-10秒推奨、最大15秒）
        transcript: 音声の転写テキスト（Noneの場合はWhisperで自動生成）
    
    Returns:
        作成されたプロンプトファイルのパス（.npz形式）
    """
    print(f"🎙️  プロンプト '{name}' を作成中...")
    
    vallex_prompt = _get_vallex_prompt_module()
    
    # 作業ディレクトリをvallexに変更
    original_cwd = os.getcwd()
    os.chdir(str(vallex_path))
    try:
        # VALL-E-Xのmake_promptを呼び出し
        vallex_prompt.make_prompt(name, audio_prompt_path, transcript)
    finally:
        os.chdir(original_cwd)
    
    # 保存先パスを返す
    prompt_path = CUSTOMS_DIR / f"{name}.npz"
    print(f"✓ プロンプト '{name}' が作成されました: {prompt_path}")
    return prompt_path


def list_prompts():
    """利用可能なプロンプトのリストを取得"""
    prompts = []
    
    # customsディレクトリから
    for prompt_file in CUSTOMS_DIR.glob("*.npz"):
        prompts.append(prompt_file.stem)
    
    # presetsディレクトリから（VALL-E-Xのプリセット）
    presets_dir = vallex_path / "presets"
    if presets_dir.exists():
        for preset_file in presets_dir.glob("*.npz"):
            prompts.append(preset_file.stem)
    
    return sorted(prompts)