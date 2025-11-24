#!/usr/bin/env python3
"""
Firebase認証情報をJSONファイルから.envファイルに追加するスクリプト
"""

import json
import sys
import os
from pathlib import Path

def setup_firebase_env(json_file_path: str):
    """Firebase認証情報をJSONファイルから.envファイルに追加"""
    
    # JSONファイルを読み込む
    try:
        with open(json_file_path, 'r') as f:
            firebase_config = json.load(f)
    except FileNotFoundError:
        print(f"❌ エラー: ファイルが見つかりません: {json_file_path}")
        return False
    except json.JSONDecodeError as e:
        print(f"❌ エラー: JSONの解析に失敗しました: {e}")
        return False
    
    # 必要な情報を取得
    project_id = firebase_config.get('project_id')
    private_key_id = firebase_config.get('private_key_id')
    private_key = firebase_config.get('private_key')
    client_email = firebase_config.get('client_email')
    client_id = firebase_config.get('client_id')
    
    if not all([project_id, private_key_id, private_key, client_email, client_id]):
        print("❌ エラー: JSONファイルに必要な情報が不足しています")
        return False
    
    # .envファイルのパス
    env_file = Path(__file__).parent / '.env'
    
    # 既存の.envファイルを読み込む
    env_vars = {}
    if env_file.exists():
        with open(env_file, 'r') as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith('#') and '=' in line:
                    key, value = line.split('=', 1)
                    env_vars[key.strip()] = value.strip()
    
    # Firebase認証情報を追加/更新
    env_vars['FIREBASE_PROJECT_ID'] = project_id
    env_vars['FIREBASE_PRIVATE_KEY_ID'] = private_key_id
    env_vars['FIREBASE_PRIVATE_KEY'] = f'"{private_key}"'  # ダブルクォートで囲む
    env_vars['FIREBASE_CLIENT_EMAIL'] = client_email
    env_vars['FIREBASE_CLIENT_ID'] = client_id
    
    # .envファイルに書き込む
    with open(env_file, 'w') as f:
        f.write("# Fish Audio API\n")
        if 'FISH_AUDIO_API_KEY' in env_vars:
            f.write(f'FISH_AUDIO_API_KEY={env_vars["FISH_AUDIO_API_KEY"]}\n')
        f.write("\n# Firebase Authentication\n")
        f.write(f'FIREBASE_PROJECT_ID={env_vars["FIREBASE_PROJECT_ID"]}\n')
        f.write(f'FIREBASE_PRIVATE_KEY_ID={env_vars["FIREBASE_PRIVATE_KEY_ID"]}\n')
        f.write(f'FIREBASE_PRIVATE_KEY={env_vars["FIREBASE_PRIVATE_KEY"]}\n')
        f.write(f'FIREBASE_CLIENT_EMAIL={env_vars["FIREBASE_CLIENT_EMAIL"]}\n')
        f.write(f'FIREBASE_CLIENT_ID={env_vars["FIREBASE_CLIENT_ID"]}\n')
        f.write("\n# その他\n")
        if 'MONTHLY_COST_LIMIT' in env_vars:
            f.write(f'MONTHLY_COST_LIMIT={env_vars["MONTHLY_COST_LIMIT"]}\n')
        else:
            f.write('MONTHLY_COST_LIMIT=5000.0\n')
        if 'PORT' in env_vars:
            f.write(f'PORT={env_vars["PORT"]}\n')
        else:
            f.write('PORT=8000\n')
    
    print("✅ Firebase認証情報を.envファイルに追加しました")
    print(f"\n設定された情報:")
    print(f"  - Project ID: {project_id}")
    print(f"  - Client Email: {client_email}")
    print(f"\n⚠️  注意: .envファイルを確認して、FIREBASE_PRIVATE_KEYが正しく設定されているか確認してください。")
    
    return True


if __name__ == '__main__':
    if len(sys.argv) != 2:
        print("使用方法: python setup_firebase_env.py <firebase-json-file-path>")
        print("\n例:")
        print("  python setup_firebase_env.py ~/Downloads/personastamp-studio-firebase-adminsdk-xxxxx.json")
        sys.exit(1)
    
    json_file_path = sys.argv[1]
    if setup_firebase_env(json_file_path):
        print("\n✅ 設定完了！サーバーを再起動してください。")
    else:
        print("\n❌ 設定に失敗しました。")
        sys.exit(1)

