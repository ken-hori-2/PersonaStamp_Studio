"""
長い音声ファイル（60秒など）から最適なプロンプトを作成するユーティリティ
"""
import os
import torch
import torchaudio
import numpy as np
from pathlib import Path
from typing import Optional, List, Tuple
import sys


def split_long_audio(
    audio_path: str,
    segment_length: float = 10.0,
    overlap: float = 0.0,
    output_dir: str = "./segments",
) -> List[Tuple[str, float, float]]:
    """
    長い音声ファイルを複数のセグメントに分割する
    
    Args:
        audio_path: 入力音声ファイルのパス
        segment_length: 各セグメントの長さ（秒）
        overlap: セグメント間のオーバーラップ（秒）
        output_dir: 出力ディレクトリ
    
    Returns:
        [(セグメントパス, 開始時間, 終了時間), ...] のリスト
    """
    # 絶対パスに変換
    audio_path = os.path.abspath(audio_path)
    if not os.path.exists(audio_path):
        raise FileNotFoundError(f"音声ファイルが見つかりません: {audio_path}")
    
    output_dir = os.path.abspath(output_dir)
    os.makedirs(output_dir, exist_ok=True)
    
    # 音声を読み込み
    wav, sr = torchaudio.load(audio_path)
    
    # ステレオをモノラルに変換
    if wav.size(0) == 2:
        wav = wav.mean(0, keepdim=True)
    
    # 正規化
    if wav.abs().max() > 1:
        wav = wav / wav.abs().max()
    
    total_length = wav.size(-1) / sr
    print(f"📊 音声ファイル情報:")
    print(f"   長さ: {total_length:.2f} 秒")
    print(f"   サンプリングレート: {sr} Hz")
    
    segments = []
    segment_samples = int(segment_length * sr)
    overlap_samples = int(overlap * sr)
    step_samples = segment_samples - overlap_samples
    
    start_sample = 0
    segment_idx = 0
    
    while start_sample < wav.size(-1):
        end_sample = min(start_sample + segment_samples, wav.size(-1))
        segment = wav[:, start_sample:end_sample]
        
        start_time = start_sample / sr
        end_time = end_sample / sr
        
        # セグメントを保存
        segment_path = os.path.join(output_dir, f"segment_{segment_idx:03d}.wav")
        torchaudio.save(segment_path, segment, sr)
        
        segments.append((segment_path, start_time, end_time))
        print(f"   セグメント {segment_idx}: {start_time:.2f}s - {end_time:.2f}s ({end_time - start_time:.2f}s)")
        
        segment_idx += 1
        start_sample += step_samples
        
        # 最後のセグメントが短すぎる場合は前のセグメントとマージ
        if end_sample >= wav.size(-1) and len(segments) > 1:
            last_segment = segments[-1]
            prev_segment = segments[-2]
            if (last_segment[2] - last_segment[1]) < segment_length * 0.5:
                # 前のセグメントを削除して、マージしたセグメントを作成
                os.remove(prev_segment[0])
                segments.pop(-2)
                
                # マージしたセグメントを作成
                merged_start = int(prev_segment[1] * sr)
                merged_end = int(last_segment[2] * sr)
                merged_segment = wav[:, merged_start:merged_end]
                merged_path = os.path.join(output_dir, f"segment_{segment_idx-2:03d}_merged.wav")
                torchaudio.save(merged_path, merged_segment, sr)
                segments[-1] = (merged_path, prev_segment[1], last_segment[2])
                os.remove(last_segment[0])
                break
    
    print(f"\n✅ {len(segments)}個のセグメントを作成しました")
    return segments


