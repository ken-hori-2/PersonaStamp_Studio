# Audio Tools - Streamlit Web UI

YouTube音声ダウンロードと音源分離のためのWebインターフェース

## 📋 機能概要

### 📺 YouTube音声ダウンロード
- YouTube URLから音声をダウンロード
- WAV形式に自動変換
- ダウンロードした音声の再生・ダウンロード機能

### 🎤 音源分離（ボーカル抽出）
- 音楽ファイルからボーカル（人の声）を抽出
- Demucsによる高精度音源分離
- ボーカルのみ分離（高速）と完全分離（4-stem）の両方に対応
- 分離結果の再生・ダウンロード機能

## 🚀 セットアップ

### 必要な環境

- Python 3.10以上
- 以下のツール（オプション）:
  - `yt-dlp`: YouTubeダウンロード用
  - `demucs`: 音源分離用
  - `ffmpeg`: 音声変換用（システムレベルでインストールが必要）

### インストール

1. リポジトリのルートディレクトリで依存関係をインストール：
   ```bash
   pip install -r requirements.txt
   ```

2. オプション機能のインストール：

   **YouTubeダウンロード機能:**
   ```bash
   pip install yt-dlp
   ```

   **音源分離機能:**
   ```bash
   pip install demucs
   ```

   **ffmpeg（システムレベル）:**
   - macOS: `brew install ffmpeg`
   - Ubuntu/Debian: `sudo apt install ffmpeg`
   - Windows: [ffmpeg公式サイト](https://ffmpeg.org/download.html)からダウンロード

## 💻 起動方法

```bash
streamlit run app_audio_tools/app.py
```

ブラウザで `http://localhost:8501` が自動的に開きます。

## 📖 使い方

### 1. YouTube音声ダウンロード

1. 「📺 YouTubeダウンロード」タブを選択
2. YouTube URLを入力
3. 「📥 ダウンロード開始」ボタンをクリック
4. ダウンロード完了後、音声を再生・ダウンロードできます

**出力先:** `examples/downloaded_YYYYMMDD_HHMMSS.wav`

### 2. 音源分離

1. 「🎤 音源分離」タブを選択
2. 音楽ファイルをアップロード（WAV, MP3, M4A, FLAC, OGG形式対応）
3. 分離モードを選択:
   - **ボーカルのみ（高速・推奨）**: vocalsとno_vocalsのみ出力
   - **完全分離（4-stem）**: vocals, drums, bass, otherを出力
4. 分離モデルを選択（htdemucs推奨）
5. 「🎵 音源分離を開始」ボタンをクリック
6. 分離完了後、各パートを再生・ダウンロードできます

**出力先:** `separated/<モデル名>/<ファイル名>/`

**注意:** 初回実行時はモデルのダウンロードで数分かかります。

## 📁 ファイル構成

```
app_audio_tools/
├── app.py          # メインのStreamlitアプリケーション
└── README.md       # このファイル
```

## ⚠️ 注意事項

1. **ツールのインストール**: 各機能を使用するには、対応するツール（yt-dlp、demucs、ffmpeg）がインストールされている必要があります。サイドバーで状態を確認できます。

2. **処理時間**: 
   - YouTubeダウンロード: 動画の長さとネットワーク速度に依存
   - 音源分離: ファイルサイズと選択したモデルに依存（初回はモデルダウンロードで時間がかかります）

3. **ファイルサイズ**: 大きなファイルの処理には時間がかかる場合があります。

4. **出力ファイル**: ダウンロードや分離したファイルは、プロジェクトの`examples/`や`separated/`ディレクトリに保存されます。

## 🔗 関連リンク

- [yt-dlp Documentation](https://github.com/yt-dlp/yt-dlp)
- [Demucs GitHub](https://github.com/facebookresearch/demucs)
- [ffmpeg Documentation](https://ffmpeg.org/documentation.html)
- [Streamlit Documentation](https://docs.streamlit.io/)

## 🤝 貢献

バグ報告や機能要望は、GitHubのIssuesでお願いします。

