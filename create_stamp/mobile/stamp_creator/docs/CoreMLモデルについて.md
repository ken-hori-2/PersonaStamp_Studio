# CoreMLモデルについて

## 📌 現在の実装状況

### ✅ CoreMLモデルは不要です

現在の実装では、**AppleのVision Frameworkの組み込みAPI**（`VNGeneratePersonSegmentationRequest`）を使用しているため、**追加のCoreMLモデルをダウンロードする必要はありません**。

- ✅ 既にiOSに組み込まれているAPIを使用
- ✅ 追加のダウンロード不要
- ✅ アプリサイズが小さくて済む
- ⚠️ ただし、**人物検出のみ**に限定される

### 現在プロジェクトにあるResnet50.mlmodelについて

プロジェクト内に `Resnet50.mlmodel` が存在しますが、これは**画像分類用**のモデルで、現在の背景除去アプリでは使用していません。削除しても問題ありません。

---

## 🔮 将来、CoreMLモデルを追加する場合

人物以外の被写体（動物、物体など）にも対応したい場合や、より高精度な背景除去が必要な場合は、以下のようなCoreMLモデルを追加できます。

### 推奨モデル

1. **U^2Net** - 汎用的な背景除去モデル
   - 人物以外にも対応
   - 高精度
   - モデルサイズ: 約4-5MB

2. **MODNet** - 人物専用だが高精度
   - 人物の背景除去に特化
   - より高精度な結果
   - モデルサイズ: 約2-3MB

3. **DeepLabV3** - セマンティックセグメンテーション
   - 複数の物体カテゴリに対応
   - モデルサイズ: 約10MB

---

## 📥 CoreMLモデルの取得方法

### 方法1: 既存のCoreMLモデルを使用（推奨）

#### U^2Netモデルの取得

1. **Apple Developerのサンプルコードから取得**
   - [Apple Developer - Core ML](https://developer.apple.com/machine-learning/models/)
   - 背景除去用のサンプルモデルを探す

2. **Hugging Faceから取得**
   - [Hugging Face - CoreML Models](https://huggingface.co/models?library=coreml)
   - 検索: "u2net", "background removal", "segmentation"

3. **GitHubから取得**
   - 検索: "u2net coreml", "background removal coreml"
   - 例: [u2net-coreml](https://github.com/search?q=u2net+coreml)

#### モデルファイルの配置

1. ダウンロードした `.mlmodel` ファイルを取得
2. Xcodeでプロジェクトを開く
3. プロジェクトナビゲーターで `stamp_creator` フォルダを右クリック
4. **Add Files to "stamp_creator"...** を選択
5. `.mlmodel` ファイルを選択して追加
6. **Copy items if needed** にチェックを入れる
7. **Add** をクリック

### 方法2: PythonでPyTorchモデルをCoreMLに変換

既存のPyTorchモデル（U^2Netなど）をCoreML形式に変換する場合：

#### 必要な環境

```bash
# Python環境のセットアップ
pip install torch torchvision
pip install coremltools
pip install pillow numpy
```

#### 変換スクリプト例

```python
import torch
import coremltools as ct
from PIL import Image

# PyTorchモデルを読み込み（例: U^2Net）
# model = torch.load('u2net.pth')
# model.eval()

# 入力例を作成
example_input = torch.rand(1, 3, 320, 320)

# CoreMLに変換
traced_model = torch.jit.trace(model, example_input)
mlmodel = ct.convert(
    traced_model,
    inputs=[ct.TensorType(name="input", shape=(1, 3, 320, 320))],
    outputs=[ct.TensorType(name="output")],
    compute_units=ct.ComputeUnit.ALL  # Neural Engine, GPU, CPUすべてを使用
)

# 保存
mlmodel.save("U2Net.mlmodel")
```

#### 変換後の配置

変換した `.mlmodel` ファイルを上記「方法1」の手順でXcodeプロジェクトに追加

---

## 🔧 CoreMLモデルを実装に追加する場合のコード変更

### 1. モデルの読み込み

```swift
import CoreML
import Vision

// モデルの読み込み
func loadModel() -> VNCoreMLModel? {
    guard let modelURL = Bundle.main.url(forResource: "U2Net", withExtension: "mlmodel") else {
        return nil
    }
    
    do {
        let model = try MLModel(contentsOf: modelURL)
        return try VNCoreMLModel(for: model)
    } catch {
        print("モデルの読み込みに失敗: \(error)")
        return nil
    }
}
```

### 2. 背景除去処理の変更

```swift
func removeBackgroundWithCoreML(image: UIImage) {
    guard let coreMLModel = loadModel() else {
        // フォールバック: Vision Frameworkの人物セグメンテーションを使用
        removeBackground() // 既存のメソッド
        return
    }
    
    guard let pixelBuffer = image.toCVPixelBuffer() else { return }
    
    let request = VNCoreMLRequest(model: coreMLModel) { request, error in
        // 処理結果を取得
        if let results = request.results as? [VNPixelBufferObservation],
           let result = results.first {
            // マスクを使って透過画像を生成
            let processed = self.createTransparentImage(from: image, maskBuffer: result.pixelBuffer)
            DispatchQueue.main.async {
                self.processedImage = processed
                self.isProcessing = false
            }
        }
    }
    
    let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
    try? handler.perform([request])
}
```

---

## 📊 モデル比較

| モデル | 対応範囲 | 精度 | サイズ | 処理速度 | 実装難易度 |
|--------|---------|------|--------|---------|-----------|
| **Vision Framework**<br>(現在使用) | 人物のみ | 高 | 0MB<br>(組み込み) | 速い | 簡単 ⭐ |
| **U^2Net** | 汎用 | 高 | 4-5MB | 中 | 中 ⭐⭐ |
| **MODNet** | 人物 | 非常に高 | 2-3MB | 速い | 中 ⭐⭐ |
| **DeepLabV3** | 汎用<br>(複数カテゴリ) | 高 | 10MB | 遅い | 難 ⭐⭐⭐ |

---

## 🎯 推奨アプローチ

### 現在の実装で十分な場合
- ✅ **何も追加不要** - そのまま使用可能
- ✅ 人物の背景除去のみで問題ない場合

### 拡張が必要な場合

1. **まずはU^2Netを試す**（汎用性が高い）
   - GitHubやHugging Faceから既存のCoreMLモデルを取得
   - 上記のコード変更を実装

2. **モデルの選択**
   - 人物のみ: MODNet（高精度）
   - 汎用: U^2Net（バランスが良い）
   - 複数カテゴリ: DeepLabV3（高機能だが重い）

---

## 📝 まとめ

### 現在の状況
- ✅ **CoreMLモデルのダウンロードは不要**
- ✅ Vision Frameworkの組み込みAPIを使用
- ✅ すぐに実行可能

### 将来の拡張
- 🔮 人物以外にも対応したい場合のみ、CoreMLモデルを追加
- 🔮 上記の手順でモデルを取得・追加可能

---

**結論**: 現在の実装では、CoreMLモデルのダウンロードや追加は一切不要です。そのまま実行できます！

