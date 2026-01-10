# 管理者設定ガイド

## 📋 概要

管理者機能は**Webインターフェース（Streamlitダッシュボード）でのみ利用可能**です。iOSアプリからは管理者APIにアクセスできません。

---

## 🔒 セキュリティ設計

### 管理者機能の分離

- **iOSアプリ**: エンドユーザー向け機能のみ（TTS生成、Voice Clone作成、モデル管理）
- **Webダッシュボード**: 管理者向け機能（コスト管理、ユーザー統計、全体分析）

この設計により：
- ✅ モバイルアプリのサイズを小さく保つ
- ✅ セキュリティリスクを最小化
- ✅ 管理者機能の更新が容易
- ✅ エンドユーザーと管理者の機能を明確に分離

---

## ⚙️ 管理者メールアドレスの設定

### Render（本番環境）での設定

1. **Renderダッシュボードにログイン**
   - https://dashboard.render.com

2. **サービスを選択**
   - `personastamp-studio` サービスを選択

3. **環境変数を設定**
   - 「Environment」タブを開く
   - 「Add Environment Variable」をクリック
   - 以下を追加：

   ```
   Key: ADMIN_EMAILS
   Value: admin@example.com,manager@example.com
   ```

   **重要**: 複数の管理者を設定する場合は、カンマ（`,`）で区切ります。

4. **サービスを再デプロイ**
   - 環境変数を追加した後、サービスを再デプロイしてください

### ローカル開発環境での設定

`.env`ファイルに追加：

```env
ADMIN_EMAILS=admin@example.com,manager@example.com
```

または、環境変数として設定：

```bash
export ADMIN_EMAILS="admin@example.com,manager@example.com"
```

---

## 🔍 現在の管理者設定を確認

### Renderでの確認方法

1. Renderダッシュボードでサービスを選択
2. 「Environment」タブで`ADMIN_EMAILS`の値を確認

### バックエンドログで確認

バックエンドサーバーの起動時に、管理者メールアドレスがログに表示されます（実装が必要な場合は追加可能）。

---

## 📝 管理者の追加・削除

### 管理者を追加する場合

1. Renderダッシュボードで`ADMIN_EMAILS`環境変数を編集
2. 新しいメールアドレスを追加（カンマ区切り）
3. サービスを再デプロイ

**例**:
```
既存: admin@example.com
追加後: admin@example.com,newadmin@example.com
```

### 管理者を削除する場合

1. Renderダッシュボードで`ADMIN_EMAILS`環境変数を編集
2. 削除するメールアドレスを削除
3. サービスを再デプロイ

---

## ⚠️ 注意事項

1. **メールアドレスの正確性**
   - 管理者メールアドレスは、Firebase Authenticationで登録されているメールアドレスと**完全に一致**する必要があります
   - 大文字・小文字は区別されません（自動的に小文字に変換されます）

2. **セキュリティ**
   - 管理者メールアドレスは機密情報です
   - 環境変数として安全に管理してください
   - 公開リポジトリにコミットしないでください

3. **iOSアプリからのアクセス**
   - iOSアプリから管理者APIにアクセスしようとしても、管理者でない場合は403エラーが返されます
   - 管理者がiOSアプリを使用する場合でも、管理者機能にはアクセスできません（Webダッシュボードを使用してください）

---

## 🚀 管理者ダッシュボードの起動

管理者ダッシュボードを起動するには：

```bash
# 環境変数を設定（ローカル開発の場合）
export ADMIN_EMAILS="admin@example.com"
export API_BASE_URL="https://personastamp-studio.onrender.com"

# ダッシュボードを起動
streamlit run admin_dashboard.py
```

詳細は [ADMIN_DASHBOARD_README.md](./ADMIN_DASHBOARD_README.md) を参照してください。

---

## 📞 サポート

管理者設定に関する問題がある場合：

1. 環境変数`ADMIN_EMAILS`が正しく設定されているか確認
2. メールアドレスがFirebase Authenticationで登録されているか確認
3. バックエンドサーバーを再デプロイ

---

**更新日**: 2025年1月  
**作成者**: AI Assistant







