# Render デプロイ設定ガイド

## 起動コマンドの変更

プロジェクト構造を整理したため、Renderの起動コマンドを以下のように変更してください。

### 変更前
```bash
python api_server.py
```
または
```bash
uvicorn api_server:app --host 0.0.0.0 --port $PORT
```

### 変更後（推奨）
```bash
python main.py
```
または
```bash
uvicorn main:app --host 0.0.0.0 --port $PORT
```

## Render ダッシュボードでの設定

1. **Render ダッシュボードにログイン**
2. **サービスを選択**
3. **Settings タブを開く**
4. **Build & Deploy セクションで以下を設定**:
   - **Start Command**: `python main.py`
   - または: `uvicorn main:app --host 0.0.0.0 --port $PORT`

## 新しいプロジェクト構造

```
personastamp_api/
├── core/                    # コアAPIコード
│   ├── api_server.py        # メインAPIサーバー
│   ├── auth.py              # 認証モジュール
│   ├── database.py          # データベースモジュール
│   └── fish_audio_client.py # Fish Audio APIクライアント
│
├── admin/                   # 管理者機能
│   └── admin_dashboard.py  # Streamlitダッシュボード
│
├── utils/                   # ユーティリティ・テスト
│   ├── setup_firebase_env.py
│   └── test_firebase.py
│
├── config/                  # 設定ファイル（機密情報含む）
│   └── GoogleService-Info.plist
│
├── storage/                 # 生成ファイル・データベース
│   ├── generated_audio/     # 生成された音声ファイル
│   └── tts_app.db          # データベース
│
├── docs/                    # ドキュメント
├── ios_app/                 # iOSアプリ
├── main.py                  # エントリーポイント（新規）
├── requirements.txt
└── README.md
```

## 環境変数

環境変数は変更不要です。以下の環境変数が設定されていることを確認してください：

- `FISH_AUDIO_API_KEY`
- `FIREBASE_PROJECT_ID`
- `FIREBASE_PRIVATE_KEY_ID`
- `FIREBASE_PRIVATE_KEY`
- `FIREBASE_CLIENT_EMAIL`
- `FIREBASE_CLIENT_ID`
- `ADMIN_EMAILS` (管理者向けAPI用)
- `PORT` (Renderが自動設定)

## ローカル開発環境での起動

ローカル開発環境でも同様に`main.py`を使用できます：

```bash
# 仮想環境をアクティベート
source venv/bin/activate

# サーバーを起動
python main.py
```

または：

```bash
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

## トラブルシューティング

### インポートエラーが発生する場合

プロジェクトのルートディレクトリ（`personastamp_api/`）がPythonパスに含まれていることを確認してください。

Renderでは自動的に設定されますが、ローカル環境で問題が発生する場合は：

```bash
export PYTHONPATH="${PYTHONPATH}:$(pwd)"
```

---

**更新日**: 2025年1月
**作成者**: AI Assistant

