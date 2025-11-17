# セットアップガイド

このドキュメントでは、音源分離iOSアプリのセットアップ手順を詳しく説明します。

## 前提条件

- macOS（Xcodeを実行できる環境）
- Xcode 14.0以上
- iOS 15.0以上のデバイスまたはシミュレータ
- Core MLモデルファイル（`.mlmodelc`形式）

## ステップ1: Xcodeプロジェクトの作成

### 方法A: 新規プロジェクトを作成

1. Xcodeを起動
2. 「Create a new Xcode project」を選択
3. テンプレート選択：
   - **Platform**: iOS
   - **Template**: App
4. プロジェクト情報：
   - **Product Name**: `VoiceCreator`
   - **Team**: 開発チームを選択
   - **Organization Identifier**: 例: `com.yourcompany`
   - **Interface**: SwiftUI
   - **Language**: Swift
   - **Storage**: None
5. 保存場所を選択して「Create」

### 方法B: 既存のプロジェクトに追加

既存のXcodeプロジェクトがある場合：

1. Xcodeでプロジェクトを開く
2. プロジェクトナビゲーターで右クリック → 「Add Files to...」
3. このディレクトリ内のすべての`.swift`ファイルを選択
4. 「Copy items if needed」にチェック
5. ターゲットに追加することを確認

## ステップ2: ファイルの配置

プロジェクトに以下のファイルが含まれていることを確認：

- `VoiceCreatorApp.swift` - アプリエントリーポイント
- `ContentView.swift` - メインUI
- `AudioSeparationViewModel.swift` - ViewModel
- `AudioSeparator.swift` - 音源分離ロジック
- `CoreMLModelWrapper.swift` - Core MLモデルラッパー
- `Info.plist` - アプリ設定

## ステップ3: フレームワークの追加

プロジェクトのターゲット設定で、以下のフレームワークがリンクされていることを確認：

1. プロジェクトナビゲーターでプロジェクトを選択
2. ターゲットを選択
3. 「General」タブ → 「Frameworks, Libraries, and Embedded Content」
4. 以下のフレームワークを追加（「+」ボタンから）：
   - `AVFoundation.framework`
   - `Accelerate.framework`
   - `CoreML.framework`
   - `SwiftUI.framework`（通常は自動的に含まれます）
   - `UniformTypeIdentifiers.framework`

または、「Build Phases」タブ → 「Link Binary With Libraries」から追加。

## ステップ4: Core MLモデルの準備

### オプション1: 事前コンパイル済みモデルを使用

1. [swift-spleeterのGitHub Releases](https://github.com/jiyimeta/swift-spleeter/releases)からモデルをダウンロード
2. 以下のファイルをダウンロード：
   - `Spleeter2.mlmodelc`
   - `Spleeter4.mlmodelc`（オプション）
   - `Spleeter5.mlmodelc`（オプション）

### オプション2: 自分でモデルを生成

1. [spleeter-pytorch](https://github.com/jiyimeta/spleeter-pytorch)リポジトリをクローン
2. 手順に従ってPyTorchモデルからCore MLモデルを生成
3. 生成された`.mlmodelc`ファイルを取得

## ステップ5: モデルの配置

### 方法A: アプリバンドルに含める（推奨）

1. Xcodeプロジェクトナビゲーターで、プロジェクトフォルダを右クリック
2. 「Add Files to...」を選択
3. ダウンロードした`.mlmodelc`ファイルを選択
4. 「Copy items if needed」にチェック
5. ターゲットに追加することを確認
6. 「Create groups」を選択

**注意**: この方法では、モデルファイルがアプリバンドルに含まれるため、アプリサイズが大きくなります（各モデル約35MB）。

### 方法B: 実行時にダウンロード

1. アプリのDocumentsディレクトリにモデルを配置するコードを追加
2. 初回起動時にモデルをダウンロード
3. `AudioSeparator.swift`の`getModelURL`メソッドがDocumentsディレクトリを検索するように実装済み

## ステップ6: ビルド設定の確認

1. プロジェクトナビゲーターでプロジェクトを選択
2. ターゲットを選択
3. 「General」タブで以下を確認：
   - **Deployment Target**: iOS 15.0以上
   - **Supported Destinations**: iPhone, iPad

4. 「Build Settings」タブで以下を確認：
   - **Swift Language Version**: Swift 5.7以上
   - **iOS Deployment Target**: 15.0以上

## ステップ7: 権限設定の確認

`Info.plist`に以下の権限説明が含まれていることを確認：

- `NSMicrophoneUsageDescription`: 音源ファイル選択の説明
- `NSPhotoLibraryUsageDescription`: 音源ファイル選択の説明（必要に応じて）

## ステップ8: ビルドと実行

1. デバイスまたはシミュレータを選択
2. 「Product」→「Run」（⌘R）でビルドと実行
3. エラーが発生した場合は、以下を確認：
   - すべてのファイルがターゲットに追加されているか
   - フレームワークが正しくリンクされているか
   - モデルファイルが正しく配置されているか

## トラブルシューティング

### エラー: "Core MLモデルが見つかりません"

- モデルファイルがプロジェクトに追加されているか確認
- モデルファイルがターゲットに含まれているか確認
- `AudioSeparator.swift`の`getModelURL`メソッドのパスを確認

### エラー: "Framework not found"

- 「Build Phases」→「Link Binary With Libraries」でフレームワークが追加されているか確認
- フレームワークのパスが正しいか確認

### エラー: ビルドエラー

- Xcodeのバージョンが14.0以上か確認
- Swiftのバージョンが5.7以上か確認
- すべてのインポート文が正しいか確認

### パフォーマンスの問題

- 長い音源ファイルの処理には時間がかかります
- チャンクサイズを調整することで、メモリ使用量と処理速度のバランスを調整できます
- `AudioSeparator.swift`の`chunkSize`を調整

## 次のステップ

セットアップが完了したら、[README.md](README.md)を参照してアプリの使用方法を確認してください。

