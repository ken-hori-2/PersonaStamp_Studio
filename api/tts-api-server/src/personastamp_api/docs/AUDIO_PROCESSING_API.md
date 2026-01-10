# 音声処理API仕様

## 概要

音声ファイルの処理機能を提供するAPIです。録音だけでなく、ファイルの音源を選択したり、無音区間の削除が可能です。

## 機能

1. **無音区間削除**: 音声から無音区間を削除（常時利用可能・軽量）
2. **音源分離（ボーカル抽出）**: 音楽ファイルからボーカルを抽出（現在は利用不可、将来的に使用可能）

## ⚠️ 重要な注意事項

### 音源分離機能について

**音源分離機能は現在利用できませんが、コードはコメントアウトで残されています。**

#### 現在の状況

- **Spleeter**: 依存関係の競合により現在は使用不可
  - Spleeter 2.1.0はhttpx<0.17.0を要求しますが、firebase-adminとfish-audio-sdkはhttpx>=0.27.2を要求するため、依存関係の競合が発生
  - コードは`audio_processing.py`にコメントアウトで残されています
  - 依存関係の競合が解消されれば、コメントアウトを解除して使用可能

- **Demucs**: Render無料プランでは重すぎるため現在は使用不可
  - 高品質な音源分離が可能ですが、メモリとCPU使用量が大きい
  - コードは`audio_processing.py`にコメントアウトで残されています
  - Render有料プランや別の環境では使用可能

#### 将来的な使用可能性

以下の条件が満たされれば、音源分離機能を使用できます：

1. **Spleeterを使用する場合**:
   - 依存関係の競合が解消される（firebase-admin/fish-audio-sdkのhttpx要件が緩和される、またはSpleeterのhttpx要件が更新される）
   - `requirements.txt`に`spleeter==2.1.0`を追加
   - `audio_processing.py`の`separate_vocals`関数のコメントアウトを解除

2. **Demucsを使用する場合**:
   - Render有料プランにアップグレード、または別の環境（AWS、GCPなど）で実行
   - `requirements.txt`に`demucs>=4.0.0`を追加
   - `audio_processing.py`の`separate_vocals_demucs`関数のコメントアウトを解除

#### 現在の推奨事項

- 無音区間削除のみを利用する（推奨）
- 音源分離をiOSアプリ側で実装する
- 別の音源分離サービスを使用する

詳細は `docs/DEPENDENCY_INVESTIGATION.md` を参照してください。

## APIエンドポイント

### 音声処理（無音区間削除のみ）

無音区間削除を実行できます。

iOSアプリ側でファイルを読み込んでbase64エンコードして送信します。

```http
POST /api/v2/audio/process
Authorization: Bearer <Firebase ID Token>
Content-Type: application/json

{
  "audio_base64": "base64エンコードされた音声データ",
  "separate_vocals": false,
  "remove_silence": true,
  "silence_thresh": -40.0,
  "min_silence_len": 500,
  "keep_silence": 200
}
```

**レスポンス:**
```json
{
  "output_audio_base64": "処理後の音声データ（base64）",
  "vocals_audio_base64": null,
  "message": "音声処理が完了しました（無音区間削除済み）"
}
```

**パラメータ説明:**
- `audio_base64`: base64エンコードされた音声データ（必須）
- `separate_vocals`: 音源分離を有効にする（現在は使用不可、常にfalse）
- `remove_silence`: 無音区間削除を有効にする（デフォルト: false）
- `separation_model`: 分離モデル（現在は使用不可）
- `silence_thresh`: 無音とみなす音量閾値（dB、デフォルト: -40.0）
- `min_silence_len`: 無音とみなす最小長さ（ミリ秒、デフォルト: 500）
- `keep_silence`: 無音区間の前後に残す長さ（ミリ秒、デフォルト: 200）

**注意**: `separate_vocals`を`true`に設定すると、503エラーが返されます。

## サポートファイル形式

iOSアプリ側で以下の形式のファイルを読み込んでbase64エンコードして送信できます：

- WAV
- MP3
- M4A
- FLAC
- OGG

## iOSアプリからの呼び出し例

### Swift実装例

