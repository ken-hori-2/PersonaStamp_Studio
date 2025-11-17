# 音源分離 iOSアプリ

Swift・Core MLを使用した音源分離iOSアプリです。Spleeterモデルを使用して、音楽ファイルからボーカルや楽器を分離できます。

## 機能

- **2stems分離**: ボーカルと伴奏に分離
- **4stems分離**: ボーカル、ドラム、ベース、その他に分離
- **5stems分離**: ボーカル、ドラム、ベース、ピアノ、その他に分離
- 進捗表示
- リアルタイム処理

## 必要な環境

- iOS 15.0以上
- Xcode 14.0以上
- Swift 5.7以上

## セットアップ

### 1. Core MLモデルの準備

このアプリを使用するには、SpleeterのCore MLモデルが必要です。以下のいずれかの方法でモデルを取得してください：

#### 方法1: 事前コンパイル済みモデルを使用

[swift-spleeterのGitHub Releases](https://github.com/jiyimeta/swift-spleeter/releases)から、以下のモデルファイルをダウンロードしてください：

- `Spleeter2.mlmodelc` (2stems用)
- `Spleeter4.mlmodelc` (4stems用)
- `Spleeter5.mlmodelc` (5stems用)

#### 方法2: 自分でモデルを生成

[spleeter-pytorch](https://github.com/jiyimeta/spleeter-pytorch)を使用して、PyTorchモデルからCore MLモデルを生成できます。

### 2. モデルの配置

ダウンロードまたは生成したモデルファイル（`.mlmodelc`）を以下のいずれかの場所に配置してください：

- **アプリバンドル内**: Xcodeプロジェクトに追加し、ターゲットに含める
- **Documentsディレクトリ**: アプリのDocumentsディレクトリに配置（初回起動時にダウンロードするなど）

### 3. Xcodeプロジェクトの作成

#### 新規プロジェクトを作成する場合

1. Xcodeを起動し、「Create a new Xcode project」を選択
2. 「iOS」→「App」を選択
3. プロジェクト情報を入力：
   - **Product Name**: VoiceCreator
   - **Interface**: SwiftUI
   - **Language**: Swift
   - **Storage**: None（または必要に応じて）
4. 保存場所を選択してプロジェクトを作成

#### 既存のプロジェクトに追加する場合

1. このディレクトリ内のすべてのSwiftファイルをXcodeプロジェクトに追加
2. ターゲットの設定で以下を確認：
   - **Deployment Target**: iOS 15.0以上
   - **Frameworks**: 
     - AVFoundation
     - Accelerate
     - CoreML
     - SwiftUI
     - UniformTypeIdentifiers

#### プロジェクト設定

**Build Settings**で以下を確認：
- **Swift Language Version**: Swift 5.7以上
- **iOS Deployment Target**: 15.0以上

**Info.plist**に以下を追加（既に含まれています）：
- `NSMicrophoneUsageDescription`: 音源ファイル選択の説明
- `NSPhotoLibraryUsageDescription`: 音源ファイル選択の説明（必要に応じて）

## 使用方法

1. アプリを起動
2. 「音源ファイルを選択」ボタンをタップして、分離したい音楽ファイルを選択
3. 分離タイプ（2stems/4stems/5stems）を選択
4. 「音源分離を実行」ボタンをタップ
5. 処理が完了すると、分離された音源ファイルが表示されます

## アーキテクチャ

### 主要なクラス

- **`VoiceCreatorApp`**: アプリのエントリーポイント
- **`ContentView`**: メインUI（SwiftUI）
- **`AudioSeparationViewModel`**: UI状態管理（ObservableObject）
- **`AudioSeparator`**: 音源分離のコアロジック
  - STFT（短時間フーリエ変換）の実装
  - Core ML推論の実行
  - 逆STFTによる波形復元

### 処理フロー

1. **音源ファイルの読み込み**: AVFAudioを使用してオーディオファイルを読み込む
2. **STFT変換**: 時間領域の波形を周波数領域のスペクトログラムに変換
3. **Core ML推論**: スペクトログラムをチャンクに分割してモデルに投入
4. **マスク適用**: モデルの出力マスクを適用して各ステムを分離
5. **逆STFT変換**: スペクトログラムを時間領域の波形に戻す
6. **ファイル保存**: 分離された各ステムをWAVファイルとして保存

## 技術的な詳細

### STFT実装

- **フレームサイズ**: 4096サンプル
- **ホップサイズ**: 1024サンプル
- **ウィンドウ関数**: Hann窓
- **FFT**: AccelerateフレームワークのvDSPを使用

### メモリ管理

長い音源ファイルを処理する際のメモリ使用量を抑えるため、以下の対策を実装：

- チャンク単位での処理
- 固定サイズのバッファ使用
- 不要なデータの即座解放

## 注意事項

- モデルファイルは比較的大きい（各35MB程度）ため、アプリサイズに注意してください
- 処理時間は音源ファイルの長さとデバイスの性能に依存します
- 初回実行時はモデルの読み込みに時間がかかる場合があります

## 参考資料

- [Swift・Core MLで音源分離してみた - Qiita](https://qiita.com/jiyimeta/items/b2de46e045bfa1dc295f)
- [swift-spleeter - GitHub](https://github.com/jiyimeta/swift-spleeter)
- [Spleeter - GitHub](https://github.com/deezer/spleeter)

## ライセンス

このプロジェクトは参考記事の実装を基に作成されています。Spleeterモデル自体のライセンスについては、元のリポジトリを参照してください。

