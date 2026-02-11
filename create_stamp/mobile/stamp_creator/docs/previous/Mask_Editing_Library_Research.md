# マスク編集ライブラリ調査結果

## 概要

背景除去後に、背景除去領域を塗ったり消したりできるマスク編集機能を実装するためのライブラリを調査しました。

---

## 推奨ライブラリ

### 1. **TinyCrayon SDK** ⭐ 最推奨

**特徴:**
- **iOS専用のマスク編集SDK**（Swift/Objective-C対応）
- ブラシツール（塗りつぶし・消去）を内蔵
- クイック選択ツール
- 髪の毛ブラシツール（細かい部分の編集に最適）
- **MITライセンス**（商用利用可能・無料）
- 高精度なオブジェクト切り抜き

**GitHub:** https://github.com/TinyCrayon/TinyCrayon-iOS-SDK  
**公式サイト:** https://tinycrayon.github.io/TinyCrayon-iOS-SDK/  
**API ドキュメント:** https://tinycrayon.github.io/TinyCrayon-iOS-SDK/docs-iOS/index.html  
**ガイド:** https://tinycrayon.github.io/TinyCrayon-iOS-SDK/guides-iOS/get-started.html

**インストール方法:**
- CocoaPods/SPMは非対応
- 手動インストール（Frameworkファイルを追加）

**実装例:**
```swift
import TinyCrayon

// マスク編集ビューを追加
let maskEditor = TCMaskEditor(image: extractedImage)
maskEditor.delegate = self
view.addSubview(maskEditor.view)
```

**メリット:**
- ✅ **iOS専用ライブラリ**で、要求に完全一致
- ✅ マスク編集専用で、要求に完全一致
- ✅ ブラシツール（塗りつぶし・消去）が標準装備
- ✅ 商用利用可能・無料
- ✅ 高精度な編集が可能

**デメリット:**
- ⚠️ 外部ライブラリの依存が必要
- ⚠️ 手動インストールが必要（CocoaPods/SPM非対応）

---

### 2. **ZLImageEditor**

**特徴:**
- 包括的な画像エディタフレームワーク
- 描画機能（グラフィティ）
- モザイク機能
- クロップ、テキスト・画像ステッカー
- フィルター、調整機能

**GitHub:** https://github.com/longitachi/ZLImageEditor

**メリット:**
- ✅ 多機能な画像エディタ
- ✅ 描画機能が標準装備
- ✅ モザイク機能も利用可能

**デメリット:**
- ⚠️ マスク編集専用ではない
- ⚠️ マスク編集機能を実装する必要がある可能性

---

### 3. **Brightroom**

**特徴:**
- Core ImageとMetalベースの画像エディタ
- コンポーザブルな設計
- カスタマイズ可能
- ブラシツールの実装が可能

**GitHub:** https://github.com/muukii/Brightroom

**メリット:**
- ✅ 高性能（GPU加速）
- ✅ カスタマイズ性が高い
- ✅ モダンな設計

**デメリット:**
- ⚠️ マスク編集機能を自分で実装する必要がある
- ⚠️ 学習コストが高い

---

### 4. **LaMa-Eraser-iOS**

**特徴:**
- SwiftUIベースのアプリ
- LaMa機械学習モデルを使用
- 画像インペインティング（欠損部分の補完）
- マスクを描いて編集

**GitHub:** https://github.com/whiteio/LaMa-Eraser-iOS

**メリット:**
- ✅ マスクを描いて編集できる
- ✅ 機械学習ベースの高精度な補完

**デメリット:**
- ⚠️ インペインティング（補完）が主目的
- ⚠️ マスク編集専用ではない

---

### 5. **AnyImageKit**

**特徴:**
- 写真編集ツールボックス
- 描画、クロップ、フィルター機能
- 写真選択・編集・キャプチャ

**GitHub:** https://github.com/AnyImageKit/AnyImageKit

**メリット:**
- ✅ 多機能なツールボックス
- ✅ 描画機能が標準装備

**デメリット:**
- ⚠️ マスク編集専用ではない
- ⚠️ マスク編集機能を実装する必要がある可能性

