はい、わかりました。以下は **iOS アプリ + バックエンド** を想定した設計ドキュメント（設計仕様書）です。あなたがそのまま実装を始めるために必要な構成、API 定義、データモデル、セキュリティなどを含めています。

---

## 設計ドキュメント：シンプルなマルチユーザー TTS + ボイスクローンアプリ

### 目的・要件整理

* ユーザーは iOS アプリで登録／ログインを行い、自分の声をクローン（Voice Cloning）できる。
* クローンした声モデルの **ID を保存**。
* ユーザーがアプリ内でテキストを入力し、そのクローンした声で TTS を呼び出す。
* 生成された音声 (TTS の返り値) は **サーバー上には保存しない**（ストレージ管理を軽くする）。
* 各ユーザーは **自分専用の声 (モデル)** を持つが、共有はしない。
* 安全に API キー (Fish Audio など) を扱い、認証付きでバックエンドを経由して呼び出す。

---

## 技術スタック案

* **iOS アプリ**: Swift + SwiftUI (または UIKit)、Firebase Authentication (ログイン)
* **バックエンド**: FastAPI (Python) または Node.js (Express)
* **認証**: Firebase ID トークン (バックエンドで検証)
* **データストア**: Firestore / Firebase Realtime Database / PostgreSQL など
* **シークレット管理**: 環境変数 / Secret Manager (GCP 等)
* **音声 API**: Fish Audio (TTS, Voice Cloning) ([fish.audio][1])
* **ログ**: メトリクス用ログ (Cloud Logging など)
* **通信**: HTTPS (TLS)

---

## アーキテクチャ （Mermaid 図）

以下は Mermaid 形式でのシステム構成図 (ドキュメントにそのまま貼って使えます)：

```mermaid
graph LR
  subgraph iOS App
    UI[ユーザー UI] --> |ログイン| FirebaseAuth
    UI --> |クローン音声作成 (音声アップロード)| API[Backend API]
    UI --> |テキスト入力 + TTS リクエスト| API
  end

  subgraph Backend
    API --> Auth[Firebase ID トークン検証]
    Auth --> Rate[レート制御]
    Auth --> ModelStore[声モデル管理 (DB)]
    API --> Cloner[Voice Cloning ラッパー]
    API --> TTS[Text-to-Speech ラッパー]
    API --> Logger[ログ記録]
  end

  subgraph FishAudio
    Cloner --> FAClone[Voice Clone API (Fish)]
    TTS --> FATTS[Text-to-Speech API (Fish)]
  end

  ModelStore --> DB[(データベース)]
```

---

## API 設計 (バックエンド)

バックエンドが提供する REST API エンドポイント例：

| エンドポイント         | メソッド | リクエスト                                                                      | レスポンス                                                                      | 備考                                |
| --------------- | ---- | -------------------------------------------------------------------------- | -------------------------------------------------------------------------- | --------------------------------- |
| `/clone`        | POST | `{ "audio_base64": "...", "reference_name": "my_voice" }` + Firebase Token | `{ "model_id": "abc123" }`                                                 | 音声サンプルを送ってクローン作成。返り値にモデル ID を返す。  |
| `/tts`          | POST | `{ "model_id": "abc123", "text": "こんにちは" }` + Firebase Token               | audio binary / URL                                                         | 指定モデルでテキストを読み上げ。音声データをストリーミングで返す。 |
| `/models`       | GET  | (Firebase Token)                                                           | `[{ "model_id": "abc123", "name": "my_voice", "created_at": "..." }, ...]` | ユーザーが持っているクローンモデル一覧を取得。           |
| `/delete_model` | POST | `{ "model_id": "abc123" }` + Firebase Token                                | `{ "success": true }`                                                      | モデルを削除 (オプション)                    |

---

## データモデル (バックエンド)

例として、Firestore または SQL データベースで以下のようなスキーマを持つ。

**VoiceModel** テーブル / コレクション：

