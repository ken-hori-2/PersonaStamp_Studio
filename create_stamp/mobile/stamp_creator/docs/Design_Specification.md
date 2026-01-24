# stamp_creator 設計仕様書

**対象**: `stamp_creator/stamp_creator` 配下の実装  
**作成**: 実装調査に基づく設計ドキュメント

---

## 1. 概要

stamp_creator は、**背景除去・背景合成・画像編集・TTSスタンプ動画作成**の 4 機能を持つ iOS アプリである。  
SwiftUI をベースにし、**MVVM** に近い構成で、タブで各機能を切り替える。

### 1.1 対応 OS

- iOS 16.0 以上: `NavigationStack` を使用
- iOS 16.0 未満: `NavigationView` にフォールバック

### 1.2 主な技術

- **SwiftUI**（UI）
- **Vision / VisionKit**（ImageAnalyzer, ImageAnalysisInteraction：背景除去の被写体検出・切り出し）
- **PencilKit**（画像・マスクの手書き編集）
- **AVFoundation**（AVSpeechSynthesizer：TTS、AVAssetWriter：画像+音声の動画出力）
- **Photos**（保存）

---

## 2. アーキテクチャ

### 2.1 構成

- **View**: SwiftUI の `View`。UI とユーザー操作の受け持ち。
- **ViewModel**: `ObservableObject`。画像解析・マスク編集など、**状態とロジック**を保持。View から `@StateObject` / `@ObservedObject` で参照。
- **Model**: ドメインデータ（例: `TextLayer`, `FontOption`）。View/ViewModel から利用。

View は主に `@State` で画面ローカルな状態（ピッカー表示、アラート、ボタンの不透明度など）を、ViewModel 経由で「解析結果・編集結果」などを扱う。

### 2.2 レイヤーと責務

| レイヤー | 役割 |
|----------|------|
| **App** | エントリーポイント。`ContentView` を表示。 |
| **ContentView** | タブ構成の定義。各タブに 1 つのメインビューを割り当て。 |
| **Models** | テキストレイヤーなど、アプリ全体で使うデータ構造。 |
| **ViewModels** | 画像解析・マスク編集のビジネスロジックと公開状態。 |
| **Views** | 各機能のメイン画面と、シート・オーバーレイ。 |
| **Views/Components** | 画像ピッカー、ズーム可能な画像、マスク編集、チェッカーパターンなど、再利用コンポーネント。 |
| **Utilities** | ボタンスタイル、`UIImage` 拡張など。 |

---

## 3. フォルダ・ファイル構成

```
stamp_creator/
├── stamp_creatorApp.swift      # @main、WindowGroup で ContentView
├── ContentView.swift           # TabView（Remove BG / Compose / Edit / TTS Stamp）
├── Models/
│   └── TextLayer.swift        # TextLayer, FontOption（画像編集のテキスト用、一部コメントアウト）
├── ViewModels/
│   ├── ImageAnalysisViewModel.swift   # ImageAnalyzer / ImageAnalysisInteraction のラップ
│   └── MaskEditingViewModel.swift     # マスクの初期化・適用・PencilKit 連携
├── Views/
│   ├── BackgroundRemovalView.swift    # 背景除去タブ
│   ├── BackgroundCompositionView.swift# 背景合成タブ
│   ├── ImageEditorView.swift         # 画像編集タブ
│   ├── TTSStampView.swift            # TTS スタンプタブ
│   ├── EditingSheetView.swift        # 画像編集：PencilKit シート
│   ├── ExtractedImageView.swift      # 抽出結果の表示・保存
│   └── Components/
│       ├── ImagePicker.swift         # UIImagePickerController の SwiftUI ラップ
│       ├── ZoomableImageView.swift   # ピンチ・スクロール、長押し/タップ、ImageAnalysis 連携
│       ├── ZoomablePencilKitImageView.swift  # PencilKit + ズーム、編集シート用
│       ├── MaskEditingView.swift     # マスクの PencilKit 編集（UIViewRepresentable）
│       ├── CheckerboardPattern.swift # 透過表示用チェッカーパターン
│       ├── EditableTextView.swift    # 画像上のテキスト編集（未使用 or 一部のみ）
│       ├── TextEditorView.swift      # テキスト編集パネル（未使用 or 一部のみ）
│       ├── TextLayerView.swift       # テキストレイヤー表示（未使用 or 一部のみ）
│       └── (ImagePicker は上記)
├── Utilities/
│   ├── ButtonStyles.swift    # ScaleButtonStyle など
│   └── UIImage+Extensions.swift  # fixedOrientation() など
└── Assets.xcassets/          # アプリアイコン、アクセント、画像アセット
```