def find_best_segment(
    segments: List[Tuple[str, float, float]],
    method: str = "energy",
) -> Tuple[str, float, float]:
    """
    最適なセグメントを選択する
    
    Args:
        segments: セグメントのリスト
        method: 選択方法 ("energy", "middle", "first", "last")
            - energy: エネルギーが最も高いセグメント
            - middle: 中央のセグメント
            - first: 最初のセグメント
            - last: 最後のセグメント
    
    Returns:
        最適なセグメント (パス, 開始時間, 終了時間)
    """
    if method == "middle":
        idx = len(segments) // 2
        return segments[idx]
    elif method == "first":
        return segments[0]
    elif method == "last":
        return segments[-1]
    elif method == "energy":
        # 各セグメントのエネルギーを計算
        energies = []
        for segment_path, _, _ in segments:
            wav, _ = torchaudio.load(segment_path)
            energy = (wav ** 2).mean().item()
            energies.append(energy)
        
        # エネルギーが最も高いセグメントを選択
        best_idx = np.argmax(energies)
        print(f"📊 エネルギー分析:")
        for i, (segment, energy) in enumerate(zip(segments, energies)):
            marker = " ← 選択" if i == best_idx else ""
            print(f"   セグメント {i}: エネルギー = {energy:.6f}{marker}")
        
        return segments[best_idx]
    else:
        raise ValueError(f"Unknown method: {method}")


def create_prompt_from_long_audio(
    name: str,
    audio_path: str,
    segment_length: float = 10.0,
    selection_method: str = "energy",
    transcript: Optional[str] = None,
    auto_transcribe: bool = True,
    output_dir: str = "./vallex/customs",
    cleanup_segments: bool = True,
) -> str:
    """
    長い音声ファイルから最適なプロンプトを作成する
    
    Args:
        name: プロンプト名
        audio_path: 音声ファイルのパス
        segment_length: セグメントの長さ（秒、最大15秒）
        selection_method: セグメント選択方法 ("energy", "middle", "first", "last")
        transcript: 転写テキスト（Noneの場合は自動生成）
        auto_transcribe: 自動転写を使用するか
        output_dir: 出力ディレクトリ
        cleanup_segments: セグメントファイルを削除するか
    
    Returns:
        作成されたプロンプトファイルのパス
    """
    # セグメント長さの制限をチェック
    if segment_length > 15:
        print(f"⚠️  セグメント長さが15秒を超えています。15秒に制限します。")
        segment_length = 15.0
    
    # 絶対パスに変換（os.chdirの前に）
    audio_path = os.path.abspath(audio_path)
    
    # vallexパスを設定
    vallex_path = Path(__file__).parent.parent / "vallex"
    
    # プロジェクトルートのutilsを一時的にsys.pathから削除
    project_root = Path(__file__).parent.parent
    project_utils_path = str(project_root / "utils")
    if project_utils_path in sys.path:
        sys.path.remove(project_utils_path)
    
    # vallexパスを最初に追加
    vallex_path_str = str(vallex_path)
    if vallex_path_str not in sys.path:
        sys.path.insert(0, vallex_path_str)
    
    original_cwd = os.getcwd()
    os.chdir(vallex_path)
    
    try:
        # ステップ1: 音声をセグメントに分割
        print(f"\n{'='*60}")
        print(f"🎯 長い音声からプロンプトを作成")
        print(f"{'='*60}")
        print(f"\n📁 音声ファイル: {audio_path}")
        
        segments_dir = os.path.join(os.path.dirname(audio_path), "segments")
        segments = split_long_audio(
            audio_path,
            segment_length=segment_length,
            overlap=0.0,
            output_dir=segments_dir,
        )
        
        # ステップ2: 最適なセグメントを選択
        print(f"\n🔍 最適なセグメントを選択中（方法: {selection_method}）...")
        best_segment_path, start_time, end_time = find_best_segment(segments, method=selection_method)
        print(f"✅ 選択されたセグメント: {best_segment_path}")
        print(f"   時間範囲: {start_time:.2f}s - {end_time:.2f}s")
        
        # ステップ3: 選択されたセグメントからプロンプトを作成
        print(f"\n🎤 プロンプトを作成中...")
        
        # vallexのutilsをインポート
        from utils import prompt_making
        
        import torch
        
        # CPUを強制（MPSの問題を回避）
        prompt_making.device = torch.device('cpu')
        
        # 転写テキストの処理
        if transcript is None and auto_transcribe:
            # セグメントに対応する転写テキストを抽出する必要がある
            # ここでは、セグメント全体を転写する
            transcript = None
        elif transcript:
            # 転写テキストが提供されている場合、セグメントに対応する部分を抽出
            # 簡易実装：全体の転写テキストを使用
            pass
        
        prompt_making.make_prompt(name, best_segment_path, transcript=transcript)
        
        # クリーンアップ
        if cleanup_segments:
            print(f"\n🧹 一時ファイルを削除中...")
            for segment_path, _, _ in segments:
                if os.path.exists(segment_path):
                    os.remove(segment_path)
            if os.path.exists(segments_dir) and not os.listdir(segments_dir):
                os.rmdir(segments_dir)
        
        prompt_path = os.path.join(output_dir, f"{name}.npz")
        print(f"\n✅ プロンプトを作成しました: {prompt_path}")
        print(f"{'='*60}")
        
        return prompt_path
        
    finally:
        os.chdir(original_cwd)


