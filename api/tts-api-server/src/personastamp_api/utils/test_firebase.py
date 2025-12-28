#!/usr/bin/env python3
"""
Firebase認証の設定をテストするスクリプト
"""

import os
import sys
from pathlib import Path

# .envファイルを読み込む
try:
    from dotenv import load_dotenv
    env_path = Path(__file__).parent / '.env'
    load_dotenv(env_path)
except ImportError:
    print("⚠️  python-dotenvがインストールされていません")
    print("   仮想環境をアクティベートしてください: source venv/bin/activate")
    sys.exit(1)

def test_firebase_config():
    """Firebase認証情報が正しく設定されているかテスト"""
    
    print("🔍 Firebase認証情報を確認中...\n")
    
    # 必要な環境変数をチェック
    required_vars = [
        'FIREBASE_PROJECT_ID',
        'FIREBASE_PRIVATE_KEY_ID',
        'FIREBASE_PRIVATE_KEY',
        'FIREBASE_CLIENT_EMAIL',
        'FIREBASE_CLIENT_ID'
    ]
    
    missing_vars = []
    for var in required_vars:
        value = os.environ.get(var)
        if not value:
            missing_vars.append(var)
            print(f"❌ {var}: 未設定")
        else:
            # 秘密鍵の場合は一部のみ表示
            if var == 'FIREBASE_PRIVATE_KEY':
                if value.startswith('"') and value.endswith('"'):
                    value = value[1:-1]  # クォートを除去
                if 'BEGIN' in value:
                    print(f"✅ {var}: 設定済み (秘密鍵)")
                else:
                    print(f"⚠️  {var}: 設定されていますが、形式が正しくない可能性があります")
            else:
                print(f"✅ {var}: {value}")
    
    if missing_vars:
        print(f"\n❌ 以下の環境変数が設定されていません:")
        for var in missing_vars:
            print(f"   - {var}")
        print("\n📝 設定方法:")
        print("   1. Firebase Consoleで認証情報を取得")
        print("   2. .envファイルに追加")
        print("   3. または setup_firebase_env.py を使用")
        return False
    
    # Firebase Admin SDKの初期化をテスト
    print("\n🔧 Firebase Admin SDKの初期化をテスト中...")
    try:
        from auth import initialize_firebase
        initialize_firebase()
        print("✅ Firebase認証の初期化に成功しました！")
        return True
    except ValueError as e:
        print(f"❌ エラー: {e}")
        return False
    except Exception as e:
        print(f"❌ 予期しないエラー: {e}")
        import traceback
        traceback.print_exc()
        return False


if __name__ == '__main__':
    if test_firebase_config():
        print("\n🎉 Firebase認証の設定が完了しています！")
        print("   サーバーを起動して動作確認してください:")
        print("   python api_server.py")
    else:
        print("\n⚠️  Firebase認証の設定が完了していません。")
        print("   詳細は FIREBASE_SETUP.md を参照してください。")
        sys.exit(1)