---

## 4. 各レイヤーの詳細

### 4.1 App・ContentView

- **stamp_creatorApp.swift**  
  - `@main` の `App`。`WindowGroup { ContentView() }` のみ。

- **ContentView.swift**  
  - `TabView(selection: $selectedTab)` で 4 タブを定義。  
  - 各タブは `NavigationStack`（iOS 16+）または `NavigationView` で包み、その中に 1 つのメインビューを置く。
  - タブ:
    1. **Remove BG** (tag 0): `BackgroundRemovalView`
    2. **Compose** (tag 1): `BackgroundCompositionView`
    3. **Edit** (tag 2): `ImageEditorView`
    4. **TTS Stamp** (tag 3): `TTSStampView`

### 4.2 Models

- **TextLayer**  
  - テキストの内容・位置・フォント・色・整列など。`Identifiable`。  
  - 画像編集のテキストレイヤー用に用意されているが、View 側では主にコメントアウト。

- **FontOption**  
  - `id`, `name`, `displayName`, `fontName`。  
  - `FontOption.availableFonts` で利用可能フォント一覧。  
  - `TextEditorView` などで利用想定（現状は未使用 or 部分的）。

### 4.3 ViewModels

#### ImageAnalysisViewModel

- **役割**: VisionKit の `ImageAnalyzer` と `ImageAnalysisInteraction` をラップし、**画像解析**と**被写体の画像抽出**を提供。
- **主な状態**:
  - `isAnalyzing`: 解析中フラグ
  - `detectedSubjects`: 検出された被写体の `Set<ImageAnalysisInteraction.Subject>`
- **主なメソッド**:
  - `analyzeImage(_ image: UIImage) async throws`: 解析実行。`interaction.analysis` と `detectedSubjects` を更新。
  - `extractImage(for subjects:) async throws -> UIImage`: 指定被写体だけを切り出した画像を返す。

#### MaskEditingViewModel

- **役割**: **マスクの初期化・更新・元画像への適用**。透過 PNG からアルファをマスク化し、PencilKit で編集したマスクを `CIBlendWithMask` 的に使って透過画像を更新する。
- **主な状態**:
  - `originalImage`, `maskImage`, `editedImage`
  - `isEditing`, `isAddingMode`（白=追加 / 黒=削除）
- **主なメソッド**:
  - `initializeMask(from:originalImage:)`: 抽出画像のアルファからグレースケールマスクを生成し、`applyMaskToImage` で `editedImage` を更新。
  - `updateMask(_ newMask:)`: PencilKit 等から渡されたマスクで `editedImage` を再計算。
  - `applyMaskToImage()`: マスクを元画像に適用して `editedImage` を生成。
  - `reset()`: マスク・編集状態のクリア。

### 4.4 Views（メイン）

#### BackgroundRemovalView

- **機能**: 画像から**被写体を選択して背景を除去**。VisionKit の Image Analysis を利用。
- **流れ**:
  1. `ImagePicker` で画像選択 → `loadImage` で `ImageAnalysisViewModel.analyzeImage` を呼び出し、`detectedSubjects` を取得。
  2. `ZoomableImageView` で画像を表示。**長押し**で被写体を選択／追加、**タップ**で選択解除。長押し位置付近に「Remove Background」ボタンを表示。
  3. ボタン押下で `viewModel.extractImage(for: detectedSubjects)` を実行。結果を `processedImage` に格納。
  4. `ExtractedImageView` をシートで表示。保存時は `Photos` へ書き出す。
