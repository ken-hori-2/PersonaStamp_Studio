"""
Firebase Authentication モジュール
仕様書: specs/05_AUTHENTICATION.md
"""

import os
import firebase_admin
from firebase_admin import credentials, auth
from fastapi import HTTPException, Header, Depends
from typing import Dict

# Firebase Admin SDKの初期化
_firebase_initialized = False


def initialize_firebase():
    """Firebase Admin SDKを初期化"""
    global _firebase_initialized
    
    if _firebase_initialized:
        return
    
    if not firebase_admin._apps:
        # 環境変数から認証情報を取得
        project_id = os.environ.get("FIREBASE_PROJECT_ID")
        private_key_id = os.environ.get("FIREBASE_PRIVATE_KEY_ID")
        private_key = os.environ.get("FIREBASE_PRIVATE_KEY")
        client_email = os.environ.get("FIREBASE_CLIENT_EMAIL")
        client_id = os.environ.get("FIREBASE_CLIENT_ID")
        
        if not all([project_id, private_key_id, private_key, client_email, client_id]):
            raise ValueError(
                "Firebase認証情報が環境変数に設定されていません。"
                "FIREBASE_PROJECT_ID, FIREBASE_PRIVATE_KEY_ID, FIREBASE_PRIVATE_KEY, "
                "FIREBASE_CLIENT_EMAIL, FIREBASE_CLIENT_ID を設定してください。"
            )
        
        # 秘密鍵の改行文字を処理
        if private_key:
            private_key = private_key.replace('\\n', '\n')
        
        cred = credentials.Certificate({
            "type": "service_account",
            "project_id": project_id,
            "private_key_id": private_key_id,
            "private_key": private_key,
            "client_email": client_email,
            "client_id": client_id,
            "auth_uri": "https://accounts.google.com/o/oauth2/auth",
            "token_uri": "https://oauth2.googleapis.com/token",
        })
        firebase_admin.initialize_app(cred)
        _firebase_initialized = True


def verify_firebase_token(
    authorization: str = Header(None, alias="Authorization")
) -> Dict:
    """
    Firebase IDトークンを検証してユーザー情報を返す
    
    Args:
        authorization: Authorizationヘッダー（Bearer <token>形式）
    
    Returns:
        ユーザー情報（user_id, email, firebase_uid）
    
    Raises:
        HTTPException: 認証エラーの場合
    """
    # Firebase Admin SDKを初期化
    initialize_firebase()
    
    if not authorization:
        raise HTTPException(
            status_code=401,
            detail="Authorizationヘッダーが必要です"
        )
    
    # "Bearer "を除去
    if not authorization.startswith("Bearer "):
        raise HTTPException(
            status_code=401,
            detail="Authorizationヘッダーの形式が正しくありません。Bearer <token>形式で送信してください。"
        )
    
    token = authorization[7:]  # "Bearer "を除去
    
    try:
        # トークンを検証
        decoded_token = auth.verify_id_token(token)
        user_id = decoded_token['uid']
        email = decoded_token.get('email')
        
        # ユーザーがデータベースに存在するかチェック
        # 存在しない場合は作成
        from database import get_user_by_id, create_user
        
        user = get_user_by_id(user_id)
        if not user:
            # 新規ユーザーを作成
            create_user(user_id=user_id, email=email)
        
        return {
            "user_id": user_id,
            "email": email,
            "firebase_uid": user_id
        }
    except auth.InvalidIdTokenError:
        raise HTTPException(
            status_code=401,
            detail="無効なトークンです"
        )
    except auth.ExpiredIdTokenError:
        raise HTTPException(
            status_code=401,
            detail="トークンの有効期限が切れています"
        )
    except Exception as e:
        raise HTTPException(
            status_code=401,
            detail=f"認証エラー: {str(e)}"
        )


# 依存性注入用の関数
def get_current_user(user: Dict = Depends(verify_firebase_token)) -> Dict:
    """現在のユーザー情報を取得（依存性注入用）"""
    return user

