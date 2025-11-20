"""
音声クローン精度向上のためのユーティリティ
"""
import os
import torch
import torchaudio
import numpy as np
from pathlib import Path
from typing import Optional, Tuple


def preprocess_audio(
    audio_path: str,
    output_path: Optional[str] = None,
    normalize: bool = True,
    remove_noise: bool = False,
    target_sr: Optional[int] = None,
) -> Tuple[torch.Tensor, int]:
    """
    音声ファイルを前処理して品質を向上させる
    
    Args:
        audio_path: 入力音声ファイルのパス
        output_path: 出力ファイルのパス（Noneの場合は上書きしない）
        normalize: 音量を正規化するか
        remove_noise: ノイズ除去を実行するか（noisereduceが必要）
        target_sr: 目標サンプリングレート（Noneの場合は変更しない）
    
    Returns:
        処理された音声テンソルとサンプリングレート
    """
    # 音声を読み込み
    wav, sr = torchaudio.load(audio_path)
    
    # ステレオをモノラルに変換
    if wav.size(0) == 2:
        wav = wav.mean(0, keepdim=True)
    
    # リサンプリング
    if target_sr is not None and target_sr != sr:
        resampler = torchaudio.transforms.Resample(sr, target_sr)
        wav = resampler(wav)
        sr = target_sr
    
    # ノイズ除去
    if remove_noise:
        try:
            import noisereduce as nr
            # numpy配列に変換
            audio_np = wav.squeeze().numpy()
            # ノイズ除去
            reduced_noise = nr.reduce_noise(y=audio_np, sr=sr)
            # テンソルに戻す
            wav = torch.from_numpy(reduced_noise).unsqueeze(0)
        except ImportError:
            print("⚠️  noisereduceがインストールされていません。ノイズ除去をスキップします。")
            print("   インストール: pip install noisereduce")
    
    # 正規化
    if normalize:
        max_val = wav.abs().max()
        if max_val > 0:
            wav = wav / max_val
            # クリッピング（念のため）
            wav = torch.clamp(wav, -1.0, 1.0)
    
    # 保存
    if output_path:
        torchaudio.save(output_path, wav, sr)
        print(f"✅ 処理済み音声を保存しました: {output_path}")
    
    return wav, sr


def create_high_quality_prompt(
    name: str,
    audio_path: str,
    transcript: Optional[str] = None,
    preprocess: bool = True,
    whisper_model_size: str = "medium",
    output_dir: str = "./vallex/customs",
) -> str:
    """
    高品質なプロンプトを作成する
    
    Args:
        name: プロンプト名
        audio_path: 音声ファイルのパス
        transcript: 転写テキスト（Noneの場合はWhisperで自動生成）
        preprocess: 音声前処理を実行するか
        whisper_model_size: Whisperモデルのサイズ（tiny, base, small, medium, large, large-v2）
        output_dir: 出力ディレクトリ
    
    Returns:
        作成されたプロンプトファイルのパス
    """
    import sys
    vallex_path = Path(__file__).parent.parent / "vallex"
    sys.path.insert(0, str(vallex_path))
    os.chdir(vallex_path)
    
    from utils import prompt_making
    import torch
    
    # CPUを強制（MPSの問題を回避）
    prompt_making.device = torch.device('cpu')
    
    # 音声前処理
    if preprocess:
        processed_path = f"./prompts/{name}_processed.wav"
        os.makedirs("./prompts", exist_ok=True)
        preprocess_audio(audio_path, processed_path, normalize=True, remove_noise=False)
        audio_path = processed_path
    
    # より大きなWhisperモデルを使用（オプション）
    if whisper_model_size != "medium":
        # Whisperモデルを変更するには、prompt_makingモジュールを修正する必要があります
        print(f"⚠️  Whisperモデルサイズの変更には、prompt_making.pyの修正が必要です")
        print(f"    現在のモデル: medium（推奨: large-v2）")
    
    # プロンプトを作成
    prompt_making.make_prompt(name, audio_path, transcript)
    
    # 処理済みファイルを削除
    if preprocess and os.path.exists(f"./prompts/{name}_processed.wav"):
        os.remove(f"./prompts/{name}_processed.wav")
    
    prompt_path = os.path.join(output_dir, f"{name}.npz")
    print(f"✅ 高品質プロンプトを作成しました: {prompt_path}")
    
    return prompt_path


