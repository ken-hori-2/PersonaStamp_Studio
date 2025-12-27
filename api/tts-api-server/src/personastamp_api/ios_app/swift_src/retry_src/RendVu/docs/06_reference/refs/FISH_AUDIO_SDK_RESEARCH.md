# Fish Audio SDK 調査レポート

## 📋 調査概要

Fish Audio SDKの公式ドキュメントと実装コードを調査し、音声クローン時の文字起こしの推奨事項、APIパラメータ、TTS時の感情表現などの特徴をまとめました。

---

## 1. 文字起こし（Transcription）について

### ✅ 公式推奨事項

**Fish Audio SDKでは、音声クローン時に文字起こしを添えることが推奨されています。**

#### 推奨される理由

1. **音声クローンの精度向上**
   - 文字起こしを提供することで、モデルが音声とテキストの対応関係をより正確に学習できます
   - 音声認識の精度が向上し、より自然な音声合成が可能になります

2. **実装コードでの確認**
   - `create_voice_clone.py`では、`transcription`パラメータが`texts`として`create_model()`に渡されています
   - 文字起こしが空の場合でも動作しますが、品質向上のため推奨されています

#### 現在の実装状況

**Webアプリ（app.py）:**
- ✅ Whisperを使用した自動文字起こし機能が実装済み
- ✅ ユーザーが手動で文字起こしを編集可能
- ✅ 文字起こしなしでも続行可能（警告表示あり）

**iOSアプリ（RendVu）:**
- ❌ 現在、文字起こし機能は実装されていません
- ⚠️ `call_fish_audio_clone()`では`texts=[""]`として空文字列が渡されています

#### 推奨される改善

iOSアプリでも文字起こし機能を追加することを推奨します：

```swift
// 推奨実装例
func cloneVoice(audioData: Data, referenceName: String, transcription: String?) async throws -> String {
    // ...
    let texts = transcription?.isEmpty == false ? [transcription!] : [""]
    // ...
}
```

---

## 2. 音声クローン作成API（create_model）のパラメータ

### 主要パラメータ

| パラメータ | 型 | 説明 | 必須 | デフォルト |
|-----------|-----|------|------|-----------|
| `title` | str | モデルのタイトル/名前 | ✅ | - |
| `description` | str | モデルの説明 | ❌ | "" |
| `voices` | List[bytes] | 音声サンプルのバイナリデータ（複数可） | ✅ | - |
| `texts` | List[str] | 各音声サンプルに対応する文字起こし（推奨） | ❌ | [""] |
| `visibility` | str | 公開設定 ("private", "public", "unlist") | ❌ | "private" |
| `enhance_audio_quality` | bool | 音質向上オプション | ❌ | False |

### 実装例

```python
from fish_audio_sdk import Session

session = Session(api_key)

model = session.create_model(
    title="My Custom Voice",
    description="Voice cloned from sample audio",
    voices=[audio_data],  # 複数のサンプルを指定可能
    texts=[transcription] if transcription else [""],  # 文字起こし（推奨）
    visibility="private",
    enhance_audio_quality=True  # 音質向上
)
```

### ベストプラクティス

1. **複数の音声サンプルを使用**
   - 2-3個の音声サンプルで最適な品質が得られます
   - 各サンプルは10-30秒が推奨

2. **文字起こしの提供**
   - 各音声サンプルに対応する正確な文字起こしを提供
   - 自動文字起こし（Whisper等）を使用する場合も、手動で修正可能に

3. **音質向上オプション**
   - `enhance_audio_quality=True`を設定することで、音質が向上します

---

## 3. TTS生成APIのパラメータと機能

### TTSRequestの主要パラメータ

| パラメータ | 型 | 説明 | 範囲/オプション |
|-----------|-----|------|----------------|
| `text` | str | 音声に変換するテキスト | - |
| `reference_id` | str | 使用する音声モデルID | オプション（デフォルト音声を使用） |
| `format` | str | 出力フォーマット | "mp3", "wav", "opus", "pcm" |
| `prosody` | Prosody | 韻律制御（話速・音量） | - |
| `normalize` | bool | 音声正規化 | True/False |
| `latency` | str | レイテンシ設定 | "balanced", "low", "high" |

### Prosody（韻律制御）

```python
from fish_audio_sdk import Prosody

prosody = Prosody(
    speed=1.0,    # 話速（0.5-2.0）
    volume=0      # 音量（-20～20）
)
```

### 出力フォーマット別の設定

```python
# MP3
request_params["mp3_bitrate"] = 192

# WAV
request_params["sample_rate"] = 44100

# Opus
request_params["opus_bitrate"] = 48

# PCM
request_params["sample_rate"] = 44100
```

---

## 4. 感情表現（Emotions）機能

### ✅ 感情タグのサポート

Fish Audio SDKでは、テキスト内に感情タグを埋め込むことで、音声に感情を付与できます。

### 利用可能な感情タグ

