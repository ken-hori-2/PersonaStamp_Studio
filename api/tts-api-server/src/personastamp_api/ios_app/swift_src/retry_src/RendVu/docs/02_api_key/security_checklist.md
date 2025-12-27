# セキュリティチェックリスト

## 📋 概要

GitHubにアップロードする前に、機密情報が漏洩しないか確認するチェックリストです。

---

## ✅ 現在の設定状況

### GoogleService-Info.plist

- ✅ **`.gitignore`に含まれている**
  - `RendVu/.gitignore`の96-98行目に`GoogleService-Info.plist`が含まれています
  - `**/GoogleService-Info.plist`で全てのディレクトリをカバー

- ✅ **実際のファイルは追跡されていない**
  - `git ls-files`で確認したところ、実際の`GoogleService-Info.plist`は追跡されていません
  - `.example`ファイルのみ追跡されています（これは安全です）

---

## ⚠️ 注意が必要なファイル

### GoogleService-Info.plist.backup

**状況**: `.backup`ファイルは`.gitignore`に含まれていない可能性があります

**確認方法**:
```bash
git check-ignore -v RendVu/RendVu/GoogleService-Info.plist.backup
```

**推奨対策**:
1. `.gitignore`に`*.backup`を追加
2. または、`.backup`ファイルを削除（必要に応じて）

---

## 🔍 確認手順

### 1. .gitignoreの確認

```bash
# .gitignoreにGoogleService-Info.plistが含まれているか確認
grep -i "GoogleService-Info" RendVu/.gitignore
```

**期待される結果**:
```
GoogleService-Info.plist
**/GoogleService-Info.plist
```

### 2. 追跡されているファイルの確認

```bash
# 実際のGoogleService-Info.plistが追跡されていないか確認
git ls-files | grep -i "GoogleService-Info.plist" | grep -v "\.example"
```

**期待される結果**: 何も表示されない（空）

### 3. 機密情報を含む可能性のあるファイルの確認

```bash
# .backupファイルが追跡されていないか確認
git ls-files | grep -i "\.backup"

# APIキーを含む可能性のあるファイルを検索
git ls-files | xargs grep -l "AIzaSy" 2>/dev/null | grep -v "\.example" | grep -v "\.md"
```

**期待される結果**: 何も表示されない（空）

---

## 🛡️ 推奨される対策

### 1. .gitignoreの強化

`.gitignore`に以下を追加することを推奨します:

```
# バックアップファイル
*.backup
*.bak
*~

# 機密情報を含む可能性のあるファイル
**/GoogleService-Info.plist
**/GoogleService-Info.plist.backup
**/GoogleService-Info.plist.bak
```

### 2. .exampleファイルの確認

`.example`ファイルには実際のAPIキーが含まれていないことを確認:

```bash
# .exampleファイルに実際のAPIキーが含まれていないか確認
grep -r "AIzaSy" --include="*.example" --include="*.plist.example"
```

**期待される結果**: `YOUR_API_KEY_HERE`などのプレースホルダーのみ

### 3. 過去のコミットの確認

過去のコミットに機密情報が含まれていないか確認:

```bash
# 過去のコミットでGoogleService-Info.plistが含まれていないか確認
git log --all --full-history -- "**/GoogleService-Info.plist" | grep -v "\.example"
```

もし過去のコミットに含まれている場合:
- `git filter-branch`または`git filter-repo`を使用して履歴から削除
- GitHubのSecret Scanningを有効化

---

## 📋 チェックリスト

### アップロード前の確認

- [ ] `.gitignore`に`GoogleService-Info.plist`が含まれている
- [ ] 実際の`GoogleService-Info.plist`が追跡されていない
- [ ] `.backup`ファイルが追跡されていない
- [ ] `.example`ファイルに実際のAPIキーが含まれていない
- [ ] 過去のコミットに機密情報が含まれていない

### 追加のセキュリティ対策

- [ ] GitHubのSecret Scanningを有効化
- [ ] コードレビューで機密情報の漏洩を確認
- [ ] 定期的に`.gitignore`を確認

---

## 🚨 もし機密情報が漏洩した場合

### 即座に実施すべき対策

1. **APIキーを無効化**
   - Google Cloud Console > APIとサービス > 認証情報
   - 漏洩したAPIキーを削除または無効化

2. **新しいAPIキーを作成**
   - 新しいAPIキーを作成
   - 適切な制限を設定

3. **GitHubの履歴から削除**
   - `git filter-branch`または`git filter-repo`を使用
   - または、新しいリポジトリを作成

4. **GoogleService-Info.plistを更新**
   - 新しいAPIキーで`GoogleService-Info.plist`を更新

---

## 📚 参考資料

- [GitHub Secret Scanning](https://docs.github.com/en/code-security/secret-scanning)
- [.gitignore のベストプラクティス](https://github.com/github/gitignore)

---

**更新日**: 2025年1月  
**作成者**: AI Assistant

