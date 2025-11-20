# iOS初心者向け — 環境構築から「背景除去スタンプ作成アプリ」公開まで（Markdown）

> このドキュメントは、iOSアプリ作成が初めての方向けに、**環境構築 → 開発（背景除去・透過PNG生成）→ テスト → App Store申請・公開**までを、できるだけ細かく順を追って説明したものです。サンプルコード（Swift）や設定の具体手順、注意点を含みます。

---

## 目次

1. 準備物（ハード／アカウント）
2. 開発環境構築（macOS / Xcode / Git）
3. Xcodeでプロジェクト作成（最小構成）
4. 画像の取り扱い（カメラ・フォトライブラリ）
5. **背景除去（まずは人物向け Vision を使う方法）**
6. 背景除去結果を透過PNGとして保存・共有
7. UIの基本（撮影 → 処理 → 保存の流れ）
8. テスト（シミュレータ→実機→TestFlight）
9. App Store 申請準備（バンドルID・署名・アイコン・プライバシー）
10. App Store Connect にアップロード → TestFlight → 本番公開
11. 便利ツール（Fastlane 等）と運用のコツ
12. よくあるトラブル対処

---

## 1. 準備物

* **Mac**（macOS 最新推奨）
* **Apple ID**（App Store Connect に登録するもの）
* **Apple Developer Program** への加入（個人：年間 $99）※公開するには必要
* **Internet 接続**（Xcode／Apple サービス利用のため）
* 推奨：Git（バージョン管理）

---

## 2. 開発環境構築

### 1) Xcode のインストール

* App Store から Xcode をインストール（または Apple Developer サイトからダウンロード）
* Xcode を起動 → 初回はコンポーネントを追加でインストール

### 2) コマンドラインツール / Git

```bash
# Homebrew が無ければ導入（任意）
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
# Git がなければ
brew install git
```

### 3) Apple Developer Program 登録