- **補足**: マスク編集（`MaskEditingView` / `MaskEditingViewModel`）は、抽出後のマスクを PencilKit で直す経路で利用する想定。`ZoomableImageView` に `environmentObject(viewModel)` を渡して ImageAnalysis と連携。

#### BackgroundCompositionView

- **機能**: **背景除去済みの透過画像（foreground）** を、任意の**背景色・キャンバスサイズ**の上に合成し、画像として保存。
- **主な状態**:
  - `foregroundImage`, `composedImage`, `previewImage`
  - `backgroundColor`（白 / 透明）, `squareSize`（512 / 1024 / 2048）
  - `foregroundScale`, `initialScale`（スライダーで前景の拡大率を調整）
- **処理**:
  - 背景色・サイズ・スケールに応じて、`UIGraphicsImageRenderer` 等で前景を背景の上に描画し `composedImage` を生成。保存は `Photos`。

#### ImageEditorView

- **機能**: 画像を開き、**PencilKit で手描き編集**。編集結果を画像として保持・保存。
- **流れ**:
  1. `ImagePicker` で画像選択。
  2. 画像タップで `EditingSheetView` をシート表示。`ZoomablePencilKitImageView` で PencilKit 描画。Done で `onSave(editedImage)` により `selectedImage` を更新。
  3. 保存ボタンで `Photos` に書き出し。
- **補足**: テキストレイヤー（`TextLayer`, `TextEditorView`, `TextLayerView`, `EditableTextView`）はコメントアウトされており、現状は PencilKit のみ有効。

#### TTSStampView

- **機能**: **画像 ＋ テキストの TTS 音声** から、**静止画＋音声の動画**を作り、写真ライブラリに保存する。
- **流れ**:
  1. `ImagePicker` で画像選択。テキストを `TextEditor` に入力。
  2. 「Generate」で `generateTTS` → `synthesizeSpeech(text:)`。`AVSpeechSynthesizer.write` で PCM を CAF ファイルに保存し、`audioURL` に保持。
  3. 再生は `AVAudioEngine` + `AVAudioPlayerNode` で `audioURL` を再生。
  4. 「Save」で `createVideoWithImageAndAudio(image:audioURL:)` を実行。`AVAssetWriter` で静止画 1 フレーム＋音声を MOV にまとめ、`Photos` に保存。
- **TTS**: `AVSpeechSynthesizer`。`SynthesizerHolder` で保持し、`write` のコールバックで `AVAudioFile` に PCM を書き出して CAF を生成。`TTSDelegate` で合成完了を検知。
- **動画**: 音声の長さを `AVAsset` から取得し、その長さの動画を生成。1 枚の画像を最初のフレームとして追加し、音声トラックを `AVAssetReader` / `AVAssetWriterInput` で流し込む。

#### EditingSheetView

- **機能**: `ImageEditorView` 用の **PencilKit 編集シート**。`ZoomablePencilKitImageView` を表示し、Undo/Redo、ツールピッカー、Done で `onSave(compositeImage)` を呼ぶ。
- **補足**: `compositeImage` は、元画像に PencilKit の `PKCanvasView.drawing` を重ねて合成した `UIImage`。

#### ExtractedImageView

- **機能**: 背景除去で得た**透過画像**を、チェッカーパターン背景の上で表示。Close / Save で閉じる or 写真ライブラリに保存。
- **補足**: `ZoomableExtractedImageView`（`UIScrollView` + `UIImageView`）でピンチズーム可能。

### 4.5 Views/Components