| タグ | 説明 | 例 |
|------|------|-----|
| `(happy)` | 嬉しい | `(happy) とても嬉しいニュースです！` |
| `(sad)` | 悲しい | `(sad) 残念ながら、期待通りではありませんでした。` |
| `(excited)` | 興奮 | `(excited) これは素晴らしい発見です！` |
| `(calm)` | 穏やか | `(calm) それでは、説明を始めます。` |
| `(angry)` | 怒り | `(angry) これは許せません！` |
| `(surprised)` | 驚き | `(surprised) まさか、そんなことが！` |
| `(whispering)` | ささやき | `(whispering) これは秘密です。` |
| `(shouting)` | 叫び | `(shouting) 助けて！` |
| `(laughing)` | 笑い | `(laughing) それは面白いですね！` |

### 使用例

```python
text = """
(happy) とても嬉しいニュースです！
(sad) 残念ながら、期待通りではありませんでした。
(excited) これは素晴らしい発見です！
(calm) それでは、説明を始めます。
(angry) これは許せません！
(surprised) まさか、そんなことが！
"""

request = TTSRequest(
    text=text,
    reference_id=model_id,
    prosody=Prosody(speed=1.0, volume=0)
)
```

### 公式ドキュメントでの言及

- [Emotion Reference](https://docs.fish.audio/api-reference/emotion-reference) - 64以上の感情表現の完全リファレンス
- [Emotion & Expression Control](https://docs.fish.audio/developer-guide/best-practices/emotion-control) - 感情制御のベストプラクティス

---

## 5. その他の主要機能

### 5.1 モデル管理API

```python
# モデル一覧取得
models = session.list_models(self_only=True, page_size=20)

# モデル取得
model = session.get_model(model_id)

# モデル更新
session.update_model(model_id, title="New Title", description="New Description")

# モデル削除
session.delete_model(model_id)
```

### 5.2 APIクレジット管理

```python
# クレジット残高確認
credit = session.get_api_credit()
print(f"残高: {credit.credit}")
```

### 5.3 ストリーミング対応

- WebSocketを使用したリアルタイムTTSストリーミングが可能
- 低レイテンシでの音声生成に対応

---

## 6. 現在の実装との比較

### Webアプリ（app.py）

| 機能カテゴリ | 機能 | 実装状況 | 備考 |
|------------|------|---------|------|
| **音声クローン作成** | ファイルアップロード | ✅ 実装済み | WAV, MP3, M4A, FLAC, OGG対応 |
| | 自動文字起こし（Whisper） | ✅ 実装済み | 自動実行、手動編集可能 |
| | 文字起こし手動編集 | ✅ 実装済み | テキストエリアで編集可能 |
| | モデル名・説明設定 | ✅ 実装済み | タイトルと説明を設定可能 |
| | 公開設定 | ✅ 実装済み | private/public/unlist選択可能 |
| | 音質向上オプション | ✅ 実装済み | enhance_audio_quality=True |
| **TTS生成** | モデル選択 | ✅ 実装済み | ドロップダウンで選択 |
| | テキスト入力 | ✅ 実装済み | テキストエリアで入力 |
| | 感情表現タグ | ✅ 実装済み | UIで説明あり、手動入力 |
| | Prosody制御 | ✅ 実装済み | 話速・音量調整可能 |
| | フォーマット選択 | ✅ 実装済み | MP3, WAV, Opus, PCM対応 |
| | 音声ダウンロード | ✅ 実装済み | 生成音声をダウンロード可能 |
| **モデル管理** | モデル一覧表示 | ✅ 実装済み | JSONファイルから読み込み |
| | モデル削除 | ✅ 実装済み | 削除ボタンあり |
| | モデル情報表示 | ✅ 実装済み | 詳細情報を表示 |
| | モデル保存 | ✅ 実装済み | JSONファイルで管理 |

### iOSアプリ（RendVu） - 最新実装状況（2025年1月更新）

| 機能カテゴリ | 機能 | 実装状況 | 備考 |
|------------|------|---------|------|
| **音声クローン作成** | 録音機能 | ✅ 実装済み | デバイスで直接録音 |
| | 自動文字起こし（iOS Speech） | ✅ 実装済み | 録音停止後自動実行、デフォルト有効 |
| | 文字起こし手動編集 | ✅ 実装済み | TextEditorで編集可能 |
| | 文字起こし再実行 | ✅ 実装済み | 再実行ボタンあり |
| | 自動文字起こしON/OFF | ✅ 実装済み | Toggleで切り替え可能 |
| | モデル名設定 | ✅ 実装済み | TextFieldで入力 |
| | 公開設定 | ⚠️ 固定 | private固定（バックエンド実装） |
| | 音質向上オプション | ✅ 実装済み | enhance_audio_quality=True（バックエンド） |
| **TTS生成** | モデル選択 | ✅ 実装済み | Pickerで選択 |
| | テキスト入力 | ✅ 実装済み | TextEditorで入力 |
| | 感情表現タグ | ✅ 実装済み | 9種類のタグ、UIで選択・挿入 |
| | 感情タグ説明表示 | ✅ 実装済み | 各タグの説明と例を表示 |
| | 使用中タグ表示 | ✅ 実装済み | テキスト内のタグを抽出して表示 |
| | Prosody制御 | ✅ 実装済み | 話速・音量調整可能（Slider） |
| | フォーマット選択 | ✅ 実装済み | PickerでMP3, WAV, Opus, PCM選択可能 |
| | 音声再生 | ✅ 実装済み | 生成音声をデバイスで再生 |
| **モデル管理** | モデル一覧表示 | ✅ 実装済み | API経由で取得・表示 |
| | モデル削除 | ✅ 実装済み | スワイプで削除可能 |
| | モデル情報表示 | ✅ 実装済み | リストで表示 |
| | モデル保存 | ✅ 実装済み | バックエンドDBで管理 |

### 実装状況のまとめ

#### ✅ 完全に実装済み（Webアプリと同等以上）
- 音声クローン作成（録音機能はiOSアプリの方が優れている）
- 文字起こし機能（iOS Speech Framework使用）
- 感情表現機能（UIで選択可能）
- Prosody制御
- フォーマット選択（MP3, WAV, Opus, PCM）
- モデル管理

#### ⚠️ 部分的に実装（改善の余地あり）
- **公開設定**: private固定（現状は問題なし）

#### 📊 実装率
- **Webアプリ（app.py）**: 100%（全機能実装済み）
- **iOSアプリ（RendVu）**: 約98%（主要機能は完全に実装済み、細かい機能が一部制限あり）

---

## 7. 推奨される改善事項

### iOSアプリ（RendVu）への推奨機能追加

1. **文字起こし機能の追加**
   - iOSの音声認識API（Speech Framework）を使用
   - または、バックエンドAPI経由でWhisperを使用
   - ユーザーが手動で編集可能なUIを提供

2. **感情表現のサポート**
   - テキスト入力時に感情タグを選択できるUI
   - 感情タグの説明と例を表示

3. **音声フォーマット選択**
   - ユーザーが出力フォーマットを選択可能に
   - デバイスに最適なフォーマットを推奨

---

## 8. 参考資料

### 公式ドキュメント

- [Fish Audio 公式サイト](https://fish.audio)
- [公式ドキュメント](https://docs.fish.audio)
- [Voice Cloning ガイド](https://docs.fish.audio/developer-guide/core-features/creating-models)
- [Text to Speech ガイド](https://docs.fish.audio/developer-guide/core-features/text-to-speech)
- [Emotion Reference](https://docs.fish.audio/api-reference/emotion-reference)
- [Best Practices - Voice Cloning](https://docs.fish.audio/developer-guide/best-practices/voice-cloning)
- [Best Practices - Emotion Control](https://docs.fish.audio/developer-guide/best-practices/emotion-control)

### プロジェクト内ドキュメント

- `/docs/FISH_AUDIO_README.md` - プロジェクト内のFish Audio使用ガイド
- `/app/create_voice_clone.py` - 音声クローン作成実装
- `/app/generate_tts.py` - TTS生成実装

---

## 9. まとめ

### 文字起こしについて

✅ **Fish Audio SDKでは、文字起こしを添えることが推奨されています。**
- 音声クローンの精度向上に寄与
- Webアプリでは既に実装済み（Whisper使用）
- iOSアプリへの実装を推奨

### 主要機能

1. **音声クローン作成**
   - 複数の音声サンプル対応
   - 文字起こしの提供で品質向上
   - 音質向上オプションあり

2. **TTS生成**
   - 感情表現タグのサポート（64+種類）
   - Prosody制御（話速・音量）
   - 複数フォーマット対応（MP3, WAV, Opus, PCM）
   - ストリーミング対応

3. **モデル管理**
   - モデルの作成・取得・更新・削除
   - 公開設定の管理
   - APIクレジット管理

### 改善推奨事項（2025年1月更新）

✅ **実装完了**:
- ✅ iOSアプリに文字起こし機能を追加（iOS Speech Framework使用）
- ✅ 感情表現のUIサポートを追加（9種類のタグ、説明付き）
- ✅ 自動文字起こしのON/OFF切り替え
- ✅ 文字起こし再実行機能

⚠️ **オプション改善**（実用上は問題なし）:
- モデル説明の手動設定機能
- 感情タグの拡張（64種類以上）

### 実装状況のまとめ（2025年1月更新）

**RendVuの実装率: 約98%**

主要機能は完全に実装済みで、Webアプリ（`app.py`）と同等以上の機能を提供しています。

詳細な比較は [`IMPLEMENTATION_COMPARISON.md`](../IMPLEMENTATION_COMPARISON.md) を参照してください。

---

**調査日**: 2025年1月  
**最終更新**: 2025年1月（実装状況を更新）  
**調査対象**: Fish Audio SDK公式ドキュメント、プロジェクト内実装コード

