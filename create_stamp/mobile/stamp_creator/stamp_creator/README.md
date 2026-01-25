# stamp_creator

**AXiV** — 背景除去・背景合成・画像編集・TTSスタンプ動画作成の 4 機能を持つ iOS アプリです。

起動時にスプラッシュ（AXiV / Rendezvous with the Moment）を表示し、デバイスの言語（en/ja）に応じて UI を切り替えます。

## 機能

| タブ | 機能 |
|------|------|
| **Remove BG** | 画像から被写体を長押しで選択し、背景を除去。VisionKit の Image Analysis を利用。 |
| **Compose** | 背景除去した透過画像を、白/透明の正方形キャンバスに合成。512 / 1024 / 2048px を選択可能。背景色・ボタン名は en/ja でローカライズ。 |
| **Edit** | 画像に PencilKit で手描き編集。ズームしたまま Done しても、編集は正しい縮尺で画像に合成される。 |
| **TTS Sticker** (en) / **TTSスタンプ** (ja) | テキストを音声で読み上げ（TTS）、画像＋音声の動画（MOV）を作成して写真ライブラリに保存。入力テキストの言語（アルファベット→英語、ひらがな・カタカナ・漢字→日本語）を自動判定し、 en/ja どちらの音声も利用可能。 |

## 多言語（en/ja）

- `Localizable.xcstrings` で en（ソース）と ja を管理。
- タブ名・ボタン・アラート・プレースホルダ・TTS の説明文などをローカライズ。en では「Stamp」を「Sticker」で表記。
- サブタイトル「Rendezvous with the Moment」は en/ja 共通で英語のまま。

## ビルド・実行

1. 親ディレクトリの `stamp_creator.xcodeproj` を Xcode で開く。
2. シミュレータまたは実機を選択して Run。

```
create_stamp/mobile/stamp_creator/
├── stamp_creator.xcodeproj   ← これを開く
├── stamp_creator/             ← 本 README の位置（アプリのソース）
│   ├── Localizable.xcstrings  # 多言語（en/ja）
│   └── Views/SplashView.swift # 起動スプラッシュ
└── docs/
```

## 構成

- **Models** … `TextLayer`, `FontOption`
- **ViewModels** … `ImageAnalysisViewModel`, `MaskEditingViewModel`
- **Views** … 各タブのメイン画面、`SplashView`、シート、`Components/` に共通 UI
- **Utilities** … `ButtonStyles`, `UIImage+Extensions`

## ドキュメント

詳細な設計・データフロー・使用フレームワークは [../docs/Design_Specification.md](../docs/Design_Specification.md) を参照。

- [docs/Design_Specification.md](../docs/Design_Specification.md) … 設計仕様書
- [docs/README.md](../docs/README.md) … ドキュメント一覧

## 技術

- SwiftUI, VisionKit, PencilKit, AVFoundation, Photos
- **NaturalLanguage** … TTS の入力テキスト言語判定（en/ja）
- **Localizable.xcstrings** … 多言語（en/ja）文案
