# stamp_creator

背景除去・背景合成・画像編集・TTSスタンプ動画作成の 4 機能を持つ iOS アプリです。

## 機能

| タブ | 機能 |
|------|------|
| **Remove BG** | 画像から被写体を長押しで選択し、背景を除去。VisionKit の Image Analysis を利用。 |
| **Compose** | 背景除去した透過画像を、白/透明の正方形キャンバスに合成。512 / 1024 / 2048px を選択可能。 |
| **Edit** | 画像に PencilKit で手描き編集。 |
| **TTS Stamp** | 画像＋テキストから TTS 音声を生成し、静止画＋音声の動画（MOV）を作成。写真ライブラリに保存。 |

## ビルド・実行

1. 親ディレクトリの `stamp_creator.xcodeproj` を Xcode で開く。
2. シミュレータまたは実機を選択して Run。

```
create_stamp/mobile/stamp_creator/
├── stamp_creator.xcodeproj   ← これを開く
├── stamp_creator/             ← 本 README の位置（アプリのソース）
└── docs/
```

## 構成

- **Models** … `TextLayer`, `FontOption`
- **ViewModels** … `ImageAnalysisViewModel`, `MaskEditingViewModel`
- **Views** … 各タブのメイン画面、シート、`Components/` に共通 UI
- **Utilities** … `ButtonStyles`, `UIImage+Extensions`

## ドキュメント

詳細な設計・データフロー・使用フレームワークは [../docs/Design_Specification.md](../docs/Design_Specification.md) を参照。

- [docs/Design_Specification.md](../docs/Design_Specification.md) … 設計仕様書
- [docs/README.md](../docs/README.md) … ドキュメント一覧

## 技術

- SwiftUI, VisionKit, PencilKit, AVFoundation, Photos
