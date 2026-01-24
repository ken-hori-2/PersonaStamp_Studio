# iOS 17以降のSubject Lifting機能の実装

## 📋 概要

iOS 17以降で利用可能な`VNGenerateForegroundInstanceMaskRequest`（Subject Lifting）を実装しました。これは、写真アプリの「長押しで切り抜き」機能と同じ技術を使用した、システムレベルで最適化された超高速な被写体検出APIです。

## ✨ 主な特徴

### 1. 超高速処理
- システムレベルで最適化されているため、従来の`VNGeneratePersonSegmentationRequest`より高速
- Neural Engineを効率的に活用

### 2. 人物以外の被写体にも対応
- 人物だけでなく、動物、物体など様々な被写体を検出可能
- より汎用的な背景除去が可能

### 3. 自動最適化
- システムが自動的に最適な設定を選択
- 開発者が細かい設定を調整する必要がない

## 🔧 実装内容

### 1. Subject Lifting APIの実装

```swift
@available(iOS 17.0, *)
func generateForegroundMaskWithSubjectLifting(_ image: UIImage) -> CVPixelBuffer? {
    guard let ciImage = CIImage(image: image) else { return nil }
    
    var resultMask: CVPixelBuffer?
    let semaphore = DispatchSemaphore(value: 0)
    
    let request = VNGenerateForegroundInstanceMaskRequest { request, error in
        if let error = error {
            print("❌ [Subject Lifting] エラー: \(error.localizedDescription)")
            semaphore.signal()
            return
        }
        
        guard let observation = request.results?.first as? VNPixelBufferObservation else {
            print("❌ [Subject Lifting] 被写体が検出されませんでした")
            semaphore.signal()
            return
        }
        
        resultMask = observation.pixelBuffer
        print("✅ [Subject Lifting] 被写体検出成功（システム最適化版）")
        semaphore.signal()
    }
    
    let handler = VNImageRequestHandler(ciImage: ciImage, orientation: .up, options: [:])
    do {
        try handler.perform([request])
        semaphore.wait()
    } catch {
        print("❌ [Subject Lifting] リクエスト実行エラー: \(error.localizedDescription)")
        return nil
    }
    
    return resultMask
}
```

### 2. フォールバック機能

iOS 17以降ではSubject Liftingを優先使用し、失敗した場合やiOS 16以前では従来の`VNGeneratePersonSegmentationRequest`にフォールバックします。

```swift
func generatePersonSegmentationLightweight(_ image: UIImage) -> CVPixelBuffer? {
    // iOS 17以降でSubject Liftingを優先使用
    if #available(iOS 17.0, *) {
        if let mask = generateForegroundMaskWithSubjectLifting(image) {
            print("✅ [Subject Lifting] 使用（iOS 17以降の最適化版）")
            return mask
        }
        print("⚠️ [Subject Lifting] 失敗、フォールバックに切り替え")
    }
    
    // フォールバック: 従来の人物セグメンテーション
    // ...
}
```

### 3. 自動領域検出への適用

画像読み込み時の自動領域検出にもSubject Liftingを適用しています。

```swift
// iOS 17以降でSubject Liftingを優先使用
if #available(iOS 17.0, *) {
    let request = VNGenerateForegroundInstanceMaskRequest { request, error in
        // 被写体検出処理
    }
    // ...
} else {
    // iOS 16以前: 従来の人物セグメンテーション
    let request = VNGeneratePersonSegmentationRequest { request, error in
        // 人物検出処理
    }
    // ...
}
```

## 📊 パフォーマンス比較

| API | iOS バージョン | 速度 | 対応範囲 | 最適化 |
|-----|--------------|------|---------|--------|
| **VNGenerateForegroundInstanceMaskRequest** | iOS 17+ | ⭐⭐⭐⭐⭐ | 人物・物体・動物 | システム最適化 |
| VNGeneratePersonSegmentationRequest | iOS 15+ | ⭐⭐⭐ | 人物のみ | 手動設定 |

## 🎯 使用方法

### 基本的な使い方

1. **画像を選択**: 「Select Photo」または「Camera」ボタンで画像を選択
2. **自動検出**: iOS 17以降では自動的にSubject Liftingが使用されます
3. **領域を選択**: タップまたはドラッグで領域を選択
4. **背景除去**: 「Remove Background」ボタンをタップ

### 動作確認

- **iOS 17以降**: Subject Liftingが自動的に使用されます（超高速）
- **iOS 16以前**: 従来の人物セグメンテーションにフォールバック

## 🔍 技術的な詳細

### APIの違い

#### VNGenerateForegroundInstanceMaskRequest（iOS 17+）
- **目的**: 画像全体から被写体（人物・物体・動物）を自動検出
- **最適化**: システムレベルで最適化
- **設定**: 自動設定（開発者が調整不要）
- **速度**: 超高速

#### VNGeneratePersonSegmentationRequest（iOS 15+）
- **目的**: 画像全体から人物のみを検出
- **最適化**: 手動で設定を調整可能
- **設定**: `qualityLevel`、`outputPixelFormat`などを手動設定
- **速度**: 高速（Subject Liftingよりやや遅い）

### タップ位置や領域の指定について

`VNGenerateForegroundInstanceMaskRequest`は画像全体から被写体を検出するAPIです。タップ位置や領域に基づく検出は、以下の方法で実現しています：

1. **領域のクロップ**: ユーザーが選択した領域で画像をクロップ
2. **クロップ画像で検出**: クロップ画像に対してSubject Liftingを実行
3. **結果を合成**: 検出結果を元画像に合成

これにより、選択領域内の被写体のみを効率的に検出できます。

## 📝 注意事項

### iOS バージョン要件
- **Subject Lifting**: iOS 17.0以降が必要
- **フォールバック**: iOS 15.0以降で動作（人物セグメンテーション）

### 実機でのテスト
- シミュレータではVision Frameworkが動作しません
- 実機（iPhone/iPad）でテストが必要です

### パフォーマンス
- Subject Liftingはシステムレベルで最適化されているため、非常に高速です
- ただし、画像サイズや複雑さによって処理時間は変わります

## 🚀 今後の改善案

1. **複数被写体の検出**: 複数の被写体を同時に検出・選択
2. **被写体の種類判定**: 人物、動物、物体などを自動判定
3. **リアルタイムプレビュー**: 選択領域を変更しながら、リアルタイムで背景除去のプレビューを表示

## 📚 参考資料

- [Apple Developer - Vision Framework](https://developer.apple.com/documentation/vision)
- [VNGenerateForegroundInstanceMaskRequest Documentation](https://developer.apple.com/documentation/vision/vngenerateforegroundinstancemaskrequest)
- iOS 17 Release Notes
