# PersonaStamp Studio

Fish Audio SDKを使用した音声クローン・TTS（Text-to-Speech）の総合ツールキット

[![Python Version](https://img.shields.io/badge/python-3.10%2B-blue)](https://www.python.org/)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)

## 📋 概要

PersonaStamp Studioは、Fish Audio SDKを使用した音声クローン（Voice Cloning）とテキスト読み上げ（TTS）の完全なツールキットです。コマンドラインとWeb UIの両方を提供し、音声クローンの作成からTTS生成まで、簡単に実行できます。

## ✨ 主な機能

- 🎤 **音声クローン**: 10-30秒の音声サンプルから声を複製
- 🔊 **高品質TTS**: 自然な音声合成
- 🌐 **Web UI**: StreamlitベースのモダンなWebインターフェース
- 💻 **CLI**: コマンドラインからの実行も可能
- 😊 **感情表現**: (happy), (sad), (excited) などのタグで感情を制御
- ⚡ **韻律制御**: 話速と音量の調整
- 📦 **複数フォーマット**: WAV, MP3, Opus, PCM出力
- 🎵 **音源分離**: 音楽からボーカルのみを抽出（Demucs使用）
- 📺 **YouTube対応**: YouTubeから音声をダウンロード
- 🤖 **自動文字起こし**: Whisperによる自動文字起こし機能

## 📁 プロジェクト構造

```
PersonaStamp_Studio/
├── app/                          # Streamlit Web UI
│   ├── app.py                    # メインのWebアプリケーション
│   ├── create_voice_clone.py     # 音声クローンモデル作成機能
│   ├── generate_tts.py           # TTS生成機能
│   ├── models.json               # モデル情報の永続化ストレージ
│   └── README.md                 # Web UIの詳細ドキュメント
├── src/                          # コマンドライン用スクリプト
│   ├── create_voice_clone.py     # 音声クローンモデル作成
│   ├── generate_tts.py           # TTS音声生成
│   ├── utils/                    # ユーティリティ
│   │   ├── audio_separation.py   # 音源分離（ボーカル抽出）
│   │   └── youtube_downloader.py # YouTube音声ダウンロード
│   └── README.md                 # CLIの詳細ドキュメント
├── docs/                         # ドキュメント
│   ├── SETUP.md                  # 詳細セットアップガイド
│   ├── PROJECT_SUMMARY.md        # プロジェクトサマリー
│   └── FISH_AUDIO_README.md      # Fish Audio公式ドキュメント
├── examples/                     # 音声サンプル
├── output/                       # 生成された音声ファイル
├── workflow.py                   # 対話式の完全ワークフロー
├── requirements.txt              # 依存パッケージ
├── packages.txt                  # Streamlit Cloud用システム依存
└── README.md                     # このファイル
```

## 🚀 クイックスタート

### 1. 前提条件

- **Python**: 3.10以上（推奨: 3.10.11）
- **Fish Audio APIキー**: [Fish Audio](https://fish.audio) で取得

### 2. インストール

```bash
# リポジトリをクローン
git clone <repository-url>
cd PersonaStamp_Studio

# 依存パッケージのインストール
pip install -r requirements.txt
```

### 3. APIキーの設定

**方法1: .envファイルを使用（推奨）**

```bash
# .envファイルを作成
echo "FISH_AUDIO_API_KEY=your_actual_api_key_here" > .env
```

**方法2: 環境変数で設定**

```bash
# macOS/Linux
export FISH_AUDIO_API_KEY="your_api_key_here"

# Windows (PowerShell)
$env:FISH_AUDIO_API_KEY = "your_api_key_here"
```

### 4. 起動方法

#### 🌐 Web UIを使用（推奨）

```bash
streamlit run app/app.py
```

ブラウザで `http://localhost:8501` が自動的に開きます。

**詳細な使い方は [app/README.md](app/README.md) を参照してください。**

#### 💻 コマンドラインを使用

対話式のワークフローで全ステップを実行:

```bash
python workflow.py
```

個別のスクリプトを実行:

```bash
# 音声クローンモデルの作成
python src/create_voice_clone.py

# TTS音声の生成
python src/generate_tts.py
```

**詳細な使い方は [src/README.md](src/README.md) を参照してください。**

## 📖 使い方の選択

### Web UI（app/）

- ✅ **初心者向け**: 直感的なGUI
- ✅ **モダンなUI**: ダークモード対応
- ✅ **モデル管理**: 視覚的なモデル管理機能
- ✅ **自動文字起こし**: Whisperによる自動文字起こし
- ✅ **スマホ対応**: モバイルブラウザでも動作

→ [app/README.md](app/README.md) を参照

### コマンドライン（src/）

- ✅ **自動化**: スクリプトでの自動実行
- ✅ **音源分離**: 音楽からボーカル抽出
- ✅ **YouTube対応**: YouTubeから音声ダウンロード
- ✅ **バッチ処理**: 複数ファイルの一括処理

→ [src/README.md](src/README.md) を参照

## 🔧 オプション機能

### 音源分離機能

音楽ファイルからボーカル（人の声）のみを抽出します。

```bash
# Demucsをインストール
pip install demucs

# ボーカルのみ抽出
python src/utils/audio_separation.py song.mp3
```

### YouTube音声ダウンロード

```bash
# yt-dlpをインストール
pip install yt-dlp

# YouTubeから音声をダウンロード
python src/utils/youtube_downloader.py "https://www.youtube.com/watch?v=xxxxx"
```

## ☁️ Streamlit Cloudでのデプロイ

Streamlit Cloudでデプロイする場合：

1. GitHubリポジトリにプッシュ
2. [Streamlit Cloud](https://streamlit.io/cloud) でアプリを接続
3. アプリのパスを `app/app.py` に設定
4. 環境変数 `FISH_AUDIO_API_KEY` を設定

**注意**: `packages.txt` に `ffmpeg` が含まれていることを確認してください（Whisper機能に必要）。

## 📚 ドキュメント

- [Web UI 詳細ドキュメント](app/README.md) - Streamlitアプリの使い方
- [CLI 詳細ドキュメント](src/README.md) - コマンドラインスクリプトの使い方
- [詳細セットアップガイド](docs/SETUP.md)
- [プロジェクトサマリー](docs/PROJECT_SUMMARY.md)
- [Fish Audio 公式ドキュメント](https://docs.fish.audio/)

## ⚠️ 注意事項

- **セキュリティ**: APIキーは`.env`ファイルで管理し、絶対にGitにコミットしないでください
- **音声サンプル**: クリアな音質でノイズのないものを使用してください
- **APIクレジット**: APIクレジットの消費に注意してください
- **商用利用**: 商用利用の際はFish Audioの利用規約を確認してください

## 🤝 貢献

Issue、Pull Requestを歓迎します！

## 📄 ライセンス

このプロジェクトはMITライセンスの下で公開されています。

## 🔗 リンク

- [Fish Audio 公式サイト](https://fish.audio)
- [Fish Audio ドキュメント](https://docs.fish.audio/)
- [Fish Audio SDK (PyPI)](https://pypi.org/project/fish-audio-sdk/)
- [Streamlit Documentation](https://docs.streamlit.io/)

## 📞 サポート

質問や問題がある場合は、[Issues](https://github.com/yourusername/PersonaStamp_Studio/issues) にて報告してください。
