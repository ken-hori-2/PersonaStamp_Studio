"""
モックiOSクライアント用のテストスクリプト
APIの動作確認用
"""

import requests
import json
from pathlib import Path

# APIサーバーのベースURL
BASE_URL = "http://localhost:8000"

def test_create_user():
    """ユーザー作成のテスト"""
    print("=" * 50)
    print("1. ユーザー作成テスト")
    print("=" * 50)
    
    url = f"{BASE_URL}/api/v2/users"
    payload = {
        "user_id": None,  # 自動生成
        "daily_tts_limit": 20,
        "daily_clone_limit": 2
    }
    
    try:
        response = requests.post(url, json=payload)
        print(f"Status Code: {response.status_code}")
        print(f"Response: {json.dumps(response.json(), indent=2, ensure_ascii=False)}")
        
        if response.status_code == 200:
            return response.json()["api_key"]
        else:
            print(f"Error: {response.text}")
            return None
    except requests.exceptions.ConnectionError:
        print("エラー: サーバーに接続できません。サーバーが起動しているか確認してください。")
        return None

def test_tts_generate(api_key: str):
    """TTS生成のテスト"""
    print("\n" + "=" * 50)
    print("2. TTS生成テスト")
    print("=" * 50)
    
    url = f"{BASE_URL}/api/v2/tts/generate"
    headers = {
        "X-API-Key": api_key,
        "Content-Type": "application/json"
    }
    payload = {
        "text": "こんにちは。これはテスト音声です。",
        "format": "mp3",
        "speed": 1.0,
        "volume": 0
    }
    
    try:
        response = requests.post(url, json=payload, headers=headers)
        print(f"Status Code: {response.status_code}")
        
        if response.status_code == 200:
            # 音声ファイルを保存
            output_file = Path(__file__).parent / "test_output.mp3"
            with open(output_file, "wb") as f:
                f.write(response.content)
            print(f"音声ファイルを保存しました: {output_file}")
            return True
        else:
            print(f"Error: {response.text}")
            return False
    except Exception as e:
        print(f"Error: {e}")
        return False

def test_get_stats(api_key: str):
    """利用統計取得のテスト"""
    print("\n" + "=" * 50)
    print("3. 利用統計取得テスト")
    print("=" * 50)
    
    url = f"{BASE_URL}/api/v2/users/me/stats"
    headers = {
        "X-API-Key": api_key
    }
    
    try:
        response = requests.get(url, headers=headers)
        print(f"Status Code: {response.status_code}")
        print(f"Response: {json.dumps(response.json(), indent=2, ensure_ascii=False)}")
        
        return response.status_code == 200
    except Exception as e:
        print(f"Error: {e}")
        return False

def test_admin_stats():
    """管理者統計取得のテスト"""
    print("\n" + "=" * 50)
    print("4. 管理者統計取得テスト")
    print("=" * 50)
    
    url = f"{BASE_URL}/api/v2/admin/stats"
    
    try:
        response = requests.get(url)
        print(f"Status Code: {response.status_code}")
        print(f"Response: {json.dumps(response.json(), indent=2, ensure_ascii=False)}")
        
        return response.status_code == 200
    except Exception as e:
        print(f"Error: {e}")
        return False

def test_usage_limit(api_key: str):
    """利用制限のテスト（制限に達するまでリクエスト）"""
    print("\n" + "=" * 50)
    print("5. 利用制限テスト（複数回リクエスト）")
    print("=" * 50)
    
    url = f"{BASE_URL}/api/v2/tts/generate"
    headers = {
        "X-API-Key": api_key,
        "Content-Type": "application/json"
    }
    payload = {
        "text": "テスト",
        "format": "mp3"
    }
    
    # 制限に達するまでリクエスト（最大25回）
    for i in range(25):
        try:
            response = requests.post(url, json=payload, headers=headers, timeout=10)
            print(f"Request {i+1}: Status {response.status_code}", end="")
            
            if response.status_code == 200:
                print(" ✓")
            elif response.status_code == 429:
                error_detail = response.json().get('detail', '') if response.content else ''
                print(f" ✗ (制限到達: {error_detail})")
                break
            else:
                print(f" ✗ (Error: {response.text[:100]})")
                break
        except Exception as e:
            print(f" ✗ (Exception: {e})")
            break

def main():
    """メイン関数"""
    print("モックiOSクライアント - APIテスト")
    print("=" * 50)
    
    # 1. ユーザー作成
    api_key = test_create_user()
    if not api_key:
        print("\nユーザー作成に失敗しました。テストを終了します。")
        print("サーバーが起動しているか確認してください: python api_server.py")
        return
    
    print(f"\n生成されたAPIキー: {api_key}")
    
    # 2. TTS生成
    test_tts_generate(api_key)
    
    # 3. 利用統計取得
    test_get_stats(api_key)
    
    # 4. 管理者統計取得
    test_admin_stats()
    
    # 5. 利用制限テスト（オプション）
    print("\n利用制限テストを実行しますか？ (y/n): ", end="")
    try:
        choice = input().strip().lower()
        if choice == 'y':
            test_usage_limit(api_key)
    except KeyboardInterrupt:
        print("\nテストを中断しました。")
    
    print("\n" + "=" * 50)
    print("テスト完了")
    print("=" * 50)

if __name__ == "__main__":
    main()

