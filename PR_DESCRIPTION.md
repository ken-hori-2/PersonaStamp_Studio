## 変更内容
- フォルダ名 `init_test` から `stamp_creator` への変更に伴う依存関係の更新
- Xcodeプロジェクトファイル（`project.pbxproj`）内のプロジェクト名、ターゲット名、アプリ名を `stamp_creator` に変更
- Bundle Identifier を `com.ken.init-test` から `com.ken.stamp-creator` に変更
- Swiftファイル `init_testApp.swift` を `stamp_creatorApp.swift` にリネームし、構造体名とコメントを更新
- `ContentView.swift` のコメント内のプロジェクト名を更新
- ドキュメントファイル（`実行手順.md`、`実機での実行時の問題と対処法.md`、`CoreMLモデルについて.md`）内の参照を更新
- Xcodeスキーム管理ファイル（`xcschememanagement.plist`）のスキーム名を更新
- 埋め込まれたGitリポジトリ（`.git` フォルダ）を削除して警告を解消

## 変更理由
フォルダ名を `init_test` から `stamp_creator` に変更したことに伴い、プロジェクト内のすべての参照を新しい名前に対応させる必要がありました。これにより、Xcodeプロジェクトが正常にビルド・実行できるようになります。

また、`stamp_creator` フォルダ内に埋め込まれていたGitリポジトリを削除することで、メインリポジトリに正常に追加できるようになりました。

## 関連Issue
なし

## 確認事項
- [ ] Xcodeでプロジェクトが正常に開けること
- [ ] プロジェクトが正常にビルドできること
- [ ] アプリが正常に実行できること
- [ ] ドキュメント内の手順が正しく更新されていること
- [ ] Gitの警告が表示されないこと

## テスト方法
1. Xcodeで `stamp_creator.xcodeproj` を開く
2. プロジェクトが正常に読み込まれることを確認
3. ターゲット `stamp_creator` を選択してビルド（`Cmd + B`）
4. ビルドが成功することを確認
5. シミュレータまたは実機で実行（`Cmd + R`）
6. アプリが正常に起動することを確認
7. ドキュメント（`実行手順.md`）に記載されている手順を確認