* `model_id` (文字列, 主キー)
* `user_id` (Firebase UID)
* `reference_name` (文字列、ユーザーがつけた名前)
* `created_at` (タイムスタンプ)
* `metadata` (任意 JSON: Fish API によるパラメータなど)

---

## 認証とセキュリティ

1. **iOS**: Firebase Authentication を利用し、ログイン (メール・Apple など)
2. **トークン取得**: ログイン後、iOS アプリ側で `getIDToken()` を呼び、Bearer トークンを取得
3. **バックエンド**: リクエスト時に Authorization ヘッダーで送られてきたトークンを Firebase Admin SDK で検証 → UID を得る
4. **API キー秘匿**: Fish Audio の API キーはサーバーの環境変数または Secrets Manager に保存し、iOS アプリには渡さない
5. **TLS**: HTTPS を強制

---

## Voice Cloning (Fish Audio) の実装

* Fish Audio の開発者ドキュメントによれば、REST API または SDK が提供されている。 ([fish.audio][1])
* 例 (Python, FastAPI 側)：

```python
from fastapi import FastAPI, Depends, HTTPException
from pydantic import BaseModel
import base64
from fish_audio_sdk import Session, VoiceCloneRequest

app = FastAPI()

# 環境変数などからキーを取得
FISH_API_KEY = "…"

session = Session(FISH_API_KEY)

class CloneRequest(BaseModel):
    audio_base64: str
    reference_name: str

@app.post("/clone")
async def clone_voice(req: CloneRequest, uid = Depends(verify_firebase)):
    # base64 デコード
    audio_bytes = base64.b64decode(req.audio_base64)
    # Fish Audio にクローンリクエスト
    response = session.voice_cloning(VoiceCloneRequest(
        reference_audio=audio_bytes,
        reference_id=req.reference_name
    ))
    # response にはクローンしたモデル ID 等が返る (SDK ドキュメントを要確認)
    model_id = response.reference_id  # 例
    # DB に保存 (pseudo)
    save_model_to_db(uid, model_id, req.reference_name)
    return {"model_id": model_id}
```

* **注意点**：Fish Audio の SDK や API ドキュメントを最新で確認する必要があります (モデル名、レスポンス形式など)。

---

## TTS 実装 (Voice → テキスト合成)

* Fish Audio の **TTS API** ドキュメントを参照。 ([fish.audio][1])
* 例 (FastAPI + Python)：

```python
from pydantic import BaseModel
from fish_audio_sdk import TTSRequest

class TTSReq(BaseModel):
    model_id: str
    text: str

@app.post("/tts")
async def tts(req: TTSReq, uid = Depends(verify_firebase)):
    # モデル所有チェック (DB で uid と model_id の整合性確認)
    if not check_model_belongs_to_user(uid, req.model_id):
        raise HTTPException(status_code=403, detail="Not allowed")

    # Fish Audio TTS 呼び出し
    tts_request = TTSRequest(
        text=req.text,
        reference_id=req.model_id,
        format="mp3"
    )
    # ストリーミングレスポンスを返す例
    audio_stream = session.tts(tts_request)
    return StreamingResponse(audio_stream, media_type="audio/mpeg")
```

* この例では、**TTS 生成後はサーバーに音声を保存せず**、クライアント (iOS) にストリーミングで返却。

---

## iOS 側（Swift）実装

### ログイン + トークン取得

```swift
import FirebaseAuth

func getIdToken() async throws -> String {
    let user = Auth.auth().currentUser
    return try await user!.getIDToken()
}
```

### クローンリクエスト (音声サンプルアップロード)

```swift
func cloneVoice(audioData: Data, name: String) async throws -> String {
    let token = try await getIdToken()
    let url = URL(string: "https://your-backend.com/clone")!
    var req = URLRequest(url: url)
    req.httpMethod = "POST"
    req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
    let body: [String: Any] = [
      "audio_base64": audioData.base64EncodedString(),
      "reference_name": name
    ]
    req.httpBody = try JSONSerialization.data(withJSONObject: body)

    let (data, resp) = try await URLSession.shared.data(for: req)
    // エラーチェック省略
    let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
    return json["model_id"] as! String
}
```

