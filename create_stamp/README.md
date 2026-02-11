# AXiV — しゃべるスタンプ

**Rendezvous with that Moment.**  
App Store にて公開中の、写真から「音声付きスタンプ」まで一気通貫で作れる iOS アプリです。

---

## 紹介動画

<video src="portfolio/AXiV-App-Preview.mp4" controls width="640" poster="portfolio/AXiV_1.png">  
お使いの環境では動画を再生できません。 [動画をダウンロード](portfolio/AXiV-App-Preview.mp4)
</video>

---

## コンセプト・メッセージ（App Store プロモーション）

### キャッチコピー

**AXiVを通じてあの瞬間と再会しよう。**

必要なのは写真1枚だけ。思い出をあなたの感性で彩り、世界に一つだけの「音声付きスタンプ」として再起動。作成したスタンプは動画形式で保存して、みんなと共有して盛り上がろう。保存じゃない、これは新しい思い出の体験です。

---

### 概要

**【記憶を、体験として再起動する。】**

AXiVは、あなたの写真に新しい命を吹き込む、次世代のスタンプ作成アプリです。  
*Rendezvous with that moment through the AXiV.*

あの日の記憶、大切な人との時間、ふとした瞬間の感情。AXiVは、それらを単なる「保存物」から、もう一度触れられる「体験」へとアップデートします。

---

### AXiVでできること

スマホに眠っている写真1枚から、驚くほど簡単にハイクオリティなスタンプを作成できます。

1. **AI背景除去** — 思い出の主役だけを鮮やかに切り出し
2. **ベース構成** — 透過や白背景など、スタンプの土台を自在に構築
3. **感性エディタ** — 今の気分でお絵描きやデコレーションをプラス
4. **音声生成（AIボイス）** — 入力した文字をスタンプが喋り出す
5. **動画形式で保存** — 作成したスタンプは、声も一緒に共有可能

---

### AXiVという名前に込めた想い

- **Archive Experience in Vision** — 記憶を視点と感情で再起動する。
- **Axis + Rendezvous** — 記憶という「軸」で、過去の自分や大切な人と「再会」する交差点。

ただの画像作成ツールではありません。AXiVは、あなたの思い出をあなたの感性でカスタマイズし、仲間と共有して盛り上がるための、新しいコミュニケーションの形です。

---

### こんな方におすすめ

- 友達との思い出をもっと楽しく共有したい
- 世界に一つだけの手作りスタンプを作りたい
- 写真にメッセージや声を乗せて届けたい
- 最新のAI技術を使ってエモいコンテンツを作りたい

**さあ、AXiVを起動して。  
思い出と、もう一度出会おう。**

---

## 主な機能（技術面）

| タブ | 機能 |
|------|------|
| **Remove BG** | 画像内の被写体を長押しで選択し、背景を除去。VisionKit の Image Analysis を利用。 |
| **Compose Base** | 背景除去した透過画像を、白/透明の正方形キャンバス（512/1024/2048px）に合成。 |
| **Edit Sticker** | PencilKit で手描き編集。ズームしたまま完了しても、正しい縮尺で画像に合成。 |
| **Audio Sticker** | テキストを TTS で音声化し、画像＋音声の動画（MOV）を作成してフォトライブラリに保存。入力テキストの言語（英/日）を自動判定。 |

起動時は AXiV のスプラッシュを表示し、デバイスの言語（en/ja）に応じて UI を切り替える多言語対応です。

---

## 技術スタック

| 分野 | 技術 |
|------|------|
| **UI** | SwiftUI（iOS 16+ は `NavigationStack`） |
| **背景除去** | VisionKit（`ImageAnalyzer`, `ImageAnalysisInteraction`）— 被写体検出・切り出し |
| **画像編集** | PencilKit（手描き）、`UIGraphicsImageRenderer`（合成） |
| **音声・動画** | AVFoundation（`AVSpeechSynthesizer` / TTS、`AVAssetWriter` / MOV 出力） |
| **言語判定** | NaturalLanguage（`NLLanguageRecognizer`）— TTS 用に en/ja を自動判定 |
| **保存** | Photos（フォトライブラリ） |
| **多言語** | `Localizable.xcstrings`（en/ja） |

処理はすべて **デバイス上** で実行し、画像・音声をサーバーに送信しません。

---

## 実装のポイント

- **構成**: SwiftUI + MVVM に近い構成。View / ViewModel / Model を分離し、タブごとにメインの View を割り当て。
- **背景除去**: VisionKit の `.visualLookUp` で被写体を検出。長押しで選択・タップで解除。抽出画像はメモリ上のみで保持し、保存はユーザーが明示的に実行したときのみ。
- **編集**: PencilKit のキャンバスを `canvasView.bounds` 基準で合成するため、ズーム状態に依存せず一貫した編集結果を画像に反映。
- **TTS**: 入力テキストの言語を自動判定し、英語・日本語の音声を切り替え。生成した音声と画像から MOV を組み立て、フォトライブラリに保存。
- **ローカライズ**: タブ名・ボタン・アラート・説明文を en/ja で管理。App Store 審査（顔データの取り扱い説明など）にも対応済み。

---

## App Store

本アプリは **App Store で公開されています**。

- アプリ名: **AXiV — しゃべるスタンプ**
- 対応: iPhone / iPad（iOS 16.0 以上）

---

## ポートフォリオ用素材

リポジトリ内の `portfolio/` に、アイコン・画面プレビュー・紹介動画を置いています。

| 素材 | ファイル |
|------|----------|
| アプリアイコン | [App Icon Template.png](portfolio/App%20Icon%20Template.png) |
| 紹介動画（App Store 公開） | [AXiV-App-Preview.mp4](portfolio/AXiV-App-Preview.mp4) |
| 画面プレビュー | [AXiV_1.png](portfolio/AXiV_1.png) ～ [AXiV_6.png](portfolio/AXiV_6.png)、[IMG_3491.PNG](portfolio/IMG_3491.PNG) |

### プレビュー画像

<img src="portfolio/AXiV_1.png" width="240" alt="AXiV 画面プレビュー 1"> <img src="portfolio/AXiV_2.png" width="240" alt="AXiV 画面プレビュー 2"> <img src="portfolio/AXiV_3.png" width="240" alt="AXiV 画面プレビュー 3">

<img src="portfolio/AXiV_4.png" width="240" alt="AXiV 画面プレビュー 4"> <img src="portfolio/AXiV_5.png" width="240" alt="AXiV 画面プレビュー 5"> <img src="portfolio/AXiV_6.png" width="240" alt="AXiV 画面プレビュー 6">

---

## ソースコード・ドキュメント

- **アプリ本体（Xcode プロジェクト）**: [mobile/stamp_creator/](mobile/stamp_creator/)
- **起動・ビルド手順**: [mobile/stamp_creator/README.md](mobile/stamp_creator/README.md)
- **設計仕様・データフロー**: [mobile/stamp_creator/docs/Design_Specification.md](mobile/stamp_creator/docs/Design_Specification.md)

---

## ライセンス

本リポジトリの利用条件はプロジェクトのルート方針に従います。
