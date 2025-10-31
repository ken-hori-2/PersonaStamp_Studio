# Fish Audio Demo - 環境構築ガイド

## Python環境要件

- **Python バージョン**: 3.10以上（推奨: 3.10.11）
- **OS**: Windows / macOS / Linux

## 必要なライブラリ

このプロジェクトで使用するPythonライブラリ：

### メインライブラリ
- `fish-audio-sdk` (>=2025.6.3) - Fish Audio API SDK

### 依存ライブラリ（自動インストール）
- `httpx` - HTTPクライアント
- `httpx-ws` - WebSocket対応
- `ormsgpack` - MessagePackシリアライズ
- `pydantic` - データバリデーション

### 標準ライブラリ（インストール不要）
- `os` - ファイル・ディレクトリ操作
- `datetime` - 日時処理

## インストール手順

### 1. 仮想環境の作成（推奨）

```powershell
# Windowsの場合
python -m venv env
.\env\Scripts\activate

# macOS/Linuxの場合
python3 -m venv env
source env/bin/activate
```

### 2. 必要なライブラリのインストール

```powershell
# requirements.txtを使用
pip install -r requirements.txt

# または直接インストール
pip install fish-audio-sdk
```

### 3. インストールの確認

```powershell
pip show fish-audio-sdk
```

出力例:
```
Name: fish-audio-sdk
Version: 2025.6.3
Summary: fish.audio platform api sdk
```

## セットアップ完了後

1. APIキーを環境変数に設定:
   ```powershell
   $env:FISH_AUDIO_API_KEY = "your_api_key_here"
   ```

2. スクリプトを実行:
   ```powershell
   python 2_generate_tts.py
   ```

## トラブルシューティング

### インストールエラーが発生する場合

```powershell
# pipをアップグレード
python -m pip install --upgrade pip

# 再度インストール
pip install -r requirements.txt
```

### 依存関係の問題

```powershell
# すべての依存関係を含めて再インストール
pip install --force-reinstall fish-audio-sdk
```

## バージョン情報

- **作成日**: 2025-10-31
- **Python**: 3.10.11
- **fish-audio-sdk**: 2025.6.3
