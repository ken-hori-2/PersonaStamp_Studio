# iOSアプリ軽量化仕様書

## 📋 概要

現在のアプリは画像を読み込むと自動的に全画像に対して重い背景除去処理が実行され、アプリが固まる問題があります。LINEスタンプメーカーのように、サクサク動くが、ユーザーが囲った領域から背景除去（人のみでOK）できるように軽量化します。

## 🎯 目標

1. **サクサク動作**: 画像を読み込んだ時点では処理を実行せず、即座に表示
2. **オンデマンド処理**: ユーザーが領域を選択（囲む）した時点で、その領域のみを処理
3. **軽量処理**: 必要最小限のVision Frameworkリクエストのみ実行
4. **人物のみ対応**: 人物の背景除去のみ（既存の機能を維持）

## 🔍 現在の問題点

### 1. 画像読み込み時の自動処理
- 画像を選択すると即座に全画像に対して処理が実行される
- 複数のVision Frameworkリクエストが同時実行される
  - 人物セグメンテーション（VNGeneratePersonSegmentationRequest）
  - 顔検出（VNDetectFaceRectanglesRequest）
  - 体の姿勢検出（VNDetectHumanBodyPoseRequest）

### 2. 重い処理
- 画像の前処理（prepareImage: 向き修正、リサイズ）
- マスクの後処理（postProcessMask: モルフォロジー演算）
- ピクセル単位の処理（createTransparentImageManual: 全ピクセルを処理）

### 3. 不要な処理
- 体の姿勢検出は背景除去に直接必要ない
- 複数人物の検出・選択機能は、ユーザーが領域を選択する方式に変更

## ✨ 新しい実装方針

### 1. 画像読み込み時（軽量）
- 画像を読み込んだら、**即座に表示**（処理は実行しない）
- 画像の向き修正のみ実行（表示用）
- Vision Frameworkのリクエストは一切実行しない

### 2. ユーザー操作（領域選択）
- ユーザーが画像上で**ドラッグして領域を選択**（囲む）
- 選択領域を視覚的に表示（矩形やハイライト）
- 選択領域の座標を保存

### 3. 背景除去処理（オンデマンド）
- ユーザーが「背景除去」ボタンをタップした時点で処理を開始
- **選択領域内のみ**を処理対象とする
- 処理範囲を限定することで高速化

### 4. 処理の最適化
- **人物セグメンテーションのみ**実行（顔検出、体の姿勢検出は削除）
- 選択領域に基づいて画像をクロップ（処理範囲を縮小）
- マスクの後処理は簡略化（必要最小限のみ）
- 処理完了後、元画像サイズに戻す

## 📐 UI/UX設計

### 画面構成
```
┌─────────────────────────┐
│   Stamp Creator         │
│                         │
│  ┌─────────────────┐   │
│  │                 │   │
│  │   画像表示エリア  │   │
│  │  (選択領域表示)   │   │
│  │                 │   │
│  └─────────────────┘   │
│                         │
│  [画像を選択]           │
│  [領域を選択]           │
│  [背景除去]             │
│  [保存]                 │
└─────────────────────────┘
```

### 操作フロー
1. **画像選択**: ユーザーが画像を選択
   - 画像が即座に表示される（処理なし）
2. **領域選択**: ユーザーが画像上でドラッグして領域を選択
   - 選択領域が矩形で表示される
   - 選択領域を変更可能（再ドラッグ）
3. **背景除去**: 「背景除去」ボタンをタップ
   - 選択領域内のみを処理
   - 処理中はプログレスインジケーターを表示
4. **結果表示**: 処理完了後、透過画像を表示
   - チェッカーパターンの背景で透過を視覚化
5. **保存**: 「保存」ボタンで写真ライブラリに保存

## 🔧 技術実装詳細

### 1. 画像読み込み処理（軽量化）
```swift
// 画像選択時: 処理を実行せず、表示のみ
func loadImage(_ image: UIImage) {
    // 向き修正のみ（軽量）
    selectedImage = image.fixedOrientation()
    processedImage = nil  // 処理済み画像をクリア
    selectedRegion = nil   // 選択領域をクリア
}
```

