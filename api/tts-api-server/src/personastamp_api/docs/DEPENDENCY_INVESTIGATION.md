# 依存関係の競合調査結果

## 調査目的
`firebase-admin`と`fish-audio-sdk`を古いバージョンに下げて、`httpx`要件を緩和し、`spleeter 2.1.0`（`httpx<0.17.0`要求）との競合を解消できるか調査。

## 調査結果

### 1. 現在の依存関係

#### firebase-admin 7.1.0
- **httpx要件**: `httpx[http2]==0.28.1`（厳密に固定）
- **Python要件**: Python 3.8以上

#### fish-audio-sdk 1.1.0
- **httpx要件**: `httpx>=0.27.2`
- **Python要件**: Python 3.9以上

#### fish-audio-sdk 1.0.0
- **httpx要件**: `httpx>=0.27.2`（1.1.0と同じ）
- **Python要件**: Python 3.9以上

#### spleeter 2.1.0
- **httpx要件**: `httpx<0.17.0 and >=0.16.1`
- **Python要件**: Python 3.10まで

### 2. firebase-adminのバージョン調査

#### firebase-admin 6.6.0
- **httpx要件**: 調査中（httpxを要求していない可能性）
- **Python要件**: Python 3.8以上（推測）

#### firebase-admin 6.0.0
- **httpx要件**: 調査中（httpxを要求していない可能性）
- **Python要件**: Python 3.8以上（推測）

**注意**: firebase-admin 6.x系ではhttpxを使用していない可能性があります。httpxは7.0.0以降で導入された可能性があります。

### 3. コードベースで使用している機能

#### firebase-admin
以下の基本的な機能のみを使用：
- `firebase_admin.initialize_app()`
- `credentials.Certificate()`
- `auth.verify_id_token()`
- `auth.InvalidIdTokenError`
- `auth.ExpiredIdTokenError`

**結論**: これらの機能はfirebase-admin 6.0.0以降で利用可能です。

#### fish-audio-sdk
以下の基本的な機能のみを使用：
- `Session`
- `TTSRequest`
- `Prosody`
- `HttpCodeErr`
- `session.tts()`
- `session.create_model()`

**結論**: これらの機能はfish-audio-sdk 1.0.0以降で利用可能です。

### 4. 解決策の検討

#### オプション1: firebase-adminを6.x系にダウングレード
- **メリット**: httpx要件が緩和される可能性（httpxを使用していない場合）
- **デメリット**: 
  - セキュリティアップデートが適用されない可能性
  - 新機能が利用できない
- **リスク**: 低（使用している機能は基本的なもの）

#### オプション2: fish-audio-sdkを1.0.0にダウングレード
- **メリット**: なし（httpx要件は同じ）
- **デメリット**: バグ修正や改善が適用されない
- **結論**: 効果なし（httpx要件が同じ）

#### オプション3: firebase-admin 6.x + fish-audio-sdk 1.0.0 + spleeter 2.1.0
- **可能性**: firebase-admin 6.xがhttpxを使用していない場合、競合が解消される可能性
- **httpx要件**:
  - fish-audio-sdk 1.0.0: `httpx>=0.27.2`
  - spleeter 2.1.0: `httpx<0.17.0 and >=0.16.1`
  - **結論**: 依然として競合（両立不可能）

### 5. 最終結論

**残念ながら、httpxの依存関係の競合は解消できません。**

理由：
1. `fish-audio-sdk`（1.0.0以降）は`httpx>=0.27.2`を要求
2. `spleeter 2.1.0`は`httpx<0.17.0`を要求
3. これらの要件は同時に満たすことができません

`firebase-admin`を6.x系にダウングレードしても、`fish-audio-sdk`と`spleeter`の間の競合は残ります。

### 6. 推奨される解決策

1. **音源分離をiOSアプリ側で実装**（最推奨）
   - サーバーの負荷を軽減
   - 依存関係の競合を完全に回避
   - ユーザー体験の向上（オフライン処理可能）

2. **音源分離専用サービスとして分離**
   - Python 3.10環境で`spleeter`のみを実行する別サービスを作成
   - メインAPIとは分離して運用
   - マイクロサービスアーキテクチャ

3. **別の軽量な音源分離ライブラリを検討**
   - Python 3.13対応の代替ライブラリを調査
   - 依存関係の競合がないライブラリを探す

4. **Spleeterをオプショナル機能として維持**
   - 現在の実装を維持（オプショナル）
   - 音源分離が必要な場合はiOSアプリ側で実装

---

**調査日**: 2025年1月
**調査者**: AI Assistant