* [https://developer.apple.com/join/](https://developer.apple.com/join/) から加入
* 加入後、App Store Connect にアクセス可能になる

---

## 3. Xcode でプロジェクト作成（最小構成）

1. Xcode を起動 → "Create a new Xcode project" → **App** を選択
2. Product Name: `BGRemovalStamp` 等
3. Interface: **Storyboard** または **SwiftUI**（ここでは UIKit の Storyboard を想定）
4. Language: **Swift**
5. Team: 自分の Apple ID を選択（自動署名を有効にする）
6. Bundle Identifier: `com.yourname.BGRemovalStamp` を設定
7. 保存して Git リポジトリを初期化（任意）

---

## 4. 画像の取り扱い（カメラ・フォトライブラリ）

### 必要な Info.plist 設定

* `NSCameraUsageDescription`（カメラ使用）
* `NSPhotoLibraryUsageDescription`（写真ライブラリ使用）

**例（Info.plist に追加）**

```xml
<key>NSCameraUsageDescription</key>
<string>カメラで写真を撮影してスタンプを作成します。</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>写真を読み込み・保存するために使用します。</string>
```

### 画像取得の基本（UIImagePickerController）

* シンプル実装でまずは `UIImagePickerController` を使う
* Swift のサンプルコードは後述

---

## 5. 背景除去（まずは人物向け Vision を使う方法）

初心者には **Vision フレームワークの人物セグメンテーション** が一番簡単で高精度です。人物限定ですが、最短で動くものを作るには最適。

### 1) 実装の流れ（概要）

1. `UIImage` を `CIImage` / `CVPixelBuffer` に変換
2. `VNGeneratePersonSegmentationRequest` を実行
3. 返ってきたマスク（グレースケール）を使って元画像を合成
4. 透過PNG を生成して保存

### 2) サンプルコード（Swift）

```swift
import Vision
import UIKit

func generatePersonMask(pixelBuffer: CVPixelBuffer, completion: @escaping (CVPixelBuffer?) -> Void) {
    let request = VNGeneratePersonSegmentationRequest()
    request.qualityLevel = .balanced // .accurate や .fast に変更可能
    request.outputPixelFormat = kCVPixelFormatType_OneComponent8
    request.usesCPUOnly = false

    let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
    DispatchQueue.global(qos: .userInitiated).async {
        do {
            try handler.perform([request])
            if let result = request.results?.first as? VNPixelBufferObservation {
                completion(result.pixelBuffer)
            } else {
                completion(nil)
            }
        } catch {
            print("Vision error: \(error)")
            completion(nil)
        }
    }
}
```

### 3) マスクで合成してアルファ付き画像を作る

```swift
func makeImageWithAlpha(from image: UIImage, maskBuffer: CVPixelBuffer) -> UIImage? {
    guard let cgImage = image.cgImage else { return nil }

    // maskBuffer -> CGImage
    let ciMask = CIImage(cvPixelBuffer: maskBuffer)
    let context = CIContext()
    guard let maskCG = context.createCGImage(ciMask, from: ciMask.extent) else { return nil }

    // 元画像のサイズにマスクをリサイズする必要がある場合がある
    let mask = UIImage(cgImage: maskCG)

    // 描画して透明PNGを得る
    let renderer = UIGraphicsImageRenderer(size: image.size)
    let out = renderer.image { ctx in
        // 元画像を描画
        image.draw(in: CGRect(origin: .zero, size: image.size))
        // マスクをクリッピングとして使い、背景をクリアする
        guard let maskRef = mask.cgImage else { return }
        ctx.cgContext.clip(to: CGRect(origin: .zero, size: image.size), mask: maskRef)
        // 背景を透明にするため何もしない（クリッピングだけ）
    }
    return out
}
```

> ⚠️ 実際にはマスク画像のサイズや向き（縦横比）を元画像に合わせて合わせ込む処理が必要です。CIImage の `transformed(by:)` や `draw(in:)` のパラメータで調整してください。

---

## 6. 背景除去結果を透過PNGとして保存・共有

```swift
if let pngData = finalImage.pngData() {
    // 写真ライブラリに保存
    UIImageWriteToSavedPhotosAlbum(UIImage(data: pngData)!, nil, nil, nil)

    // またはファイル保存
    let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    let fileURL = docs.appendingPathComponent("sticker_01.png")
    try? pngData.write(to: fileURL)
}
```

---

## 7. UI の基本設計（シンプル版）

* ホーム画面

  * [写真を選ぶ] ボタン
  * [カメラで撮る] ボタン
  * 最近作成したスタンプ一覧（サムネイル）
* 編集画面

  * 元画像表示
  * 背景除去ボタン（処理中はローディング）
  * 処理後プレビュー（透過PNG）
  * 保存／共有ボタン

---

## 8. テスト（実機→TestFlight）

1. 実機でテストするには、Xcode の `Targets` → `Signing & Capabilities` で Team を設定（自動署名）
2. デバイスを接続して実行（Run）
3. TestFlight にアップロードするには、Product → Archive → Organizer → Distribute App → App Store Connect を選択

---

## 9. App Store 申請準備（詳細）

### 必須チェックリスト

* Apple Developer Program に加入済
* App のバンドルIDとバージョン番号を設定
* App Icon（複数解像度）を用意
* スクリーンショット（iPhone の各サイズ）を用意
* プライバシーポリシー（外部 URL）を用意
* Info.plist に適切な使用説明文を追加
* 署名（Signing）設定が正しい

### App Icon サイズ（代表）

* 1024×1024（App Store用）
* その他 Xcode の Asset Catalog が要求するサイズ

---

## 10. App Store Connect にアップロード → TestFlight → 本番公開

1. App Store Connect にログイン → My Apps → + ボタン → New App
2. App 名（ローカライズ可）、プラットフォーム iOS、Bundle ID を選択
3. App Store の情報を入力（説明、キーワード、サポートURL、プライバシーポリシー）
4. Xcode で Archive → Upload to App Store
5. App Store Connect でビルドが処理されるのを待ち、TestFlight に割り当て
6. テスターへ配布（内部／外部）→ フィードバックを得る
7. 問題なければ、App Store Connect でレビュー提出 → 公開

---

## 11. 便利ツール（任意）

* **Fastlane**: ビルドの自動化、スクショ自動アップ、TestFlight アップロードを自動化
* **Sentry / Firebase Crashlytics**: クラッシュレポート
* **GitHub Actions**: CI / CD

---

## 12. よくあるトラブルと対処

* **マスクがずれる** → マスクのリサイズやアスペクト比の扱いを確認
* **透過が反映されない** → PNG 形式で保存されているか、alpha チャンネルが付与されているか確認
* **署名エラー** → Xcode の Team 設定、Bundle Identifier、プロビジョニングを確認（自動署名を一度オフにして再設定することで直ることあり）
* **TestFlight でクラッシュ** → Crashlytics やコンソールログで原因を探る

---

## 付録：フルサンプル（超シンプルFlow）

1. カメラ or ライブラリで UIImage を得る
2. UIImage -> CVPixelBuffer に変換
3. Vision でマスク生成
4. マスク合成して透過PNG生成
5. 保存 or 共有

---

## 次のステップ（拡張案）

* 人物以外も対応する：U^2Net / MODNet を CoreML に変換して組み込む
* iMessage スタンプパック形式でエクスポート
* UI でマスクブラシや微調整機能を追加
* バッチ処理で複数画像を一括生成

---

## もっと欲しいものがあれば

* U^2Net（または軽量モデル）を CoreML 化するための**具体的なスクリプト**（Python + coremltools）
* スタータープロジェクト（Xcode の雛形）を作る
* Fastlane を使った TestFlight / App Store への自動デプロイ

必要なら上記のどれかを作成して、あなたのプロジェクトに合わせてカスタマイズします。よろしくお願いします！