### 2. 領域選択機能
```swift
// 選択領域の状態管理
@State private var selectedRegion: CGRect?  // 選択領域（画像座標系）
@State private var isSelectingRegion = false  // 選択中フラグ
@State private var selectionStartPoint: CGPoint?  // 選択開始点

// ドラッグで領域を選択
func handleDragGesture(value: DragGesture.Value) {
    // ドラッグ開始時
    if value.startLocation != selectionStartPoint {
        selectionStartPoint = value.startLocation
    }
    
    // ドラッグ中: 選択領域を更新
    if let start = selectionStartPoint {
        let rect = CGRect(
            x: min(start.x, value.location.x),
            y: min(start.y, value.location.y),
            width: abs(value.location.x - start.x),
            height: abs(value.location.y - start.y)
        )
        selectedRegion = rect
    }
}
```

### 3. 軽量な背景除去処理
```swift
func removeBackgroundInRegion() {
    guard let image = selectedImage,
          let region = selectedRegion else { return }
    
    isProcessing = true
    
    DispatchQueue.global(qos: .userInitiated).async {
        // 1. 選択領域で画像をクロップ（処理範囲を縮小）
        guard let croppedImage = self.cropImage(image, to: region) else {
            DispatchQueue.main.async {
                self.isProcessing = false
                self.showError("画像のクロップに失敗しました")
            }
            return
        }
        
        // 2. クロップ画像に対して人物セグメンテーションのみ実行
        guard let mask = self.generatePersonSegmentation(croppedImage) else {
            DispatchQueue.main.async {
                self.isProcessing = false
                self.showError("人物が検出されませんでした")
            }
            return
        }
        
        // 3. マスクを使って透過画像を生成（簡略化版）
        guard let processed = self.createTransparentImage(from: croppedImage, mask: mask) else {
            DispatchQueue.main.async {
                self.isProcessing = false
                self.showError("画像の処理に失敗しました")
            }
            return
        }
        
        // 4. 元画像サイズに戻す（選択領域の位置を考慮）
        let finalImage = self.compositeImage(original: image, processed: processed, region: region)
        
        DispatchQueue.main.async {
            self.processedImage = finalImage
            self.isProcessing = false
        }
    }
}

// 人物セグメンテーションのみ実行（軽量）
func generatePersonSegmentation(_ image: UIImage) -> CVPixelBuffer? {
    guard let ciImage = CIImage(image: image) else { return nil }
    
    var resultMask: CVPixelBuffer?
    let request = VNGeneratePersonSegmentationRequest { request, error in
        guard let observation = request.results?.first as? VNPixelBufferObservation else {
            return
        }
        resultMask = observation.pixelBuffer
    }
    
    request.qualityLevel = .balanced  // 高速化のためbalancedを使用
    request.outputPixelFormat = kCVPixelFormatType_OneComponent8
    
    let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
    try? handler.perform([request])
    
    return resultMask
}
```

### 4. 処理の最適化ポイント
- **画像クロップ**: 選択領域のみを処理することで、処理範囲を大幅に縮小
- **Quality Level**: `.accurate` → `.balanced` に変更（速度優先）
- **後処理の簡略化**: モルフォロジー演算を削除または簡略化
- **不要なリクエスト削除**: 顔検出、体の姿勢検出を削除

## 📊 パフォーマンス目標

### 処理時間の目標
- **画像読み込み**: < 100ms（即座に表示）
- **領域選択**: リアルタイム（ドラッグに追従）
- **背景除去**: < 2秒（選択領域が画面の50%以下の場合）

### メモリ使用量
- 画像読み込み時: 元画像のみ保持
- 処理中: クロップ画像 + マスク（元画像より小さい）
- 処理後: 透過画像のみ保持

## 🚀 実装手順

1. **バックアップ作成** ✅
2. **仕様書作成** ✅
3. **画像読み込み処理の軽量化**
   - 自動処理を削除
   - 表示のみに変更
4. **領域選択機能の実装**
   - ドラッグジェスチャーの追加
   - 選択領域の視覚化
5. **軽量な背景除去処理の実装**
   - 選択領域でのクロップ
   - 人物セグメンテーションのみ実行
   - 不要な処理の削除
6. **UIの調整**
   - ボタンの配置
   - プログレスインジケーター
7. **テスト**
   - 実機での動作確認
   - パフォーマンス測定

## 📝 注意事項

- 既存の機能（透過画像の保存など）は維持
- 人物のみの背景除去（既存の制約を維持）
- 実機でのテストが必要（シミュレータでは動作しない）

## 🔄 将来の拡張

- 複数領域の選択
- 自動領域検出（オプション）
- 処理品質の選択（高速/高品質）
