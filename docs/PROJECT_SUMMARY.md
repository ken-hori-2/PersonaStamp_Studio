# プロジェクトサマリー

## 概要

Fish Audio SDKを使用した音声クローン・TTS（Text-to-Speech）の総合ツールキットです。YouTubeからの音声取得、音源分離、音声クローン作成、TTS生成までの完全なワークフローを提供します。

## ファイル構成

### メインスクリプト

- **workflow.py** - 対話式の完全ワークフロー（初心者向け）
- **src/create_voice_clone.py** - 音声クローンモデル作成
- **src/generate_tts.py** - TTS音声生成

### ユーティリティ

- **src/utils/audio_separation.py** - Demucsによる音源分離（ボーカル抽出）
- **src/utils/youtube_downloader.py** - YouTube音声ダウンロード

### ディレクトリ

- **examples/** - 入力音声サンプル
- **output/** - 生成されたTTS音声
- **separated/** - 音源分離の出力
- **docs/** - ドキュメント

## 主な機能

### 1. 音源分離（audio_separation.py）

**目的:** 音楽ファイルからボーカル（人の声）のみを抽出

**使用技術:** Demucs（最先端の音源分離AI）

**モデル:**
- `htdemucs` - 最高品質（推奨）
- `htdemucs_ft` - fine-tuned版
- `mdx_extra` - 超高品質（処理時間長）

**使い方:**
```powershell
# ボーカルのみ抽出（高速）
python src/utils/audio_separation.py song.mp3

# 完全分離（vocals, drums, bass, other）
python src/utils/audio_separation.py song.mp3 full
```

**出力:**
- `separated/htdemucs/<filename>/vocals.wav` - ボーカルのみ
- `separated/htdemucs/<filename>/no_vocals.wav` - 伴奏のみ

### 2. YouTube音声ダウンロード（youtube_downloader.py）

**目的:** YouTubeから音声を取得してWAV形式で保存

**使用技術:** yt-dlp + ffmpeg

**使い方:**
```powershell
python src/utils/youtube_downloader.py "https://www.youtube.com/watch?v=xxxxx"
```

**出力:** `examples/downloaded.wav`

### 3. 音声クローン作成（create_voice_clone.py）

**目的:** 音声サンプルから声を複製するAIモデルを作成

**必要なもの:**
- 10-30秒のクリアな音声サンプル
- Fish Audio APIキー
- APIクレジット

**使い方:**
```powershell
python src/create_voice_clone.py
```

**出力:** 
- モデルID（`model_id.txt` に保存）
- Fish Audioクラウドに音声モデルが作成される

### 4. TTS生成（generate_tts.py）

**目的:** 作成した音声モデルでテキストから音声を生成

**機能:**
- カスタム音声での音声合成
- 感情表現タグ: (happy), (sad), (excited) など
- 話速・音量の調整
- 複数フォーマット対応: WAV, MP3, Opus, PCM

**使い方:**
```powershell
python src/generate_tts.py
```

**出力:** `output/tts_output_<timestamp>.wav`

### 5. 統合ワークフロー（workflow.py）

**目的:** 対話式で全ステップを実行

**フロー:**
1. 音声ソース選択（ファイル or YouTube）
2. 音源分離（オプション）
3. 音声クローンモデル作成
4. TTS生成テスト（オプション）

**使い方:**
```powershell
python workflow.py
```

## ワークフローの例

### パターンA: YouTubeから音声クローンを作成

```powershell
# 1. YouTubeから音声をダウンロード
python src/utils/youtube_downloader.py "https://youtu.be/xxxxx"

# 2. ボーカルを抽出
python src/utils/audio_separation.py examples/downloaded.wav

# 3. 音声クローンを作成
python src/create_voice_clone.py
# → examples内のボーカル音声を指定

# 4. TTSで音声生成
python src/generate_tts.py
```

### パターンB: 既存の音声ファイルから作成

```powershell
# 音楽ファイルがある場合
python src/utils/audio_separation.py my_song.mp3

# クリアな音声ファイルがある場合は直接作成
python src/create_voice_clone.py
# → examples/my_voice.wav を指定

python src/generate_tts.py
```

### パターンC: ワークフローを使用（最も簡単）

```powershell
python workflow.py
# → 対話式で全ステップを実行
```

## 依存関係

### 必須
- `fish-audio-sdk` - Fish Audio SDK
- `python-dotenv` - 環境変数管理

### オプション
- `demucs` - 音源分離（pip install demucs）
- `yt-dlp` - YouTubeダウンロード（pip install yt-dlp）
- `ffmpeg` - 音声変換（システムインストール）

## 環境変数

`.env`ファイルで管理:

```
FISH_AUDIO_API_KEY=your_api_key_here
```

`.env.example`をコピーして使用:
```powershell
Copy-Item .env.example .env
# .envファイルを編集してAPIキーを設定
```

## 出力ファイル

| ディレクトリ | 内容 | Git管理 |
|------------|------|---------|
| examples/ | 入力音声サンプル | ❌ (.gitignore) |
| separated/ | 音源分離結果 | ❌ (.gitignore) |
| output/ | 生成されたTTS音声 | ❌ (.gitignore) |
| model_id.txt | モデルID | ❌ (.gitignore) |

## トラブルシューティング

### demucsが動作しない
```powershell
pip install demucs
```

### yt-dlpが動作しない
```powershell
pip install yt-dlp
# ffmpegもインストールが必要
```

### APIキーエラー
- `.env`ファイルが作成されているか確認
- `FISH_AUDIO_API_KEY`が正しく設定されているか確認
- Fish Audioアカウントのクレジット残高を確認

### 音声クローンの品質が低い
- 10-30秒のクリアな音声サンプルを使用
- ノイズのない音声を使用
- 音源分離でボーカルを抽出してから使用

## APIクレジット

Fish Audio APIは使用量に応じて課金されます:
- 音声クローンモデル作成: クレジット消費
- TTS生成: テキスト長に応じて消費

詳細: https://fish.audio/pricing

## ライセンス

MIT License

## 関連リンク

- [Fish Audio 公式サイト](https://fish.audio)
- [Fish Audio ドキュメント](https://docs.fish.audio/)
- [Demucs GitHub](https://github.com/facebookresearch/demucs)
- [yt-dlp GitHub](https://github.com/yt-dlp/yt-dlp)
