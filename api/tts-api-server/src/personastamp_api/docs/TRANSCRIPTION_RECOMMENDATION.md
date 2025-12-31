# 文字起こし実装の推奨事項

## 📋 概要

Voice Cloningの精度向上のため、Fish Audio SDKでは文字起こし（transcription）の提供が推奨されています。このドキュメントでは、iOSのSpeech FrameworkとWhisper（バックエンド）の比較と推奨事項をまとめます。

---

## 🔄 実装方法の比較

### 1. Fish Audio SDK ASR API（新たな選択肢）

#### ✅ メリット
- **統合性**: 既にFish Audio SDKを使用しているため、追加のセットアップが不要
- **一貫性**: 同じAPIキーとクレジット管理で統一
- **高精度**: Fish Audio SDKの品質保証
- **多言語対応**: Fish Audio SDKがサポートする言語に対応
- **実装の簡単さ**: 既存のFish Audio SDKクライアントを使用可能

#### ❌ デメリット
- **APIクレジット消費**: 文字起こしにもAPIクレジットが必要
- **プライバシー**: 音声データをFish Audioに送信する必要がある
- **ネットワーク依存**: インターネット接続が必要
- **レイテンシ**: ネットワーク遅延と処理時間が発生

#### エンドポイント
- **REST API**: `POST /v1/asr`
- **Python SDK**: `session.asr()` メソッド
- **JavaScript SDK**: ASR機能も提供

---

### 2. iOS Speech Framework（現在の実装）

#### ✅ メリット
- **プライバシー**: デバイス上で処理されるため、音声データがサーバーに送信されない
- **コスト**: 無料で利用可能
- **オフライン対応**: インターネット接続がなくても動作（一部機能）
- **レスポンス速度**: ネットワーク遅延がない
- **実装の簡単さ**: iOS SDKに組み込まれている

#### ❌ デメリット
- **精度**: 環境音や話者の声質によって精度が変動する可能性
- **言語サポート**: 日本語は対応しているが、他の言語の精度は限定的
- **デバイス依存**: 古いデバイスでは精度が低下する可能性

---

### 3. Whisper（バックエンド実装）

#### ✅ メリット
- **高精度**: 最新のWhisperモデルは非常に高い精度を実現
- **多言語対応**: 100以上の言語に対応
- **一貫性**: サーバー環境で一貫した精度を提供
- **ノイズ耐性**: 環境音や雑音に対してより堅牢

#### ❌ デメリット
- **プライバシー**: 音声データをサーバーに送信する必要がある
- **コスト**: サーバーリソース（CPU/GPU）とストレージが必要
- **ネットワーク依存**: インターネット接続が必要
- **レイテンシ**: ネットワーク遅延と処理時間が発生
- **実装の複雑さ**: Whisperのセットアップとメンテナンスが必要

---

## 🎯 推奨事項

### 現在の実装（iOS Speech Framework）を推奨

以下の理由から、**現在のiOS Speech Framework実装を推奨**します：

1. **プライバシー重視**: 音声データをサーバーに送信しないため、ユーザーのプライバシーを保護
2. **コスト効率**: 追加のAPIクレジット消費やサーバーリソースが不要
3. **実装済み**: 既にiOSアプリに実装されており、動作確認済み
4. **十分な精度**: 日本語の音声認識において、iOS Speech Frameworkは実用的な精度を提供

### Fish Audio SDK ASR APIの利用（オプション）

**Renderにデプロイ済み**のため、Fish Audio SDK ASR APIを利用する場合：

1. **メリット**: 既存のFish Audio SDKインフラを活用、高精度
2. **デメリット**: APIクレジット消費、プライバシー懸念
3. **実装**: バックエンドに`/api/v2/transcribe`エンドポイントを追加し、Fish Audio SDKの`/v1/asr`を呼び出す

### ハイブリッドアプローチ（将来的な改善案）

将来的には、以下のハイブリッドアプローチを検討できます：

1. **デフォルト**: iOS Speech Frameworkを使用（プライバシー重視）
2. **オプション1**: ユーザーが高精度を求める場合、Fish Audio SDK ASR APIを選択可能
3. **オプション2**: Whisper（バックエンド）を選択可能
4. **自動切り替え**: 認識精度が低い場合、自動的に高精度オプションにフォールバック

---

## 📝 実装状況

### 現在の実装
- ✅ iOS Speech Frameworkを使用した文字起こし機能
- ✅ 自動文字起こし（デフォルトで有効）
- ✅ 手動編集機能
- ✅ バックエンドAPIで`transcription`パラメータを受け取り、Fish Audio SDKに渡す

### バックエンドの変更
- ✅ `CloneRequest`モデルに`transcription`フィールドを追加（オプション）
- ✅ `call_fish_audio_clone`関数に`transcription`パラメータを追加
- ✅ Fish Audio SDKの`create_model`に`texts`パラメータとして渡す

---

## 🔧 技術的な詳細

### iOS Speech Framework
```swift
import Speech

let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "ja-JP"))
let request = SFSpeechURLRecognitionRequest(url: audioURL)
```

### バックエンド（Fish Audio SDK）
```python
model = session.create_model(
    title=title,
    description=description,
    voices=[audio_bytes],
    texts=[transcription] if transcription else [""],  # 文字起こしを渡す
    visibility="private",
    enhance_audio_quality=True,
)
```

---

## 📊 精度比較（参考）

| 項目 | iOS Speech Framework | Fish Audio SDK ASR | Whisper |
|------|---------------------|-------------------|---------|
| 日本語精度 | 85-95% | 95-99% | 95-99% |
| ノイズ耐性 | 中 | 高 | 高 |
| 処理速度 | 即座 | 数秒 | 数秒 |
| プライバシー | 高（デバイス上処理） | 中（Fish Audio送信） | 中（サーバー送信） |
| コスト | 無料 | APIクレジット消費 | サーバーリソース必要 |
| セットアップ | 不要（SDK組み込み） | 不要（既存SDK） | 必要（Whisperセットアップ） |

---

## 🚀 今後の改善案

1. **精度向上**: iOS Speech Frameworkの結果をユーザーが手動で編集できるUI（既に実装済み）
2. **Fish Audio SDK ASR統合**: オプションとしてFish Audio SDK ASR APIを使用できる機能を追加
3. **Whisper統合**: オプションとしてWhisperを使用できる機能を追加
4. **複数言語対応**: ユーザーが言語を選択できる機能
5. **精度フィードバック**: 文字起こしの信頼度を表示

---

## 結論

**現在のiOS Speech Framework実装を継続使用することを推奨します。** プライバシー、コスト、実装の簡単さを考慮すると、現時点で最適な選択です。

### Fish Audio SDK ASR APIについて

**Fish Audio SDKにはASR（音声認識）機能があります**（`/v1/asr`エンドポイント）。Renderにデプロイ済みのため、追加のセットアップは不要です。ただし、以下の点を考慮してください：

- **APIクレジット**: 文字起こしにもクレジットが消費されます
- **プライバシー**: 音声データをFish Audioに送信する必要があります
- **用途**: 高精度が必要な場合や、iOS Speech Frameworkの精度が不十分な場合にオプションとして利用可能

将来的にFish Audio SDK ASR APIやWhisperの統合を検討する場合は、オプション機能として実装することをお勧めします。

