# VALL-E-X スタイル音声クローン

MicrosoftのVALL-E XゼロショットTTSモデルのオープンソース実装を参考にした音声クローンシステムです。

## 特徴

- 🎤 **ゼロショット音声クローン**: 3-10秒の音声サンプルから音声をクローン
- 🌍 **多言語対応**: 英語、日本語、中国語に対応
- 🎭 **感情制御**: 音声プロンプトの感情を維持
- 🔀 **クロスリンガル**: 異なる言語での音声合成
- 🎚️ **アクセント制御**: アクセントの制御が可能

## インストール

### 1. 仮想環境の作成と有効化

```bash
# 仮想環境を作成（Python 3.10を使用）
python3.10 -m venv env

# 仮想環境を有効化
source env/bin/activate  # macOS/Linux
# または
env\Scripts\activate  # Windows
```

### 2. 依存関係のインストール

```bash
pip install --upgrade pip setuptools wheel
pip install -r requirements.txt
```

**注意**: `sudachipy`はRustコンパイラが必要なため、インストールが失敗する場合があります。日本語処理には`pyopenjtalk-prebuilt`が使用されます。

### 3. モデルのダウンロード

初回実行時に自動的にモデルがダウンロードされます。手動でダウンロードする場合は、以下のURLからダウンロードして `./checkpoints/` ディレクトリに配置してください。

- VALL-E-X チェックポイント: https://huggingface.co/Plachta/VALL-E-X/resolve/main/vallex-checkpoint.pt
- Whisper モデル: https://openaipublic.azureedge.net/main/whisper/models/345ae4da62f9b3d59415adc60127b97c714f32e89e936602e85993674d08dcb1/medium.pt (whisper/ディレクトリに配置)

## 使用方法

### 基本的な音声生成

```python
from utils.generation import SAMPLE_RATE, generate_audio, preload_models
from scipy.io.wavfile import write as write_wav

# モデルのロード
preload_models()

# テキストから音声を生成
text = "Hello, this is a test of voice cloning."
audio_array = generate_audio(text)

# 音声を保存
write_wav("output.wav", SAMPLE_RATE, audio_array)
```

### 音声クローン（推奨方法）

`clone_voice.py`を使用すると、音声クローンの作成から音声生成まで簡単に実行できます。

#### 方法1: 一括実行（最も簡単）

```python
from clone_voice import clone_and_generate

# 音声ファイルからクローンを作成し、テキストを生成
prompt_path, output_file = clone_and_generate(
    audio_path="path/to/your/voice_sample.wav",
    text="こんにちは、これは音声クローンのテストです。",
    prompt_name="my_voice",  # 省略可（音声ファイル名から自動生成）
    output_path="output.wav",
    language="ja",  # または "auto" で自動検出
)
```

#### 方法2: ステップバイステップ

```python
from clone_voice import create_voice_clone, generate_with_cloned_voice

# ステップ1: プロンプトの作成
prompt_path = create_voice_clone(
    audio_path="path/to/your/voice_sample.wav",
    prompt_name="my_voice",
    transcript=None,  # Noneの場合はWhisperで自動転写
    auto_transcribe=True,
)

# ステップ2: クローン音声でテキストを生成
output_file = generate_with_cloned_voice(
    text="Hello, this is a test.",
    prompt_name="my_voice",
    output_path="output.wav",
    language="auto",
)
```

#### 方法3: 低レベルAPI（詳細な制御が必要な場合）

```python
from utils.prompt_making import make_prompt
from utils.generation import generate_audio, preload_models

# プロンプトの作成
make_prompt(
    name="my_voice",
    audio_prompt_path="path/to/your/voice_sample.wav",
    transcript="This is the transcript of the audio.",  # 省略可
)

# モデルのロード
preload_models()

# 音声生成
audio_array = generate_audio(text="Hello, world!", prompt="my_voice")
write_wav("output.wav", SAMPLE_RATE, audio_array)
```

### コマンドライン使用

#### 音声生成

```bash
python voice_clone.py generate \
    --text "Hello, this is a test." \
    --prompt "my_voice" \
    --output "output.wav"
```

#### 音声クローンの作成と生成（推奨）

```bash
# 一括実行（プロンプト作成 + 音声生成）
python clone_voice.py clone \
    --audio "path/to/voice_sample.wav" \
    --text "Hello, this is a test." \
    --name "my_voice" \
    --output "output.wav"

# プロンプトのみ作成
python clone_voice.py create \
    --audio "path/to/voice_sample.wav" \
    --name "my_voice" \
    --transcript "Transcript text"  # 省略可（自動転写）

# 既存のプロンプトで音声生成
python clone_voice.py generate \
    --text "Hello, world!" \
    --prompt "my_voice" \
    --output "output.wav"
```

#### 従来の方法（voice_clone.py）

```bash
# プロンプト作成
python voice_clone.py create_prompt \
    --name "my_voice" \
    --audio "path/to/voice_sample.wav" \
    --transcript "Transcript text"  # 省略可
```

#### プロンプト一覧

```bash
python voice_clone.py list_prompts
```

## プロジェクト構造

```
voice_clone/
├── utils/
│   ├── __init__.py
│   ├── generation.py      # 音声生成機能（VALL-E-Xラッパー）
│   └── prompt_making.py   # プロンプト作成機能（VALL-E-Xラッパー）
├── vallex/                # VALL-E-Xリポジトリ（クローン済み）
├── checkpoints/           # モデルチェックポイント（自動生成）
├── customs/               # カスタム音声プロンプト（自動生成）
├── prompts/               # 音声プロンプト（自動生成）
├── whisper/               # Whisperモデル（自動生成）
├── env/                   # 仮想環境
├── voice_clone.py         # メインスクリプト
├── example.py             # 使用例
├── requirements.txt       # 依存関係
└── README.md             # このファイル
```

## 対応言語

| 言語 | コード | ステータス |
|------|--------|-----------|
| 英語 | `en` | ✅ |
| 日本語 | `ja` | ✅ |
| 中国語（簡体字） | `zh` | ✅ |

## ハードウェア要件

- **GPU**: 6GB VRAM以上推奨（CPUでも動作可能）
- **メモリ**: 8GB以上推奨
- **ストレージ**: モデルファイル用に数GB必要

## 注意事項

✅ **VALL-E-Xの実装が統合されました！**

このプロジェクトは、[VALL-E-X](https://github.com/Plachtaa/VALL-E-X)リポジトリをクローンし、その機能をラッパーとして提供します。実際のVALL-E-Xモデルが使用されます。

## 参考リポジトリ

- [VALL-E-X (Plachtaa)](https://github.com/Plachtaa/VALL-E-X)
- [VALL-E (Microsoft)](https://github.com/microsoft/unilm/tree/master/valle)

## ライセンス

MIT License

## トラブルシューティング

### モデルのダウンロードが失敗する場合

手動でモデルをダウンロードして `./checkpoints/` ディレクトリに配置してください。

### Whisperの転写が失敗する場合

`--transcript` オプションで手動で転写テキストを指定してください。

### メモリ不足エラー

GPUのVRAMが不足する場合は、モデルのオフローディング機能を使用するか、より小さなバッチサイズを使用してください。