| コンポーネント | 役割 |
|----------------|------|
| **ImagePicker** | `UIImagePickerController` の `UIViewControllerRepresentable`。フォトライブラリから 1 枚選択。 |
| **ZoomableImageView** | `UIScrollView` + 画像ビュー。ピンチズーム・パン。長押し／タップのコールバック、ズーム変化のコールバック。`ImageAnalysisInteraction` を使うため `environmentObject(ImageAnalysisViewModel)` を要求。 |
| **ZoomablePencilKitImageView** | PencilKit の `PKCanvasView` を画像の上に重ね、ズーム・パン・描画。`EditingSheetView` から利用。`onSave` で描画と画像の合成結果を返す。 |
| **MaskEditingView** | `UIViewRepresentable`。画像の上に `PKCanvasView` を重ね、白/黒でマスクを編集。`MaskEditingViewModel` と連携し、`updateMask` でマスクを更新。 |
| **CheckerboardPattern** | 透過を表すグレーのチェッカーパターン。`ExtractedImageView` の背景などで使用。 |
| **EditableTextView** | 画像上でドラッグ・ピンチ可能なテキスト。`TextLayer` 用。現状は ImageEditor ではコメントアウト。 |
| **TextEditorView** | フォント・サイズ・色などを選ぶテキスト編集パネル。`TextLayer` 用。同上。 |
| **TextLayerView** | テキストレイヤーの表示用。同上。 |

### 4.6 Utilities

- **ButtonStyles**: `ScaleButtonStyle`。押下時に少し縮小・透過するアニメーション。
- **UIImage+Extensions**: `fixedOrientation()`。Exif の向きを正した `UIImage` を返す。

---

## 5. 画面・機能ごとのデータフロー（概要）

### 5.1 背景除去（Remove BG）

```
ImagePicker → selectedImage
    → loadImage → ImageAnalysisViewModel.analyzeImage
    → detectedSubjects 更新
ZoomableImageView（長押し/タップ）→ detectedSubjects の増減
Remove Background ボタン
    → ImageAnalysisViewModel.extractImage(for: detectedSubjects)
    → processedImage
ExtractedImageView（シート）← processedImage
    → Save → Photos
```

### 5.2 背景合成（Compose）

```
ImagePicker → foregroundImage（透過 PNG 想定）
backgroundSettingsArea → backgroundColor, squareSize
compositionOptionsArea → foregroundScale, initialScale
Compose ボタン → performComposition → composedImage
Save → Photos
```

### 5.3 画像編集（Edit）

```
ImagePicker → selectedImage
画像タップ → EditingSheetView（ZoomablePencilKitImageView）
Done → onSave(compositeImage) → selectedImage 更新
Save → Photos
```

### 5.4 TTS スタンプ

```
ImagePicker → selectedImage
TextEditor → textInput
Generate → synthesizeSpeech → audioURL
Play → AVAudioEngine + audioURL
Save → createVideoWithImageAndAudio(image, audioURL) → MOV → Photos
```

---

## 6. 使用フレームワーク・API

| フレームワーク | 用途 |
|----------------|------|
| **SwiftUI** | 全体の UI。`View`, `@State`, `@StateObject`, `sheet`, `alert` 等。 |
| **VisionKit** | `ImageAnalyzer`, `ImageAnalysisInteraction`。被写体検出・抽出。 |
| **PencilKit** | `PKCanvasView`, `PKToolPicker`, `PKInkingTool`。画像・マスクの手描き。 |
| **AVFoundation** | `AVSpeechSynthesizer`, `AVAudioEngine`, `AVAssetWriter`, `AVAssetReader`。TTS と動画生成。 |
| **Photos** | `PHPhotoLibrary.shared().performChanges` で画像・動画を保存。 |
| **UIKit** | `UIImage`, `UIViewControllerRepresentable`, `UIScrollView`, `UIImageView` 等のブリッジ。 |

---

## 7. アセット（Assets.xcassets）

- **AppIcon.appiconset**: アプリアイコン。
- **AccentColor.colorset**: アクセント色。
- **画像**: `cat`, `earth`, `earth2`, `IMG_sample`, `uedaline` など。主にプレースホルダーやサンプル用。

---

## 8. 今後の拡張の目安

- **TextLayer / TextEditorView / EditableTextView / TextLayerView**: 画像編集のテキストレイヤー機能として、コメントアウトを外して有効化する形で拡張可能。
- **MaskEditingView / MaskEditingViewModel**: 背景除去の抽出結果を、マスクとして PencilKit で微調整する画面を追加する場合に利用可能。
- **TTSStampView**: TTS エンジンの差し替え（例: 外部 API）や、動画の解像度・コーデックのオプション追加が想定しやすい。

---

*以上、stamp_creator の現行実装に基づく設計仕様である。*