```swift
import Foundation

class AudioProcessingService {
    let baseURL = "https://your-api-server.com"
    let authToken: String
    
    init(authToken: String) {
        self.authToken = authToken
    }
    
    // 音声ファイルをbase64エンコード
    private func encodeAudioToBase64(audioFileURL: URL) throws -> String {
        let audioData = try Data(contentsOf: audioFileURL)
        return audioData.base64EncodedString()
    }
    
    // 音声処理（無音区間削除のみ）
    func processAudio(
        audioFileURL: URL,
        separateVocals: Bool = false,  // 現在は使用不可
        removeSilence: Bool = true,
        separationModel: String = "spleeter:2stems",  // 現在は使用不可
        silenceThresh: Float = -40.0,
        minSilenceLen: Int = 500,
        keepSilence: Int = 200
    ) async throws -> (processedAudio: Data, vocalsAudio: Data?) {
        // ファイルをbase64エンコード
        let audioBase64 = try encodeAudioToBase64(audioFileURL: audioFileURL)
        
        // リクエストボディを作成
        let requestBody: [String: Any] = [
            "audio_base64": audioBase64,
            "separate_vocals": separateVocals,
            "remove_silence": removeSilence,
            "separation_model": separationModel,
            "silence_thresh": silenceThresh,
            "min_silence_len": minSilenceLen,
            "keep_silence": keepSilence
        ]
        
        // リクエストを作成
        var request = URLRequest(url: URL(string: "\(baseURL)/api/v2/audio/process")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        // リクエストを送信
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NSError(domain: "AudioProcessingError", code: -1)
        }
        
        // レスポンスをパース
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let outputBase64 = json["output_audio_base64"] as! String
        let vocalsBase64 = json["vocals_audio_base64"] as? String
        
        // base64デコード
        guard let processedAudioData = Data(base64Encoded: outputBase64) else {
            throw NSError(domain: "AudioProcessingError", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to decode output audio"])
        }
        
        var vocalsAudioData: Data? = nil
        if let vocalsBase64 = vocalsBase64,
           let vocalsData = Data(base64Encoded: vocalsBase64) {
            vocalsAudioData = vocalsData
        }
        
        return (processedAudio: processedAudioData, vocalsAudio: vocalsAudioData)
    }
}
```

## 使用例

### 1. 録音した音声から無音区間を削除してVoice Cloningに使用

```swift
// 1. 録音した音声ファイルのURLを取得
let audioFileURL = // 録音ファイルのURL

// 2. 無音区間削除を実行（音源分離は現在利用不可）
let (processedAudio, _) = try await audioProcessingService.processAudio(
    audioFileURL: audioFileURL,
    separateVocals: false,  // 現在は使用不可
    removeSilence: true
)

// 3. 処理済み音声をVoice Cloning APIに送信
let base64Audio = processedAudio.base64EncodedString()
// ... Voice Cloning APIを呼び出す
```

### 2. ファイル選択からVoice Cloningまで

```swift
// 1. ファイル選択（UIDocumentPickerViewControllerなど）
let audioFileURL = // 選択されたファイルのURL

// 2. 無音区間削除を実行（音源分離は現在利用不可）
let (processedAudio, _) = try await audioProcessingService.processAudio(
    audioFileURL: audioFileURL,
    separateVocals: false,  // 現在は使用不可
    removeSilence: true
)

// 3. 処理済み音声をbase64エンコード
let audioBase64 = processedAudio.base64EncodedString()

// 4. Voice Cloning APIに送信
let cloneRequest = CloneRequest(
    audio_base64: audioBase64,
    reference_name: "my_voice",
    transcription: nil  // オプション: 文字起こし
)
// ... Voice Cloning APIを呼び出す
```

## 注意事項

1. **音源分離機能**: 現在は利用できません（依存関係の競合によりコメントアウト）
2. **処理時間**: 無音区間削除は軽量な処理のため、高速に実行されます
3. **ファイルサイズ**: 大きなファイルの処理には時間がかかります
4. **認証**: すべてのエンドポイントでFirebase IDトークンによる認証が必要です
5. **一時ファイル**: 処理されたファイルは一時的に保存されますが、一定時間後に自動削除されます

## エラーハンドリング

- `400 Bad Request`: 無効なリクエスト（ファイル形式がサポートされていないなど）
- `401 Unauthorized`: 認証エラー
- `503 Service Unavailable`: 音源分離機能が要求された場合（現在は利用不可）
- `500 Internal Server Error`: サーバー内部エラー

## 依存関係

### 現在使用中
- `pydub`: 音声処理ライブラリ（無音区間削除）

### 将来的に使用可能（コードはコメントアウトで残されています）
- `spleeter==2.1.0`: 音源分離ライブラリ（依存関係の競合により現在は使用不可）
- `demucs>=4.0.0`: 高品質音源分離ライブラリ（Render無料プランでは重すぎるため現在は使用不可）

**注意**: 
- SpleeterとDemucsのコードは`audio_processing.py`にコメントアウトで残されています
- 依存関係の競合が解消されるか、環境が整えば、コメントアウトを解除して使用可能です
- 詳細は `docs/DEPENDENCY_INVESTIGATION.md` を参照してください
