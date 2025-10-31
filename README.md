# Fish Audio TTS Demo

Fish Audio SDKを使用した音声クローン・TTSのデモプロジェクト

[![Python Version](https://img.shields.io/badge/python-3.10%2B-blue)](https://www.python.org/)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)

## 📋 概要

このプロジェクトは、Fish Audio SDKを使用した音声クローン（Voice Cloning）とテキスト読み上げ（TTS: Text-to-Speech）のサンプル実装です。

## ✨ 機能

- 🎤 **音声クローン**: 10-30秒の音声サンプルから声を複製
- 🔊 **高品質TTS**: 自然な音声合成
- 😊 **感情表現**: (happy), (sad), (excited) などのタグで感情を制御
- ⚡ **韻律制御**: 話速と音量の調整
- 📦 **複数フォーマット**: WAV, MP3, Opus, PCM出力
- 🎵 **音源分離**: 音楽からボーカルのみを抽出（Demucs使用）
- 📺 **YouTube対応**: YouTubeから音声をダウンロード

## 📁 プロジェクト構造

```
fish_audio_demo/
├── src/
│   ├── create_voice_clone.py    # 音声クローンモデル作成
│   ├── generate_tts.py           # TTS音声生成
│   └── utils/                    # ユーティリティ
│       ├── audio_separation.py   # 音源分離（ボーカル抽出）
│       └── youtube_downloader.py # YouTube音声ダウンロード
├── examples/                     # 音声サンプル
├── output/                       # 生成された音声ファイル
├── separated/                    # 音源分離結果
├── docs/                         # ドキュメント
│   ├── SETUP.md                  # 詳細セットアップガイド
│   └── FISH_AUDIO_README.md      # Fish Audio公式ドキュメント
├── requirements.txt              # 依存パッケージ
├── .env.example                  # 環境変数テンプレート
└── README.md                     # このファイル
```

## 🚀 クイックスタート

### 1. 前提条件

- **Python**: 3.10以上（推奨: 3.10.11）
- **Fish Audio APIキー**: [Fish Audio](https://fish.audio) で取得

### 2. インストール

**基本パッケージ**

```powershell
# 依存パッケージのインストール
pip install -r requirements.txt
```

**オプション: 音源分離機能**

```powershell
# 音楽からボーカルを抽出する場合
pip install demucs

# YouTubeから音声をダウンロードする場合
pip install yt-dlp
# ※ ffmpeg のシステムインストールも必要
```

### 3. APIキーの設定

**方法1: .envファイルを使用（推奨）**

```powershell
# .env.example をコピーして .env を作成
Copy-Item .env.example .env

# .env ファイルを編集してAPIキーを設定
# FISH_AUDIO_API_KEY=your_actual_api_key_here
```

**方法2: 環境変数で設定**

```powershell
$env:FISH_AUDIO_API_KEY = "your_api_key_here"
```

### 4. 実行

#### 🚀 簡単スタート（推奨）

対話式のワークフローで全ステップを実行:

```powershell
python workflow.py
```

このスクリプトが以下をガイドします:
1. 音声ソースの選択（ファイル or YouTube）
2. 音源分離（必要に応じて）
3. 音声クローンモデル作成
4. TTS生成テスト

#### 個別実行

各機能を個別に実行する場合:

##### 音声クローンモデルの作成

```powershell
python src/create_voice_clone.py
```

##### TTS音声の生成

```powershell
python src/generate_tts.py
```

## 📖 詳細な使い方

### ワークフロー全体

#### 1. YouTubeから音声を取得（オプション）

```powershell
python src/utils/youtube_downloader.py "https://www.youtube.com/watch?v=xxxxx"
```

#### 2. 音楽からボーカルを抽出（オプション）

```powershell
# 音楽ファイルからボーカルのみを抽出
python src/utils/audio_separation.py examples/downloaded.wav

# 出力: separated/htdemucs/downloaded/vocals.wav
```

#### 3. 音声クローンモデルを作成

```powershell
# 抽出したボーカル音声でクローンを作成
python src/create_voice_clone.py
```

#### 4. TTSで音声を生成

```powershell
python src/generate_tts.py
```

### 各機能の詳細

#### 音源分離

音楽ファイルからボーカル（人の声）のみを抽出します。

```powershell
# 基本的な使用（ボーカルのみ抽出）
python src/utils/audio_separation.py song.mp3

# 完全分離（vocals, drums, bass, other）
python src/utils/audio_separation.py song.mp3 full

# 高品質モデルを使用
python src/utils/audio_separation.py song.mp3 vocal htdemucs_ft
```

**対応モデル:**
- `htdemucs`: 最高品質（推奨・デフォルト）
- `htdemucs_ft`: 最高品質・fine-tuned版
- `mdx_extra`: 超高品質（処理時間長）

#### YouTube音声ダウンロード

```powershell
python src/utils/youtube_downloader.py "https://www.youtube.com/watch?v=xxxxx"
# または短縮URL
python src/utils/youtube_downloader.py "https://youtu.be/xxxxx"
```

### 音声クローン

1. 10-30秒程度のクリアな音声サンプルを `examples/` に配置
2. `src/create_voice_clone.py` を実行
3. 生成されたモデルIDが `model_id.txt` に保存されます

### TTS生成

生成されたモデルIDを使用して、以下のオプションで音声を生成できます:

- **基本的なTTS**: デフォルト設定での音声生成
- **長文TTS**: 長いテキストの自然な読み上げ
- **感情表現**: (happy), (sad), (excited) などのタグを使用
- **話速・音量調整**: speed（0.5-2.0）とvolume（-20~20）のパラメータ

## 📚 ドキュメント

- [詳細セットアップガイド](docs/SETUP.md)
- [Fish Audio 公式ドキュメント](https://docs.fish.audio/)
- [Python SDK リファレンス](https://docs.fish.audio/sdk-reference/python/)

## ⚠️ 注意事項

- **セキュリティ**: APIキーは`.env`ファイルで管理し、絶対にGitにコミットしないでください
- 音声サンプルはクリアな音質でノイズのないものを使用してください
- APIクレジットの消費に注意してください
- 商用利用の際はFish Audioの利用規約を確認してください

## 🤝 貢献

Issue、Pull Requestを歓迎します！

## 📄 ライセンス

このプロジェクトはMITライセンスの下で公開されています。

## 🔗 リンク

- [Fish Audio 公式サイト](https://fish.audio)
- [Fish Audio ドキュメント](https://docs.fish.audio/)
- [Fish Audio SDK (PyPI)](https://pypi.org/project/fish-audio-sdk/)

## 📞 サポート

質問や問題がある場合は、[Issues](https://github.com/yourusername/fish_audio_demo/issues) にて報告してください。
