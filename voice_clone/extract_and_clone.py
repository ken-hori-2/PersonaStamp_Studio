"""
vocals.wavから声の特徴がある15秒を抽出し、音声クローンを作成
"""
import os
import sys
import torch
import torchaudio
import numpy as np
from pathlib import Path

# vallexパスを設定
vallex_path = Path(__file__).parent / "vallex"
sys.path.insert(0, str(vallex_path))

# プロジェクトルートのutilsを一時的に削除
project_root = Path(__file__).parent
project_utils_path = str(project_root / "utils")
if project_utils_path in sys.path:
    sys.path.remove(project_utils_path)

original_cwd = os.getcwd()
os.chdir(vallex_path)

try:
    print("=" * 60)
    print("🎯 vocals.wavから声の特徴がある15秒を抽出")
    print("=" * 60)
    
    # ステップ1: 音声ファイルを読み込み
    audio_path = os.path.join(project_root, "vocals.wav")
    print(f"\n📁 音声ファイル: {audio_path}")
    
    wav, sr = torchaudio.load(audio_path)
    
    # ステレオをモノラルに変換
    if wav.size(0) == 2:
        wav = wav.mean(0, keepdim=True)
    
    # 正規化
    if wav.abs().max() > 1:
        wav = wav / wav.abs().max()
    
    total_length = wav.size(-1) / sr
    print(f"   長さ: {total_length:.2f} 秒")
    print(f"   サンプリングレート: {sr} Hz")
    
    # ステップ2: 15秒のセグメントに分割して分析
    segment_length = 15.0
    segment_samples = int(segment_length * sr)
    num_segments = int(np.ceil(total_length / segment_length))
    
    print(f"\n🔍 {segment_length}秒のセグメントを分析中...")
    
    segments = []
    for i in range(num_segments):
        start_sample = i * segment_samples
        end_sample = min(start_sample + segment_samples, wav.size(-1))
        
        if end_sample - start_sample < segment_samples * 0.5:  # 短すぎるセグメントはスキップ
            break
        
        segment = wav[:, start_sample:end_sample]
        start_time = start_sample / sr
        end_time = end_sample / sr
        
        # エネルギー（音量）を計算
        energy = (segment ** 2).mean().item()
        
        # ゼロクロッシング率（音声の特徴量）を計算
        segment_np = segment.squeeze().numpy()
        zero_crossings = np.sum(np.diff(np.signbit(segment_np)))
        zcr = zero_crossings / len(segment_np)
        
        # スペクトラル重心（音色の特徴）を計算
        fft = np.fft.rfft(segment_np)
        magnitude = np.abs(fft)
        freqs = np.fft.rfftfreq(len(segment_np), 1/sr)
        if np.sum(magnitude) > 0:
            spectral_centroid = np.sum(freqs * magnitude) / np.sum(magnitude)
        else:
            spectral_centroid = 0
        
        # 総合スコア（エネルギー + ゼロクロッシング率 + スペクトラル重心）
        # 正規化してスコアを計算
        score = energy * 0.5 + (zcr / 100) * 0.3 + (spectral_centroid / 5000) * 0.2
        
        segments.append({
            'index': i,
            'segment': segment,
            'start_time': start_time,
            'end_time': end_time,
            'energy': energy,
            'zcr': zcr,
            'spectral_centroid': spectral_centroid,
            'score': score
        })
        
        print(f"   セグメント {i}: {start_time:.1f}s - {end_time:.1f}s | "
              f"エネルギー: {energy:.6f} | ZCR: {zcr:.2f} | スペクトラル重心: {spectral_centroid:.1f}Hz | スコア: {score:.6f}")
    
    # ステップ3: 最適なセグメントを選択
    best_segment = max(segments, key=lambda x: x['score'])
    print(f"\n✅ 選択されたセグメント: {best_segment['index']}")
    print(f"   時間範囲: {best_segment['start_time']:.2f}s - {best_segment['end_time']:.2f}s")
    print(f"   スコア: {best_segment['score']:.6f}")
    
    # ステップ4: 選択されたセグメントを保存
    segment_path = os.path.join(project_root, "vocals_best_15sec.wav")
    torchaudio.save(segment_path, best_segment['segment'], sr)
    print(f"\n💾 セグメントを保存しました: {segment_path}")
    
    # ステップ5: プロンプトを作成
    print(f"\n🎤 プロンプトを作成中...")
    
    from utils import prompt_making
    prompt_making.device = torch.device('cpu')
    
    prompt_name = "vocals_15sec"
    prompt_making.make_prompt(prompt_name, segment_path)
    
    prompt_path = os.path.join(vallex_path, "customs", f"{prompt_name}.npz")
    print(f"✅ プロンプトを作成しました: {prompt_path}")
    
    # ステップ6: 音声生成をテスト
    print(f"\n🎵 音声生成をテスト中...")
    
    from utils.generation import SAMPLE_RATE, generate_audio, preload_models
    from scipy.io.wavfile import write as write_wav
    
    preload_models()
    
    test_text = "こんにちは、これは15秒のセグメントから作成した音声クローンのテストです。声の特徴がしっかりと再現されているか確認します。"
    
    print(f"📝 テストテキスト: {test_text}")
    
    audio_array = generate_audio(
        text=test_text,
        prompt=prompt_name,
        language="ja",
        accent="no-accent"
    )
    
    output_path = os.path.join(project_root, "test_vocals_15sec_clone.wav")
    write_wav(output_path, SAMPLE_RATE, audio_array)
    print(f"✅ テスト音声を保存しました: {output_path}")
    
    print("\n" + "=" * 60)
    print("✅ 完了！")
    print("=" * 60)
    print(f"\n📌 作成されたファイル:")
    print(f"   - 抽出セグメント: {segment_path}")
    print(f"   - プロンプト: {prompt_path}")
    print(f"   - テスト音声: {output_path}")
    print(f"\n📌 使用方法:")
    print(f"   python voice_clone.py generate \\")
    print(f"       --text '任意のテキスト' \\")
    print(f"       --prompt {prompt_name} \\")
    print(f"       --language ja \\")
    print(f"       --output output.wav")
    
finally:
    os.chdir(original_cwd)




