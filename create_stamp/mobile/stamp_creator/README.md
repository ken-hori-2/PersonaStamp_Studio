# mobile/stamp_creator

このフォルダは、iOSアプリ **`stamp_creator`（AXiV）** のプロジェクト一式（Xcodeプロジェクト、アプリ本体ソース、ドキュメント）を置いています。

## すぐに起動する（開発）

1. Xcodeで `stamp_creator.xcodeproj` を開く
2. 実機 or シミュレータを選択して Run

```
create_stamp/mobile/stamp_creator/
├── stamp_creator.xcodeproj/     # Xcodeプロジェクト
├── stamp_creator/               # アプリ本体ソース（SwiftUI）
└── docs/                        # 設計・運用ドキュメント
```

## どこに何があるか

- **アプリ概要 / 機能 / 技術 / ビルド手順（詳細）**: `stamp_creator/README.md`
- **ドキュメント一覧（設計仕様・App Store素材など）**: `docs/README.md`
- **設計仕様書（実装調査ベース）**: `docs/Design_Specification.md`

## よく触る場所（例）

- **多言語（en/ja）**: `stamp_creator/Localizable.xcstrings`
  - 画面文言は基本 `String(localized:)` 経由で参照します
- **アプリアイコン（iPhone/iPad）**: `stamp_creator/Assets.xcassets/AppIcon.appiconset/`
  - `Contents.json` に各サイズのエントリが定義されています（iPad含む）
  - 実ファイル（PNG）が足りない場合は、XcodeのAsset Catalog上で警告が出ます

## 注意

- 写真の読み込み/保存、カメラ利用を行うため、`Info.plist`（Xcodeのビルド設定で生成）に権限文言が含まれます。