def generate_with_custom_params(
    text: str,
    prompt: Optional[str] = None,
    language: str = "auto",
    accent: str = "no-accent",
    temperature: float = 0.8,
    top_k: int = 50,
    output_path: str = "output.wav",
) -> np.ndarray:
    """
    カスタムパラメータで音声を生成する
    
    Args:
        text: 生成するテキスト
        prompt: プロンプト名またはパス
        language: 言語（auto, en, zh, ja, mix）
        accent: アクセント制御
        temperature: 温度パラメータ（0.7-1.3推奨）
        top_k: Top-kサンプリング（30-100推奨）
        output_path: 出力ファイルのパス
    
    Returns:
        生成された音声配列
    """
    import sys
    vallex_path = Path(__file__).parent.parent / "vallex"
    sys.path.insert(0, str(vallex_path))
    os.chdir(vallex_path)
    
    from utils.generation import SAMPLE_RATE, preload_models
    from models.vallex import VALLE
    from data.tokenizer import AudioTokenizer, tokenize_audio
    from data.collation import get_text_token_collater
    from utils.g2p import PhonemeBpeTokenizer
    from vocos import Vocos
    import langid
    import numpy as np
    
    langid.set_languages(['en', 'zh', 'ja'])
    
    # モデルをロード
    preload_models()
    
    # グローバル変数を取得
    import utils.generation as gen_module
    model = gen_module.model
    codec = gen_module.codec
    vocos = gen_module.vocos
    text_tokenizer = gen_module.text_tokenizer
    text_collater = gen_module.text_collater
    device = gen_module.device
    
    # テキスト処理
    text = text.replace("\n", "").strip(" ")
    if language == "auto":
        language = langid.classify(text)[0]
    
    from macros import lang2token, token2lang, langdropdown2token, NUM_QUANTIZERS, code2lang
    
    lang_token = lang2token[language]
    lang = token2lang[lang_token]
    text = lang_token + text + lang_token
    
    # プロンプトの読み込み
    if prompt is not None:
        prompt_path = prompt
        if not os.path.exists(prompt_path):
            prompt_path = f"./presets/{prompt}.npz"
        if not os.path.exists(prompt_path):
            prompt_path = f"./customs/{prompt}.npz"
        if not os.path.exists(prompt_path):
            raise ValueError(f"Cannot find prompt {prompt}")
        
        prompt_data = np.load(prompt_path)
        audio_prompts = prompt_data['audio_tokens']
        text_prompts = prompt_data['text_tokens']
        lang_pr = prompt_data['lang_code']
        lang_pr = code2lang[int(lang_pr)]
        
        audio_prompts = torch.tensor(audio_prompts).type(torch.int32).to(device)
        text_prompts = torch.tensor(text_prompts).type(torch.int32)
    else:
        audio_prompts = torch.zeros([1, 0, NUM_QUANTIZERS]).type(torch.int32).to(device)
        text_prompts = torch.zeros([1, 0]).type(torch.int32)
        lang_pr = lang if lang != 'mix' else 'en'
    
    enroll_x_lens = text_prompts.shape[-1]
    
    # テキストトークン化
    phone_tokens, langs = text_tokenizer.tokenize(text=f"_{text}".strip())
    text_tokens, text_tokens_lens = text_collater([phone_tokens])
    text_tokens = torch.cat([text_prompts, text_tokens], dim=-1)
    text_tokens_lens += enroll_x_lens
    
    # アクセント制御
    lang = lang if accent == "no-accent" else token2lang[langdropdown2token[accent]]
    
    # カスタムパラメータで推論
    encoded_frames = model.inference(
        text_tokens.to(device),
        text_tokens_lens.to(device),
        audio_prompts,
        enroll_x_lens=enroll_x_lens,
        top_k=top_k,  # カスタムパラメータ
        temperature=temperature,  # カスタムパラメータ
        prompt_language=lang_pr,
        text_language=langs if accent == "no-accent" else lang,
    )
    
    # デコード
    frames = encoded_frames.permute(2, 0, 1)
    features = vocos.codes_to_features(frames)
    samples = vocos.decode(features, bandwidth_id=torch.tensor([2], device=device))
    
    audio_array = samples.squeeze().cpu().numpy()
    
    # 保存
    from scipy.io.wavfile import write as write_wav
    write_wav(output_path, SAMPLE_RATE, audio_array)
    print(f"✅ 音声を保存しました: {output_path}")
    
    return audio_array


if __name__ == "__main__":
    # 使用例
    print("音声クローン精度向上ユーティリティ")
    print("詳細は improve_quality_guide.md を参照してください")