### TTS リクエスト

```swift
func generateTTS(modelId: String, text: String) async throws -> Data {
    let token = try await getIdToken()
    let url = URL(string: "https://your-backend.com/tts")!
    var req = URLRequest(url: url)
    req.httpMethod = "POST"
    req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
    let body: [String: Any] = [
      "model_id": modelId,
      "text": text
    ]
    req.httpBody = try JSONSerialization.data(withJSONObject: body)

    let (data, resp) = try await URLSession.shared.data(for: req)
    // data に音声のバイナリ (mp3 など) が入っている想定
    return data
}
```

---

## エラーハンドリング / レート制御 / ロギング

* **レート制御**

  * リクエストごと、または TTS 呼び出し回数で制限を設ける (たとえば、1 分あたり N 回)
  * Redis やインメモリキャッシュなどでカウント管理

* **ロギング**

  * 各 `/clone` と `/tts` リクエストのメタデータ (UID, timestamp, request size, duration) を記録
  * エラー時はエラー内容 + スタックトレース (必要に応じて)

* **課金 (今回シンプル版では未実装)**

  * 今回要件には「課金しない / クレジット管理は不要」なので省略可能。ただし将来的な拡張余地は残す設計が望ましい。

---

## セキュリティ・プライバシー

* **API キー管理**

  * Fish Audio の API キーをバックエンドでのみ保持
  * バージョン管理システム (Git) には絶対に含めない
* **通信保護**

  * TLS (HTTPS) を必須とする
* **認可チェック**

  * `/tts` 時にリクエストされた `model_id` が、リクエストユーザー (UID) のものであるかを検証
* **プライバシー**

  * ユーザーが提供する音声サンプル (クローン元) は適切に扱う (必要であれば暗号化 or 最小保存)
  * ログに機密な内容 (ユーザーの個人情報が入った音声テキスト など) を残す場合には暗号化・匿名化を検討

---

## 実装ステップ (マイルストーン)

1. Firebase プロジェクト作成 + 認証 (Email / Apple) 設定
2. バックエンド (FastAPI) 基礎構造作成

   * Firebase トークン検証機能
   * DB モデル (VoiceModel) 設定
3. Fish Audio アカウント取得 + API キー発行
4. Voice Cloning API 呼び出し実装 (`/clone`)
5. TTS API 呼び出し実装 (`/tts`)
6. iOS アプリ側：ログイン機能 + トークン取得
7. iOS 側：音声録音 (サンプル) + base64変換 + `/clone` 呼び出し
8. iOS 側：テキスト → `/tts` 呼び出し + 再生 UI
9. ロギング + エラーハンドリングの強化
10. テスト (単体・統合)

---

## 補足：Fish Audio に関する注意点と確認すべきこと

* Fish Audio の **Instant Voice Cloning** は「数秒〜10秒程度の音声サンプルから声を再現」可能。 ([fish.audio][2])
* API キーは REST API および SDK (Python, JavaScript) 経由で利用可能。 ([fish.audio][1])
* TTS リクエスト時には `reference_id` (＝声モデル ID) を指定することで、その声で読み上げが可能。 ([fish.audio][1])
* サンプル音声の長さや品質要件 (サンプリングレート、フォーマット) は Fish Audio のドキュメントで確認する必要あり。

---

もしよければ、この設計をもとに **課金 (サブスク or コイン制) を含めた拡張版設計書** も同時に作れます。どうしますか？

[1]: https://fish.audio/ja/developers/?utm_source=chatgpt.com "Developers - Fish Audio"
[2]: https://fish.audio/ja/voice-clone/?utm_source=chatgpt.com "Voice Cloning - Fish Audio"