def create_multiple_prompts_from_long_audio(
    base_name: str,
    audio_path: str,
    segment_length: float = 10.0,
    max_prompts: Optional[int] = None,
    transcript_segments: Optional[List[str]] = None,
    output_dir: str = "./vallex/customs",
) -> List[str]:
    """
    長い音声ファイルから複数のプロンプトを作成する
    
    Args:
        base_name: プロンプト名のベース
        audio_path: 音声ファイルのパス
        segment_length: セグメントの長さ（秒）
        max_prompts: 作成するプロンプトの最大数（Noneの場合は全て）
        transcript_segments: 各セグメントの転写テキスト（順序対応）
        output_dir: 出力ディレクトリ
    
    Returns:
        作成されたプロンプトファイルのパスのリスト
    """
    # 絶対パスに変換
    audio_path = os.path.abspath(audio_path)
    
    # セグメントに分割
    segments_dir = os.path.join(os.path.dirname(audio_path), "segments")
    segments = split_long_audio(
        audio_path,
        segment_length=segment_length,
        overlap=0.0,
        output_dir=segments_dir,
    )
    
    if max_prompts:
        segments = segments[:max_prompts]
    
    # vallexパスを設定
    vallex_path = Path(__file__).parent.parent / "vallex"
    
    # プロジェクトルートのutilsを一時的にsys.pathから削除
    project_root = Path(__file__).parent.parent
    project_utils_path = str(project_root / "utils")
    if project_utils_path in sys.path:
        sys.path.remove(project_utils_path)
    
    # vallexパスを最初に追加
    vallex_path_str = str(vallex_path)
    if vallex_path_str not in sys.path:
        sys.path.insert(0, vallex_path_str)
    
    original_cwd = os.getcwd()
    os.chdir(vallex_path)
    
    prompt_paths = []
    
    try:
        # vallexのutilsをインポート
        from utils import prompt_making
        
        import torch
        
        prompt_making.device = torch.device('cpu')
        
        print(f"\n🎤 {len(segments)}個のプロンプトを作成中...")
        
        for i, (segment_path, start_time, end_time) in enumerate(segments):
            prompt_name = f"{base_name}_seg{i:02d}"
            transcript = transcript_segments[i] if transcript_segments and i < len(transcript_segments) else None
            
            print(f"\n   [{i+1}/{len(segments)}] {prompt_name} ({start_time:.1f}s - {end_time:.1f}s)")
            
            try:
                prompt_making.make_prompt(prompt_name, segment_path, transcript=transcript)
                prompt_path = os.path.join(output_dir, f"{prompt_name}.npz")
                prompt_paths.append(prompt_path)
                print(f"      ✅ 作成完了")
            except Exception as e:
                print(f"      ❌ エラー: {e}")
        
        # クリーンアップ
        for segment_path, _, _ in segments:
            if os.path.exists(segment_path):
                os.remove(segment_path)
        if os.path.exists(segments_dir) and not os.listdir(segments_dir):
            os.rmdir(segments_dir)
        
        print(f"\n✅ {len(prompt_paths)}個のプロンプトを作成しました")
        return prompt_paths
        
    finally:
        os.chdir(original_cwd)


if __name__ == "__main__":
    # 使用例
    print("長い音声ファイルからプロンプトを作成するユーティリティ")
    print("\n使用例:")
    print("  from utils.long_audio_prompt import create_prompt_from_long_audio")
    print("  create_prompt_from_long_audio(")
    print("      name='vocals',")
    print("      audio_path='vocals.wav',")
    print("      segment_length=10.0,")
    print("      selection_method='energy'")
    print("  )")