---

### 6. **MediaEditor**

**特徴:**
- 拡張可能な画像編集ライブラリ
- 単一または複数の画像編集
- 様々なソースからの画像編集

**GitHub:** https://github.com/wordpress-mobile/MediaEditor-iOS

**メリット:**
- ✅ 拡張可能な設計
- ✅ WordPress製（安定性）

**デメリット:**
- ⚠️ マスク編集機能を自分で実装する必要がある

---

## 実装方法の比較

### 方法1: TinyCrayon SDKを使用（推奨）

**手順:**
1. CocoaPodsまたはSPMでTinyCrayon SDKをインストール
2. 背景除去後の画像をTinyCrayon SDKに渡す
3. マスク編集ビューを表示
4. ユーザーがブラシツールで編集
5. 編集後のマスクを取得して画像に適用

**メリット:**
- ✅ 実装が簡単
- ✅ 高精度な編集が可能
- ✅ ブラシツールが標準装備

---

### 方法2: Core ImageとVision Frameworkを使用（カスタム実装）

**手順:**
1. 背景除去後のマスクを取得
2. カスタムUIViewでブラシツールを実装
3. タッチイベントでマスクを更新
4. Core Imageでマスクを適用

**メリット:**
- ✅ 外部依存なし
- ✅ 完全なカスタマイズが可能

**デメリット:**
- ⚠️ 実装コストが高い
- ⚠️ ブラシツールの実装が必要

---

### 方法3: 既存の画像エディタライブラリを拡張

**手順:**
1. ZLImageEditorやBrightroomなどのライブラリを使用
2. マスク編集機能を追加実装
3. 背景除去後の画像を編集

**メリット:**
- ✅ 既存の機能を活用できる

**デメリット:**
- ⚠️ マスク編集機能を自分で実装する必要がある

---

## 推奨実装方針

### 最推奨: TinyCrayon SDK

**理由:**
1. **マスク編集専用**で、要求に完全一致
2. **ブラシツール（塗りつぶし・消去）**が標準装備
3. **MITライセンス**で商用利用可能・無料
4. **高精度な編集**が可能
5. **実装が簡単**

**実装イメージ:**
```swift
// 背景除去後の画像をマスク編集ビューに渡す
let maskEditor = TCMaskEditor(image: extractedImage)
maskEditor.delegate = self
maskEditor.showBrushTool() // ブラシツールを表示
maskEditor.showEraserTool() // 消去ツールを表示

// 編集完了後、マスクを取得
let editedMask = maskEditor.getMask()
let editedImage = applyMask(to: originalImage, mask: editedMask)
```

---

## 実装時の考慮事項

### 1. マスクの形式
- `CVPixelBuffer`形式のマスク
- `UIImage`形式のマスク
- `CGImage`形式のマスク

### 2. パフォーマンス
- 大きな画像の処理時のメモリ管理
- リアルタイムプレビューの最適化
- GPU加速の活用

### 3. UX
- ブラシサイズの調整
- アンドゥ・リドゥ機能
- ズーム・パン機能との統合

### 4. 統合
- 既存の`ExtractedImageView`との統合
- 編集後の保存機能
- 編集履歴の管理

---

## 次のステップ

1. **TinyCrayon SDKの評価**
   - サンプルプロジェクトで動作確認
   - 既存コードとの統合可能性を確認

2. **カスタム実装の検討**
   - TinyCrayon SDKが要件に合わない場合
   - Core ImageとVision Frameworkを使用した実装

3. **プロトタイプの作成**
   - 最小限の機能でプロトタイプを作成
   - ユーザーフィードバックを収集

---

## 参考リンク

- **TinyCrayon SDK:** https://tinycrayon.github.io/TinyCrayon-iOS-SDK/
- **ZLImageEditor:** https://github.com/longitachi/ZLImageEditor
- **Brightroom:** https://github.com/muukii/Brightroom
- **Core Image Framework:** https://developer.apple.com/documentation/coreimage
- **Vision Framework:** https://developer.apple.com/documentation/vision
