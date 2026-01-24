# 画像編集ライブラリ調査結果

## 概要

背景除去後の画像に編集機能（テキスト入力、ペン描画、色変更）を追加するためのiOSライブラリを調査しました。

---

## 推奨ライブラリ

### 1. **PencilKit** ⭐ 最推奨

**特徴:**
- **Apple純正の描画フレームワーク**（iOS 13+）
- ペン、テキスト、色選択が標準装備
- 無料、Apple純正なので安定性が高い
- 高パフォーマンス（Metal使用）
- Apple Pencil対応

**主な機能:**
- ペン描画（`PKInkingTool`）
- テキスト入力（`PKToolPicker`）
- 色選択（`PKToolPicker`に内蔵）
- 図形挿入
- アンドゥ/リドゥ

**公式ドキュメント:** https://developer.apple.com/documentation/pencilkit

**メリット:**
- ✅ Apple純正で安定性が高い
- ✅ テキスト入力、ペン描画、色選択が標準装備
- ✅ 無料
- ✅ 高パフォーマンス
- ✅ Apple Pencil対応

**デメリット:**
- ⚠️ iOS 13以降が必要

---

### 2. **Drawsana**

**特徴:**
- Asana製のオープンソースライブラリ
- ペン、テキスト、図形、色選択
- 拡張可能

**GitHub:** https://github.com/Asana/Drawsana

**主な機能:**
- ペン描画（線のスムージング付き）
- テキスト入力
- 図形（楕円、矩形、線、矢印）
- 色選択
- アンドゥ/リドゥ

**メリット:**
- ✅ 多機能
- ✅ 拡張可能
- ✅ オープンソース

**デメリット:**
- ⚠️ 外部ライブラリの依存が必要
- ⚠️ メンテナンス状況を確認する必要がある

---

### 3. **MaLiang**

**特徴:**
- Metalベースの描画ライブラリ
- 高性能
- Apple Pencil対応

**GitHub:** https://github.com/Harley-xk/MaLiang

**主な機能:**
- ペン描画（ベジェ曲線）
- テクスチャ回転
- グロー効果
- Apple Pencil対応
- 3D Touch対応

**メリット:**
- ✅ 高性能（Metal使用）
- ✅ Apple Pencil対応

**デメリット:**
- ⚠️ テキスト入力機能がない（要追加実装）
- ⚠️ 外部ライブラリの依存が必要

---

### 4. **Kanvas**

**特徴:**
- Tumblr製の画像編集ライブラリ
- エフェクト、描画、テキスト、ステッカー

**GitHub:** https://github.com/tumblr/kanvas-ios

**主な機能:**
- エフェクト
- 描画
- テキスト
- ステッカー
- GIF作成

**メリット:**
- ✅ 多機能
- ✅ エフェクト機能も含む

**デメリット:**
- ⚠️ 外部ライブラリの依存が必要
- ⚠️ テキスト入力機能の詳細を確認する必要がある

---

## 実装方針

### 最推奨: **PencilKit**

**理由:**
1. **Apple純正**で安定性が高い
2. **テキスト入力、ペン描画、色選択**が標準装備
3. **無料**
4. **高パフォーマンス**
5. **Apple Pencil対応**

**実装イメージ:**
```swift
import PencilKit

struct ImageEditorView: View {
    @State private var canvasView = PKCanvasView()
    @State private var toolPicker = PKToolPicker()
    
    var body: some View {
        PKCanvasViewRepresentable(canvasView: $canvasView)
            .onAppear {
                toolPicker.addObserver(canvasView)
                toolPicker.setVisible(true, forFirstResponder: canvasView)
                canvasView.becomeFirstResponder()
            }
    }
}
```

---

## 実装計画

### 1. タブの追加
- 背景除去タブ
- 編集タブ

### 2. 編集機能の実装
- PencilKitを使用した描画機能
- テキスト入力機能
- 色選択機能
- 編集後の画像を保存

### 3. UI構成
- タブバーでタブを切り替え
- 編集タブでPencilKitを使用
- ツールバーで色選択など

---

## 参考リンク

- **PencilKit:** https://developer.apple.com/documentation/pencilkit
- **Drawsana:** https://github.com/Asana/Drawsana
- **MaLiang:** https://github.com/Harley-xk/MaLiang
- **Kanvas:** https://github.com/tumblr/kanvas-ios
