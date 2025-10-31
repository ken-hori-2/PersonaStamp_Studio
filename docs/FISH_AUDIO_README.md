# Fish Audio 音声クローン & TTS プロジェクト

Fish Audio SDKを使用した音声クローンとテキスト読み上げ（TTS）の実装です。

## 📋 概要

このプロジェクトは、Fish Audioの音声クローン技術を使用して、わずか数秒の音声サンプルからその人の声を再現し、任意のテキストを読み上げることができます。

## 🚀 セットアップ

### 1. 必要なパッケージのインストール

```powershell
pip install fish-audio-sdk
```

### 2. APIキーの取得

1. [Fish Audio](https://fish.audio)にアクセス
2. アカウントを作成
3. ダッシュボードからAPIキーを取得

### 3. APIキーの設定

**方法1: 環境変数（推奨）**
```powershell
$env:FISH_AUDIO_API_KEY = "your_api_key_here"
```

**方法2: スクリプト内で直接設定**
各スクリプトの`API_KEY`変数を編集：
```python
API_KEY = "your_api_key_here"
```

## 📁 ファイル構成

```
├── fish_audio.py                # プロジェクト説明（このファイル）
├── 1_create_voice_clone.py      # 音声クローンモデル作成
├── 2_generate_tts.py            # TTS音声生成
├── FISH_AUDIO_README.md         # このREADME
├── sample_voice.wav             # 音声サンプル（あなたが用意）
└── model_id.txt                 # 作成されたモデルID（自動生成）
```

## 🎯 使い方

### ステップ1: 音声クローンモデルの作成

1. **音声サンプルを準備**
   - ファイル名: `sample_voice.wav`
   - 推奨長さ: 10-30秒
   - 品質: クリアで雑音なし

2. **スクリプトを実行**
   ```powershell
   python 1_create_voice_clone.py
   ```

3. **出力**
   - モデルIDが`model_id.txt`に保存されます
   - 既存モデルの一覧が表示されます

### ステップ2: TTSで音声を生成

1. **スクリプトを実行**
   ```powershell
   python 2_generate_tts.py
   ```

2. **生成される音声ファイル**
   - `tts_basic.wav` - 基本的な音声
   - `tts_long.wav` - 長いテキストの音声
   - `tts_emotions.wav` - 感情表現付き音声

## 🎨 機能

### 1_create_voice_clone.py の機能

- ✅ 音声ファイルから音声クローンモデルを作成
- ✅ 既存モデルの一覧表示
- ✅ モデルIDの自動保存
- ✅ 音質向上オプション
- ✅ 複数の音声サンプル対応

### 2_generate_tts.py の機能

- ✅ カスタム音声モデルでのTTS生成
- ✅ 複数フォーマット対応（WAV, MP3, Opus, PCM）
- ✅ 話速・音量の調整
- ✅ 感情表現のサポート
- ✅ 長文テキストの処理
- ✅ タイムスタンプ付き出力ファイル名

## 🎭 感情表現

テキスト内で以下のタグを使用して感情を表現できます：

```python
text = """
(happy) とても嬉しいニュースです！
(sad) 残念ながら、期待通りではありませんでした。
(excited) これは素晴らしい発見です！
(calm) それでは、説明を始めます。
(angry) これは許せません！
(surprised) まさか、そんなことが！
(whispering) これは秘密です。
"""
```

利用可能な感情タグ：
- `(happy)` - 嬉しい
- `(sad)` - 悲しい
- `(angry)` - 怒り
- `(excited)` - 興奮
- `(calm)` - 穏やか
- `(surprised)` - 驚き
- `(whispering)` - ささやき
- `(shouting)` - 叫び
- `(laughing)` - 笑い

## ⚙️ カスタマイズ

### 話速と音量の調整

```python
generate_tts(
    api_key=API_KEY,
    text="テキスト",
    model_id=model_id,
    speed=1.2,    # 1.2倍速（0.5-2.0）
    volume=5      # 音量+5（-20～+20）
)
```

### 出力フォーマットの変更

```python
generate_tts(
    api_key=API_KEY,
    text="テキスト",
    model_id=model_id,
    format="mp3",         # mp3, wav, opus, pcm
    output_file="output.mp3"
)
```

### 複数の音声サンプルを使用

`1_create_voice_clone.py`を編集：

```python
# 複数の音声ファイルを読み込む
voices = []
texts = []

for i in range(3):
    with open(f"sample_{i}.wav", "rb") as f:
        voices.append(f.read())
        texts.append(f"サンプル{i}のテキスト")

model = session.create_model(
    title="高品質ボイスモデル",
    voices=voices,
    texts=texts,
    enhance_audio_quality=True
)
```

## 📝 ベストプラクティス

### 音声サンプルの品質

✅ **推奨**
- 10-30秒の長さ
- クリアな音声
- バックグラウンドノイズなし
- 生成言語と同じ言語
- 多様なイントネーション

❌ **避けるべき**
- 短すぎる（10秒未満）
- 雑音が多い
- 音量が小さすぎる/大きすぎる
- 複数の話者が混在

### 文字起こしの重要性

音声サンプルの文字起こしを提供すると品質が向上します：

```python
create_voice_clone_model(
    api_key=API_KEY,
    audio_file_path="sample_voice.wav",
    transcription="こんにちは、私の名前は太郎です。"
)
```

### パフォーマンスのヒント

1. 頻繁に使う声はモデルとして事前アップロード
2. 2-3個の音声サンプルで最適な品質
3. 各サンプルは30秒以内に
4. 音声レベルを正規化してからアップロード

## 🔧 トラブルシューティング

### APIキーエラー

```
警告: APIキーが設定されていません！
```

**解決方法:**
- 環境変数`FISH_AUDIO_API_KEY`を設定
- またはスクリプト内の`API_KEY`を編集

### 音声ファイルが見つからない

```
エラー: 音声ファイルが見つかりません: sample_voice.wav
```

**解決方法:**
- `sample_voice.wav`をスクリプトと同じディレクトリに配置
- またはスクリプト内の`AUDIO_FILE`パスを変更

### モデルIDファイルがない

```
警告: model_id.txt が見つかりません
```

**解決方法:**
- 先に`1_create_voice_clone.py`を実行
- または手動でモデルIDを入力

### 音声品質が悪い

**解決方法:**
1. より長い音声サンプルを使用（10-30秒）
2. 複数の音声サンプルを提供
3. 音声サンプルの品質を改善
4. 文字起こしを追加

## 📚 参考資料

- [Fish Audio 公式ドキュメント](https://docs.fish.audio/)
- [Voice Cloning ガイド](https://docs.fish.audio/sdk-reference/python/voice-cloning)
- [Text to Speech ガイド](https://docs.fish.audio/sdk-reference/python/text-to-speech)
- [API リファレンス](https://docs.fish.audio/sdk-reference/python/api-reference)

## 📄 ライセンス

Fish Audio SDKの利用規約に従ってください：
- [Terms of Service](https://fish.audio/terms)
- [Privacy Policy](https://fish.audio/privacy)

## 🤝 サポート

問題が発生した場合：
1. [Fish Audio Discord](https://discord.gg/dF9Db2Tt3Y)
2. [GitHub Issues](https://github.com/fishaudio)
3. サポートメール: support@fish.audio

---

**Note:** このプロジェクトはFish Audio SDKを使用しています。商用利用の場合は適切なライセンスを確認してください。
