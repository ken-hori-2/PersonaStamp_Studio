# 背景除去ツール (Background Remover)

このツールは、`rembg`ライブラリを使用して画像から背景を自動的に除去するPythonスクリプトです。

## インストール

### 仮想環境の作成とアクティベート

```bash
# 仮想環境を作成
python3 -m venv env

# 仮想環境をアクティベート
# macOS/Linuxの場合:
source env/bin/activate

# Windowsの場合:
# env\Scripts\activate
```

### 依存関係のインストール

```bash
pip install -r requirements.txt
```

### GPUを使用する場合（オプション）

GPUを使用して処理速度を向上させたい場合は、以下のコマンドを実行してください：

```bash
pip install rembg[gpu]
```

**注意**: GPUを使用する場合は、`onnxruntime-gpu`が必要です。詳細は[ONNX Runtime公式サイト](https://onnxruntime.ai/)を参照してください。

### モデルの事前ダウンロード（推奨）

初回実行時にモデルが自動的にダウンロードされますが、事前にダウンロードしておくことで処理時間を短縮できます。

```bash
# すべてのモデルを事前にダウンロード
python download_models.py --all

# 特定のモデルのみダウンロード（例: u2net）
python download_models.py --model u2net

# 複数のモデルをダウンロード
python download_models.py --model u2net --model u2net_human_seg
```

**注意**: モデルは `~/.u2net/` ディレクトリにキャッシュされます。一度ダウンロードすれば、次回以降は自動的に使用されます。

## 使用方法

### 基本的な使い方

```bash
python background_remover.py input_image.jpg
```

このコマンドを実行すると、`input_image_remove.png`という名前で背景が除去された画像が保存されます。

### 出力ファイル名を指定する場合

```bash
python background_remover.py input_image.jpg -o output.png
```

### 背景色を適用する場合

背景除去後に白い背景（または指定した色の背景）を適用する場合：

```bash
python background_remover.py input_image.jpg --apply-background
```

### カスタム背景色を指定する場合

```bash
python background_remover.py input_image.jpg --apply-background --background-color 0 0 255
```

背景色はBGR形式で指定します（例: `0 0 255`は赤色）。

### モデルタイプの選択

異なる用途に応じてモデルを選択できます：

```bash
# 人物専用モデル（人物の精度が高い）
python background_remover.py photo.jpg --model u2net_human_seg

# 一般物体にも対応（人・物体の両方を検出、デフォルト）
python background_remover.py image.jpg --model u2net

# ポートレート専用（人物写真に最適）
python background_remover.py portrait.jpg --model birefnet-portrait

# 高精度モデル（処理が遅いが精度が高い）
python background_remover.py image.jpg --model sam
```

### 精度向上オプション

髪の毛など細かい部分の精度を向上させる場合：

```bash
# アルファマッティングを使用（髪の毛の間も除去し切る）
python background_remover.py photo.jpg --alpha-matting

# マスクの後処理を有効化（エッジの滑らかさ向上）
python background_remover.py photo.jpg --post-process

# 両方を組み合わせて最高精度
python background_remover.py photo.jpg --alpha-matting --post-process
```

## よくある質問（FAQ）

### Q1: 人以外も背景として認識されますか？それとも物体も認識されますか？

**A:** 使用するモデルによって異なります：

- **`u2net`（デフォルト）**: **人・物体の両方を前景として認識**します。人物だけでなく、物体（商品、動物、建物など）も前景として残し、それ以外を背景として除去します。
- **`u2net_human_seg`**: **人物専用**です。人物のみを前景として認識し、物体も背景として除去される可能性があります。
- **`birefnet-portrait`**: ポートレート（人物写真）専用で、人物の精度が高いです。

### Q2: 複数人や複数個あるときの特定の対象を残す指定はできますか？

**A:** rembgの標準機能では、**特定の対象を指定して残す機能はありません**。モデルは画像内のすべての前景（人や物体）を自動的に検出し、背景のみを除去します。

複数人や複数物体がある場合：
- **すべての前景が残り、背景のみが除去**されます
- 特定の人物や物体だけを残したい場合は、事前に画像をトリミングするか、後処理でマスクを編集する必要があります

### Q3: 精度を向上させることは可能ですか？たとえば髪の毛の間も除去し切るなど

**A:** はい、以下の方法で精度を向上できます：

1. **アルファマッティング（`--alpha-matting`）**
   - 髪の毛の間や細かいエッジ部分の精度が向上
   - 半透明部分の処理が改善
   - 処理時間はやや長くなります

2. **マスク後処理（`--post-process`）**
   - マスクのエッジを滑らかに
   - ノイズを除去

3. **適切なモデルの選択**
   - 人物写真: `u2net_human_seg` または `birefnet-portrait`
   - 一般物体: `u2net` または `isnet-general-use`
   - 最高精度: `sam`（処理が遅い）

**使用例：**
```bash
# 髪の毛の精度を向上させる
python background_remover.py photo.jpg --model u2net_human_seg --alpha-matting --post-process
```

## 使用技術

このツールは**AI（深層学習）技術**を使用して背景除去を行います。

### コア技術

1. **rembgライブラリ**
   - 深層学習ベースの背景除去ライブラリ
   - 初回実行時にAIモデル（約176MB）を自動ダウンロード

2. **U^2-Net（U Square Net）**
   - セマンティックセグメンテーション用の深層学習モデル
   - 画像から前景（被写体）と背景を自動的に識別
   - エンコーダー・デコーダー構造を持つCNN（畳み込みニューラルネットワーク）

3. **pymatting**
   - セグメンテーション結果を基に、より精密なマット（透明度マスク）を生成
   - エッジ部分の滑らかな処理を実現

4. **ONNX Runtime**
   - 学習済みモデルを実行するための推論エンジン
   - CPU/GPU両対応で高速な推論を実現

### 処理フロー

1. **画像入力** → PIL/Pillowで画像を読み込み
2. **AI推論** → U^2-Netモデルで前景/背景を識別
3. **マット生成** → pymattingで精密な透明度マスクを作成
4. **背景除去** → アルファチャネル付きPNGとして出力

## 機能

- **AI背景除去**: 深層学習モデル（U^2-Net）を使用して画像から背景を自動的に除去
- **マスク適用**: 背景除去後の画像に新しい背景色を適用
- **複数フォーマット対応**: JPEG、PNGなど、一般的な画像フォーマットに対応

## iOSアプリ組み込み用ツール（高精度・人物選択機能付き）

`mobile_background_remover.py` は、iOSアプリに組み込むことを想定した高精度な背景除去ツールです。

### 主な特徴

- **複数人物の自動検出**: YOLOv8を使用して画像内の人物を自動検出
- **選択的抽出**: 検出された人物の中から、抽出したい人物を選択可能
- **高精度な背景除去**: `u2net_human_seg` + アルファマッティングで高精度処理
- **ONNX Runtime対応**: iOSアプリへの移植が容易

### 使用方法

```bash
# 1. 人物を検出して可視化（人物の位置とIDを確認）
python mobile_background_remover.py image.jpg --detect

# 2. 検出された人物のうち、1人目（ID: 0）のみを抽出
python mobile_background_remover.py image.jpg --select 0

# 3. 複数の人物を選択して抽出（1人目と3人目）
python mobile_background_remover.py image.jpg --select 0 2

# 4. すべての人物を抽出
python mobile_background_remover.py image.jpg --select-all

# 5. 高精度モデルを使用（ポートレート専用）
python mobile_background_remover.py image.jpg --select 0 --model birefnet-portrait
```

### 処理フロー

1. **人物検出**: YOLOv8で画像内の人物を検出
2. **可視化**: 検出された人物にバウンディングボックスとIDを表示
3. **選択**: 抽出したい人物のIDを指定
4. **背景除去**: 選択された人物のみを高精度で背景除去

### iOSアプリへの移植

このツールは以下の技術を使用しており、iOSアプリに移植可能です：

- **ONNX Runtime**: モデル推論エンジン（iOS版あり）
- **YOLOv8**: 人物検出モデル（ONNX形式に変換可能）
- **U^2-Net**: 背景除去モデル（ONNX形式）

iOSアプリでは、ONNX Runtime for iOSを使用してモデルを実行できます。

## 参考資料

この実装は以下の記事を参考にしています：
- [簡単に背景除去する (Background remove) - Qiita](https://qiita.com/kotai2003/items/2cddf1b3e17c728439b0)

